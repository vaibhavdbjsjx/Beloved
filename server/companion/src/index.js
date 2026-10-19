// Beloved companion server (Cloudflare Worker).
//
//   POST /v1/companion   { messages: [{role, text}], context: {...} }
//        Header X-Beloved-Subscription: StoreKit 2 signed transaction (JWS) → Premium allowance
//        Header X-Beloved-Install: random per-install UUID → free allowance
//        → text/event-stream: data: {"type":"delta","text":"…"} … data: {"type":"done"}
//   GET  /health
//
// Holds the model API key (secret GEMINI_API_KEY); stores nothing about conversations.
// The only state is a per-subscription daily counter in KV (USAGE), kept for two days.

import { APPLE_ROOT_CA_G3_SHA256, VerificationError, verifySubscription } from "./jws.js";
import { systemPrompt } from "./prompt.js";

const MAX_BODY_BYTES = 200_000;
const MAX_TURNS = 24;
const MAX_CHARS = 4_000;
const FAITHS = new Set(["christianity", "islam", "hinduism"]);

export default {
  fetch(request, env, ctx) {
    return handle(request, env, ctx);
  },
};

function json(status, body) {
  return new Response(JSON.stringify(body), { status, headers: { "content-type": "application/json" } });
}

const str = (value, max) => (typeof value === "string" ? value.slice(0, max) : null);
const strList = (value, maxItems, maxChars) =>
  Array.isArray(value) ? value.filter((v) => typeof v === "string").slice(0, maxItems).map((v) => v.slice(0, maxChars)) : [];

/** Validates and normalises the app's request. Returns { messages, context } or null. */
export function validateRequest(body) {
  if (!body || typeof body !== "object" || !Array.isArray(body.messages)) return null;
  const messages = body.messages.slice(-MAX_TURNS);
  if (messages.length === 0) return null;
  const turns = [];
  for (const [index, message] of messages.entries()) {
    const role = message?.role;
    const text = str(message?.text, MAX_CHARS)?.trim();
    if (!(role === "user" || role === "assistant") || !text) return null;
    if (role !== (index % 2 === 0 ? "user" : "assistant")) return null; // alternate, starting with the user
    turns.push({ role, content: text });
  }
  if (turns[turns.length - 1].role !== "user") return null;

  const c = body.context && typeof body.context === "object" ? body.context : {};
  const faith = FAITHS.has(c.faith) ? c.faith : null;
  const library = Array.isArray(c.library)
    ? c.library.slice(0, 200).filter((i) => typeof i?.id === "string" && /^[a-z0-9.\-]{1,80}$/.test(i.id)).map((i) => ({
        id: i.id,
        title: str(i.title, 80) ?? i.id,
        kind: str(i.kind, 30) ?? "prayer",
        themes: strList(i.themes, 8, 30),
      }))
    : [];
  const context = {
    faith,
    tradition: str(c.tradition, 80),
    focuses: strList(c.focuses, 6, 60),
    language: str(c.language, 20) ?? "en",
    helpWith: strList(c.helpWith, 10, 60),
    scripture: strList(c.scripture, 3, 20).filter((w) => ["bible", "quran", "bhagavad-gita"].includes(w)),
    library,
    today: str(c.today, 40),
    observances: strList(c.observances, 8, 120),
  };
  return { messages: turns, context };
}

function utcDay(now) {
  return new Date(now).toISOString().slice(0, 10);
}

