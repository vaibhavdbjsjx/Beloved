# Beloved — premium phase roadmap

Date: 2026-10-11. Owner brief (paraphrased): every feature must be genuinely useful and worth
paying for, across all faiths, with **extra depth for Christians** (the largest paying market for
this category). A faith-aware companion that is as good to talk to as a general chatbot, but
humble, faith-scoped and never misquoting. Hindu users should be able to ask for a mantra by deity
or purpose (e.g. during pregnancy), the Hanuman Chalisa, the Gayatri mantra. Per-faith colour
themes. No arch/mosque-like motif. A new, premium dove logo.

Owner decisions (2026-10-11): companion = **cloud model for subscribers** (Gemini through
Beloved's own Cloudflare Worker; library answers for free users); logo = **dove, "Halo"
direction**.

## Status

| # | Work | State |
|---|---|---|
| 1 | Dove logo ("Halo"): icon, in-app marks, shield icon from one geometry (D53) | done |
| 2 | Arch motif removed: circle of light, beads, circular status marks (D53) | done |
| 3 | Per-faith themes: lapis (Christian/brand), emerald (Islam), saffron (Hindu) (D53) | done |
| 4 | Companion: verified-text markers, faith-scoped prompt, chat UI, history on device | done |
| 5 | Companion server: Cloudflare Worker, StoreKit JWS check, daily cap, streaming | deployed with Gemini free tier; `/health` rechecked 2026-10-12 |
| 6 | Libraries with verified sources: Christian traditional prayers (BCP 1662, creeds, Hail Mary…), Hindu mantras by deity and purpose (Hanuman Chalisa, Gayatri, Mahamrityunjaya, Santana Gopala…), Islamic duas and dhikr | planned |
| 7 | Onboarding: what you'd like help with (life situations, prayer goals) feeding the companion and content | planned |
| 8 | Christian depth: prayer journal and prayer requests (answered/ongoing), Bible reading plans, verse memorisation | planned |
| 9 | Counter for rosary / tasbih / japa mala | planned |
| 10 | Islam: prayer times (on-device calculation) and qibla | planned |
| 11 | Home-screen and Lock Screen verse widget | planned |
| 12 | Subscription: StoreKit products (owner creates in App Store Connect), paywall listing only real features | in progress |

## Companion design

- **The model never writes holy text.** It inserts markers — `⟦bible:PSA 23:1-3⟧`,
  `⟦quran:94:5-6⟧`, `⟦gita:2:47⟧`, `⟦prayer:hanuman-chalisa⟧` — and the app replaces each with the
  verified text from the on-device library, with its source. An unresolvable marker is shown as a
  plain reference, never as text.
- **Faith-scoped.** The system prompt carries the user's faith, tradition, focus and (only if
  they chose to share it) what they'd like help with. It answers within that tradition, says
  plainly where traditions differ, and doesn't compare faiths.
- **Humble and safe.** Not a priest, imam or pandit; suggests speaking to one for weighty
  matters. Crisis language routes to helplines (SafetyRouter). No medical claims: a mantra
  "traditionally recited during pregnancy" is offered as devotion, never as treatment.
- **Privacy.** Messages go to our proxy and the model provider only for subscribers who use the
  companion; nothing is stored server-side beyond a per-subscription daily counter. The privacy
  policy and App Store privacy label change before release.
