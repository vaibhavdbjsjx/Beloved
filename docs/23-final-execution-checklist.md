# Beloved — final execution checklist

> **Update 2026-10-09:** the requirement-by-requirement status, configuration inventory and
> fresh verification results are in **docs/24-traceability-and-configuration.md**. Changes since
> the 2026-10-05 list below: onboarding rules moved to `PLFaith/OnboardingFlow` with 12 tests;
> corrupt onboarding progress no longer discards the profile; Settings gained notification
> status and recovery plus the build number; onboarding honours Reduce Motion; unused
> `AssistantPipeline` removed from start-up; release gate checks environment, endpoint and URLs;
> content report explains each blocked item and blocks approved items labelled "draft";
> version 1.0.0 (1); website rebuilt with stylesheet, `_headers`, pre-launch note, Screen Time
> and accessibility sections, requirements and bug reporting, extended terms, `check.py` and
> tests; device plan D39–D42 added and old name removed from docs/11. Xcode now has an Apple
> account but still no team or signing identity; the iPhone is still unavailable.

Date: 2026-10-05. Baseline: `~/Documents/pray`, no commits and no remote (every file is
untracked; nothing was committed or pushed). Builds on docs/20 (submission kit), docs/21
(readiness A–J) and docs/22 (Apple requirements audit). Status words: **DONE** (verified here),
**UNVERIFIED** (needs device or Apple), **BLOCKED** (needs someone outside code).

## Change log (this phase)

| File | Change | Why |
|---|---|---|
| `App/…/App/ProfileStore.swift` | `OnboardingProgress` (step and faith-chosen flag) added to `StoredProfile`, tolerant decoding | Closing the app mid-setup no longer loses answers |
| `App/…/App/AppModel.swift` | `saveOnboardingProgress`; completion clears progress | Same |
| `App/…/Onboarding/OnboardingView.swift` | Restores and saves progress (on every step change and when the app leaves the foreground). New **summary** step (practice, moment length, protection, notifications, what happens next). Screen Time step says what happens if you skip or decline. Notifications step says pauses still work without notifications | Brief §4; honest permission copy |
| `App/…/App/PrayerLockApp.swift` | Launch-failure screen hides the raw error outside development builds and logs it | Internal text must not reach users |
| `UITests/PrayerLockUITests.swift` | Taps the new "Start using Beloved" button | Flow changed |
| `website/build.py` | Rewritten: home (how it works, features, why, privacy), FAQ, support, privacy, terms, 404, robots.txt, sitemap.xml, icons, Open Graph/Twitter metadata, canonical URLs; no JavaScript; refuses production builds without real owner values; `--preview` mode | Brief §10–11 |
| `website/content/terms.md`, `website/site.example.json`, `website/README.md` | Terms source (owner values as tokens), empty config template, instructions | Never invent legal values |
| `docs/20` | Promotional text, What's New, Terms URL, age-rating answers, review-contact checklist; review notes mention the summary step | Brief §12–13 |
| `docs/DECISIONS.md` | D30–D32 | Record decisions |

No architecture, Screen Time, content or release-gate code was changed.

## Completed (DONE)

- 145/145 package tests; Debug and Release BUILD SUCCEEDED (0 Swift warnings); UI test bundles
  compile (TEST BUILD SUCCEEDED); analyzer ANALYZE SUCCEEDED.
- Release gate in archive mode exits 1 (placeholder identity; 0 of 26 items visible). Gate not
  weakened.
