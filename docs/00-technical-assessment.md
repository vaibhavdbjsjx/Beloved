# Technical assessment (start of Phase 1)

Date: 2026-10-01

## Starting state

- `~/Documents/pray` **did not exist**. It was created and initialised as its own git repository
  (the home directory is itself a git repo; a nested repo keeps Prayer Lock's history separate).
- No existing code, assets, configuration, or tests → nothing to preserve or migrate.
  Phase 1 therefore established a new foundation rather than extending one.

## Toolchain found

| Item | Value |
|---|---|
| Xcode | 27.0 (27A266a) |
| Swift | 6.4 |
| SDKs | iOS 27.0, iOS Simulator 27.0 (SDK only) |
| Simulator runtimes | **none installed** |
| Disk free | ~8.5 GB (too little to add a ~8 GB simulator runtime safely) |
| Homebrew / XcodeGen / Tuist | not installed |

## Decisions taken (details in DECISIONS.md)

| Area | Decision |
|---|---|
| Platform / UI | Native Swift 6 + SwiftUI, iOS-first. |
| Minimum iOS | **18.0** — keeps iPhone XS/XR (which can't run iOS 26+); newer APIs (26.4/26.5 shield features) are used behind `#available`. |
| Modularity | All product logic in a local Swift package (`Packages/PrayerLockKit`, 9 modules) that builds and tests on macOS in seconds; the Xcode project holds only UI + extension entry points. |
| Project file | Hand-generated Xcode project (objectVersion 77) with **synchronized folders** — no XcodeGen/Tuist dependency; new files are picked up automatically. |
| Persistence | Local JSON files with iOS Data Protection + App Group `UserDefaults` for extension-shared state. No database, no third-party dependencies. |
| Dependencies | **Zero third-party packages.** |
| Testing | Swift Testing for the package (runs via `swift test`); XCUITest smoke tests for app flows. |

## Constraints that shaped the work

- Screen Time behaviour can only be validated on a physical device with a signing team —
  unavailable in this session. iOS code is **compile-verified**, not run.
- Religious content must not be invented: the bundled catalog is explicitly a set of
  **draft development fixtures**, and release builds refuse to show unreviewed content.
