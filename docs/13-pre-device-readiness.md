# Pre-signing / pre-device readiness audit (Phase 2.5)

Audit date: 2026-10-01. **No physical iPhone has been used. Nothing below is device-verified.**
Evidence levels: **DOC** = verified from Apple documentation/SDK · **TEST** = verified by
automated test · **BUILD** = verified by compilation/build output only · **DEVICE?** = not yet
verified on a device.

## 1. Target matrix (effective Xcode build settings, Debug and Release identical except `PL_ENVIRONMENT`)

| Target | Type | Bundle ID | App Group | Family Controls | Signing status |
|---|---|---|---|---|---|
| PrayerLock | application | `unconfigured.prayerlock` | `group.unconfigured.prayerlock` | `true` in `App/PrayerLock.entitlements` | Automatic; **no Team** → fails "requires a development team" |
| ShieldConfiguration | app-extension | `unconfigured.prayerlock.ShieldConfiguration` | same | `true` | same |
| ShieldAction | app-extension | `unconfigured.prayerlock.ShieldAction` | same | `true` | same |
| ActivityMonitor | app-extension | `unconfigured.prayerlock.ActivityMonitor` | same | `true` | same |
| PrayerLockUITests | ui-testing bundle | `unconfigured.prayerlock.UITests` | — (no entitlements) | — | needs team to run on device |
| PL*Tests (8) | SwiftPM test targets | n/a (package) | n/a | n/a | run via `swift test` on macOS; no signing |

Other facts: deployment target iOS 18.0; Swift 6; extensions `SKIP_INSTALL=YES`,
`APPLICATION_EXTENSION_API_ONLY=YES`; Debug → `development`, Release → `production` content
policy; scheme archives with Release; "Validate distribution identity" build phase on the app.

## 2. Entitlements & App Group

- All four entitlement files: valid plists (`plutil -lint` OK); exactly two keys each:
  `com.apple.developer.family-controls` = Boolean `true` (the documented type) and
  `com.apple.security.application-groups` = [`$(PL_APP_GROUP_ID)`]. **BUILD**
- All four targets resolve the **same** App Group `group.unconfigured.prayerlock`; Info.plist
  `PLAppGroupIdentifier` matches in all four built bundles. **BUILD**
- No reference to any other project's App Group: the only other `group.` literal is
  `group.example` inside a unit-test fixture (`PLCoreTests.swift:121,126`). **verified by search**
- Expansion of `$(PL_APP_GROUP_ID)` inside entitlements happens at signing; **cannot be
  verified here** — the iOS 27 SDK refuses ad-hoc signing ("Ad Hoc code signing is not allowed
  with SDK 'iOS 27.0'") and real signing needs a team/profile. → docs/11 P1. **DEVICE?**
- Readiness for Apple's distribution approval: configuration is structurally ready (four explicit
  bundle IDs, one App Group, the entitlement on every target that uses Screen Time APIs). It
  becomes requestable only after the final prefix and Team ID exist. Not requested. Not approved.

## 3. Signing — what is still needed (owner)

| Item | Current state |
|---|---|
| Apple Developer Program membership (**paid**) | unknown; free Personal Teams can't use Family Controls (Apple DTS, forum 764682) |
| Team ID | not set (`DEVELOPMENT_TEAM =` in `Config/Identity.xcconfig`) |
| Final bundle prefix | placeholder `unconfigured.prayerlock` (deliberately kept; name undecided) |
| Xcode account | none configured on this Mac |
| Signing identities / provisioning profiles | 0 / 0 on this Mac |
| App IDs + App Group registered | not done (needs prefix + team) |
| Family Controls distribution approval | not requested (needs final IDs) |

## 4. Device readiness checklist

### Mac (checked 2026-10-01)
| Item | Status |
|---|---|
| Xcode | ✅ 27.0 (27A266a), active developer dir `/Applications/Xcode.app` |
| iOS SDK | ✅ iOS 27.0 (device + simulator SDKs); iPhoneOS platform present |
| Command-line tools | ✅ 27.0 |
| macOS | 27.0 |
| Disk | ⚠️ **3.9 GB free (99% used)** — enough for incremental device builds (~0.7 GB DerivedData), not for a simulator runtime |
| Signing identities | ❌ 0 |
| Provisioning profiles | ❌ 0 |
| Xcode Apple ID | ❌ none |
| Simulator runtimes | ❌ none (not to be installed) |

