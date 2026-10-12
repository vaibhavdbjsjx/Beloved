# Privacy model

Religious belief is special-category personal data (e.g. GDPR Art. 9). Prayer history and
moods are intimate. The design goal is to need almost none of it off-device.

## Commitments (implemented in Phase 1)

| Commitment | How |
|---|---|
| No account | There is no sign-in, no server user record. |
| No analytics, ads, or tracking SDKs | Zero third-party dependencies; `PrivacyInfo.xcprivacy` declares no tracking and no collected data. |
| No network calls with user data | The current build makes none (StoreKit is inactive while the paywall is disabled). |
| Local storage, encrypted at rest | Profile and history in the app's private container with `NSFileProtectionComplete`. |
| Least sharing with extensions | Extensions see only protection settings, shield copy, pending shield requests and the opaque app selection — never history, moods, or names. |
| Apple's opaque tokens | Screen Time gives tokens, not app names; the app never requests usage data (`FamilyActivityData` deliberately unused). |
| Optional personal data | Name, faith, tradition, focus, check-ins are all optional; "rather not say" is a first-class path. |
| Moods can be ephemeral | "Remember daily check-ins" off → mood used for today's choice only, never written to history or disk. |
| Delete everything | Settings → Delete all my data: removes profile, history, shared state, shields, schedules. |
| Logs | Never contain prayer text, moods, or names (policy in `Logging.swift`). |
| Protection event log (Phase 2) | Last 100 protection events (kind, time, counts/durations) in the App Group for troubleshooting; no app names or tokens; visible only in development builds' diagnostics; cleared by "Delete all my data"; never transmitted (also required by DPLA §3.3.3(P)). |
| Honest disclosure | The app states that device backups include its data. |

## Future features and their privacy rules

| Feature | Rule |
|---|---|
| AI assistant | Opt-in; minimised prompt (see 05); proxy stores no content by default; disclosed in the App Privacy label as "User Content — not linked to identity" if any is processed. |
| Sync across devices | Prefer CloudKit private database (Apple-hosted, user's iCloud) over our servers. |
| Accounts (if ever) | Must include in-app account deletion (Guideline 5.1.1(v)). |
| Analytics | Only aggregate, privacy-preserving, opt-in; never prayer content, moods, or faith. |
| Journal | Local, `.complete` protection, optional Face ID lock. |

## App Store privacy label (current build)

"Data Not Collected" is accurate **for Phase 1** — re-assess before each release, especially
when StoreKit, the assistant, or any analytics are enabled.
