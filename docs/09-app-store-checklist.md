# App Store readiness checklist

> **Superseded on 2026-10-05 by [docs/19](19-app-store-readiness.md)** (Phase 5 audit, brand "Beloved") and [docs/20](20-app-store-submission-kit.md). Kept for history.

Nothing below is claimed compliant until checked against Apple's guidelines **at submission
time**. ✅ done · 🟡 partially · ⬜ not started · ⛔ blocker.

## Identity & naming
- ⛔ **App name**: many App Store apps already use "Prayer Lock" in their names (e.g. "Prayer Lock: Bible App Blocker", "prayer lock: muslim focus", "Prayer Lock: Noor" — iTunes Search API, 2026-10-01). Names must be unique (2.3.7) and must not use another developer's brand (4.1). Choose an original brand before any public build; "Prayer Lock" is a working name (`AppBrand.displayName`, `INFOPLIST_KEY_CFBundleDisplayName`).
- ⬜ Original icon and brand identity (no orange lock motif).
- 🟡 Real bundle ID prefix + team ID: single location `Config/Identity.xcconfig`; archives are blocked while placeholders remain (verified).

## Licence (DPLA §3.3.3(P)) — verified 2026-10-01
- ⛔ **Primary purpose**: Family Controls apps must primarily offer family controls or *individual device/focus management*. Position Prayer Lock as personal device-usage management with a prayer pause in the entitlement request, listing, and review notes (wording in docs/12). Risk: Apple may judge a predominantly religious-content app differently — keep the protection loop central.
- ✅ No Family-Controls-derived data leaves the device (selection, grants, event log stay local).

## Capabilities & entitlements
- 🟡 Family Controls capability — entitlements files present for app + 3 extensions; ⛔ **distribution entitlement must be requested from Apple for each of the 4 bundle IDs** (approval times reported as days to weeks). Steps: docs/12.
- 🟡 App Group `group.<prefix>` — in entitlements; register in the developer portal for all 4 bundle IDs.
- ✅ No Time-Sensitive / Critical Alert entitlements requested (not needed).

## Privacy
- ✅ `PrivacyInfo.xcprivacy` for app and each extension (UserDefaults reasons CA92.1 / 1C8F.1; no tracking; no collected data).
- ⬜ App Privacy "nutrition label" in App Store Connect ("Data Not Collected" is accurate for Phase 1 — re-check before release).
- ⬜ Privacy Policy URL (required for all apps, 5.1.1(i)) — must cover Screen Time data, local storage, assistant (if enabled), deletion.
- ✅ In-app data deletion (Settings → Delete all my data). Account deletion requirement (5.1.1(v)) applies only if accounts are added.
- ✅ No usage descriptions needed today (Family Controls and local notifications have no Info.plist purpose strings).

## Screen Time flow
- ✅ Authorization requested only after explanation, with "Set up later".
- ✅ App states plainly what it can't do (calls, notifications, Focus).
- 🟡 Shield → app hand-off uses only public APIs (notification + iOS 26.5 `openParentalControlsApp`); ⬜ device-verify.
- ⬜ Review notes for App Review explaining the self-control (`.individual`) use case and how to test it.

## Subscriptions (when enabled) — 3.1.2
- ⬜ Paywall shows price, period, what's included, trial terms, auto-renewal, Terms of Use (EULA) and Privacy Policy links; Restore Purchases accessible.
- ✅ No hard-coded prices; prices from StoreKit only.
- ⬜ Subscription provides ongoing value (content updates, assistant) — define before launch.

## Content
- ⛔ **Religious content review & licensing** — 1.1.5 prohibits inaccurate or misleading quotations of religious texts. Release builds already block unreviewed and uncleared content; reviewed content packs are required before launch.
- ✅ Provenance labels on every segment; AI text never presented as scripture.
- ⬜ Advisors per faith; review records in `ReviewInfo`.
- ⬜ If the AI assistant ships: content filtering, report mechanism, published contact info (1.2-style safeguards), and age-rating answers for AI-generated content.

## Age rating
- ⬜ Complete the (updated) age-rating questionnaire. Expected low rating; AI-generated content and any user-generated content affect answers.

## Accessibility
- 🟡 Dynamic Type, VoiceOver labels, Reduce Motion, 44pt+ targets implemented; ⬜ audit on device (Accessibility Inspector, largest text sizes, VoiceOver walkthrough).
- ⬜ App Store Accessibility Nutrition Labels.

## Localization
- 🟡 String Catalog in place; English only. ⬜ Translations (Hindi, Arabic, Spanish… based on market research); RTL layout review.

## App Review risks
1. Family Controls entitlement denied or delayed (mitigation: request early, clear use-case description).
2. Name/brand similarity to existing "prayer lock" apps (mitigation: rebrand).
3. Inaccurate religious quotations (mitigation: provenance model + review gate).
4. Subscription disclosure issues (mitigation: follow 3.1.2 exactly).
5. AI-generated religious content (mitigation: validator, labels, report button, opt-in).
6. Shield hand-off behaviour perceived as misleading if the app can't actually open (mitigation: honest copy, notification fallback).
