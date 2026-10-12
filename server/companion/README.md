# Beloved companion server

A Cloudflare Worker between the app and the model provider. It:

- verifies the App Store's signed subscription proof (StoreKit 2 transaction JWS) against Apple's
  pinned root certificate (Apple Root CA – G3), and checks bundle, product, expiry, revocation;
- applies a daily fair-use allowance per subscription (KV counter, kept 48 h — nothing else is stored);
- owns the system prompt (`src/prompt.js`): faith-scoped, humble, and forbidden from writing holy
  text — it emits markers the app fills from its verified on-device library;
- streams the reply as simple events (`data: {"type":"delta","text":"…"}` … `{"type":"done"}`).

Tests: `node --test server/companion/test/*.test.js` (uses a TEST-ONLY certificate chain in
`test/fixtures`; production trusts only Apple's root).

## Deploy (owner)

Needs: a Cloudflare account, a Google AI Studio (Gemini) API key, the final bundle ID and subscription product IDs.

1. `cd server/companion && npx wrangler login`
2. `npx wrangler kv namespace create USAGE` → put the id in `wrangler.toml`.
3. Set `BUNDLE_ID` and `PRODUCT_IDS` in `wrangler.toml` (they must match App Store Connect).
4. `npx wrangler secret put GEMINI_API_KEY` → paste the key when asked (type it yourself; it is
   never stored in the repo or the app).
5. `npx wrangler deploy` → note the `*.workers.dev` URL (or attach a custom domain).
6. Set `PL_COMPANION_URL` in `Config/Secrets.xcconfig` (or the build settings) to that URL.
7. Check: `curl https://<url>/health` → `{"ok":true}`.

Cost control: `DAILY_LIMIT` messages per subscriber per day, `MAX_TOKENS` per answer, `MODEL`.
