# AI prayer assistant — architecture

Status: **pipeline implemented and unit-tested in `PLAssistant`; no language model connected;
no assistant UI yet.** Without a model the pipeline answers from the verified library and says
so (`.generationUnavailable`).

## Pipeline

```
USER REQUEST
  → 1. SAFETY ROUTER        on-device, before anything else            (LocalSafetyRouter)
  → 2. INTENT               faith / practice / focus / mood / themes / weekday / reference (IntentParser)
  → 3. FAITH CONTEXT        tradition, today's observances, devotional customs   (FaithContextResolver)
  → 4. SOURCE RETRIEVAL     verified passages from the curated catalog  (CatalogSourceRetriever)
  → 5. GENERATION           optional; server-side proxy                (GenerationProvider)
  → 6. RESPONSE VALIDATION  untrusted draft → provenance-labelled segments (ResponseValidator)
  → USER                    segments + notices (crisis resources, disclaimers, removals, customs)
```
Every stage is a protocol or value type and can be replaced independently.

## 1. Safety routing

- **Crisis** (self-harm, harm to others, abuse) → no generation; show region-aware resources
  (US 988, UK/IE Samaritans 116 123, India Tele-MANAS 14416) plus the universal "contact local
  emergency services". Numbers must be re-verified before each release.
- **Medical/psychological advice** ("should I stop taking my medication") → proceed with a
  clear *not medical advice* notice. Prayer for someone's healing is fine; advice is not.
- **Decline** — only a narrow phrase list in Phase 1 (broad words like "mock" appear in sincere
  requests: "they mock my faith — give me strength"). Nuance belongs to layer 2.
- Layer 1 is deterministic, English-only, conservative (false positives show support resources).
  **Layer 2** (planned): a server-side classifier model before generation, multilingual.

## 2–4. Grounding

- Retrieval scope is decided by **code**, not by the model: requested faith (an explicit
  request for another faith is honoured), user's tradition only within their own faith,
  requested focus, mood/themes, today's observances, opt-in customs.
- Retrieval uses the same `ContentSelector` and `ContentPolicy` as prayer moments, so drafts
  and uncleared editions can't leak into answers in release builds.
- A prayer request is still grounded: if the requested kind has no citable sources, retrieval
  falls back to source passages across kinds.
- "Shiva mantra for Monday" → the weekday custom is attached as an *explanation* notice
  ("In many Hindu communities…"), never asserted.

## 5. Generation (planned backend)

- The app never holds model-provider API keys. It will call a **Prayer Lock proxy**
  (`PLAssistantEndpoint`), which holds keys, runs layer-2 safety, rate-limits, and logs no
  content by default.
- What leaves the device (`GenerationPrompt`): the typed request, faith/tradition/focus IDs,
  mood if the user chose one for this request, language, devotional notes, and the retrieved
  passages. **Never** the name, history, journal, or device identifiers (unit-tested).
- The model must output structured JSON (`GenerationDraft`): each segment has a `role`; quotes
  are made only by `passageID`. Rules sent with every request: `PromptBuilder.rules`.
- Model choice is deferred; latest Claude models are a strong default for safety and
  instruction following.

## 6. Validation (enforced regardless of model behaviour)

| Draft segment | Result |
|---|---|
| `sourceText`/`traditionalText` **with** a valid `passageID` | replaced by the **library's verified segment** (the model's wording is discarded) |
| `sourceText`/`traditionalText` without a valid ID | **removed** (+ notice) |
| any generated text citing a reference not among retrieved passages (e.g. "John 3:16") | **removed** |
| generated text containing a quotation ≥ 6 words | **removed** (could be fabricated scripture) |
| `paraphrase` without a valid source | relabelled `devotionalInterpretation` |
| `composedPrayer` from the model | relabelled `generatedPrayer`, author "AI-generated" |

Users therefore always see the distinction the product requires: **verified source text ·
paraphrase · AI-generated prayer · explanation · devotional interpretation**.

## Product rules for the assistant UI (later phase)

- Opt-in; first use explains what is sent and to whom.
- Every answer shows provenance labels; AI text is visually distinct.
- Report button on every answer (App Store 1.2-style safeguards for generated content).
- No conversation history stored server-side; local history optional and deletable.
- Premium-gated per `monetization.json` (`assistant`), decided at pricing time.
