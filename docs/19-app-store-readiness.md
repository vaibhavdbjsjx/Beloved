# Beloved — App Store readiness audit (Phase 5)

Date: 2026-10-05. Public brand: **Beloved** (owner decision). Repository and folder names are
unchanged (`~/Documents/pray`, targets `PrayerLock`). Evidence labels: **VERIFIED** (run or
inspected on this Mac), **DOC** (current Apple documentation, cited), **UNVERIFIED** (needs a
signed build, a physical iPhone, App Store Connect or a person — see §17).

Nothing here claims the app works on an iPhone: it has **never run on a device or a
simulator** (no signing identity, no Team ID, no simulator runtime on this Mac).

## 1. Baseline (recorded before any change)

| Item | Value (VERIFIED) |
|---|---|
| Working directory | `/Users/vaibhavsg/Documents/pray`, its own git repository (`.git` in the folder) |
| Parent repository | `~` (BuzzOS repo) ignores the folder via `~/.git/info/exclude` line 10 `/Documents/pray/` |
| Branch / commits / remotes | `main`, **0 commits**, 0 remotes; all files untracked |
| Project files | 139 (non-ignored) before this phase |
| Targets | `PrayerLock` (app), `ShieldConfiguration`, `ShieldAction`, `ActivityMonitor` (app extensions), `PrayerLockUITests` |
| Bundle IDs | `$(PL_BUNDLE_ID_PREFIX)` + `.ShieldConfiguration` / `.ShieldAction` / `.ActivityMonitor` / `.UITests`; prefix was the placeholder `unconfigured.prayerlock` |
| App Group | `group.$(PL_BUNDLE_ID_PREFIX)` on all four targets |
| Entitlements | each of the four: `com.apple.developer.family-controls = true`, `com.apple.security.application-groups = [$(PL_APP_GROUP_ID)]` |
| Signing | Automatic; `DEVELOPMENT_TEAM` empty; 0 identities / 0 profiles on this Mac |
| Tests | 141 Swift Testing unit tests (8 bundles); 3 XCUITests (compile only) |
| Disk | **144 MB free (99 % full)** — see §16 |

## 2. Brand check — "Beloved" (2026-10-05)

**Result: serious conflicts.** The owner has chosen the name; these are the facts to weigh, not a
veto. Nothing here is legal advice or trademark clearance.

| Where | Finding | Class |
|---|---|---|
| App Store (iTunes Search API, US/IN/GB; 9 query variants) | 28 listings contain "beloved". **Same category:** "Beloved - Bible Verse & Prayer" (Reference, 2026), "Beloved: Bible for Women" (Reference, 2026, with an AI companion), "BeLoved: Scripture Meditation" (Lifestyle, 2025), "BelovedBible" (Book, 2026), "The Beloved — Salawat" (Islamic prayers, 2026), "Beloved Women" (Bible studies, 46 ratings), "THE BELOVED AWAKENING", "Beloved In Process", five church apps. **An app is already titled exactly "Beloved"** (Shopping, 2026-09-18) and another "BeLoved" (relationships, 2023). Couples/dating uses: "BeLoved: Couples Tracker", "Beloved AI: Your AI Love Story" (Play) | **RED** |
| Google Play (US/IN/GB) | "Beloved", "Beloved Women", "Beloved Presence", "Beloved In Process", "Beloved AI: Your AI Love Story", "My Beloved", others | **RED** |
| US trademarks (Trademarkia mirror of USPTO data) | 335 results. **BELOVED — Augustine Institute, Inc., live/registered in class 9 (downloadable media "in the field of religion"), 41 (religious education), 16 and 38** (filed 2014). BELOVED in classes 5, 14, 25, 30/35, 43 (other owners). "Beloved in Christ Gallery" (35/41) | **RED** (same field, class 9) |
| India trademarks (QuickCompany mirror of IP India data) | BELOVED in classes 3, 18, 30, 43 (other goods); "Untamed Beloved" class 41. No exact BELOVED found in classes 9/41/42/44/45 | YELLOW |
| Domains | beloved.com, beloved.app, getbeloved.com, joinbeloved.com (a caregiver-jobs service), belovedapp.com (for sale) — all registered; `.in` DNS SERVFAIL (unknown); belovedprayer.com no registration record | ORANGE |
| Social | GitHub, YouTube, Instagram (personal account) and X handles "beloved" taken; @belovedapp is a "Beloved Couples App" channel | YELLOW |
| Meaning | Multi-faith resonance, but each tradition has a specific referent: Jesus / the beloved disciple (Christianity); "the Beloved" (Ḥabīb) often means the Prophet Muhammad in Islamic devotion; Krishna as the beloved in bhakti. Also a romantic term of endearment | — |

