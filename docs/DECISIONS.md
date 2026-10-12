# Decision log

Short ADRs. Status: Accepted unless noted. Date: 2026-10-01 (Phase 1).

### D1 — Native Swift/SwiftUI, iOS-first
Screen Time APIs (FamilyControls, ManagedSettings, DeviceActivity) and their extensions are
native-only; cross-platform frameworks would still need native extensions and add a layer.
Android will need a separate platform layer anyway (entirely different blocking APIs).

### D2 — Minimum iOS 18.0
Covers iPhone XS/XR (no iOS 26 support), gives `@Observable`, `Synchronization.Mutex`, SwiftUI
`Tab`, and Foundation's Indian calendars. iOS 26.4/26.5 shield features are used behind
`#available`. Revisit at launch with real adoption data.

### D3 — Logic in a local Swift package, 9 modules
Fast `swift test` on the Mac without a simulator; enforced layering; extensions link only what
they need. The app target is UI + composition root.

### D4 — No project generator; synchronized folders
XcodeGen/Tuist aren't installed and would add tooling. Xcode's objectVersion 77 synchronized
folders mean adding files needs no project edits.

### D5 — Zero third-party dependencies
Nothing needed so far justifies supply-chain and privacy review. Add only with a written reason.

### D6 — Local JSON + Data Protection, not a database
Small data volumes; chosen to suit memory-constrained extensions (extension memory not yet
measured on a device); trivially exportable and deletable. `SessionRepository` protocol allows a later move to SQLite/SwiftData.

### D7 — Split private vs shared storage
Sensitive data stays in the app container (`.complete`); the App Group holds only operational,
non-personal state for extensions.

### D8 — `.individual` authorization only
Prayer Lock is a voluntary self-control tool. No `.child` parental mode; no `denyAppRemoval`.

### D9 — Shield hand-off: notification always, `openParentalControlsApp` when available (flagged)
The only official direct path is iOS 26.5+, and its behaviour under `.individual` is
unverified. Belt and braces, controlled by `PLUseOpenParentAppResponse`.

### D10 — Unlock enforcement via DeviceActivity with honest short durations
15-minute minimum is a platform rule; short unlocks are usage-based within a 15-minute window
and described as such. Relock is scheduled before shields are removed (fail-safe). Per-grant
activity names neutralise the `intervalDidEnd`-on-stop behaviour. Unlock scope: all protected
apps (simpler and predictable); per-app unlock is a future option.

### D11 — Provenance on every content segment; release gate on review + rights
Directly addresses the core risk (fabricated or misattributed religious text; Guideline 1.1.5).
The same segment model serves curated content and AI answers.

### D12 — Phase 1 content are labelled drafts; Hindu dates from sourced tables only
Nothing is invented and nothing unreviewed can reach production. Lunisolar computation is
deferred until validated against published panchangs.

### D13 — Devotional customs are opt-in associations with explanations
Avoids presenting regional customs (e.g. Monday–Shiva) as universal religious truth.

### D14 — Monetization: StoreKit 2, config-driven, paywall off, no prices
Pricing pending research; architecture complete and tested; no purchase UI until products exist.

### D15 — Assistant: deterministic safety + retrieval on-device; generation via proxy only
No API keys in the app; minimal prompt; validator enforces provenance independent of the model.

### D16 — Gentle habit design
Consistency ("5 of the last 7 days") shown alongside streaks; no loss-aversion mechanics,
no recording of abandoned moments in Phase 1.

### D17 — "Prayer Lock" is a working name (Open)
Many App Store apps already use "Prayer Lock" in their names (Christian, Muslim and generic
variants; verified 2026-10-01), so it can't be the public name (Guidelines 2.3.7 / 4.1).
Rebrand required before TestFlight external testing.

## Phase 2 (2026-10-01)

