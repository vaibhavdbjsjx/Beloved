# Beloved — final App Store readiness audit

Date: 2026-10-05 (updated after disk recovery). Scope: `~/Documents/pray` as built on this Mac.
Builds on docs/19 (evidence) and docs/20 (metadata). Nothing submitted, deployed, committed or pushed.

**Environment (verified 2026-10-05):**
- Disk: 0 B free at worst → **8.2 GB free now**. Project-generated artifacts removed earlier:
  package `.build` (~286 MB) and this project's Xcode DerivedData/build cache (~765 MB); the
  project's DerivedData folders now total ~0.4 MB. Nothing personal or in the source tree was
  touched. The rest of the recovered space was freed outside this project. **Still below the
  15 GB target for archive/device work.**
- Xcode 27.0, iOS 27 SDK. **No Apple account in Xcode, 0 teams, 0 signing identities, 0
  provisioning profiles.** `DEVELOPMENT_TEAM` empty; `PL_BUNDLE_ID_PREFIX = unconfigured.beloved`.
- Identifiers (`Config/Identity.xcconfig`): `<prefix>`, `<prefix>.ShieldConfiguration`,
  `<prefix>.ShieldAction`, `<prefix>.ActivityMonitor`; App Group `group.<prefix>`; Family
  Controls entitlement on all 4 targets.
- iPhone (iPhone17,2, UDID 00008140-000A5C3936FB001C): `devicectl` state **unavailable**; no
  reason, iOS version or Developer Mode state is reported (the phone is not connected/unlocked).


## A. PASS (verified on this Mac)