**Consequences:**
- The App Store Connect app name must be unique (Guideline 2.3.7, DOC), and the plain
  "Beloved" is already used. A longer name is needed, for example "Beloved: Prayer Before
  Apps" (27 characters). Its availability can only be checked inside App Store Connect
  (UNVERIFIED).
- A trademark attorney should assess the Augustine Institute registrations **before launch**.

What was applied:
- The home-screen name (`INFOPLIST_KEY_CFBundleDisplayName`) and all in-app copy now read
  **Beloved**.
- The placeholder identity is now `unconfigured.beloved`.
- No permanent identifier was chosen.

Not renamed, because these are not user-visible:
- target, product and module names (`PrayerLock`; `CFBundleName` follows `PRODUCT_NAME`);
- the storage directory;
- Screen Time store and activity names;
- the notification identifier.

These go with the deferred repository rename. Renaming the Screen Time names later would
orphan shields on installed devices.

## 3. Placeholder / completeness sweep — findings and fixes

Searched all code and resources for TODO, FIXME, TBD, placeholder, dummy, lorem, sample,
example, mock, fake, "coming soon", "not yet", "later phase", temporary, and for every
user-visible string (VERIFIED).

| Finding | Action |
|---|---|
| **No app icon image** — `AppIcon.appiconset` declared a 1024 slot with no file, which would fail App Store validation | **Fixed:** original 1024×1024 icon, opaque (no alpha channel), lapis background with the app's breathing mark. Verified compiled into `Assets.car` (`AppIcon`, 1024 px) |
| Settings → Premium: "Premium isn't available in this version yet…" (coming-soon copy) | **Removed:** the whole Premium section is hidden while the paywall is disabled |
| Privacy screen: "If an optional assistant is added later…" (future promise) | **Replaced** with present-tense facts |
| Sources screen in release builds listed editions marked "Pending edition selection / Rights pending" | **Fixed:** release builds list only editions quoted by content users can see; development builds still list everything with its rights status |
| Brand strings "Prayer Lock" in an alert, the diagnostics report, shield fallback copy and editorial author labels | **Fixed** → Beloved |
| **All 26 content items are `draft`** → a release build shows **no prayers, scripture, mantras or duas** (only "Sit quietly for a moment") | **Not fixable by engineering.** Approving religious content needs qualified human review and rights clearance (§10). Added a **release gate**: archives now fail while any offered faith would show no content. Release builds warn (VERIFIED) |
| Hindu festival observances have no date source ("PENDING: regional panchang…") | Never displayed (no dates are produced), so nothing incomplete reaches users. Hindu festival dates are a content task (§10) |
| `ProtectionDiagnosticsView`, review badges, the "Development build" note | Already shown only when `PLEnvironment = development` (Debug). Release builds have `production` (VERIFIED in the built Info.plist) |
| Assistant pipeline | Not reachable from any screen; no endpoint configured; nothing to remove from the UI |

## 4. Interaction map — every visible control

