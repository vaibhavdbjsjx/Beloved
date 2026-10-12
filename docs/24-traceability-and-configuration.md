# Beloved — requirements traceability and configuration inventory

Date: 2026-10-09, updated 2026-10-10 (simulator UI tests), on the current working tree (no commits exist; every file is untracked).
Evidence is from this session's runs (section 4). Status: **PASS** (implemented, with
automated or inspection evidence appropriate to the claim), **PARTIAL**, **MISSING**, **FAIL**,
**UNVERIFIED** (code complete; behaviour needs a device), **BLOCKED** (external dependency),
**N/A**. Nothing is PASS because it merely compiles. No device test has run, so every
device-only behaviour is UNVERIFIED.

## 1. Inventory

| Kind | Items |
|---|---|
| iOS app | `PrayerLock` target (display name Beloved), SwiftUI, iOS 18.0+, iPhone only |
| Extensions | `ShieldConfiguration` (ManagedSettingsUI), `ShieldAction` (ManagedSettings), `ActivityMonitor` (DeviceActivity) |
| Package | `PrayerLockKit`: PLCore, PLDesign, PLBrand, PLFaith, PLContent, PLCalendar, PLHabits, PLProtection, PLMonetization, PLAssistant (not used by the app in this release) |
| Tests | 182 Swift package tests (9 targets, incl. `PLBrandTests` palette contrast); 17 UI tests run on the iOS 27.0 simulator (`sh scripts/verify.sh --ui`); 12 release-tool tests (`Config/test_release_tools.py`); 19 website tests (`website/test_site.py`). All device-free checks: `sh scripts/verify.sh` |
| Build scripts | `Config/validate-release.sh` (Xcode build phase), `Config/release-content-report.py` |
| Content | `PLContent/Resources/content-fixtures.json` (26 items), `taxonomy.json`; `PLFaith/Resources/faiths.json` (faiths, traditions, editions with licences); calendar and devotional data in PLCalendar |
| Legal | `App/PrayerLock/Resources/Legal/PrivacyPolicy.md` (bundled and published); `website/content/terms.md` (web only) |
| Website | `website/build.py`, `check.py`, `verify_live.py`, `test_site.py`, `content/terms.md`, `static/assets/` (icons), `site.example.json`; `netlify.toml` at the repo root |
| Configuration | `Config/Identity.xcconfig`, `Shared.xcconfig`, `Debug.xcconfig`, `Release.xcconfig`, `Secrets.example.xcconfig` (real `Secrets.xcconfig` is git-ignored) |
| External services | **None.** No networking code, no backend, no analytics or crash SDKs, 0 package dependencies. StoreKit code exists but is unreachable (paywall off) |

## 2. Traceability matrix

