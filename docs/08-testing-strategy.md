# Testing strategy

## Layers

| Layer | Tooling | Runs where | Status |
|---|---|---|---|
| Domain unit tests (8 targets) | Swift Testing, `Packages/PrayerLockKit/Tests` | `swift test` on macOS (seconds), or the iOS scheme | **141 tests passing** on macOS (Phase 2: +29 protection-engine tests with a fake platform) |
| Data integrity | `CatalogValidator` + tests over bundled JSON | same | passing (0 structural errors; drafts flagged as warnings) |
| iOS compile checks | `xcodebuild build` / `build-for-testing` for `generic/platform=iOS` | Mac | passing (app + 3 extensions + all test bundles, Debug & Release) |
| UI smoke tests | XCUITest (`UITests/`), launched with `-PLUITesting` (throwaway storage) | Simulator/device | **written, compiled, not yet run** (no simulator runtime installed) |
| Screen Time device tests | **docs/11-device-test-plan.md** (31 device scenarios + entitlement cases) | physical iPhone with a signing team | **not yet possible** (no device, no signing identity in this environment) |

## Commands

```bash
# Fast: all domain tests on the Mac
cd Packages/PrayerLockKit && swift test

# Compile app, extensions and every test bundle for iOS
xcodebuild -project PrayerLock.xcodeproj -scheme PrayerLock -destination 'generic/platform=iOS' build-for-testing CODE_SIGNING_ALLOWED=NO

# Everything on a simulator (after installing an iOS runtime: Xcode ▸ Settings ▸ Components)
xcodebuild -project PrayerLock.xcodeproj -scheme PrayerLock -destination 'platform=iOS Simulator,name=iPhone 17' test
```

## What the unit tests pin down

- **Calendar correctness**: Western Easter 2000–2027 sample years, Orthodox Pascha, Julian
  Christmas → 7 Jan, Advent starts, Lent 2026 range, Ramadan as an Umm al-Qura month with
  round-trip checks and "estimated" precision, weekly observances, tradition filtering, no
  invented Hindu dates.
- **Content integrity**: bundled catalog has no structural errors; AI text rejected from
  catalog; quotations need edition + reference; cross-faith taxonomy rejected; release policy
  blocks drafts and uncleared editions; *no fixture is shippable today*.
- **Selection**: never crosses faiths; neutral-only for "rather not say"; mood, occasion,
  focus, tradition, premium rules; daily determinism and anti-repeat.
- **Protection**: unlock plans respect the 15-minute minimum and one-week maximum; short
  unlocks use usage thresholds; status derivation; request expiry/consumption; 50-item limits.
- **Habits**: streak alive until day ends, gaps, abandoned sessions ignored, time-zone day
  boundaries, consistency and totals.
- **Monetization**: entitlement matrix incl. grace period and stale cache; verified-only
  mapping; config contains no prices; unavailable service is honest.
- **Assistant**: crisis routing (and sincere requests not misrouted), intent parsing for the
  spec's example requests, validator guarantees (fabricated quotes/references removed,
  library text substituted), crisis never reaches generation, prompt minimisation.

## Build matrix (Phase 2, 2026-10-01)

| Build | Result |
|---|---|
| Package for iOS (all modules incl. Screen Time adapter) | ✅ succeeded, 0 warnings |
| App scheme Debug / Release (app + 3 extensions), unsigned | ✅ succeeded, 0 warnings |
| ShieldConfiguration / ShieldAction / ActivityMonitor schemes alone | ✅ succeeded, 0 warnings |
| build-for-testing (8 unit bundles + UI tests) | ✅ succeeded |
| Signed device build | ❌ "Signing for … requires a development team" (all 4 targets) — expected, no Team ID |
| Archive | ❌ blocked by "Validate distribution identity" — expected while identity is placeholder |
| Run tests on a simulator | ❌ "Unable to find a device matching … iOS Simulator" — no runtime installed |

## Device test plan for Screen Time (superseded by docs/11-device-test-plan.md)

Run on at least: one device on iOS 18.x, one on iOS 26.4, one on ≥ 26.5.

1. Authorization: approve, deny, revoke in Settings → app status updates.
2. Picker: apps, categories, websites; >50 apps shows the limit message.
3. Shield appears on protected apps/sites with Prayer Lock copy and app name.
4. **Begin**: (≥26.5) app opens directly? (<26.5) notification arrives; shield shows "Open Prayer Lock…".
5. Moment completion → apps open; completion copy matches chosen duration.
6. Relock: 15/30/60 min at wall-clock end; 5 min after 5 min of *use*; rest-of-day at midnight.
7. New unlock during an active unlock → no premature relock (stale callback ignored).
8. Protection off → shields removed immediately; on → re-applied.
9. Remove all apps → shields removed (no stale shields).
10. Reboot / force-quit app during unlock → relock still happens.
11. Token expiry (≥26.5) handling.
12. Extension memory (Instruments) under load.
13. Notifications from shielded apps — observe and document behaviour.

## Gaps to close next

- Run XCUITests on a simulator; add accessibility audits (`performAccessibilityAudit`).
- App-layer unit tests for `AppModel` (needs protocol seams around Screen Time).
- Snapshot tests for key screens in light/dark and largest Dynamic Type sizes.
- StoreKitTest-based purchase tests once products exist.
