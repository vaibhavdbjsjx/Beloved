# Beloved

An iPhone app that turns the moment you reach for a distracting app into a moment of prayer:
**Pause → Spiritual moment → Intention → Access.** Multi-faith (Christianity, Islam, Hinduism
to start), privacy-first, built on Apple's Screen Time APIs.

> Public brand: **Beloved** (chosen 2026-10-05; see the conflict report in
> [docs/19](docs/19-app-store-readiness.md) §2). The folder, Xcode targets and package keep
> their original `PrayerLock` names until the repository is renamed.

**App Store readiness: see [docs/19](docs/19-app-store-readiness.md) (audit, blockers, owner
actions) and [docs/20](docs/20-app-store-submission-kit.md) (metadata, review notes, privacy
answers).**

## Status — Phase 5 (release hardening done; never run on a device; not submittable yet)

| Area | State |
|---|---|
| Domain logic (faith model, content engine, calendar, habits, protection, monetization, AI pipeline) | Implemented in `Packages/PrayerLockKit`, **145 unit tests passing** |
| iOS app (onboarding, Today, Moment, Protection, Journey, Settings, dev diagnostics) | Implemented, **compiles** (Debug + Release, 0 warnings); never run on a simulator or device |
| Protection loop (Phase 2) | Safety rules in a tested `ProtectionEngine` (45 protection tests); iOS adapter + 3 extensions **compile against the iOS 27 SDK**; **not verified on a real iPhone** — see [docs/11](docs/11-device-test-plan.md) |
| Signing | Identity in `Config/Identity.xcconfig` (placeholders until the owner sets them); archives blocked until then — see [docs/12](docs/12-signing-setup.md) |
| Content | 26 **draft** items — release builds show none until reviewed and rights-cleared; archives are blocked until every offered faith has content (`python3 Config/release-content-report.py`) |
| Subscriptions | None in this release (nothing premium exists yet); StoreKit 2 code dormant and tested; no purchase UI shown |
| AI assistant | Not in this release (no backend, no UI, no keys); pipeline code unit-tested |
| Privacy | No network, accounts, analytics or SDKs; privacy policy bundled in-app (`App/PrayerLock/Resources/Legal/PrivacyPolicy.md`) and generated for the web (`website/`) |
| Icon | Original 1024 px icon in `Assets.xcassets/AppIcon.appiconset` |

## Repository layout

```
App/                      SwiftUI app (Sources/App = composition root & state, Sources/Features = screens)
Extensions/               ShieldConfiguration, ShieldAction, ActivityMonitor
Packages/PrayerLockKit/   PLCore · PLFaith · PLContent · PLCalendar · PLHabits · PLProtection
                          PLMonetization · PLAssistant · PLDesign  (+ Tests)
UITests/                  XCUITest smoke tests
Config/                   xcconfig files (copy Secrets.example.xcconfig → Secrets.xcconfig)
website/                  public privacy/support pages generator (see website/README.md)
docs/                     research, architecture, decisions, checklists
```

## Build & test

```bash
cd Packages/PrayerLockKit && swift test
```

```bash
xcodebuild -project PrayerLock.xcodeproj -scheme PrayerLock -destination 'generic/platform=iOS' build CODE_SIGNING_ALLOWED=NO
```

To run on a device: follow [docs/12-signing-setup.md](docs/12-signing-setup.md) (set the
identity in `Config/Identity.xcconfig`, register the App Group + Family Controls for all four
bundle IDs), then run the device test plan in [docs/11](docs/11-device-test-plan.md).

## Documentation

| Doc | Topic |
|---|---|
| [00 Technical assessment](docs/00-technical-assessment.md) | Starting point, toolchain, key choices |
| [01 iOS capabilities](docs/01-ios-capabilities.md) | What Screen Time APIs can/can't do (verified in the iOS 27 SDK) |
| [02 Architecture](docs/02-architecture.md) | Modules, processes, navigation, lock loop, cross-cutting concerns |
| [03 Data models](docs/03-data-models.md) | Types and where data lives |
| [04 Faith, content & calendar](docs/04-faith-content-calendar.md) | Faith model, provenance, content engine, calendar engine |
| [05 AI architecture](docs/05-ai-architecture.md) | Assistant pipeline and safeguards |
| [06 Privacy model](docs/06-privacy-model.md) | Commitments and how they're enforced |
| [07 Monetization](docs/07-monetization.md) | StoreKit 2 architecture |
| [08 Testing strategy](docs/08-testing-strategy.md) | Test layers + device test plan |
| [09 App Store checklist](docs/09-app-store-checklist.md) | Readiness and review risks |
| [10 Competitive landscape](docs/10-competitive-landscape.md) | Category research and differentiation |
| [11 Device test plan](docs/11-device-test-plan.md) | Automated / simulator / real-device / entitlement test cases |
| [12 Signing setup](docs/12-signing-setup.md) | Identity, capabilities, entitlement request (owner steps) |
| [13 Pre-device readiness](docs/13-pre-device-readiness.md) | Target matrix, signing/device checklists, assumption register (what is and isn't verified) |
| [14–18 Naming research](docs/18-second-generation-brand-research.md) | Brand research rounds (history) |
| [19 App Store readiness](docs/19-app-store-readiness.md) | Phase 5 audit: brand conflicts, completeness, privacy, permissions, interaction map, owner actions, score |
| [20 Submission kit](docs/20-app-store-submission-kit.md) | Metadata draft, App Review notes, App Privacy and accessibility answers |
| [Decisions](docs/DECISIONS.md) · [Roadmap](docs/ROADMAP.md) | ADR log and phases |