| Screen | Control | Behaviour (code-verified) |
|---|---|---|
| Onboarding — Welcome | Get started | → Faith step |
| Onboarding — every later step | Back (chevron, labelled "Back") | → previous applicable step |
| Faith | Faith rows, "I'd rather not say" | select (selected trait announced) |
| Faith | Continue | disabled until a choice is made (dimmed); then → next applicable step |
| Tradition / Focus (only when the faith has them) | rows, "Prefer not to specify", Continue | select; continue |
| Personalize | First name field, Length picker, Show original script, Show transliteration, Use weekday customs (only for faiths with customs), Continue | edit the draft profile; continue |
| Privacy | Read the Privacy Policy | sheet with the bundled policy; Done closes it |
| Privacy | Continue | → Protection |
| Protection (setup) | Allow Screen Time access | system authorization (Face ID / Touch ID / passcode); on failure an alert explains |
| Protection (setup) | Choose apps / Change apps | system `FamilyActivityPicker` |
| Protection (setup) | Protection toggle | disabled until apps are chosen (status line explains why) |
| Protection (setup) | Open for (picker) | sets the unlock duration; footer explains how it is enforced |
| Protection (setup) | Continue / Set up later | → Notifications |
| Notifications | Allow notifications | system prompt, then onboarding finishes |
| Notifications | Not now | onboarding finishes |
| Today | Mood chips | select / deselect today's check-in |
| Today | Begin a moment | full-screen moment |
| Today | Protection row | switches to the Protection tab |
| Moment | Close (×, labelled) | dismisses |
| Moment | Begin | → check-in (if none today) or reflection |
| Moment | Mood chips / Skip | → reflection |
| Moment | I've prayed / I'm ready | enabled after 5 s (hint says so) → intention |
| Moment | 4 intentions / Skip | complete the moment (and unlock if protection is on) |
| Moment | Done | dismisses |
| Protection tab | the setup controls above, plus "Allow Screen Time access again" (revoked) and "Choose apps again" (re-selection) | as above |
| Journey | — | read-only; empty state when no moments |
| Settings | Faith & tradition → rows, Save | edits the profile; Save persists |
| Settings | Length, Show original script, Show transliteration, Use weekday customs, Remember daily check-ins | persist immediately |
| Settings | How your data is handled → Read the full Privacy Policy | in-app summary, then full policy |
| Settings | Privacy Policy | bundled policy (works offline) |
| Settings | Delete all my data → Delete everything | confirmation dialog; deletes local data and returns to onboarding |
| Settings | Sources & attributions | edition list (filtered as in §3) |
| Settings | Help & support | **shown only when `PL_SUPPORT_URL` is configured** (no broken link) |
| Settings | Protection diagnostics → Copy report, Refresh | Debug builds only |
| Shield (system UI) | Begin | records the request; opens the app (iOS 26.5+) and/or posts a local notification |
| Shield (system UI) | Not now | closes the protected app |
| Notification | tap | opens the moment |

No dead buttons, blank destinations or fake controls were found. The Premium / Restore
Purchases controls exist in code but are not shown while nothing is for sale.

## 5. Accounts, Sign in with Apple, account deletion

- **No account, sign-in, backend or authentication of any kind** (VERIFIED: no networking APIs,
  no auth frameworks, no third-party packages). The app is fully usable without login, as
  Guideline 5.1.1(v) asks (DOC).
- **Sign in with Apple:** not applicable. Guideline 4.8 applies only to apps that offer
  third-party/social login (DOC). None was added.
- **Account deletion:** not applicable (5.1.1(v) applies to apps that support account creation,
  DOC). **Data deletion is still provided:** Settings → Delete all my data. It removes the
  profile, check-ins and prayer history; resets all Screen Time state (selection, settings,
  grants, pending requests, shield copy, event log); stops all monitoring and clears all
  shields. Code-verified; device behaviour UNVERIFIED.
- **App Review access:** no demo account is needed. The review notes (docs/20) explain the
  physical-device and Screen Time steps. Reviewer credentials are never stored in the
  repository; none exist.

## 6. Monetization

- The current release **sells nothing**: `monetization.json` has `isPaywallEnabled: false`;
  `UnavailablePurchaseService` is used; no purchase, paywall or restore UI is shown. This is
  deliberate. None of the features configured as premium (assistant, full library, journal,
  insights, schedules, languages) exists in the app, so a subscription would sell nothing
  (3.1.2 requires "ongoing value", DOC).
- The dormant StoreKit 2 implementation was reviewed:
  - only verified transactions are accepted;
  - `Transaction.updates` is observed;
  - `AppStore.sync` is used for restore;
  - grace period, billing retry, revocation and expiry are mapped and unit-tested;
  - prices come only from StoreKit.
  Two force-unwraps were removed. Not executed against App Store Connect (no products exist).
- Enabling purchases later requires:
  1. real premium features;
  2. products and a subscription group in App Store Connect;
  3. a paywall that meets 3.1.2 disclosures;
  4. a Terms of Use (EULA) link;
  5. StoreKit configuration-file tests on a device.
- **No Apple Pay, Stripe or Razorpay** is present.

## 7. Privacy

**Data inventory** (from source, VERIFIED):