| Item | Evidence |
|---|---|
| Package unit tests | `swift test` re-run 2026-10-05: **145 tests (8 test-target runs: 45+11+7+7+19+20+17+19), 0 failures** |
| Debug build | Re-run 2026-10-05: BUILD SUCCEEDED, 0 Swift compiler warnings |
| Release build (unsigned, generic iOS) | BUILD SUCCEEDED, 0 compiler warnings; only the two intended release-gate warnings |
| Static analysis | `analyze` (Release): ANALYZE SUCCEEDED, no findings |
| Release gate | archive mode exits 1 on placeholder identity and on missing content (as designed) |
| No placeholder/unfinished UI in Release | Source sweep; Release binary `strings` sweep (lorem, coming soon, placeholder, "not available yet", example.com, localhost, http://): none. `PLEnvironment = production`; diagnostics and review badges are Debug-only |
| No dead controls | Every control mapped in docs/19 §4; Premium/Restore hidden (nothing is sold); support link shown only when a real https URL is configured |
| Accounts | None exist; no login, no third-party login → Sign in with Apple and account deletion not applicable (Guidelines 4.8, 5.1.1(v), checked 2026-10-05) |
| Delete my data | Code deletes profile, sessions and all App Group protection keys and the event log, and clears shields and monitoring (code-verified; device behaviour UNVERIFIED) |
| Permissions | Only Screen Time (Family Controls) and local notifications. No camera, photos, microphone, location, contacts, calendar, health, Bluetooth, local network, tracking or IDFA. No usage-description strings are needed or present |
| Network | No networking code, no URLs in Swift, no API keys, no third-party SDKs |
| Privacy policy | Matches the implementation; bundled in-app (offline) and generated for the web; "Data Not Collected" is consistent with Apple's definition (only on-device processing) |
| Subscriptions | Deliberately **not** in v1 (no paid feature exists); no purchase UI; no StoreKit products should be created |
| Icon | Original 1024 px, no alpha, compiled into `Assets.car` |
| Extensions | 3 embedded; bundle IDs, extension points and principal classes resolved; privacy manifests present; one App Group across all 4 targets |
| Psalm 46:10 | **Fixed:** the full verse, character-for-character from the World English Bible (ebible.org/eng-web/PSA046.htm, fetched 2026-10-05); the "first sentence" partial removed. Still `draft` (review required) |
| Matthew 11:28, Philippians 4:6–7 | Text matches the WEB exactly |


## B. FAIL

None in code or builds. Submission-level failures are BLOCKED (C).


## C. BLOCKED (each blocks submission)

| # | Issue | Why it matters | Action | Who |
|---|---|---|---|---|
| B1 | **No release content.** All 26 items are `draft`; release builds show no prayers or scripture | Empty core experience (Guidelines 2.1, 4.2); the description would be misleading (2.3) | Approve reviewed items (H); the archive gate enforces it | You plus faith reviewers |
| B2 | **No Team ID, signing identity or profile**; prefix `unconfigured.beloved` | Can't sign, archive or install | Paid Developer Program; set `DEVELOPMENT_TEAM` and `PL_BUNDLE_ID_PREFIX` in `Config/Identity.xcconfig` | You |
| B3 | **Family Controls distribution not requested** | Required for TestFlight / App Store for each Family Controls bundle ID | Request for all 4 bundle IDs once the prefix is final (docs/12) | You → Apple |
| B4 | **Never run on a device** | The core Screen Time behaviour is unverified | docs/11 D-tests on a real iPhone (I) | You (device) + Claude (can drive tests if the device is available and signed) |
| B5 | **No hosted Privacy Policy / Support URLs** | Both required in App Store Connect; the privacy-policy URL is required by 5.1.1(i) | Build the website with `support.beloved@gmail.com`; host on HTTPS; set `PL_SUPPORT_URL` / `PL_PRIVACY_POLICY_URL` | You (Claude cannot create a domain or hosting) |
| B6 | **Name "Beloved"**: plain name already used on the App Store; same-category "Beloved" apps; live US BELOVED marks in class 9 and 41 in the religious field | App names must be unique (2.3.7); infringement risk | Legal opinion; choose a unique App Store name (e.g. "Beloved: Prayer Before Apps", availability UNVERIFIED) | You + attorney |
| B7 | **Disk 8.2 GB free** (target 15 GB) | Archive/device installs may fail | Free space outside this project | You |


## D. UNVERIFIED

- The whole protection loop on iOS: authorization, picker, shield appearance, shield actions,
  unlock, relock (including failed relock), crash and reboot recovery, revocation, token expiry,
  midnight and time-zone changes, multiple apps, removing all apps.
- The iOS 26.5 `openParentalControlsApp` hand-off under `.individual` authorization.
- Notification delivery from the ShieldAction extension.
- Entitlement expansion and signing; archive and Organizer validation.
- XCUITests: compiled, but **not run** (no simulator, no signed device build).
- VoiceOver, Larger Text at the largest sizes, Voice Control, real-device contrast.
- App Store Connect name availability, age-rating result, review outcome.


## E. MY ACTION REQUIRED

1. Free ≥ ~7 GB more (System Settings → General → Storage) to reach 15 GB.
2. **Sign in to Xcode with the Apple Developer account and provide/confirm the Team ID.**
3. iPhone: connect by cable, unlock, tap "Trust This Computer", enable Settings → Privacy &
   Security → Developer Mode, restart, unlock, confirm "Turn On". Keep it unlocked during tests.
4. Decide the name after legal advice (B6); then the bundle prefix.
5. Provide an HTTPS host (B5). Support e-mail is confirmed as support.beloved@gmail.com. Website already generated by
   `website/build.py`: home, privacy policy, support pages. Missing: hosting and URLs.
6. Engage reviewers for each faith (H).


## F. APPLE DEVELOPER ACTION REQUIRED

1. Enrol in the paid Apple Developer Program; note the Team ID. Free Personal Teams can't use
   Family Controls (docs/12).
2. Sign in to Xcode with that account.
3. Register 4 explicit App IDs: `<prefix>`, `<prefix>.ShieldConfiguration`,
   `<prefix>.ShieldAction`, `<prefix>.ActivityMonitor`.
4. Enable **Family Controls** and **App Groups** (`group.<prefix>`) on all 4.
5. Request **Family Controls (Distribution)** for each of the 4 IDs, using the docs/12
   wording. Approval cannot be assumed.
6. Let automatic signing create profiles; archive; validate in Organizer.

Currently: **nothing is registered, approved or signed** (verified: 0 identities, 0 profiles,
empty Team ID). Family Controls distribution: **BLOCKED — Apple action required.**


## G. APP STORE CONNECT ACTION REQUIRED

| Field | State |
|---|---|
| App name | Unique name needed (B6) |
| Subtitle, description, keywords | Drafted in docs/20; use the description only once approved content ships. Promotional text: not used |
| Category | Lifestyle (owner may choose otherwise) |
| Age rating | Answer the questionnaire (no UGC, AI, purchases or ads in v1) |
| App Privacy | "Data Not Collected" |
| Privacy Policy URL / Support URL | Required; not yet hosted (B5). Marketing URL optional |
| Review notes | docs/20 §5; confirm the 26.5 hand-off on a device before pasting |
| Demo account / credentials | **None required: the app has no login.** Do not create any |
| Export compliance | `ITSAppUsesNonExemptEncryption = NO` already set (no networking) |
| Content rights | Answer from the editions actually shipped (H) |
| Subscriptions / IAP | **None for v1.** Do not create products |
| Screenshots | From a real device with approved content; none exist yet |


## H. LEGAL / CONTENT ACTION REQUIRED

### Legal / trademark (status: NOT CLEARED)

- BELOVED: Augustine Institute registrations (US classes 9, 16, 38, 41, religious field);
  same-category apps (docs/19 §2). **Not cleared.** No clearance is claimed.
- Privacy policy legal review before publishing (it already matches the implementation).
- Content licences (below).
- The brand stays easy to change:
  - the display name is one build setting plus `AppBrand.displayName`;
  - the bundle prefix is unset;
  - Screen Time identifiers are brand-neutral internal strings.


### Content (26 items; release gate verified: 0 of 26 visible in Release)

| Content | Faith/tradition | Source | Rights status | Reviewer status | Release status |
|---|---|---|---|---|---|
| neutral.three-breaths | Faith-neutral reflection | Beloved editorial (draft) | Original | draft (not reviewed) | **BLOCKED** |
| neutral.intention | Faith-neutral intention | Beloved editorial (draft) | Original | draft (not reviewed) | **BLOCKED** |
| neutral.three-gifts | Faith-neutral gratitude | Beloved editorial (draft) | Original | draft (not reviewed) | **BLOCKED** |
| Psalm 46:10 | Christian scripture | WEB `bible.web` | Public domain (WEB); text verified vs ebible.org | draft (not reviewed) | **BLOCKED** |
| Matthew 11:28 | Christian scripture | WEB `bible.web` | Public domain (WEB); text verified vs ebible.org | draft (not reviewed) | **BLOCKED** |
| Philippians 4:6–7 | Christian scripture | WEB `bible.web` | Public domain (WEB); text verified vs ebible.org | draft (not reviewed) | **BLOCKED** |
| christianity.prayer.attention / anxious / forgiveness / morning-strength / lent (5) | Christian prayers | Beloved editorial (draft) | Original | draft (not reviewed) | **BLOCKED** |
| Quran 94:5–6 | Islam scripture | `quran.ar` (edition unverified) | `quran.ar` PENDING | draft (not reviewed) | **BLOCKED** |
| Quran 2:201 (dua) | Islam scripture | `quran.ar` (edition unverified) | `quran.ar` PENDING | draft (not reviewed) | **BLOCKED** |
| Quran 3:173 phrase (Hasbunallah) | Islam scripture/dhikr | `quran.ar` (edition unverified) | `quran.ar` PENDING | draft (not reviewed) | **BLOCKED** |
| Tasbih | Islam dhikr | Traditional, no edition cited | Unverified | draft (not reviewed) | **BLOCKED** |
| Istighfar | Islam dhikr | Traditional, no edition cited | Unverified | draft (not reviewed) | **BLOCKED** |
| islam.dua.attention / ramadan (2) | Islam prayers | Beloved editorial (draft) | Original | draft (not reviewed) | **BLOCKED** |
| Gayatri (Rigveda 3.62.10) | Hindu mantra (Rigveda) | No edition cited | Unverified | draft (not reviewed) | **BLOCKED** |
| Mahamrityunjaya (Rigveda 7.59.12) | Hindu mantra (Rigveda) | No edition cited | Unverified | draft (not reviewed) | **BLOCKED** |
| Om Namah Shivaya | Hindu mantra | Traditional, no edition cited | Unverified | draft (not reviewed) | **BLOCKED** |
| Om Gam Ganapataye Namah | Hindu mantra | Traditional, no edition cited | Unverified | draft (not reviewed) | **BLOCKED** |
| Om Shanti | Hindu mantra | Traditional, no edition cited | Unverified | draft (not reviewed) | **BLOCKED** |
| Bhagavad Gita 2.47 | Hindu scripture | `bhagavad-gita.sa` (edition unverified) | PENDING | draft (not reviewed) | **BLOCKED** |
| hinduism.prayer.attention / gratitude (2) | Hindu prayers | Beloved editorial (draft) | Original | draft (not reviewed) | **BLOCKED** |

All items stay blocked until approved; Quran/Gita stay blocked until an edition is licensed and verified. No translations or rights were invented.


## I. DEVICE TEST RESULTS

Prerequisites not met (no signing, phone unavailable). docs/11 status:

| Scenarios | Result |
|---|---|
| D3–D21 (authorization, picker, shield, shield action, moment, unlock, re-lock, failed re-lock, crash, relaunch, reboot, revocation, token refresh, notification hand-off, midnight, time zone, idle, extension failure, multiple/removed apps) | **NOT RUN — BLOCKED** (signing + device) |
| D32–D38 | **NOT RUN — BLOCKED** |
| Accessibility: VoiceOver, Dynamic Type, large text, contrast, labels, order, touch targets, light/dark | **NOT RUN — BLOCKED** |
| XCUITests | Compiled; NOT RUN (no simulator runtime, no signed build) |
| Archive | **NOT ATTEMPTED** — gate forbids it: Team ID missing, no signing, placeholder prefix, unapproved content |

No scenario is PASS.


## J. FINAL READINESS %

**25 %. Unchanged.** Engineering is clean and re-verified (145/145 tests, Debug/Release/analyzer
succeed). Blockers B1–B7 are outside code and each blocks submission.
