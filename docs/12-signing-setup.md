# Signing & entitlement setup (owner steps)

What the code already contains, and what only the account holder can do.

## Already configured in the repo

| Item | Where | Value |
|---|---|---|
| Bundle IDs (derived) | `Config/Identity.xcconfig` → `PL_BUNDLE_ID_PREFIX` | app `<prefix>`; extensions `<prefix>.ShieldConfiguration`, `<prefix>.ShieldAction`, `<prefix>.ActivityMonitor`; UI tests `<prefix>.UITests` |
| App Group | `Config/Shared.xcconfig` | `group.<prefix>` (same for all 4 targets) |
| Entitlements | `App/PrayerLock.entitlements`, `Extensions/*/*.entitlements` | `com.apple.developer.family-controls = true` + the App Group, for the app and all 3 extensions |
| Signing style | `Shared.xcconfig` | Automatic |
| Archive guard | build phase "Validate release readiness" → `Config/validate-release.sh` | archives fail while the prefix is a placeholder, the Team ID is empty, or an offered faith has no release-visible content |
| Placeholders | `Identity.xcconfig` | `PL_BUNDLE_ID_PREFIX = unconfigured.beloved`, `DEVELOPMENT_TEAM =` (empty) |

No passwords, certificates, private keys, or profiles are in the repo, and none are needed in it.

## What you need to do

1. **Choose the final bundle prefix** — a reverse-DNS name you control, ideally matching the
   brand (Beloved). It cannot be changed after App Store release.
2. **Set identity** in `Config/Identity.xcconfig`:
   ```
   PL_BUNDLE_ID_PREFIX = com.yourdomain.yourapp
   DEVELOPMENT_TEAM = <10-character Team ID from developer.apple.com → Membership>
   ```
   (A Team ID is not secret; committing it is normal. To build with a different team only on your own machine, override it in the git-ignored `Config/Secrets.xcconfig` instead.)
3. **Register identifiers** (Certificates, Identifiers & Profiles), or let Xcode's automatic
   signing create them on first build: the 4 explicit App IDs above (no wildcards), each with
   **Family Controls** and **App Groups** (`group.<prefix>`) enabled.
4. **Development on a device** — requires a **paid** Apple Developer Program membership: the
   Family Controls capability is not offered to free Personal Teams (Apple DTS,
   [forum 764682](https://developer.apple.com/forums/thread/764682)). Sign in to Xcode with that
   account, connect an iPhone, enable Developer Mode (Settings → Privacy & Security → Developer
   Mode → restart → Enable), build & run. Developers report Family Controls works in
   development builds **before** distribution approval (official docs only say approval is needed
   before App Store submission) — confirm on the first install (docs/11 P1–P3, D3).
   Note: ad-hoc signing is refused by the iOS 27 SDK, so a real team/profile is the only way to
   produce a signed build (verified 2026-10-01).
5. **Request distribution** at https://developer.apple.com/contact/request/family-controls-distribution
   — **once per bundle ID: the app and each of the 3 extensions** (developer reports; Apple
   staff direct problems to the portal/support). Approval can take days to weeks. Then enable
   "Family Controls (Distribution)" on each identifier.
6. **TestFlight/App Store** builds need step 5 complete for all four IDs.

### Wording for the entitlement request

Apple's licence (DPLA §3.3.3(P)) requires a primary purpose of "offering individuals the
ability to manage their devices to enable focus and productivity … or personal device usage
management". Describe Prayer Lock accordingly, e.g.:

> Prayer Lock is a personal device-usage management app. Users choose apps they want to use
> more intentionally; when they open one, a Screen Time shield invites them to pause, and the
> app guides a short reflection or prayer before granting time-limited access. It uses
> `.individual` authorization only, never manages another person's device, and no device or
> usage data leaves the device.

## What remains blocked until you act

| Blocked | Needs |
|---|---|
| Any signed build, device install, real-device testing | Team ID + Apple ID signed in to Xcode + iPhone |
| TestFlight / App Store | distribution approval for all 4 bundle IDs |
| Final bundle IDs | brand/name decision |