| ID | Requirement | Source files | Impl. | Automated tests | Device | Status |
|---|---|---|---|---|---|---|
| ON-1 | Welcome explains the product without exaggerated claims | `OnboardingView` | yes | UI test (compiled) | — | UNVERIFIED (runtime) |
| ON-2 | Faith choice with faith-neutral option; nothing pre-selected | `FaithChoiceViews` | yes | UI test asserts Continue disabled until chosen (compiled) | — | UNVERIFIED |
| ON-3 | Tradition and focus only when the faith offers them | `OnboardingFlow` | yes | `OnboardingFlowTests` (5 cases) | — | PASS |
| ON-4 | Preferences used by the product only (length, script, transliteration, customs) | `ContentPreferencesFields`, `ContentSelector` | yes | selector tests | — | PASS |
| ON-5 | Screen Time explained before the system prompt; skip and decline stated | `OnboardingView`, `ProtectionSetupSections` | yes | — | D2–D4 | UNVERIFIED |
| ON-6 | Notifications explained; optional | `OnboardingView` | yes | — | D13 | UNVERIFIED |
| ON-7 | Answers saved on every step and on backgrounding; resume after termination | `OnboardingView`, `AppModel.saveOnboardingProgress`, `StoredProfile` | yes | resume rules unit-tested; `testInterruptedOnboardingResumesAfterRelaunch` | D39 | PASS (simulator) |
| ON-8 | Corrupted or unknown saved progress handled | `OnboardingFlow.resumeStep`, tolerant `StoredProfile` decode | yes | `unknownSavedStep…`, `corruptedProgress…`, `CodableFileStore` corrupt-file test | — | PASS |
| ON-9 | Final summary of choices and next step | `OnboardingView` summary | yes | UI tests reach and tap `onboarding.finish` | D40 | PASS (simulator) |
| ON-10 | Returning users skip onboarding | `AppModel.isOnboarded` | yes | `testReturningUserSkipsOnboarding` | D42 | PASS (simulator) |
| ON-11 | No question the app doesn't use | review of every step | yes | — | — | PASS (no intention picker added: nothing would use it) |
| PR-1 | Authorization request, denial, revocation recovery | `ProtectionEngine`, `ScreenTimePlatform`, `ProtectionSetupSections` | yes | `deniedAtFirstSetup…`, `revokedAuthorization…`, `grantingAuthorization…` | D3, D4, D23 | UNVERIFIED (device) |
| PR-2 | App/category/website selection, Apple caps of 50 | `SelectionLimits`, picker | yes | `selectionLimitsMatchApplesCaps`, `selectionLimitsAreReported` | D6 | UNVERIFIED |
| PR-3 | Enable/disable protection; empty selection removes everything | `ProtectionEngine` | yes | 6 tests (enable, off, remove all/one, replace) | D7, D20, D21 | UNVERIFIED |
| PR-4 | Shield copy and actions (Begin / Not now) | `ShieldConfiguration`, `ShieldAction` extensions, `ShieldHandOff` | yes | shield-copy, request-queue and `ShieldHandOffTests` (3) | D8–D12 | PASS (decision logic) · UNVERIFIED (device) |
| PR-5 | Hand-off to the moment (iOS 26.5 open, notification fallback) | `ShieldActionExtension`, `NotificationService` | yes | — | D11–D13 | UNVERIFIED |
| PR-6 | Temporary unlock; relock scheduled **before** shields clear | `RelockService`, `UnlockPlanner` | yes | `relockIsScheduledBeforeShieldsAreRemoved`, planner tests | D14–D17 | UNVERIFIED |
| PR-7 | Failed scheduling never removes protection | `ProtectionEngine` | yes | `failedSchedulingKeepsShieldsUp`, `…KeepsTheExistingUnlock` | D38 | PASS (logic) · UNVERIFIED (device) |
| PR-8 | Stale callbacks never cancel a newer unlock | `RelockService`, `ScreenTimeNames` | yes | `staleRelockSignalNeverCancelsANewerUnlock`; `ScreenTimeNamesTests` (4: grant round-trip, foreign/daily-guard/malformed names ignored, names pinned) | D18 | PASS (logic) |
| PR-9 | Relaunch/reboot re-applies expired unlocks; daily guard heals | `ProtectionEngine.reconcile` | yes | `relaunchAfterExpiredUnlock…`, `dailyGuard…` (3) | D24–D26 | UNVERIFIED |
| PR-10 | Midnight, idle and time-zone behaviour | `UnlockPlanner`, daily guard | yes | `restOfDayEndsAtMidnight`, `…NearMidnight…` | D33–D35 | UNVERIFIED |
| PR-11 | Token expiry/refresh (iOS 26.5) never silently disables protection | `ProtectionEngine.refreshExpiredTokens` | yes | 4 refresh tests | D22, D36 | UNVERIFIED |
| PR-12 | Extension failure falls back safely | extensions | yes | — | D37 | UNVERIFIED |
| PR-13 | App Group holds only non-personal state | `ProtectionStateStore` | yes | `defaultsAndPersistence`, inspection | — | PASS |
| PR-14 | Usage-limit unlocks (< 15 min) | `UnlockPlanner` | yes | `shortUnlocks…`, `shortUnlockUsesUsageThreshold…` | D16 | UNVERIFIED |
| MO-1 | Moment shows content for the profile; honest fallback when none | `MomentView`, `ContentSelector` | yes | selector tests | — | PASS (logic) |
| MO-2 | Minimum reflection time before finishing | `MomentView` | yes | — | D14 | UNVERIFIED |
| MO-3 | Intention prompt is not stored (says so) | `MomentView` | yes | inspection | — | PASS |
| ST-1 | Every setting persists and changes behaviour | `SettingsView`, `AppModel.updateProfile` | yes | profile round-trip via `CodableFileStore` tests | — | UNVERIFIED (no app-target unit tests can run without a simulator; persistence uses the tested `CodableFileStore`) |
| ST-2 | Notification status and recovery in Settings | `SettingsView.notifications` | yes | `testSettingsOffersNotificationsAndShowsBuild` (status + Allow offered; the system prompt and the denied → iOS Settings path are not exercised) | D41 | PARTIAL (simulator) · UNVERIFIED (denied path) |
| ST-3 | Privacy policy in-app offline; support link only when https URL set | `LegalDocumentView`, `AppConfiguration` | yes | UI test (compiled); gate checks URL scheme | — | PASS (config) · UNVERIFIED (UI) |
| ST-4 | Delete all my data removes everything and returns to setup | `AppModel.deleteAllData`, `ProtectionEngine.resetAll` | yes | `resetRemovesEverything` (×2); `testDeleteAllDataReturnsToSetup` (persists across relaunch) | D31 | PASS (app data, simulator) · UNVERIFIED (shields on device) |
| ST-5 | Version and build visible for support | `SettingsView.versionDescription` | yes | UI test checks "1.0.0 (1)" format | — | PASS (simulator) |
| ST-6 | Debug-only diagnostics hidden in Release | `SettingsView` (`isDevelopment`) | yes | Release `PLEnvironment = production` verified in Info.plist | — | PASS |
| CO-1 | Release shows only approved, rights-cleared content | `ContentPolicy.release` | yes | PLContent tests; report tests | — | PASS |
| CO-2 | Validator rejects malformed records, missing citations | `CatalogValidator` | yes | PLContent tests | — | PASS |
| CO-3 | Per-item blocking reasons | `release-content-report.py --items` | **added** | `ContentReportTests` (7) | — | PASS |
| CO-4 | Approved item can't ship a "(draft)" author label | report + gate | **added** | `test_approved_item_still_labelled_draft_is_blocked` | — | PASS |
| CO-5 | Every offered faith has release content | gate | yes | `test_archive_without_release_content_fails…` | — | PASS (gate) · BLOCKED (0/26 approved) |
| CO-6 | Content approved by reviewers; rights cleared | content JSON | — | — | — | BLOCKED (human review, licences) |
| RG-1 | Archive fails on placeholder identity | `validate-release.sh` | yes | gate test | — | PASS |
| RG-2 | Release must be production; no undisclosed endpoint; https URLs | `validate-release.sh` | **added** | gate test | — | PASS |
| WEB-1 | Home, FAQ, support, privacy, terms, 404 | `website/build.py` | yes | `test_site.py` (11) + `check.py` | browser preview at 375/768/desktop | PASS |
| WEB-2 | Production refuses missing/example values; preview marks gaps | `build.py` | yes | 4 tests | — | PASS |
| WEB-3 | Links, anchors, assets, metadata, robots, sitemap verified per build | `check.py` | yes | runs on every build | — | PASS |
| WEB-4 | Security headers, no scripts | `_headers`, `check.py` | yes | header test; CSP-conflicting tags rejected | — | PASS (headers depend on host) |
| WEB-5 | Live HTTPS deployment | `netlify.toml`, `--config-env`, `verify_live.py` | prepared | env-config, clean-URL and live-verifier tests | — | BLOCKED (domain, host, owner values) |
| SEC-1 | No secrets, keys, certificates or personal paths in repo or bundle | — | — | pattern sweep + Release `strings` sweep | — | PASS |
| SEC-2 | Only Family Controls and notification permissions | — | — | API sweep | — | PASS |
| SEC-3 | No networking; privacy policy matches | — | — | sweep (no `URLSession`, no URLs in Swift) | — | PASS |
| ACC-1 | Dynamic Type, VoiceOver labels, Reduce Motion, contrast, 44 pt targets | views, `PLLabeledContentStyle`, `PLPalette` | yes — fixed this round: Welcome scrolls at large sizes, headings wrap, Form headers/footers/values use `plInkSecondary` | `PaletteContrastTests` (WCAG AA); Xcode accessibility audit on Welcome/Today/Settings; AX5 flow test with screenshots | VoiceOver on device | PASS (audit + AX5, simulator; 3 hand-verified audit exclusions) · UNVERIFIED (VoiceOver on device); the formerly unattributed Settings contrast finding was located under the translucent tab bar |
| AS-1 | Bundle IDs derive from one prefix; extensions nested under app | xcconfig | yes | `-showBuildSettings` check | — | PASS |
| AS-2 | Same version/build on all targets | xcconfig | yes (1.0.0 / 1) | build settings | — | PASS |
| AS-3 | Entitlements: Family Controls + App Group on 4 targets | `.entitlements` | yes | inspection | — | PASS (config) · BLOCKED (distribution approval) |
| AS-4 | Signing, archive, validation | — | — | — | — | BLOCKED (no team/identities) |
| AC-1 | Accounts / Sign in with Apple / account deletion | — | none | sweep | — | N/A (no accounts) |
| PAY-1 | Purchases | `PLMonetization` | off | monetization tests | — | N/A for v1 (paywall disabled, no UI) |
| BE-1 | Backend / API | — | none | — | — | N/A (offline app by design, docs/06) |