### D18 — Protection orchestration behind a `ProtectionPlatform` protocol
`ProtectionEngine<Platform>` holds every safety rule; `ScreenTimePlatform` is a thin iOS
adapter. Reason: the rules (relock-before-release, stale callbacks, empty selection, revocation,
token expiry, crash recovery) must be tested, and Screen Time can't run in `swift test`. The
app-facing API (`ScreenTimeProtectionController`) is unchanged.

### D19 — `PLBrand` module for colors
The Shield Configuration extension no longer links SwiftUI or content bundles.

### D20 — Single identity file + archive guard
`Config/Identity.xcconfig` holds the bundle prefix and Team ID (not secrets; committed once
chosen). Placeholder `unconfigured.prayerlock`. A build phase blocks archives with placeholders.

### D21 — Authorize before showing the picker
Apple documents the picker on an "individually authorized device". The spec's
"select → authorize" order is inverted to match the platform; still to be verified on a device (docs/11 D5).

### D22 — Revocation is non-destructive
iOS reports authorization asynchronously at launch and the user may re-allow access, so a
revoked state keeps choices and resumes protection after re-authorization.

### D23 — Token expiry: refresh, else ask
On iOS 26.5+, refresh on `tokensDidExpire` and on activation; on failure (or if every token is
lost) show "Confirm your apps" rather than silently disabling protection.

### D24 — On-device protection event log (diagnostics)
Bounded, count-only, local, development-visible. The read-only shield configuration extension
never writes (Apple sandbox).

## Phase 5 — App Store readiness (2026-10-05)

### D25 — Public brand "Beloved"; identifiers not yet fixed
Owner decision. Applied to the home-screen name, in-app copy and the placeholder prefix
(`unconfigured.beloved`). Target/product/module names, storage paths and Screen Time
store/activity names stay `PrayerLock`/`prayerlock` (not user-visible; renaming Screen Time
names would orphan shields). Conflicts (same-category apps, US BELOVED class 9/41
registrations) are reported in docs/19 §2 for the owner and counsel.

### D26 — First release is free; no purchase UI
Nothing configured as premium exists, so selling a subscription would violate 3.1.2
("ongoing value"). The paywall stays disabled and the Premium section is hidden; the StoreKit
code stays dormant and tested.

### D27 — Release-readiness archive gate
`Config/validate-release.sh` (+ `release-content-report.py`, mirroring
`ContentPolicy.release`) fails archives with placeholder identity or with an offered faith
that would show no approved, rights-cleared content. Release builds warn. Reason: never ship
an empty prayer app or misleading faith choices by accident.

### D28 — Privacy policy bundled in the app and generated for the web
One Markdown source (`PrivacyPolicy.md`) is rendered in-app (offline) and by
`website/build.py`. Support/privacy URLs are config values shown only when set (https only),
so the app never links to a missing page.

### D29 — Sources screen lists only editions in use
Release builds attribute exactly the editions quoted by visible content
(`ContentCatalog.citedEditions`), so pending or unused sources never appear.

### D30 — Onboarding resumes and ends with a summary
Unfinished answers and the current step are saved in `StoredProfile.onboardingProgress`
(private, `.complete`-protected container) on every step change and when the app leaves the
foreground; an inapplicable saved step falls back to the faith choice; completion clears it.
A final summary step shows practice, moment length, protection and notification state. No
"intention" picker was added: nothing in the product would use it.

### D31 — Website generated from owner config, never from invented values
`website/build.py --config site.json` builds home/FAQ/support/privacy/terms/404, robots.txt and
sitemap.xml with no JavaScript or third-party requests. Production builds refuse to run without
the real domain, support e-mail, legal name and terms date; `--preview` marks gaps and is
noindex. No download button exists until a real App Store URL is configured.

### D32 — Launch-failure details are developer-only
The launch-failure screen shows the raw error only in development builds; release builds log it
and show a plain message.

