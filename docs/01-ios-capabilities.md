# iOS capabilities & limitations (research — device behaviour unverified)

Research date: 2026-10-01 (Phase 1), re-verified and extended in Phase 2 (§7). Primary source: the **iOS 27.0 SDK shipped with Xcode 27.0 (27A266a)** —
the `.swiftinterface` and `.swiftdoc` files of `FamilyControls`, `ManagedSettings`,
`ManagedSettingsUI`, and `DeviceActivity`, plus Xcode 27's own extension templates. Where a
fact comes from elsewhere it is marked.

Legend: **[SDK]** read from the iOS 27 SDK · **[Docs]** developer.apple.com · **[Forum/3rd-party]**
reported, not authoritative · **[Unverified]** must be tested on a device.

---

## 1. What a normal App Store app can do

| Capability | API | Status |
|---|---|---|
| Ask the user (adult) to let *this app* restrict *their own* device | `AuthorizationCenter.shared.requestAuthorization(for: .individual)` (iOS 16+) — Face ID / Touch ID / passcode confirmation | **[SDK]** |
| Let the user pick apps, categories, websites | `FamilyActivityPicker` / `.familyActivityPicker(...)` (title variant iOS 26.2+) → `FamilyActivitySelection` (Codable) | **[SDK]** |
| Know *which* apps were picked | **No.** The app only receives opaque `ApplicationToken` / `ActivityCategoryToken` / `WebDomainToken`. It can *render* them with `Label(token)` but never read names or bundle IDs. | **[SDK]** |
| Put a shield over picked apps/categories/sites | `ManagedSettingsStore(named:).shield.applications / applicationCategories / webDomains / webDomainCategories` | **[SDK]** |
| Limits | "Your app can shield up to **50** application tokens at once"; same for categories and web domains (and 50 exceptions) | **[SDK]** doc comments |
| Customize the shield | `ShieldConfigurationDataSource` → `ShieldConfiguration`: blur style, background color, icon, title, subtitle, primary button (label + color), secondary button label. **No custom views.** iOS 26.4+: up to 3 `secondaryButtonSubmenuItems`. | **[SDK]** |
| React to shield buttons | `ShieldActionDelegate.handle(action:for:completionHandler:)` → `.none`, `.close`, `.defer` | **[SDK]** |
| **Open the app from the shield** | `ShieldActionResponse.openParentalControlsApp` — **iOS 26.5+**, documented as "open your parental controls app that is responsible for shielding the application". Before 26.5 there was no official way (Apple DTS confirmed "not officially supported", July 2025 — [forum 793060](https://developer.apple.com/forums/thread/793060)). | **[SDK]**; behaviour under `.individual` **[Unverified]** |
| Re-shield after a while | `DeviceActivityCenter.startMonitoring(_:during:events:)` + a `DeviceActivityMonitor` extension | **[SDK]** |
| Schedule limits | `MonitoringError.intervalTooShort`: "The minimum interval length … is **fifteen minutes**." `intervalTooLong`: max **one week**. `excessiveActivities` exists (count limit not documented in SDK). | **[SDK]** |
| Usage-based relock | `DeviceActivityEvent(applications:categories:webDomains:threshold:)` → `eventDidReachThreshold` | **[SDK]** |
| Callback timing | Interval callbacks fire "when someone uses the device during the interval"; "The system additionally calls `intervalDidEnd(for:)` when you stop monitoring an activity with an ongoing interval." | **[SDK]** doc comments |
| Token expiry | iOS 26.5+: `ManagedSettingsStore.refresh(_:)` for expired tokens and a `tokensDidExpire` notification message. **Stored selections can go stale.** | **[SDK]** |
| Store management | iOS 26.5+: `isActive`, `deleteStore()`, `deleteStores(_:)`, `stores` | **[SDK]** |
| Usage data in-app | iOS 26.4+: `FamilyActivityData` (installed apps, visited domains) and `DeviceActivityData.activityData(...)` — need the separate `family-controls.app-and-website-usage` entitlement, `.approvedWithDataAccess`, and a supported region. **Not used** (privacy). | **[SDK]** |
| Prevent deleting apps | `ApplicationSettings.denyAppRemoval` exists. **Not used**: Prayer Lock is a voluntary self-control tool, not a parental lock. | **[SDK]** |

### Extension points (from Xcode 27 templates)

| Extension | `NSExtensionPointIdentifier` | Principal class base |
|---|---|---|
| Shield Configuration | `com.apple.ManagedSettingsUI.shield-configuration-service` | `ShieldConfigurationDataSource` |
| Shield Action | `com.apple.ManagedSettings.shield-action-service` | `ShieldActionDelegate` |
| Device Activity Monitor | `com.apple.deviceactivity.monitor-extension` | `DeviceActivityMonitor` |
| (later) Device Activity Report | template exists | for on-device usage charts |

All require the `com.apple.developer.family-controls` entitlement (template entitlements file).

---

## 2. What this means for the Prayer Lock mechanism

The intended loop is *Pause → Spiritual moment → Intention → Access*. Mapped to real APIs:

1. **Pause** — the system shield appears when a protected app opens. We control only its text,
   icon, colors and two buttons. → A calm *invitation*, not the prayer itself.
2. **Hand-off to the app** — user taps **Begin**:
   - iOS 26.5+: respond `.openParentalControlsApp` (feature-flagged with
     `PLUseOpenParentAppResponse` in the extension's Info.plist).
   - Always also post a local notification ("Your moment is ready") and respond `.defer` on
     older iOS, so the shield redraws with "Open Prayer Lock to begin". This is the same
     notification-based workaround the category uses; it is honest and needs no private API.
3. **Spiritual moment + intention** — full SwiftUI in the app (no restrictions).
4. **Access** — the app clears the shield *only after* successfully scheduling a relock:
   - ≥ 15 min: one-off DeviceActivity schedule; `intervalDidEnd` re-shields.
   - < 15 min (e.g. "5 minutes"): 15-minute schedule **plus** a usage threshold event —
     i.e. "5 minutes of use, at most 15 minutes". The UI says exactly this.
   - Safety nets: a repeating daily guard schedule re-shields every day, and the app
     re-shields on foreground if a grant expired.
5. **Return to the app** — **not possible programmatically**: an app cannot open another app by
   token. The completion screen says "your apps are open — you can switch back now".

Design consequences implemented in code:
- Per-grant DeviceActivity names (`prayerlock.relock.<uuid>`) so the `intervalDidEnd` fired by
  `stopMonitoring` on a replaced grant is ignored (otherwise a fresh unlock would instantly relock).
- Fail-safe ordering: relock scheduled before shields are removed.
- Selection limit validation (50/50/50) surfaced in the UI.

## 3. Calls, notifications, Focus — what is NOT possible

Verified against the iOS 27 SDK headers:

| Wish | Reality | Closest legitimate alternative |
|---|---|---|
| Block incoming calls during prayer | No API. CallKit's Call Directory extension can only block **specific phone numbers** (`addBlockingEntry(withNextSequentialPhoneNumber:)`) — a spam-blocking tool, not "do not disturb". | Guide the user to a **Focus** (e.g. a "Prayer" Focus) in Settings. |
| Turn on Focus / Do Not Disturb | No API to enable Focus. `INFocusStatusCenter` only *reads* whether a Focus is on (with permission). | (a) User-created Shortcuts automation with Apple's "Set Focus" action, triggered by a Prayer Lock **App Intent** (e.g. "Start a prayer moment") — later phase. (b) `SetFocusFilterIntent` lets Prayer Lock *adapt itself* when the user's Focus is on (e.g. stricter defaults in a "Prayer" Focus). |
| Silence other apps' notifications | No API. `UNNotificationInterruptionLevel` applies only to the app's **own** notifications. | Focus (user-configured). |
| Hide notifications from shielded apps | **[Unverified]** whether notifications from shielded apps are suppressed. Do not claim either way until tested. | — |

The app shows these limits plainly (Protection tab: "What protection can and can't do"). No
setting claims to block calls or notifications.

## 4. Entitlements & distribution

- `com.apple.developer.family-controls` — **development** use is available when the capability
  is added in Xcode; **App Store distribution requires Apple's approval** via the Family
  Controls distribution entitlement request. **[Docs/Forum]**
- Developers report long or silent waits for that approval in 2026 (e.g. [forum 818553](https://developer.apple.com/forums/thread/818553)). **[Forum]**
  → Request it **as soon as the bundle IDs are final**, for the app **and every extension**
  (each bundle ID needs the capability — **[Forum/3rd-party]**, confirm when requesting).
- App Group `group.<prefix>` for app + extensions.
- Time-Sensitive notifications would need their own entitlement — deliberately **not** used.

## 5. Platform/tooling notes

- No iOS Simulator runtime is installed on the development Mac (and only ~8.5 GB disk free),
  so nothing has run on a simulator yet. Screen Time APIs need a **real device** for meaningful
  testing anyway (authorization and shields are limited in Simulator — **[3rd-party]**).
- Foundation on iOS 18+ includes Hindu lunisolar calendars (`.vikram`, `.gujarati`, `.marathi`,
  `.kannada`, `.telugu`, …) **[SDK]**. Candidate for computing Hindu festival dates — must be
  validated against published panchangs before use (see docs/04).

## 6. Open questions to resolve on a device (Phase 2 test plan)

1. Does `.openParentalControlsApp` open Prayer Lock under `.individual` authorization? On which iOS versions?
2. Is the hand-off notification reliably posted from the Shield Action extension?
3. One-off schedules with full date components (year…second): do `intervalDidEnd` callbacks arrive on time?
4. Usage-threshold relock for 5-minute unlocks: accuracy and latency.
5. Behaviour when tokens expire (iOS 26.5 `tokensDidExpire`) — implement refresh.
6. Notifications from shielded apps: suppressed or not?
7. Memory headroom of each extension (they run with tight limits).

## 7. Phase 2 verification (2026-10-01)

### Licence terms — **[Docs]**, quoted from the Apple Developer Program License Agreement §3.3.3(P)
> "To use the Family Controls Framework, Your Application must have a primary purpose of
> (1) offering family controls for parents and guardians … and/or (2) offering individuals
> the ability to manage their devices to enable focus and productivity through focus
> controls, timers and task management, or personal device usage management. … Device or
> usage data received through the Family Controls Framework may only be used for providing
> family controls, or individual device management. You and Your Application may not share
> device or usage data … You may not use or share such device or usage data for purposes of
> advertising …"

Consequences: Prayer Lock must be positioned (entitlement request, App Store listing, review
notes) as **personal device-usage management with a prayer/reflection pause**; no
Family-Controls-derived data (selection, unlock history, event log) may ever leave the device —
including to a future AI service.

### Entitlement
| Question | Answer | Source |
|---|---|---|
| Key | `com.apple.developer.family-controls` (Boolean); "Adding the Family Controls capability … automatically sets this entitlement" | **[Docs]** |
| App Store | "Before submitting your app to the App Store, you must request permission"; form: developer.apple.com/contact/request/family-controls-distribution | **[Docs]** |
| Which targets | App **and every Screen Time extension** bundle ID need it (our 4 entitlements files) — request distribution approval per ID; no wildcard IDs | **[Forum/3rd-party]** ([818419](https://developer.apple.com/forums/thread/818419), [701874](https://developer.apple.com/forums/thread/701874)) |
| Development before approval | Works on device with development signing | **[Forum]** — confirm on first install |
| TestFlight | Blocked until the distribution capability is enabled on the identifiers | **[Forum]** |
| Simulator | No runtime available here; Screen Time behaviour in Simulator is reported as limited — not evidence | **[3rd-party]** |

### SDK details that changed the implementation
- **Shield Configuration extension sandbox** **[SDK]**: "This sandbox prevents your extension from
  making network requests or moving sensitive content outside the extension's address space."
  It receives app names, so it is read-only (no App Group writes, no event logging).
- **Shield Action delegate** **[SDK]**: "The system doesn't provide the name of a shielded
  Application, WebDomain, or ActivityCategory" — tokens only.
- **Token expiry** **[SDK, iOS 26.5]**: `ManagedSettingsStore.refresh(_:)` (for app, category, and
  web-domain token arrays, `throws`, no documented error type) and the `tokensDidExpire`
  `NotificationCenter` message ("Use these messages to refresh tokens in your database that are
  expired"), observed via `NotificationCenter.default.addObserver(of: ManagedSettingsStore.self, for: .tokensDidExpire)`.
  What happens to tokens that *can't* be refreshed (e.g. app deleted) is undocumented → the app
  asks the user to choose again. Before iOS 26.5 there is no refresh API.
- **Usage-threshold events** **[SDK]**: `DeviceActivityEvent(…, includesPastActivity:)` (iOS 17.4+)
  is now passed explicitly as `false`, so a short unlock counts only use *after* the unlock.
- **Picker and authorization** **[SDK]**: the picker is documented in terms of an "individually
  authorized device"; the app therefore requests authorization *before* showing the picker.
  Picker behaviour without authorization is undocumented (device test D5).

### Category landscape (iTunes Search API, 2026-10-01)
The previously cited "prayer lock: christian focus" (id 6744703926) no longer resolves in the
US/IN/GB storefronts. Many "Prayer Lock"-named apps exist, including Islam-specific (DeenLock,
Salat Guard, "prayer lock islam", "prayer lock: muslim focus", "Prayer Lock: Noor") and
Hindu-specific (Dharma Lock) blockers. See docs/10.