## 3. Configuration inventory

Website keys can also be supplied as `BELOVED_<KEY>` environment variables (`--config-env`), which is how Netlify / Cloudflare Pages builds receive them.

No backend, no `.env`: every value below is a build setting (xcconfig → Info.plist) or a
website config key. **None is secret.** Xcode settings are readable inside the app binary;
website values are published. Never put API keys in either.

| Name | Purpose | Required | Consumer | Public/secret | Safe example | Where to set | Validation | If missing |
|---|---|---|---|---|---|---|---|---|
| `PL_BUNDLE_ID_PREFIX` | Bundle IDs and App Group | Archive: yes | Xcode, all targets | public | `com.<your-domain>.<app>` | `Config/Identity.xcconfig` | gate rejects `unconfigured.*`, `com.example.*` | archive fails |
| `DEVELOPMENT_TEAM` | Signing team | Signing: yes | Xcode | public | 10-char Team ID from developer.apple.com → Membership | `Identity.xcconfig` | gate | signing/archive fail |
| `PL_APP_GROUP_ID` | Shared container | derived | app + 3 extensions | public | `group.$(PL_BUNDLE_ID_PREFIX)` | `Shared.xcconfig` (derived) | — | — |
| `PL_ENVIRONMENT` | `production` / `development` content policy and diagnostics | yes | app, extensions | public | set per configuration | `Release.xcconfig`, `Debug.xcconfig` | gate: Release must be `production` | gate warns/fails |
| `PL_SUPPORT_URL` | In-app "Help & support" | no | app | public | `https:/$()/<domain>/support.html` | `Shared.xcconfig` or `Secrets.xcconfig` | gate: https, not placeholder; app ignores non-https | link hidden |
| `PL_PRIVACY_POLICY_URL` | Web copy of the policy | no (policy is bundled) | app | public | `https:/$()/<domain>/privacy.html` | same | same | in-app policy still shown |
| `PL_SUBSCRIPTION_GROUP_ID` | StoreKit status lookups | no (paywall off) | `StoreKitPurchaseService` | public | App Store Connect group ID | `Secrets.xcconfig` | — | unused in v1 |
| `PL_ASSISTANT_ENDPOINT` | Premium Companion proxy | no, but required for cloud Companion | app | public | `https:/$()/beloved-companion.beloved-app.workers.dev` | `Shared.xcconfig` or `Secrets.xcconfig` | gate requires https when set | free library answers only |
| `MARKETING_VERSION` / `CURRENT_PROJECT_VERSION` | 1.0.0 / 1 | yes | all targets | public | increment build per upload | `Shared.xcconfig` | Xcode | — |
| website `domain` | Canonical URLs, sitemap | prod: yes | `build.py` | public | `https://<host>` | `website/site.json` | https host, no example | build refused |
| website `support_email` | Support page, policy, terms | prod: yes | `build.py` | public | your real mailbox | `site.json` | e-mail format, no example | build refused |
| website `legal_name` | Copyright, terms | prod: yes | `build.py` | public | your legal name or company | `site.json` | no example | build refused |
| website `terms_effective_date` | Terms date | prod: yes | `build.py` | public | "1 November 2026" | `site.json` | no example | build refused |
| website `app_store_url` | Download button | no | `build.py` | public | `https://apps.apple.com/us/app/<name>/id<n>` | `site.json` | exact App Store URL pattern | pre-launch note instead |
| website `clean_urls` / `BELOVED_CLEAN_URLS` | Canonicals/sitemap without `.html` | Cloudflare Pages only | `build.py` | public | `true` | `site.json` or host env | boolean | `.html` URLs |
| website `contact_address`, `governing_law` | Legal footer / terms clause | no | `build.py` | public | from your lawyer | `site.json` | no example | omitted |

