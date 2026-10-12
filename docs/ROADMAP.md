# Roadmap

| Phase | Goal | Exit criteria |
|---|---|---|
| **1 — Foundation** (done) | Research, architecture, domain modules with tests, app + extensions compiling, docs | `swift test` green; app/extensions/test bundles build for iOS |
| **2 — Lock loop** (code done; device validation pending) | Protection engine + iOS adapter + extensions, token expiry, recovery states, diagnostics | Done: 141 unit tests, all iOS builds. **Pending:** device test plan (docs/11) on iOS 18 / 26.4 / 26.5+ |
| **2.5 — Pre-device readiness** (done) | Audit identity, signing, entitlements, assumptions, docs (docs/13) | No code claims beyond evidence |
| **5 — App Store readiness** (done 2026-10-05) | Brand "Beloved", icon, privacy policy (app + web), placeholder removal, release gates, metadata & review notes (docs/19–20) | 145 tests; Release build/analyze clean. **Not submittable** — see docs/19 §17 |
| **Next — Device validation** | Paid team + Team ID + identity → signed build → docs/11 on a real iPhone | Results logged in docs/11; distribution request filed only after the name is final |
| 3 — Content & brand | Original brand/name/icon; first reviewed, licensed content packs per faith; Hindu date source | Advisors engaged; packs approved; release policy shows real content |
| 4 — Personalisation & habits | Reminders, schedules (active hours), journal, Journey polish, widgets, Focus filter, App Intents | Usability tests with users from each faith |
| 5 — Monetization | Pricing research → products → paywall → StoreKit tests | 3.1.2-compliant paywall; free core preserved |
| 6 — Assistant | Proxy backend, layer-2 safety, generation, report flow | Red-team review across faiths; validator metrics |
| 7 — Localization & regions | Hindi, Arabic (RTL), others by research; regional calendars | Native-speaker review |
| 8 — Launch | App Review package, privacy policy, terms, support site | Approved build |
| Later | Android research & port | Separate platform-capability study |