| Data | Stored where | Leaves the device? |
|---|---|---|
| Spiritual profile (faith, tradition, focuses, languages, preferences, optional first name) | app container, `profile.json`, Data Protection `.complete` | no |
| Today's mood check-in | in memory; persisted only if "Remember daily check-ins" is on | no |
| Prayer history (times, trigger, content ID, themes, mood if remembered, whether access was granted) | app container, `sessions.json`, `.complete` | no |
| Screen Time selection (opaque tokens), protection settings, current grant, pending shield requests, shield text, event log (100 events, no app names) | App Group `UserDefaults` | no (read by the app's own extensions) |
| App names | only inside the Shield Configuration extension's Apple sandbox, for display | no (never stored or logged) |
| Notifications | local only | no server |
| Premium Companion messages | sent from the Companion tab after subscription | yes: Beloved Cloudflare Worker + Google Gemini, for the real-time reply |

There are no analytics, crash-reporting or ad SDKs, and no third-party app
packages. The only app network path is the Premium Companion endpoint. Privacy manifests are present in the app and all three extensions (UserDefaults
reasons CA92.1 and 1C8F.1; no tracking; no collected data types). All four are included in
the built bundle (VERIFIED).

**App Store Connect → App Privacy:** see docs/20. With the current server design, Premium
Companion messages are processed for the real-time reply and not retained as conversations;
the server keeps only a 48-hour daily message count per subscription. Re-answer if that changes.

**Privacy policy:**
- Written from the inventory above: `App/PrayerLock/Resources/Legal/PrivacyPolicy.md`.
- Bundled and shown in the app from Settings (two places) and from onboarding. It works
  offline (VERIFIED: the file is in the built `.app`).
- The same file generates the public web page (`website/build.py`).

**External deployment still needed:**
- the hosted privacy policy URL;
- the support URL, which requires the owner's support e-mail;
- the App Store Connect fields.

## 8. Permissions

| Capability | Needed? | Where requested | If denied | Info.plist string |
|---|---|---|---|---|
| Screen Time (Family Controls `.individual`) | Yes — core | Onboarding (after an explanation, with "Set up later") and the Protection tab | App works without protection; moments still work; an alert and the Protection tab offer to retry | none exists for this API (system sheet) |
| Notifications (local) | Optional — shield hand-off | Onboarding (after an explanation, with "Not now") | iOS 26.5+ may open the app directly (UNVERIFIED); otherwise the shield asks the user to open Beloved | none required |
| Camera, microphone, photos, location, contacts, calendar, speech, Bluetooth, health, motion | **Not used** | — | — | none present (VERIFIED: no such frameworks or keys) |

No functionality requires enabling notifications (5.1.2(i), DOC).

## 9. Screen Time / Family Controls, App Group, extensions

**Code-verified (unit tests; device behaviour UNVERIFIED):**
- authorization (`.individual`);
- non-destructive revocation;
- authorize-before-picker;
- the 50/50/50 selection limits;
- token-expiry refresh (iOS 26.5+);
- relock scheduled before shields are cleared;
- per-grant relock activities;
- stale callbacks ignored;
- a daily safety guard;
- crash recovery via `reconcile()` on activation;
- empty selection clears shields.

All of these sit behind `ProtectionPlatform`, with 45 tests.

**UI claims audited against the APIs:**
- The app states it **can't** block calls, silence other apps' notifications or turn on Focus.
- It never claims to return the user to the protected app ("You can switch back to your app
  now").
- Short unlocks are explained ("iOS can't schedule anything shorter" than 15 minutes).

**Built-bundle checks (VERIFIED, Release, unsigned):**

| Target | Bundle ID | Extension point | Principal class |
|---|---|---|---|
| App | `unconfigured.beloved` | — | — |
| ShieldConfiguration | `unconfigured.beloved.ShieldConfiguration` | `com.apple.ManagedSettingsUI.shield-configuration-service` | `ShieldConfiguration.ShieldConfigurationExtension` |
| ShieldAction | `unconfigured.beloved.ShieldAction` | `com.apple.ManagedSettings.shield-action-service` | `ShieldAction.ShieldActionExtension` |
| ActivityMonitor | `unconfigured.beloved.ActivityMonitor` | `com.apple.deviceactivity.monitor-extension` | `ActivityMonitor.ActivityMonitorExtension` |

- All three are embedded in `PlugIns/`, each with a privacy manifest.
- All four targets resolve the same App Group (`group.unconfigured.beloved`).
- Entitlement expansion and signing are UNVERIFIED: the iOS 27 SDK refuses ad-hoc signing,
  and no team exists.
- The placeholder identity cannot ship. The **Validate release readiness** build phase fails
  any archive while the prefix is `unconfigured.*` or the Team ID is empty (VERIFIED by
  running the script in archive mode).

## 10. Content quality and provenance

**State:** 26 items (Christianity 8, Islam 7, Hinduism 8, faith-neutral 3), all `draft`.
Rights:
- **Cleared:** World English Bible (public domain).
- **Pending clearance:** the Arabic Quran text, an English Quran translation, the Rigveda
  edition, the Bhagavad Gita edition.

**Release builds show none of the 26** (VERIFIED: `python3 Config/release-content-report.py`
→ 0 visible for every faith).

Source-fidelity check done for the reviewer (eBible.org WEB, `ebible.org/eng-web`,
2026-10-05):

| Item | Result |
|---|---|
| Matthew 11:28 (WEB) | text matches the WEB exactly |
| Philippians 4:6–7 (WEB) | text matches the WEB exactly |
| Psalm 46:10 (WEB) | **partial verse**: the fixture quotes only "Be still, and know that I am God." The WEB verse continues "I will be exalted among the nations. I will be exalted on the earth." Either quote the full verse or cite it as a partial verse before approval |

Also shown in release builds **without** the review gate, and needing advisor review:
- observance names and notes (`observances.json`);
- weekday devotional-custom explanations (`devotional-associations.json`).

They are cautious ("customs vary by region", "estimated").

**To ship content (owner and advisors):**
1. Qualified reviewers for each faith approve items (`review.status = "approved"`, with
   reviewer and date).
2. Clear rights for the Quran (Arabic text edition; licensed or public-domain English
   translation) and the Gita and Rigveda editions, or ship only items whose source rights are
   cleared.
3. Run `python3 Config/release-content-report.py` until every offered faith shows content. The
   archive gate enforces this.

## 11. AI assistant

- Not part of this release:
  - no UI;
  - `PL_ASSISTANT_ENDPOINT` is empty;
  - `UnconfiguredGenerationProvider` is used;
  - no provider API key exists anywhere (VERIFIED: no `sk-`/`Bearer`/API-key strings, no
    networking).
- The pipeline's safety, retrieval and validation code is unit-tested (19 tests) but must not
  be described as a feature.

## 12. Network / backend

- **No network endpoints, no backend, no URLs in Swift code** (VERIFIED). Nothing has to be
  live during App Review.
- The only planned URLs are the optional support and privacy-policy links. They accept
  `https` only (unit-tested) and are hidden when empty.

## 13. Offline and error states

| Situation | Behaviour |
|---|---|
| No network | Not applicable: the app is fully offline |
| Bundled data fails to load | `LaunchFailureView` explains; no crash |
| Screen Time authorization fails or is revoked | Alert, plus a "Protection is paused" state with retry |
| Tokens expire (iOS 26.5+) | Refresh; otherwise "Confirm your apps" |
| Unlock fails after a moment | The moment is saved; the user is told apps couldn't be opened |
| Data deletion partly fails | Alert asks to retry |
| No approved content | The moment offers silence ("Sit quietly…") rather than invented text |
| Privacy policy file missing (packaging defect) | An explanatory view, not a blank screen |

## 14. Legal

| Document | Needed now? | State |
|---|---|---|
| Privacy Policy | Yes (5.1.1(i), DOC) | Written; in-app; web page generated; **legal review recommended**; hosting is the owner's step |
| Terms of Use / EULA | Not required while nothing is sold or uploaded. Apple's standard EULA applies by default (App Store Connect) | Required when subscriptions launch (3.1.2) |
| Religious-content disclaimer | Good practice | Settings → About footer: independent app, doesn't speak for any religious community, every passage shows its source |
| AI disclaimer | Not applicable (no AI in this release) | — |
| Third-party attribution | Yes, for quoted editions | Settings → Sources (shows only editions in use) |
| Content licences | Required before shipping Quran, Gita or Rigveda quotations | Pending (§10) |

## 15. Accessibility (code audit — not tested with VoiceOver on a device)

Present in code:
- every text style is a Dynamic Type style;
- Reduce Motion is honoured (breathing mark, moment transitions);
- controls are at least 44 pt (buttons 50 pt);
- labels on icon-only buttons (Close, Back);
- selected-state traits on choice rows and mood chips;
- header traits;
- combined accessibility elements for the Journey week and summary;
- colour contrast meets WCAG AA (4.5:1) for every text/background pair in the palette,
  computed 2026-10-05 for light and dark: lowest is caution on canvas, 5.2:1 (light);
  secondary text 5.9:1 and higher; primary text about 15:1; button text 8.5:1 and higher.

**UNVERIFIED:** VoiceOver walkthrough, the largest accessibility text sizes on device, Voice
Control. Do not declare Accessibility Nutrition Labels until every common task (first launch,
the moment, protection setup, settings) has been completed with each feature. Apple's rule is
"users must be able to complete all of the common tasks" (DOC). Likely candidates after
testing: Larger Text, Dark Interface, Reduced Motion, Sufficient Contrast, VoiceOver.

## 16. Stability and verification run on this Mac (2026-10-05)

| Check | Result |
|---|---|
| `swift test` (package) | **145 tests in 8 bundles, all passed** (was 141; added config-link, legal-document and sources tests) |
| `xcodebuild … -configuration Release -destination generic/platform=iOS CODE_SIGNING_ALLOWED=NO build` | **BUILD SUCCEEDED, 0 compiler warnings**. The only warnings are the two intended release-readiness warnings (placeholder identity; no approved content) |
| `xcodebuild … -configuration Debug build-for-testing` | **TEST BUILD SUCCEEDED** (app, extensions, UI-test bundle incl. the new privacy-policy UI test) |
| `xcodebuild … analyze` (Release) | **ANALYZE SUCCEEDED**, no findings |
| Swift 6 strict concurrency | `SWIFT_STRICT_CONCURRENCY = complete`, Swift 6 mode, clean |
| Archive gate (script in archive mode) | fails on placeholder identity and on missing content; silent for unsigned Debug builds; passes with simulated approved content |
| UI tests, simulator, device, archive, signing | **Not run**: no simulator runtime, no device, no team; disk too full for an archive build |

**Remaining force-unwraps and preconditions, reviewed and kept:**
- `TimeZone(identifier: "UTC")!` (always exists);
- the Gregorian date from validated civil-date components;
- `precondition(start <= end)` for a programming-error invariant.

**Disk:**
- The phase started with 144 MB free.
- One build failed with "No space left on device"; macOS then reclaimed purgeable space.
- Inside Claude's own temporary scratch folder (outside the repository), stale build
  descriptions, an unused index store and raw research HTML were removed. No project or user
  files were deleted.
- The final runs (145 tests; Debug build-for-testing; Release build with 0 compiler warnings)
  were done with 3.8 GB free.
- **A signed archive needs more free space and a team** (UNVERIFIED).

## 17. What only the owner can do

| Needs | Action |
|---|---|
| Apple Developer Program (paid) | Required for Family Controls (free Personal Teams can't use it — Apple DTS, docs/12) |
| Team ID + bundle prefix | Set `DEVELOPMENT_TEAM` and `PL_BUNDLE_ID_PREFIX` in `Config/Identity.xcconfig` (a reverse-DNS prefix you own) |
| Xcode Apple ID login | Sign in to Xcode, register the 4 App IDs and the App Group, enable Family Controls on all 4 |
| Family Controls distribution approval | Request for **each of the 4 bundle IDs** (docs/12) after the identity is final |
| App Store Connect | Create the app record; choose a **unique** name (plain "Beloved" is taken); fill App Privacy ("Data Not Collected"), age rating, category, URLs and review notes (docs/20) |
| Subscriptions | None needed for this release; create products only when premium features exist |
| Physical iPhone | Run docs/11 (protection loop, shield hand-off, relock, restart, revocation) on iOS 18.x and 26.5+; VoiceOver and Larger Text pass |
| Content | Faith advisors approve items; clear Quran, Gita and Rigveda edition rights; fix the Psalm 46:10 partial quote (§10) |
| Website | Run `website/build.py` with a real support e-mail; host on HTTPS; set `PL_SUPPORT_URL` and `PL_PRIVACY_POLICY_URL` |
| Legal | Trademark attorney on "Beloved" (Augustine Institute class 9/41 registrations); review of the privacy policy |
| Disk space | Free several GB before archiving |
| Screenshots | Capture from a real device once content is approved (no generated or fake screenshots) |

## 18. Readiness score

**25 %.**

The code base is clean, tested, honest, and compiles for release with icon, privacy policy and
release gates in place. But the app has never launched on any device or simulator. It has no
shippable content, no signing identity, no Family Controls distribution approval and no hosted
policy or support pages. Its chosen name has a live US trademark in the same class and field,
plus several same-category App Store apps. Each of these blocks submission on its own.