### D33 — Onboarding rules live in the package
`OnboardingStep`, `OnboardingProgress` and `OnboardingFlow` (PLFaith) own step applicability,
navigation and resume rules so they are unit-tested; the view only renders. Unreadable saved
progress restarts onboarding without discarding the profile.

### D34 — Notifications are manageable after onboarding
Settings shows notification status with "Allow notifications" (not yet asked) or "Turn on in
the Settings app" (denied, via `openNotificationSettingsURLString`), refreshed when the app
returns to the foreground. Reason: the shield → moment hand-off relies on notifications before
iOS 26.5, so a "Not now" must be recoverable.

### D35 — Release gate covers configuration and draft labels
`validate-release.sh` also requires `PL_ENVIRONMENT = production` for Release, an empty
`PL_ASSISTANT_ENDPOINT` (no networking is disclosed), and https, non-placeholder support and
privacy URLs. The content report blocks approved items whose author label still says "draft".
The unused `AssistantPipeline` was removed from the composition root (the package module stays,
tested, for a future server-backed release).

### D36 — Website hosting assumptions
Static output with a strict CSP (`_headers`, honoured by Netlify and Cloudflare Pages); CSS in a
file, no scripts, forms or third-party requests. Production builds reject missing or example
values and run `website/check.py`.

### D37 — Extension decisions are package code
`ScreenTimeNames` (activity/store/event names and grant-ID parsing) and `ShieldHandOff`
(Begin / Not now → close, defer + notification, or open app) live in PLProtection without
Screen Time imports, so the logic the extensions run is unit-tested on macOS. The persisted
name strings are pinned by a test.

### D38 — Reproducible website deployment
Icons are committed (`website/static/assets`), config can come from `BELOVED_*` environment
variables, `netlify.toml` defines the hosted build, `BELOVED_CLEAN_URLS` matches Cloudflare
Pages' URL style, and `website/verify_live.py` checks a deployment. `scripts/verify.sh` runs
every device-free check in one command.

### D39 — Simulator UI tests and accessibility audits
UI tests run on the iOS 27.0 simulator. `-PLUITesting` plus `PL_UI_TEST_STORE=<name>` gives a
throwaway store that survives relaunches (resume, returning-user and deletion tests); without
the name every launch starts empty. Tests wait for each control to be hittable because step
transitions animate. Xcode's accessibility audit runs on Welcome, Today and Settings; it found
text that could clip at large Dynamic Type (Welcome now scrolls, section headings wrap). Its
contrast check is skipped only for elements under the translucent tab bar, because colour
contrast is proven by `PaletteContrastTests` (WCAG AA for every text/background pair, 3:1 for
the Journey dots).

### D40 — "Threshold" design system
Vellum, ink, lapis and gilt; the arch as the signature motif (sacred across every tradition
Beloved serves, owned by none); serif display and reading type; a time-of-day light wash; one
prominent action per screen; no shadows (tone and hairlines instead). Tokens and components
live in PLDesign/PLBrand; every text colour pair is AA-tested (`PaletteContrastTests`). Full
spec: docs/27-design-system.md.

### D41 — Personal intentions stay out of the extensions
Intentions are personal, so they live in the private profile only. They appear on Today and in
the moment, never on the Screen Time shield (extensions keep receiving non-personal state
only, per CLAUDE.md). `SpiritualProfile` gained tolerant decoding so adding fields can never
wipe an existing profile.

### D42 — Appearance preference in standard defaults
Automatic / Light / Dark is a device preference (`pl.appearance`), not personal data, so it is
stored in standard UserDefaults and never in the App Group. The launch argument
`-pl.appearance dark` sets it for screenshots (the simulator appearance switch does not
reach the app under XCUITest).

### D43 — App icon generated from code
`scripts/make_app_icon.py` renders the gilt threshold on lapis (opaque, 1024 px); the website
icons are regenerated from it (`website/build.py --refresh-icons`). The previous icon is kept
at docs/assets/previous-app-icon-1024.png. Branding stays easy to change if the name changes.

