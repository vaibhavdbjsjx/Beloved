# Working on Beloved

Multi-faith prayer + app-blocking iOS app. Public brand **Beloved** (`AppBrand.displayName` + `INFOPLIST_KEY_CFBundleDisplayName`); folder/targets/package keep the `PrayerLock` names; never rename Screen Time store/activity identifiers. Read `README.md` and `docs/` before large changes;
record significant decisions in `docs/DECISIONS.md`.

## Commands
- Domain tests (fast, macOS): `cd Packages/PrayerLockKit && swift test`
- iOS compile (app + extensions): `xcodebuild -project PrayerLock.xcodeproj -scheme PrayerLock -destination 'generic/platform=iOS' build CODE_SIGNING_ALLOWED=NO`
- iOS test bundles compile: same command with `build-for-testing`
- Everything that runs without a device: `sh scripts/verify.sh` (`--quick` skips Xcode builds)
- Release tooling tests (gate + content report): `python3 -m unittest Config/test_release_tools.py`
- Why each content item is hidden in Release: `python3 Config/release-content-report.py --items`
- Scripture: `python3 -I scripts/import_scripture.py [--fetch] [--check] [--sync-fixtures]` rebuilds `PLScripture/Resources` from checksum-pinned sources (`scripts/scripture/sources.json`, downloads in git-ignored `Vendor/`); tests: `python3 -m unittest scripts/test_import_scripture.py`. Never edit the generated JSON by hand except a reviewer's `review` approval.
- Devotional library (BCP 1979 prayers, Rigveda/stotra mantras, Qur'anic duas): `python3 -I scripts/import_devotions.py [--fetch] [--check] [--pin]` → `PLContent/Resources/devotions.json`; spec in `scripts/devotions/spec.json`, pins in `scripts/devotions/sources.json`; tests: `python3 -m unittest scripts/test_import_devotions.py`.
- Companion server (Cloudflare Worker): `server/companion` — tests `node --test server/companion/test/*.test.js`; deploy steps in its README (owner keys only).
- Website: `python3 website/build.py --config website/site.example.json --preview` (build runs `website/check.py`); tests: `python3 -m unittest website/test_site.py`
- UI tests (iOS 27.0 simulator installed): `sh scripts/verify.sh --ui`. Simulator results never prove Screen Time behaviour; that needs a real device.
- UI tests use `-PLUITesting` (throwaway store) and `PL_UI_TEST_STORE=<name>` to keep a store across relaunches.

## Protection loop (Phase 2)
- All protection rules live in `PLProtection/Engine` (`ProtectionEngine`, `RelockService`) behind `ProtectionPlatform`; `ScreenTimePlatform` is the only code touching FamilyControls/ManagedSettings/DeviceActivity. Add a `FakePlatform` test for every new rule.
- The Shield Configuration extension is sandboxed: read-only, links `PLBrand` not SwiftUI.
- Identity (bundle prefix, Team ID) only in `Config/Identity.xcconfig`; never invent a Team ID. The "Validate release readiness" phase (`Config/validate-release.sh`) blocks archives while placeholders remain or any offered faith has no release-visible content.
- Never claim device behaviour that hasn't been run on a physical iPhone; record runs in docs/11. The assumption register in docs/13 lists every unverified behaviour — update it when evidence arrives.

## Layout rules
- Product logic goes in `Packages/PrayerLockKit` (pure, `Sendable`, unit-tested). The app target is UI + composition root (`AppEnvironment`, `AppModel`).
- Lower modules never import higher ones (see `Package.swift` header). Screen Time code in the package is `#if os(iOS)`.
- The Xcode project uses synchronized folders: new files in `App/PrayerLock`, `Extensions/*/Sources`, `UITests` are picked up automatically. Don't hand-edit `project.pbxproj` unless adding a target.
- Domain modules hold identifiers, not UI strings; user-facing strings are `String(localized:)` / `LocalizedStringKey` in the app.

## Design (docs/27-design-system.md)
- Use PLDesign tokens and components (`plPaper`, `PLChoiceCard`, `.plPrimary`, `plEyebrow`, `ThresholdWindow`…); no raw colours or one-off sizes. One prominent action per screen.
- Every text colour pair must pass `PaletteContrastTests`; never signal state with colour alone.
- Respect Reduce Motion (`PLMotion.animation(_:reduceMotion:)`) and Dynamic Type (text styles / `@ScaledMetric`).
- Check light and dark with `sh scripts/screenshot-tour.sh OUT_DIR` before calling a screen done.

## Non-negotiables
- No fake functionality: never claim to block calls/notifications or anything iOS doesn't allow; say what isn't verified.
- Never invent religious text. Every content segment carries a `SegmentRole`; `sourceText` needs an edition + reference; AI text is never in the catalog. Keep `CatalogValidator` green.
- Scripture reader: text only from bundled editions, verbatim (Tanzil Arabic may never be altered; keep its notice and tanzil.net link). "Both" only when `versification` matches. Release shows an edition only when licence-cleared AND `review.status` approved (D50).
- Customs (weekday–deity etc.) are opt-in `DevotionalAssociation`s with explanations, not rules.
- Privacy: sensitive data only in the private container with `.complete` protection; extensions get only non-personal App Group state; never log prayer text, moods, or names.
- No secrets in the repo or app bundle; no prices in code (StoreKit only). No purchase UI unless `isPaywallEnabled` and real premium features exist.
- No placeholder or "coming soon" UI in release builds; links only to pages that exist (support/privacy URLs come from config and are hidden when empty).
- The privacy policy (`App/PrayerLock/Resources/Legal/PrivacyPolicy.md`) must change before any release that handles data differently; it also generates the web page (`website/build.py`).
- Unlock flow: schedule the relock before clearing shields; relock activities are per-grant.
- Swift 6 strict concurrency; zero third-party dependencies unless justified in DECISIONS.md.