export async function handle(request, env, ctx, deps = {}) {
  const now = deps.now ?? Date.now();
  const upstreamFetch = deps.fetch ?? fetch;
  const url = new URL(request.url);

  if (request.method === "GET" && url.pathname === "/health") return json(200, { ok: true });
  if (!(request.method === "POST" && url.pathname === "/v1/companion")) return json(404, { error: "not_found" });
  if (!env.GEMINI_API_KEY || !env.BUNDLE_ID || !env.PRODUCT_IDS) return json(503, { error: "unavailable" });

  const length = Number(request.headers.get("content-length") ?? 0);
  if (length > MAX_BODY_BYTES) return json(413, { error: "too_large" });
  let body;
  try {
    const raw = await request.text();
    if (raw.length > MAX_BODY_BYTES) return json(413, { error: "too_large" });
    body = JSON.parse(raw);
  } catch {
    return json(400, { error: "bad_request" });
  }
  const valid = validateRequest(body);
  if (!valid) return json(400, { error: "bad_request" });

  // Premium: an Apple-signed, active subscription of ours. Anyone else is a free user with
  // a smaller daily allowance, counted per install and per network address.
  let subscription = null;
  const proof = request.headers.get("x-beloved-subscription");
  if (proof) {
    try {
      subscription = await verifySubscription(proof, {
        rootFingerprints: [APPLE_ROOT_CA_G3_SHA256, ...(deps.extraRootFingerprints ?? [])],
        bundleId: env.BUNDLE_ID,
        productIds: env.PRODUCT_IDS.split(",").map((s) => s.trim()).filter(Boolean),
        environments: (env.ENVIRONMENTS ?? "Production").split(",").map((s) => s.trim()),
        now,
        requireAppleExtensions: deps.requireAppleExtensions ?? true,
      });
    } catch (error) {
      if (!(error instanceof VerificationError)) throw error;
    }
  }
  const install = request.headers.get("x-beloved-install") ?? "";
  if (!subscription && !/^[0-9a-fA-F-]{36}$/.test(install)) return json(400, { error: "bad_request" });

  if (env.USAGE) {
    const day = utcDay(now);
    const counters = subscription
      ? [[`u:${subscription.originalTransactionId}:${day}`, Number(env.DAILY_LIMIT ?? 100)]]
      : [[`f:${install.toLowerCase()}:${day}`, Number(env.FREE_DAILY_LIMIT ?? 10)],
         [`ip:${request.headers.get("cf-connecting-ip") ?? "unknown"}:${day}`, Number(env.FREE_IP_LIMIT ?? 40)]];
    const used = await Promise.all(counters.map(([key]) => env.USAGE.get(key).then((v) => Number(v ?? 0))));
    if (counters.some(([, limit], i) => used[i] >= limit)) {
      return json(429, { error: subscription ? "limit" : "free_limit" });
    }
    await Promise.all(counters.map(([key], i) => env.USAGE.put(key, String(used[i] + 1), { expirationTtl: 60 * 60 * 48 })));
  }

  const model = env.MODEL ?? "gemini-flash-latest";
  // Thinking models spend output tokens on hidden reasoning, so the budget must leave room for
  // the answer itself; grounding with Google Search makes stories and practices more accurate.
  // Each optional feature falls away if the model or the free tier refuses it.
  const features = {
    grounding: env.GROUNDING === "1",
    thinking: env.THINKING_BUDGET !== undefined && env.THINKING_BUDGET !== "",
  };
  const callModel = () => upstreamFetch(
    `https://generativelanguage.googleapis.com/v1beta/models/${model}:streamGenerateContent?alt=sse`,
    {
      method: "POST",
      // A hung upstream must not hold the person for minutes: give up and retry.
      signal: AbortSignal.timeout(Number(env.UPSTREAM_TIMEOUT_MS ?? 40_000)),
      headers: { "content-type": "application/json", "x-goog-api-key": env.GEMINI_API_KEY },
      body: JSON.stringify({
        systemInstruction: { parts: [{ text: systemPrompt(valid.context) }] },
        contents: valid.messages.map((m) => ({ role: m.role === "assistant" ? "model" : "user", parts: [{ text: m.content }] })),
        ...(features.grounding ? { tools: [{ google_search: {} }] } : {}),
        generationConfig: {
          maxOutputTokens: Number(env.MAX_TOKENS ?? 6000),
          temperature: 0.4,
          ...(features.thinking ? { thinkingConfig: { thinkingBudget: Number(env.THINKING_BUDGET) } } : {}),
        },
      }),
    },
  );
  const timedOut = () => new Response("timeout", { status: 504 });
  let upstream = await callModel().catch(timedOut);
  for (let attempt = 1; attempt <= 3 && !upstream.ok; attempt++) {
    if (upstream.status === 500 || upstream.status === 503 || upstream.status === 504) {
      // Gemini's free tier is sometimes briefly busy: wait and retry.
      await new Promise((resolve) => setTimeout(resolve, (deps.retryDelayMs ?? 1200) * attempt));
    } else if (upstream.status === 400 && features.thinking) {
      features.thinking = false;
    } else if ([400, 403, 429].includes(upstream.status) && features.grounding) {
      features.grounding = false;
    } else {
      break;
    }
    const detail = await upstream.text().catch(() => "");
    console.log(`retrying after upstream ${upstream.status}: ${detail.slice(0, 200)}`);
    upstream = await callModel().catch(timedOut);
  }
  if (!upstream.ok || !upstream.body) {
    const detail = await upstream.text().catch(() => "");
    console.log(`upstream ${upstream.status}: ${detail.slice(0, 300)}`);
    return json(upstream.status === 429 ? 429 : 503, { error: upstream.status === 429 ? "busy" : "unavailable", upstream: upstream.status });
  }

  const { readable, writable } = new TransformStream();
  const pump = relay(upstream.body, writable);
  if (ctx?.waitUntil) ctx.waitUntil(pump);
  return new Response(readable, {
    status: 200,
    headers: { "content-type": "text/event-stream", "cache-control": "no-store" },
  });
}

/** Re-emits the model's text deltas as the app's simple event stream. */
export async function relay(upstreamBody, writable) {
  const writer = writable.getWriter();
  const encoder = new TextEncoder();
  const send = (event) => writer.write(encoder.encode(`data: ${JSON.stringify(event)}\n\n`));
  const reader = upstreamBody.pipeThrough(new TextDecoderStream()).getReader();
  let buffer = "";
  let finished = false;
  try {
    while (!finished) {
      const { value, done } = await reader.read();
      if (done) break;
      buffer += value;
      let newline;
      while ((newline = buffer.indexOf("\n")) >= 0) {
        const line = buffer.slice(0, newline).trimEnd();
        buffer = buffer.slice(newline + 1);
        if (!line.startsWith("data:")) continue;
        let event;
        try {
          event = JSON.parse(line.slice(5).trim());
        } catch {
          continue;
        }
        if (event.error) {
          await send({ type: "error", code: "unavailable" });
          finished = true;
          break;
        }
        const text = (event.candidates?.[0]?.content?.parts ?? []).map((p) => p.text ?? "").join("");
        if (text) await send({ type: "delta", text });
      }
    }
    if (!finished) await send({ type: "done" });
  } catch {
    try {
      await send({ type: "error", code: "unavailable" });
    } catch {}
  } finally {
    try {
      await writer.close();
    } catch {}
  }
}