### D44 — Lapis as a fill is deep at night
`accentFill`/`onAccentFill` separate filled controls from lapis text. Dark mode fills are a deep
stone lapis `#4462B8` with parchment lettering (4.79:1) instead of a pale periwinkle slab
(≈10:1 against the night canvas, which glared and read as a default). Fills keep ≥ 3:1 against
canvas and paper in both modes (WCAG 1.4.11) — `PaletteContrastTests`.

### D45 — Accessibility findings root-caused, not excluded
- Eyebrow "text clipped": caused by `.tracking`; eyebrows now use an expanded font width
  (audit passes with no exclusion).
- Appearance segmented control did not grow at AX5 (real defect): replaced by chips.
- Remaining, evidenced: Today's three-line preview excerpt; contrast under the translucent tab
  bar; "Show transliteration" (one long word hyphenates at AX5 — the test asserts the row
  grows); one unattributed Dynamic Type finding in Settings, consistent with the system toggle
  switches, which iOS never scales.

### D46 — Revisit a moment; honest time figures
Journey's recent moments reopen their passage (read-only, only if the content policy still
permits it). A single moment adds at most 20 minutes to "time in prayer", so a moment left
open on an idle phone can't inflate it. The welcome-back rule lives in PLHabits
(`ReturnGreeting`) with boundary tests.

### D47 — One app, a dedicated scripture per faith
After choosing a faith, the user gets that faith's own scripture as a tab named the way they
call it — **Bible**, **Quran**, **Gita** — with chapter navigation, the original language, and a
daily verse. One app (not one per faith) keeps one codebase, one review, and lets people of a
household share it; the per-faith tab, Today's verse and the reader are what make it feel
dedicated. Faith-neutral users and faiths without a bundled scripture see no tab at all (no
placeholder).

### D48 — Scripture is bundled verbatim from pinned public sources
Editions (owner-approved 2026-10-11): World English Bible (eBible engwebp), Hebrew OT (WLC,
eBible hbo), Greek NT (1904 Patriarchal Text, eBible grcbyz — chosen over the Majority Text file,
which is unaccented lowercase), Tanzil Uthmani Arabic (CC BY 3.0, verbatim-only, with its notice),
Pickthall (1930, public domain; Tanzil's digital text), the Gita in Sanskrit (gita/gita dataset,
Unlicense), and Arnold's *Song Celestial* (1885, Gutenberg #2388).
- `scripts/import_scripture.py` verifies each download's SHA-256 (`scripts/scripture/sources.json`),
  checks book/chapter/verse totals, and writes `PLScripture/Resources`. `--check` (run by
  `verify.sh`) fails if the bundle differs from a fresh import. Downloads live in git-ignored
  `Vendor/`.
- Only formatting changes, each declared in the edition's `modifications` (Gita: speaker lines
  split off, verse numbers removed, legacy vowel-sign order fixed in 26 places; Arnold:
  Gutenberg header/footnotes removed, `--` → em dash). Tanzil's text is never changed.
- IAST transliteration of the Gita is generated by a deterministic transliterator (unit-tested),
  not taken from a copyrighted source; it's labelled as generated.
- Catalog items that quote these editions must match them exactly (Swift test + importer); the
  previously hand-typed Arabic/Sanskrit fixture text was replaced with the edition text.

### D49 — Original and translation side by side only when numbering agrees
The Hebrew Bible numbers verses differently in places (English Psalm 46:10 is Hebrew 46:11;
Malachi has 3 chapters in Hebrew, 4 in English), and Arnold's Gita follows chapters, not
verses. Each edition records its `versification`; "Both" is offered only when original and
translation share it (today: the Quran). The Bible's daily verse is English only for the same
reason; the Gita's daily verse is Sanskrit + IAST + Arnold's lines for that verse (pairing
needs reviewer confirmation).