## 4. Verification run (2026-10-09, this tree)

| Check | Command | Result |
|---|---|---|
| All device-free checks | `sh scripts/verify.sh --ui` (2026-10-10) | **exit 0, all passed** (rows below) |
| Package tests | `cd Packages/PrayerLockKit && swift test` | **182 passed, 0 failed** (9 test targets) |
| Release tooling | `python3 -m unittest Config/test_release_tools.py` | **15 passed** (incl. privacy-boundary guard) |
| Website | `python3 -m unittest website/test_site.py` | **19 passed** |
| Website build + check | `build.py --config website/site.example.json --preview` | site check passed (preview); production refused for example values |
| Debug build | `xcodebuild … -configuration Debug -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build` | BUILD SUCCEEDED, 0 Swift warnings |
| Release build (simulator / device arch) | same, Release; and `generic/platform=iOS` | BUILD SUCCEEDED (both) |
| UI test bundles | `build-for-testing` | TEST BUILD SUCCEEDED |
| Static analysis | `analyze` (Release) | ANALYZE SUCCEEDED, no findings |
| Release gate (archive mode) | `ACTION=install …` via test | exits 1: placeholder identity + 0/26 content (correct) |
| Target consistency | `-showBuildSettings -alltargets` | IDs nested under one prefix; 1.0.0 (1) everywhere; production in Release |
| Release bundle sweep | `strings` over every file in `PrayerLock.app` | no placeholder/local/http/personal/secret strings; no assistant code; 4 privacy manifests |
| Browser | preview at 375 px, 768 px, desktop; light and dark | no horizontal overflow, no console messages, no broken images |
| UI tests | `sh scripts/verify.sh --ui` (iPhone 17 simulator, iOS 27.0, serial) | **17 passed, 0 failed** (2026-10-10) |
| Device tests D1–D42 | — | **NOT RUN** (no signing team; iPhone unavailable) |
| Signed build / archive | `-destination 'generic/platform=iOS' -allowProvisioningUpdates` | **BLOCKED**: "requires a development team" |
| Dependency audit | — | N/A: zero third-party dependencies |
