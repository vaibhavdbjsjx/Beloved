# Protection loop — test plan

Status legend: ✅ passing (actually run) · 🔨 compiles only · ⏳ not yet run · ⛔ blocked (reason given).

Evidence for device runs: **Settings → Development → Protection diagnostics → Copy report**
(development builds only). The report lists status, authorization, App Group availability,
selection counts, settings, current grant, OS shield counts, monitored DeviceActivity names,
and the last 100 protection events — no app names, tokens, or prayer content. Paste it into
the results table for every run.

## A. AUTOMATED (no device) — `cd Packages/PrayerLockKit && swift test`

All ✅ as of 2026-10-01 (141 tests total; 45 in `PLProtectionTests`). The protection rules
run against `FakePlatform`, which records every OS call in order.

| Case | Test |
|---|---|
| Enable → shields + daily guard | `enablingProtectionAppliesShieldsAndDailyGuard` |
| **Remove all apps → no stale shields** (Phase 1 bug regression) | `removingAllAppsRemovesShieldsMonitoringAndProtection`, `removingAllAppsDuringUnlockCancelsThePendingRelock` |
| Remove one app | `removingOneAppReappliesTheRemainder` |
| Replace selection | `replacingTheSelectionAppliesTheReplacement` |
| Add apps during unlock | `changesDuringAnUnlockTakeEffectAtRelock` |
| Empty selection / denied auth blocks enabling | `enablingRequiresAuthorizationAndASelection` |
| Protection off | `turningProtectionOffRemovesShieldsAndMonitoring` |
| 50-item limits | `selectionLimitsAreReported`, `selectionLimitsMatchApplesCaps` |
| Relock scheduled **before** shields removed | `relockIsScheduledBeforeShieldsAreRemoved` |
| Scheduling failure keeps shields up | `failedSchedulingKeepsShieldsUp`, `failedSchedulingKeepsTheExistingUnlock` |
| Late/stale callback never overrides newer unlock | `staleRelockSignalNeverCancelsANewerUnlock` |
| 5-minute unlock = usage threshold in a 15-min window | `shortUnlockUsesUsageThresholdAndRelocksOnIt`, `UnlockPlannerTests` |
| Relock after protection turned off | `relockAfterProtectionWasTurnedOffDoesNothing` |
| Unlock requires auth + protection on | `unlockRequiresProtectionOnAndAuthorization` |
| App crash/kill mid-unlock → protection returns | `relaunchAfterExpiredUnlockReappliesShields` |
| Daily guard safety net | `dailyGuardRespectsActiveUnlockAndHealsExpiredOne`, `reconcileRecreatesAMissingDailyGuard`, `dailyGuardFailureDoesNotBlockProtection` |
| Authorization denied at setup | `deniedAtFirstSetupIsNotARecoveryCase` |
| Authorization revoked → recovery, choices kept | `revokedAuthorizationShowsRecoveryAndKeepsChoices` |
| Token refresh: unsupported / refreshed / failed / emptied | `unsupportedTokenRefreshChangesNothing`, `refreshedTokensAreSavedAndReapplied`, `unrefreshableTokensAskTheUserToChooseAgain`, `refreshThatLosesEveryTokenDoesNotSilentlyDisableProtection` |
| Delete all data | `resetRemovesEverything` |
| Event log bounded | `boundedAndNewestFirst` |

Also automated: `xcodebuild … build / build-for-testing` for app + each extension (🔨 compile
only — proves API usage type-checks against the iOS 27 SDK, nothing more).

## B. SIMULATOR — iOS 27.0 runtime installed 2026-10-09 (iPhone 17 simulator)

