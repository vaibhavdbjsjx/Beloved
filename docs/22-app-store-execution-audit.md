# Beloved — App Store execution audit

Date: 2026-10-05. Scope: `~/Documents/pray`. Builds on docs/19 (evidence), docs/20 (metadata),
docs/21 (readiness, A–J). Nothing was submitted, deployed, committed or pushed, and no code was
changed in this phase. Every finding was re-checked against code, config or the built bundle.

Legend: **PASS** verified · **FAIL** must fix · **BLOCKED** needs owner action ·
**UNVERIFIED** needs device/App Store · **N/A** not applicable.

## A. Current project state

| Item | State (verified 2026-10-05) |
|---|---|
| Disk | **5.9 GB free** (was 8.2 GB earlier today; the drop happened outside this project). Project build output is the only disposable data here; nothing outside the project was deleted |
| Xcode account | Owner reports signing in, but **Xcode has saved no account**: `DVTDeveloperAccountManagerAppleIDLists` is empty, no teams, 0 signing identities, 0 profiles. A signed device build fails with *"Signing for … requires a development team"* on all 4 targets |
| Team ID / prefix | `DEVELOPMENT_TEAM` empty; `PL_BUNDLE_ID_PREFIX = unconfigured.beloved` (deliberately unchanged; see 5G) |
| iPhone | iPhone17,2, **iOS 27.0 (24A437)**, UDID 00008140-000A5C3936FB001C, pairing **paired**, state **unavailable**. Not present on USB and no network tunnel, so Developer Mode cannot be read |
| Simulator runtimes | None |
| Code | No FAIL findings; no changes needed |

## B. Apple requirements audit

| # | Area | Result | Evidence |
|---|---|---|---|
| 1 | Review Guidelines (overall) | BLOCKED | Code side clean; release has no approved content (2.1/4.2), name not unique (2.3.7) |
| 2 | ASC metadata | BLOCKED | Drafted in docs/20; URLs, name and screenshots missing (L) |
| 3 | Privacy | PASS (code) | No network code, no SDKs, local storage only (H) |
| 4–6 | Account / SIWA / deletion | N/A | No accounts (C). "Delete all my data" exists anyway |
| 7 | IAP | N/A for v1 | Paywall off (D) |
| 8 | Permissions | PASS | Only Family Controls + notifications (E) |
| 9–10 | Family Controls / ManagedSettings | UNVERIFIED | Code + entitlements correct; never run on a device (I) |
| 11 | App Groups | PASS (config) | `group.$(PL_BUNDLE_ID_PREFIX)` in all 4 entitlements |
| 12 | Extensions | PASS (config) | 3 appex embedded; correct extension points and principal classes |
| 13 | Notifications | UNVERIFIED | Local only, requested in onboarding with explanation; delivery not device-tested |
| 14 | Accessibility | UNVERIFIED | (K) |
| 15 | App icon | PASS | 1024 px, no alpha, compiled into `Assets.car` |
| 16 | Launch | UNVERIFIED | Builds; not launched on device or simulator |
| 17 | Placeholder/demo content | PASS | Source and Release-bundle sweep clean (F) |
| 18 | Dead buttons | PASS | Premium/Restore hidden while paywall off; diagnostics Debug-only |
| 19–20 | Empty / error states | PASS (code) · UNVERIFIED (device) | docs/19 §4 |
| 21–22 | Network failure / offline | N/A / PASS | No networking; fully offline |
| 23 | Restore purchases | N/A | Nothing is sold; button hidden |
| 24 | Terms/privacy/support links | BLOCKED | Privacy policy bundled in-app; web URLs not hosted; support link hidden until a real https URL is set. Standard Apple EULA suffices (no custom terms needed) |
| 25 | Age rating | BLOCKED | Owner answers questionnaire in ASC |
| 26 | App Privacy | PASS (basis) | "Data Not Collected" matches code (H) |
| 27 | Review notes | BLOCKED | Drafted docs/20 §5; must be confirmed on device |
| 28 | Screenshots | BLOCKED | Need device + approved content |
| 29 | Devices | PASS | iPhone only (`TARGETED_DEVICE_FAMILY = 1`) |
| 30 | iOS version | PASS (config) · UNVERIFIED | Deployment target 18.0; owner's phone is iOS 27.0, untested |
| 31 | Info.plist | PASS | Only custom `PL*` keys + `ITSAppUsesNonExemptEncryption = NO` |
| 32 | Entitlements | PASS (config) · BLOCKED (distribution) | `family-controls` + app group on all 4 |
| 33 | Background modes | N/A | None declared or needed (extensions run in their own processes) |
| 34 | Usage descriptions | N/A | No API requires an `NS…UsageDescription` |
| 35 | Deep links / URL schemes | N/A | None declared |
| 36 | Export compliance | PASS | No encryption beyond OS; key set to NO |
| 37 | Third-party SDKs | N/A | 0 package dependencies (Package.swift and pbxproj) |
| 38 | Secrets / API keys | PASS | None in source or config; `PL_ASSISTANT_ENDPOINT` empty and unused by UI |
| 39 | Debug code in Release | PASS | Diagnostics and draft badges gated on `PLEnvironment` (`production` in Release) |
| 40 | Misleading claims | BLOCKED | Description claims prayers/scripture that Release cannot show until content is approved |