- Release bundle sweep: no placeholder, lorem, coming soon, localhost, example.com, `http://`
  (except Apple's plist DTD), personal paths or secrets. Two development-only strings
  ("Development build: …", "Protection diagnostics") are compiled in but unreachable: they are
  gated on `PLEnvironment`, which is `production` in Release.
- Security: no key, certificate, provisioning or `.env` files; no secret patterns; no e-mail
  addresses or personal paths in app, extensions, package, website or config.
- Crash risks: 3 force unwraps remain (`TimeZone("UTC")!` ×2, a Gregorian date built from a
  valid `CivilDate`); both cannot fail. No `try!`, `as!` or `fatalError`.
- Accounts: none. No login, Sign in with Apple, Google login or demo credentials, and none
  needed. Data deletion is "Delete all my data" (local); there is no account to delete.
- Payments: paywall off (`isPaywallEnabled: false`); no purchase UI; StoreKit code unreachable.
- Permissions: only Screen Time (Family Controls, individual) and notifications, each explained
  before the system prompt, each optional, with the effect of declining stated.
- Privacy policy matches code (docs/22 H).
- Website: preview built and checked in the browser at desktop and phone width (no horizontal
  scroll); no broken internal links or anchors; production mode refuses missing values; a
  production test build (scratch-only test values, not kept) produced correct canonical URLs,
  sitemap and robots.txt.

## Needs implementation (code)

None known. Re-open only if device testing finds defects.

## Needs human input (owner)

- Team ID: Xcode still shows no saved account (see below).
- Final name, decided with legal advice. Then the bundle prefix (do not use "beloved" until
  the name is decided).
- Support e-mail, domain, HTTPS host, legal name, terms effective date (`website/site.json`).
  Optional: governing-law sentence from counsel, contact address if legally required.
- App Review contact, copyright line, price and availability, category choice.
- Free disk space: 5.9 GB now, target 15 GB.

## Needs Apple approval

- Family Controls (Distribution) for 4 bundle IDs: app, `.ShieldConfiguration`,
  `.ShieldAction`, `.ActivityMonitor`. **Not requested: BLOCKED — Apple action required.**
- App Review; App Store name availability (seen only in App Store Connect).

| Target | Bundle ID | Family Controls | App Group | Distribution request | Approval |
|---|---|---|---|---|---|
| PrayerLock (app) | `<prefix>` | entitlement set | `group.<prefix>` | not requested | none |
| ShieldConfiguration | `<prefix>.ShieldConfiguration` | set | same | not requested | none |
| ShieldAction | `<prefix>.ShieldAction` | set | same | not requested | none |
| ActivityMonitor | `<prefix>.ActivityMonitor` | set | same | not requested | none |

## Needs legal/content approval

- Name and trademark: **NOT CLEARED**.
- Terms of use (`website/content/terms.md`) and the privacy policy need legal review.
- All 26 content items are draft (table in docs/22 G). Quran (`quran.ar`) and Gita
  (`bhagavad-gita.sa`) editions are unlicensed; Rigveda mantras and traditional texts have no
  cited edition. Faith reviewers are needed for every item. Nothing was approved.

## Needs physical-device verification (all UNVERIFIED)

- Onboarding: fresh install, completion, interruption, termination mid-setup and resume,
  permission denied, permission granted later, returning user. Corrupted or missing profile is
  code-verified: tolerant decoding falls back to defaults, so setup restarts.
- Screen Time: authorization, denial, revocation, picker, shield appearance, shield action, the
  iOS 26.5 hand-off, notifications, unlock, relock, failed relock, midnight, time-zone change,
  termination, reboot, extension failure, multiple and removed apps. docs/11 D3–D21 and D32–D38
  are all **NOT RUN**.
- Accessibility: VoiceOver, largest Dynamic Type, Reduce Motion, contrast, focus order, the
  shield, light/dark. Code uses system text styles, labels and 44 pt targets, but this is
  untested on a device.
- Simulator UI tests: compiled, not run (no simulator runtime installed).

## Needs hosting/domain configuration

- Domain and HTTPS static host; upload `website/public/`; set `PL_SUPPORT_URL` and
  `PL_PRIVACY_POLICY_URL`; enter the URLs in App Store Connect. Publish the site only when
  approved content ships, because the site describes prayers, scripture, mantras and duas.

## Device and signing state (checked 2026-10-05)

- Xcode: no Apple account saved (`DVTDeveloperAccountManagerAppleIDLists` empty), 0 signing
  identities, 0 profiles. A signed device build fails: "requires a development team" (×4).
- iPhone17,2 on iOS 27.0: paired but **unavailable**. Not on USB and no network tunnel.