### iPhone (requirements — no device connected, nothing verified)
| Item | Requirement |
|---|---|
| iOS version | ≥ 18.0 (deployment target). Test matrix wants 18.x, 26.4, ≥ 26.5 |
| Developer Mode | Required for development builds: Settings → Privacy & Security → Developer Mode → restart → Enable + passcode (**DOC**) |
| Connection | USB-C/Lightning cable for first pairing (then optional network pairing in Xcode's Devices window) |
| Trust | Tap "Trust This Computer" + passcode on first connection |
| Apple ID | Any Apple ID on the phone; Screen Time authorization uses the device owner's Face ID / Touch ID / passcode (**DOC**) |
| Screen Time | Must not be restricted by MDM/parental controls (FamilyControlsError `.restricted` exists — **DOC**) |

### Apple Developer
| Item | Requirement |
|---|---|
| Membership | Paid Apple Developer Program |
| Team ID | from developer.apple.com → Membership |
| App IDs | 4 explicit IDs (app + 3 extensions), no wildcards |
| Capabilities | Family Controls + App Groups on all 4 |
| Family Controls (Development) | available to paid teams via the capability (DTS) |
| Family Controls (Distribution) | request per bundle ID after the name is final (docs/12) |

## 5. Assumption register

| # | Assumption in code | Evidence | Status |
|---|---|---|---|
| A1 | `ShieldActionResponse.openParentalControlsApp` exists on iOS 26.5+ | SDK interface + doc comment | **DOC**, BUILD |
| A2 | …and it opens Prayer Lock under `.individual` authorization | none | **DEVICE?** (flagged off via `PLUseOpenParentAppResponse` if it misbehaves) |
| A3 | `.defer` makes the shield redraw so the "awaiting" subtitle shows | SDK doc comment | **DOC**; appearance DEVICE? |
| A4 | Shield Action extension can post a local notification | none | **DEVICE?** |
| A5 | Notification tap routes to the moment (delegate set at launch) | compiles | BUILD; **DEVICE?** |
| A6 | Shield Configuration extension can *read* App Group defaults inside its sandbox | none (sandbox doc forbids moving data *out*) | **DEVICE?** |
| A7 | Shield Action / Activity Monitor extensions can *write* App Group defaults; app sees writes promptly | none | **DEVICE?** (docs/11 P3) |
| A8 | `Application.localizedDisplayName` populated in the shield config | SDK doc ("system provides … display names") | **DOC**; DEVICE? |
| A9 | Same-named `ManagedSettingsStore` shares settings between app and extensions | SDK doc: same name shares settings (cross-process not explicit) | **DOC** (partial); DEVICE? |
| A10 | `FamilyActivitySelection` JSON-encoded in the App Group decodes to valid tokens in other processes | `Codable` conformance in SDK | **DOC**; DEVICE? |
| A11 | Encoded `ApplicationToken` from the shield renders via `Label(token)` in the app | compiles | BUILD; **DEVICE?** |
| A12 | Shields and schedules persist across app kill and device restart | none | **DEVICE?** (D24, D25) |
| A13 | One-off schedule with year…second components fires `intervalDidEnd` on time | SDK doc on matching policy; nothing on latency | **DEVICE?** (D15, D33) |
| A14 | Callbacks only fire while the device is in use | SDK doc | **DOC** |
| A15 | `stopMonitoring` fires `intervalDidEnd`; stale signals ignored | SDK doc + `staleRelockSignalNeverCancelsANewerUnlock` | **DOC + TEST**; timing DEVICE? |
| A16 | 15-min minimum / 1-week maximum intervals | SDK doc + `UnlockPlannerTests` | **DOC + TEST** |
| A17 | Usage threshold (`includesPastActivity: false`) ends a 5-min unlock after ~5 min of use | API in SDK; planner tested | **TEST** (logic); accuracy **DEVICE?** (D16) |
| A18 | Daily guard (00:00–23:59:59 repeating) fires `intervalDidStart` daily | none | **DEVICE?** |
| A19 | Relock ordering, failure rollback, empty-selection cleanup, crash recovery | `ProtectionEngineTests` | **TEST** (with fake platform); real-API behaviour DEVICE? |
| A20 | Authorization may read `.notDetermined` briefly at launch | community reports | **DEVICE?**; handling (non-destructive) **TEST** |
| A21 | Revoking access in Settings removes the system shields | none | **DEVICE?** (D23) |
| A22 | Picker needs prior authorization | SDK doc wording only | **DOC** (indirect); DEVICE? (D5) |
| A23 | `tokensDidExpire` is posted in the app process; `refresh(_:)` semantics | SDK (terse) | **DOC** (existence); DEVICE? (D22) |
| A24 | **Calling `refresh(_:)` on every activation is harmless for valid tokens** | none | **DEVICE?** — risk of spurious "Confirm your apps"; if D36 fails, refresh only after `tokensDidExpire` |
| A25 | `clearAllSettings()` on our named store removes only our shields | SDK doc (method exists) | **DOC**; DEVICE? |
| A26 | Category tokens also shield websites via `webDomainCategories` | compiles | BUILD; **DEVICE?** |
| A27 | `DeviceActivityCenter().activities` reflects activities started by other processes | none | **DEVICE?** (diagnostics) |
| A28 | Entitlement build-setting expansion | Xcode convention | **DEVICE?** (P1) |
| A29 | Info.plist build-setting expansion + principal class names | built products show resolved values | **BUILD**; class loading DEVICE? (P2) |
| A30 | Extensions stay within memory limits | binaries ≈ 0.7 MB, no SwiftUI | BUILD; **DEVICE?** (D30) |
| A31 | System shows a default shield if the configuration extension fails | SDK doc | **DOC**; DEVICE? (D37) |

Nothing in A1–A31 marked DEVICE? may be described as "working" until a docs/11 run records it.

## 6. Name collision check (read-only, iTunes Search API, US/IN/GB, 2026-10-01)

- 49 App Store listings contain "Prayer Lock", "PrayLock", or "Christian Focus", across
  Christian, Muslim, and Hindu audiences (e.g. "Prayer Lock: Bible App Blocker", "Prayer Lock:
  Noor", "prayer lock: muslim focus", "Muslim Prayer Lock: Awwal", "Sankalp: PrayLock & Panchang",
  "Prayer First: Christian Focus", "PrayLock - Bible Focus").
- "prayer lock: christian focus" (id 6744703926) returns no result in those storefronts today.
- The bundle namespace `com.prayerlock.*` is in use by another developer ("Prayer Lock - Quiet Time").
- Our placeholder `unconfigured.prayerlock` matches no listed bundle ID and is never meant to be
  registered — **safe as a local placeholder**. "Prayer Lock" as the on-device display name is
  acceptable only for private development builds.
- Recommendation for the later naming decision: **avoid "Prayer Lock" / "PrayLock" entirely**
  in the public name, subtitle, and bundle prefix. (Decision deferred, as instructed.)

## 7. Security (lightweight)

No credential files (`.p8/.p12/.pem/.key/.cer/.mobileprovision/.env/Secrets.xcconfig`), no
secret-like strings, no Team IDs, no personal identifiers (names, emails, home paths) in the
repo; no Git history (0 commits). Only URLs are Apple plist DTD headers. `Config/Secrets.xcconfig`
is git-ignored.

## 8. Disk (no deletions performed)

| Item | Size | Disposable? |
|---|---|---|
| Prayer Lock source (everything except caches) | 856 KB | no |
| `Packages/PrayerLockKit/.build` (SwiftPM cache, git-ignored) | 280 MB | yes — regenerated by `swift build/test` |
| Session scratch build cache (`dd`, outside repo) | ~684 MB | yes — temporary, regenerated by xcodebuild |
| `~/Library/Developer/Xcode/DerivedData/PrayerLock*` | < 1 MB | yes |
| `/tmp/plk-build.log` | 4 KB | yes |