## C. Authentication/account audit

PASS / N/A. Search for login, sign in/up, password, `ASAuthorization`, OAuth: **no matches** in
app, extensions or package sources. No account, no hidden auth flow, no login UI. Sign in with
Apple and account-deletion rules (5.1.1(v)) do not apply. No demo account is needed for review.

## D. Payments/subscriptions audit

N/A for v1. `monetization.json` has `isPaywallEnabled: false`, so `AppEnvironment` uses
`UnavailablePurchaseService`; Settings shows no Premium or Restore UI. `StoreKitPurchaseService`
(StoreKit 2: purchase, `AppStore.sync`, `Transaction.updates`, `currentEntitlements`) is present
but unreachable. `PL_SUBSCRIPTION_GROUP_ID` empty. **Do not create ASC products.** No Apple Pay
(digital goods must use IAP if ever sold).

## E. Permissions audit

PASS. Only `AuthorizationCenter.requestAuthorization` (Family Controls, `.individual`) and
`UNUserNotificationCenter.requestAuthorization([.alert, .sound])`, both from onboarding steps
that explain them first. No camera, location, contacts, microphone, photos, Bluetooth, motion,
tracking, health, calendar or reminders APIs. No usage descriptions added (none needed).
Whether the explanation matches device behaviour: UNVERIFIED.

## F. Placeholder/dead-UI audit

PASS. Sources, extensions and website searched for lorem, TODO, FIXME, coming soon, placeholder,
dummy, fake, localhost, 127.0.0.1, example domains, under construction, "not available yet".
Only hits: doc comments about test fakes, a safety-router phrase list, and `build.py` rejecting
example e-mails. **Release bundle** (`strings` over every file in `PrayerLock.app` incl. 3 appex):
only Apple's plist DTD URL. 4 privacy manifests present.

## G. Content audit

Release status for all 26: **BLOCKED** (all `draft`; release gate reports 0 of 26 visible).
I did not approve anything. Attribution requirement and reviewer are the owner's to confirm.