### D50 — The reader follows the release gates
`ScripturePolicy.release` shows an edition only when `faiths.json` clears its licence **and** a
reviewer has set its `review.status` to `approved` in `scripture-library.json`; the daily list
per faith needs its own approval. The importer always writes `draft` (a test enforces it), so
approval is always a deliberate human edit. Until then release builds show no scripture tab.

### D51 — Daily verse notification is opt-in and local
Off by default; one local notification per day scheduled 14 days ahead (each carries that day's
verse) and topped up when the app opens. Reading position and the reminder time live in the
private profile file. Nothing leaves the device.

### D52 — Reader accessibility audit: two evidenced exclusions
Root-caused and fixed: unlabeled search field (now a labelled field, no grey placeholder),
44-pt source links with readable labels, the Arabic chapter title is no longer hidden from
VoiceOver, the draft badge's contrast. Excluded on the chapter reader only, with evidence:
"Dynamic Type partially unsupported" on verses near the bottom edge (the AX5 test asserts verse
rows grow past 140 pt) and "text clipped" on Arabic, whose harakat sit above the line box but
render fully. Audits wait 3 s first: findings sampled mid-animation or mid-scroll were artefacts.

### D53 — The dove replaces the arch; a colour theme per faith
The arch motif read as a mihrab/church window — one faith's architecture — so it is gone. The
brand is a dove in flight across a gold sun ("Halo", owner-chosen 2026-10-11); one geometry
(`PLBrand/DoveGeometry`) draws the icon (`sh scripts/make_app_icon.sh`), in-app marks and the
shield icon. The pause visual is a circle of light; Journey's days are beads; status marks are
circles. Themes (`PLTheme`): lapis + gold (Christianity, brand default), emerald + gold (Islam),
saffron + marigold (Hinduism); paper and ink are shared; every theme passes the contrast tests.
Onboarding and the Screen Time shield stay in the brand theme (the shield never knows the faith).

### D54 — Devotional library imported verbatim from pinned sources
`scripts/import_devotions.py` builds `devotions.json` (50 items at first import) the same way
scripture is built: pinned Wikisource revisions with checksums, markup removed, words untouched,
everything `draft`. Christianity: 28 prayers and 4 thanksgivings from the 1979 Book of Common
Prayer (public domain), rubrics and section headings excluded. Hinduism: Gayatri (Rigveda
3.62.10) and Mahamrityunjaya (7.59.12) — replacing the earlier hand-typed fixtures — and the
Santāna Gopāla mantra and stotram (Sanskrit Wikisource, CC BY-SA). Islam: 14 Qur'anic duas and
surahs cut word-for-word from the bundled Tanzil text with the matching Pickthall English.
The Hanuman Chalisa is NOT included: no verifiable digital public-domain text was found (only
scans of unclear rights); typing it from memory would break the no-invented-text rule. It needs a
reviewer-verified transcription. Until then the companion names it and says it isn't in the
library yet. Explanations ("traditionally recited for…") are editorial, labelled, and draft.

### D55 — Companion: cloud for subscribers, verified text always
`PLCompanion` + `server/companion` (Cloudflare Worker). The model may not write holy text; it
writes markers (`⟦bible:Psalm 23:1-3⟧`, `⟦prayer:<id>⟧`) that the app fills from the on-device
library, or shows as a plain reference. The server verifies StoreKit 2 signed transactions
against the pinned Apple Root CA – G3, enforces a daily allowance, owns the system prompt
(faith-scoped, humble, no fatwas/hadith quotes, no medical claims), and stores nothing else.
Crisis language never reaches a model (on-device SafetyRouter first). Free users get answers
from the verified library on the iPhone, labelled as such. The release gate still refuses a
build with a companion endpoint until the privacy policy and App Privacy answers cover it.
Journey moved into Today so the tab bar stays at five (Today, scripture, Companion,
Protection, Settings).