Run: `sh scripts/verify.sh --ui` (or `xcodebuild test … -destination 'platform=iOS Simulator,name=iPhone 17' -parallel-testing-enabled NO CODE_SIGNING_ALLOWED=NO`). Serial runs are
more reliable on a memory-constrained Mac; two runs failed before any test started ("runner
failed to initialize", "never finished bootstrapping") and passed after rebooting/erasing the simulator.

| # | Case (UI test) | Covers | Result 2026-10-10 |
|---|---|---|---|
| S1 | `testFirstLaunchShowsWelcome` | D1 (app side) | PASS |
| S2 | `testFaithNeutralOnboardingReachesToday` | D2 up to the Screen Time prompt, D40 (summary) | PASS |
| S3 | `testInterruptedOnboardingResumesAfterRelaunch` | D39 | PASS |
| S4 | `testReturningUserSkipsOnboarding` | D42 | PASS |
| S5 | `testBackKeepsTheFaithChoice` | onboarding back navigation | PASS |
| S6 | `testManualMomentCanBeCompleted` | manual moment flow (not the shield hand-off) | PASS |
| S7 | `testPrivacyPolicyIsReadableInApp` | 5.1.1(i) in-app policy | PASS |
| S8 | `testSettingsOffersNotificationsAndShowsBuild` | D41 (app side: status + "Allow notifications"; the system prompt itself is not tapped) | PASS |
| S9 | `testDeleteAllDataReturnsToSetup` | D31 (app side: data + setup reset, persists across relaunch) | PASS |
| S10 | `testAccessibilityAuditWelcome` / `…Today` / `…Settings` / `…DarkAppearance` | Xcode accessibility audit, light and dark | PASS (with the documented exclusions below) |
| S11 | `testLargestTextSizeKeepsMainFlowUsable` | AX5 Dynamic Type: setup completes, Begin and notification controls reachable; screenshots attached | PASS |
| S12 | `testIntentionFlowsFromTodayIntoTheMoment` | Personal intentions: Today → moment → completion echo | PASS |
| S13 | `scripts/screenshot-tour.sh` | Visual QA of every main screen, light and dark (not an assertion test) | captured and reviewed 2026-10-10 |

Audit exclusions (`PrayerLockUITests`, each root-caused — DECISIONS D45): Today's three-line
preview excerpt (intentional; VoiceOver reads the full text); contrast measured under the
translucent tab bar; "Show transliteration" Dynamic Type (one long word hyphenates at AX5 — the
AX5 test asserts the row grows past 80pt); one unattributed Dynamic Type finding in Settings,
consistent with system toggle switches (iOS never scales them). Fixed rather than excluded:
eyebrow tracking, the non-scaling Appearance segmented control.

Defects the simulator found and fixed: Welcome text could clip at large sizes (now scrolls);
section headings could not wrap; Form headers/footers/values used iOS grey (~3.2:1 on the cream
canvas) — now `plInkSecondary` (≥ 4.5:1).

Not covered by the simulator (stay NOT RUN until a physical iPhone): Screen Time authorization,
the app picker, shields, shield actions, hand-off notifications, relocks, midnight/time-zone,
reboot, revocation, token expiry, extension failure (D3–D38), VoiceOver navigation.
**Simulator results are never evidence that protection works.**

## C. REAL DEVICE — ⛔ no iPhone connected, no signing identity, no Team ID (rechecked 2026-10-10)

Prerequisites: docs/12-signing-setup.md steps 1–4. **A paid Apple Developer Program team is
required** — Family Controls isn't available to free Personal Teams (Apple DTS, forum 764682).
Distribution approval is reportedly *not* needed for development builds (developer reports —
confirm on first install).
Devices: one each on **iOS 18.x**, **26.4**, **≥ 26.5** (shield hand-off differs).

### Pre-flight (first signed build — before any scenario)

| # | Check | How | Expected |
|---|---|---|---|
| P1 | Entitlements expanded and embedded | `codesign -d --entitlements - <App>.app` and each `PlugIns/*.appex` | each shows `com.apple.developer.family-controls = true` and `application-groups = [group.<prefix>]` (the `$(PL_APP_GROUP_ID)` placeholder resolved). Not verifiable before signing — ad-hoc signing is refused by the iOS 27 SDK |
| P2 | Extensions registered | Settings → Screen Time → app list after authorization; Console for extension launch | no "principal class not found" / launch errors |
| P3 | App Group live in all processes | Protection diagnostics → "App Group container: available"; after D10/D12, events written by extensions appear | extension events (`shieldBeginTapped`, `relockFired`) visible in the app |

| # | Scenario | Steps | Expected | Evidence |
|---|---|---|---|---|
| D1 | Fresh installation | Delete app if present; install from Xcode | First launch shows Welcome | screenshot |
| D2 | First launch | Complete onboarding to the Protection step | No Screen Time prompt until "Allow" tapped | — |
| D3 | Authorization granted | Tap Allow → Face ID/passcode | Status → "Choose the apps…"; event `authorizationRequested` | report |
| D4 | Authorization denied | Fresh install, cancel the system sheet | Alert; status stays "Allow Screen Time access…"; event `authorizationFailed`; app usable | report |
| D5 | Picker before authorization | (dev-only probe) present picker without auth | Document actual behaviour (unknown) | notes |
| D6 | App selection | Choose 2 apps, 1 category, 1 website | Counts shown; `Label(token)` names render | report |
| D7 | Protection enabled | Toggle on | `shieldsApplied` event; OS shielded apps = 2, category shield on; daily guard in activities | report |
| D8 | Protected app opened | Open a chosen app | System shield with Beloved title "You chose to protect <App>", subtitle, Begin / Not now | screenshot |
| D9 | Shield displayed (category + website) | Open an app in the category; the website in Safari | Same shield copy (website title uses domain) | screenshot |
| D10 | Not now | Tap Not now | App closes to Home; event `shieldNotNowTapped` | report |
| D11 | Prayer moment entered — iOS ≥ 26.5 | Tap Begin | **Record:** does Beloved open directly (`openParentalControlsApp`)? Notification also posted? | screen recording |
| D12 | Prayer moment entered — iOS < 26.5 | Tap Begin | Shield redraws "Open Beloved to begin…"; notification arrives; tapping it opens the moment showing the app's icon/name | screen recording |
| D13 | Notifications denied | Repeat D12 with notifications off | Shield text still guides user to open the app manually | screenshot |
| D14 | Temporary unlock | Complete moment (5-s minimum), choose intention | "Your apps are open until HH:MM"; shields cleared; relock activity present | report |
| D15 | Re-lock (15/30/60 min) | Wait past end while using the phone | Shield returns within ~1 min of end; `relockFired intervalEnded` | report + time |
| D16 | Re-lock (5-min use) | Unlock with 5 min; use the app 5 min | Shield returns after ~5 min of use; `relockFired usageLimitReached` | report + time |
| D17 | Re-lock (rest of day) | Unlock late evening | Shield returns after midnight on next use | report |
| D18 | Back-to-back unlocks | Unlock; within 2 min unlock again | No premature relock; `staleRelockIgnored` logged for the first grant | report |
| D19 | Multiple protected apps | Unlock, open each app | All open during window; all shielded after | screenshots |
| D20 | Remove one app | Remove one in picker while protected | Removed app opens freely; others shielded | report |
| D21 | Remove all apps | Deselect everything | **No shield anywhere**; protection off; activities empty | report |
| D22 | Token expiration (≥ 26.5) | Hard to force — observe over days; note any `tokensRefreshed` / `tokenRefreshFailed` | Shields keep working, or app asks to choose apps again | report |
| D23 | Authorization revoked | Settings → Screen Time → turn off Beloved access | On return: "Protection is paused" + re-allow; re-allow restores shields without re-picking (verify the system also removed shields when revoked) | report |
| D24 | App restart | Force-quit during an unlock; reopen after expiry | Shields re-applied on launch at latest | report |
| D25 | Device restart | Restart while protected and during an unlock | Shields persist after reboot; relock still fires | report |
| D26 | Background/foreground | Background Beloved during/after unlock, return | Status updates; pending shield request opens moment once | report |
| D27 | Extension behaviour | Run D8–D18 with Console.app filtered by subsystem | No crashes; shield config extension writes nothing; monitor callbacks logged | Console log |
| D28 | Protected app deleted/reinstalled | Delete a protected app, reinstall | Document: does the shield apply to the reinstalled app? | notes |
| D29 | Beloved deleted/reinstalled | Delete Beloved while protected | Expect all shields gone; reinstall starts fresh | notes |
| D30 | Memory | Instruments on each extension during D8–D16 | Within limits, no jetsam kills | Instruments trace |
| D31 | Delete all my data | Settings → Delete | Shields, activities, events cleared | report |
| D32 | Single protected app | Select exactly one app; enable; open it; unlock; relock | Same as D8–D15 with one token | report |
| D33 | Window ends while phone idle | Unlock 15 min; lock the phone for 30 min; unlock phone, open app | Shield on first use (callbacks need device use); `relockFired` timestamp near first use | report |
| D34 | Window crosses midnight | Unlock "Rest of the day" at 23:55, or 15 min at 23:55 | Daily guard does **not** cut a still-active grant short; relock at grant end | report |
| D35 | Time zone / clock change during unlock | Change time zone (and, separately, manual clock) mid-unlock | Document behaviour; no permanent unlock | report |
| D36 | Refresh on every activation (≥ 26.5) | Open/close app 20× over a day with valid tokens | No spurious `tokenRefreshFailed` / "Confirm your apps" (validates the refresh-on-activation assumption) | report |
| D37 | Extension failure fallback | Force an extension crash in a dev build (temporary `fatalError` behind a debug flag) | Apple documents a **default system shield** if configuration fails/takes too long — confirm the user is still blocked, and the action extension failing doesn't unlock | screenshot |
| D38 | Failed relock scheduling | Cannot be forced reliably on device | Fail-safe covered by automated tests; on device watch for `relockSchedulingFailed` in any run | report |
| D39 | Onboarding interrupted | Fresh install; answer faith + tradition; force-quit on Privacy; reopen | Resumes on Privacy with answers kept (rule unit-tested: `OnboardingFlowTests`) | report |
| D40 | Onboarding summary | Complete setup with and without protection/notifications | Summary shows practice, length, protection and notification state accurately; "Start using Beloved" opens Today | screenshot |
| D41 | Notifications recovery | Choose "Not now" in setup; Settings → Notifications → Allow; then deny in iOS Settings and return | Status updates On / Off; "Turn on in the Settings app" opens Beloved's notification settings | report |
| D42 | Returning user | Complete onboarding; force-quit; reopen | Today shown; onboarding not repeated | — |

## Coverage map (Phase 2.5 review)

| Area | Required case | Scenario(s) |
|---|---|---|
| Authorization | first / denied / revoked | D3 / D4 / D23 |
| Selection | one app / multiple / category / remove one / remove all / expired tokens | D32 / D19 / D9 / D20 / D21 / D22, D36 |
| Protection | app launch / shield / shield action / opening Beloved / moment / unlock / re-lock | D8 / D8–D9 / D10–D12 / D11–D12 / D14 / D14 / D15–D17 |
| Reliability | app killed / relaunched / device restart / background-foreground / stale callbacks / monitoring expiry / token expiry | D24 / D24 / D25 / D26 / D18 / D33–D34 / D22 |
| Failure states | no authorization / expired selection / failed relock / unavailable token / extension failure | D4, D23 / D22 / D38 (+ automated) / D28 / D37 |

Gaps that remain: token expiry cannot be forced on demand (observational only); failed
relock scheduling cannot be forced on device (automated coverage only).

## D. APPLE ENTITLEMENT (distribution) — ⛔ not requested yet

Requires Apple's approval of the Family Controls distribution entitlement for **each** of
the 4 bundle IDs (docs/12, step 5).

| # | Case | Expected |
|---|---|---|
| E1 | Distribution capability visible for app + 3 extension IDs in the developer portal | all four show Family Controls (Distribution) |
| E2 | Archive with real identity | "Validate distribution identity" passes; archive succeeds |
| E3 | TestFlight internal build | installs; D3–D21 repeated on the TestFlight build |
| E4 | App Store review build | reviewer notes explain `.individual` self-management + how to test |

## Results log

| Date | Device / iOS | Build | Scenarios | Result | Report attached |
|---|---|---|---|---|---|
| — | — | — | — | not yet run | — |