| # | Content | Faith | Source / version | Copyright status | Attribution | Reviewer required |
|---|---|---|---|---|---|---|
| 1 | Three slow breaths | Neutral | Editorial (draft) | Original, owner's | Author label TBD | Editorial |
| 2 | Intention | Neutral | Editorial | Original | TBD | Editorial |
| 3 | Three gifts | Neutral | Editorial | Original | TBD | Editorial |
| 4 | Psalm 46:10 | Christian | World English Bible | Public domain (text verified vs ebible.org) | "WEB" recommended | Christian |
| 5 | Matthew 11:28 | Christian | WEB | Public domain (verified) | "WEB" | Christian |
| 6 | Philippians 4:6–7 | Christian | WEB | Public domain (verified) | "WEB" | Christian |
| 7–11 | 5 prayers (attention, anxious, forgiveness, morning strength, Lent) | Christian | Editorial | Original | TBD | Christian |
| 12 | Quran 94:5–6 | Islam | `quran.ar`, edition not chosen | **PENDING** | Per chosen edition (e.g. Tanzil requires attribution, no changes) | Islamic scholar |
| 13 | Quran 2:201 (dua) | Islam | `quran.ar` | **PENDING** | Per edition | Islamic |
| 14 | Hasbunallah (phrase of 3:173) | Islam | `quran.ar` | **PENDING** | Per edition | Islamic |
| 15 | Tasbih | Islam | Traditional, no edition | Unverified | — | Islamic |
| 16 | Istighfar | Islam | Traditional | Unverified | — | Islamic |
| 17–18 | 2 duas (attention, Ramadan) | Islam | Editorial | Original | TBD | Islamic |
| 19 | Gayatri (Rigveda 3.62.10) | Hindu | No edition cited | Unverified | — | Hindu |
| 20 | Mahamrityunjaya (Rigveda 7.59.12) | Hindu | No edition | Unverified | — | Hindu |
| 21 | Om Namah Shivaya | Hindu | Traditional | Unverified | — | Hindu |
| 22 | Om Gam Ganapataye Namah | Hindu | Traditional | Unverified | — | Hindu |
| 23 | Om Shanti | Hindu | Traditional | Unverified | — | Hindu |
| 24 | Bhagavad Gita 2.47 | Hindu | `bhagavad-gita.sa`, edition not chosen | **PENDING** | Per edition | Hindu |
| 25–26 | 2 prayers (attention, gratitude) | Hindu | Editorial | Original | TBD | Hindu |

Explanations on Quran/Gita items are labelled "editorial summary, not a translation".

## H. Privacy/legal audit

| Topic | Code reality | Policy | Result |
|---|---|---|---|
| Data collected / transmitted | None leaves the device; no `URLSession`, no endpoints | "does not collect, sell or share" | PASS |
| Stored locally | Profile, check-ins, history, protection settings, App Group keys | Listed | PASS |
| Screen Time | Opaque tokens; shield drawn in extension sandbox | Described | PASS |
| Notifications | Local only | Described | PASS |
| Analytics / crash / SDKs / tracking / ads | None | Stated; Apple's opt-in diagnostics mentioned | PASS |
| Account data | None | N/A | PASS |
| Deletion | Settings → Delete all my data | Described | PASS (code) · UNVERIFIED (device) |
| Contact | `support.beloved@gmail.com` and support link on App Store page | E-mail confirmed; URL not hosted yet | BLOCKED (hosted support URL) |

Legal pages needed: **privacy policy URL** (required), **support URL** (required). Terms: Apple's
standard EULA is sufficient; no custom terms needed while nothing is sold. Legal review of the
policy: owner. Name/trademark: **NOT CLEARED** (docs/21 H).

## I. Family Controls audit

Config PASS for all 4 targets: `com.apple.developer.family-controls` + `group.$(prefix)`; bundle IDs
`<prefix>`, `.ShieldConfiguration`, `.ShieldAction`, `.ActivityMonitor`. Extension communication via
App Group key-value store; engine safety rules (failed relock keeps shields, failed scheduling keeps
existing unlock, revocation, etc.) are unit-tested with a fake platform. **Authorization, picker,
shielding, shield action, monitoring, schedules, limits, revocation and token refresh: UNVERIFIED**
(never run on a device).

Owner steps for distribution approval:
1. Paid Apple Developer Program membership (Personal Teams can't use Family Controls).
2. Decide the final bundle prefix (after the name decision); set `PL_BUNDLE_ID_PREFIX` and
   `DEVELOPMENT_TEAM` in `Config/Identity.xcconfig`.
3. developer.apple.com → Identifiers: register 4 explicit App IDs; enable Family Controls and
   App Groups; create and assign `group.<prefix>`.
4. Request **Family Controls (Distribution)** for each of the 4 IDs (wording in docs/12).
   **BLOCKED — Apple action required.** Development entitlement works for device testing meanwhile.
5. Xcode → automatic signing; build to device; later archive and validate.

## J. Device/signing audit

| Check | Result |
|---|---|
| Xcode account / teams | **BLOCKED**: none persisted (see A) |
| Signing identity / profiles | BLOCKED: 0 / 0 |
| Signed device build | **FAIL (expected)**: "requires a development team" ×4 targets |
| Device connection | BLOCKED: unavailable; not on USB, no network tunnel |
| iOS version | 27.0 (24A437) — read from cached pairing record |
| Developer Mode | UNVERIFIED (device not reachable) |
| Device registration | BLOCKED (needs team) |
| docs/11 D3–D38 | **NOT RUN** (all) |

## K. Accessibility audit

Code: SwiftUI system text styles, explicit `accessibilityLabel`/hints on custom controls (10 sites),
identifiers for UI tests. Dynamic Type at largest sizes, VoiceOver, contrast, touch targets, reduced
motion, layout overflow, light/dark: **UNVERIFIED** (no simulator runtime, no device).

## L. App Store Connect checklist

| Field | Status | Needs owner decision |
|---|---|---|
| App name | BLOCKED | Unique name after legal advice |
| Subtitle / description / keywords | Drafted (docs/20) | Approve; description only once content ships |
| Promotional text | Not used | Optional |
| Category | Lifestyle proposed | Yes |
| Age rating | Not answered | Yes (no UGC/ads/purchases/AI in v1) |
| App Privacy | "Data Not Collected" | Confirm |
| Privacy / Support URL | Not hosted | Domain and host; support e-mail is support.beloved@gmail.com |
| Marketing URL | Optional | — |
| Review notes | Drafted docs/20 §5 | Confirm after device test |
| Demo account | Not required (no login) | — |
| Screenshots | None | After device + content |
| Icon | Ready | — |
| Copyright | Missing | Legal name/year (not invented) |
| Content rights | Depends on G | Yes |
| Family Controls approval | Not requested | Yes (I) |
| Export compliance | NO (set) | — |
| Pricing / availability | Not set | Free? countries? |

## M. Build/test results

Run today on unchanged code:
- `swift test`: **145/145 passed**, 0 failures (8 test-target runs).
- Debug (simulator, unsigned): BUILD SUCCEEDED, 0 Swift warnings.
- Release (simulator, unsigned): BUILD SUCCEEDED, 0 Swift warnings; release-gate warnings for
  placeholder identity and 0/26 content (by design).
- Analyzer: ANALYZE SUCCEEDED.
- Release bundle sweep: clean (F).
- Signed device build: FAILED — no development team.
- Archive / validation: **NOT ATTEMPTED** — gate forbids it (placeholder identity, no team,
  unapproved content). Gate not weakened.

## N. External blockers

1. Xcode account not persisted → no Team ID, signing, profiles.
2. iPhone unavailable (not connected).
3. Family Controls distribution not requested.
4. All content draft; Quran/Gita editions unlicensed.
5. No domain or HTTPS host. Support e-mail is support.beloved@gmail.com.
6. Name not legally cleared.
7. Disk 5.9 GB (< 15 GB).

## O. Exact actions required from me (owner)

1. **Xcode → Settings → Accounts → "+" → Apple Account**; sign in with the paid Developer
   Program account until the team appears in the list; then quit and reopen Xcode once. Tell me
   the 10-character Team ID shown there.
2. iPhone: connect by **USB cable**, unlock, tap **Trust**, enter passcode. Settings → Privacy &
   Security → **Developer Mode** on → restart → unlock → "Turn On". Keep unlocked.
3. Free ~9 GB (System Settings → General → Storage); something outside the project keeps
   consuming space.
4. Name decision with counsel → final bundle prefix.
5. Support e-mail + domain/HTTPS host.
6. Faith reviewers; choose licensed Quran and Gita editions.

## P. Next executable phase

When 1 and 2 are done: set Team ID (and a provisional, non-"beloved" dev prefix only if you
approve it), signed Debug build to the iPhone, run docs/11 D3–D21 and D32–D38 plus accessibility,
record PASS/FAIL/BLOCKED/NOT RUN. Archive only after the gate's conditions are genuinely met.
