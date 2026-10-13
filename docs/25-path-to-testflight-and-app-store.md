# Beloved — path to TestFlight and App Store submission

Date: 2026-10-09 (rechecked the same day: Xcode has an Apple account saved but no team, 0 signing identities, 0 profiles; iPhone "unavailable"). Updated 2026-10-10: ~47 GB free; iOS 27.0 simulator runtime installed. Engineering that can be done without your accounts, device, domain or
approvals is complete and verified (`sh scripts/verify.sh`, docs/24). Everything below needs a
person or Apple. Steps are in dependency order; each says what it unblocks.

> **Status 2026-10-10 (rechecked):** an Apple Development certificate ("Vaibhav SG") and a
> paid individual team (`LNL8GARN23`, read from an existing Xcode-managed profile for another
> app) are now on this Mac; the iPhone (iOS 27.0.1) is **connected with Developer Mode enabled**.
> Beloved itself is still unsigned: `DEVELOPMENT_TEAM` is empty and the bundle prefix is the
> placeholder, pending your confirmation of the team and a development prefix (items 2 and 4).

## Stage 1 — Accounts and machine (you)

| # | Action | Where | Needed | Unblocks |
|---|---|---|---|---|
| 1 | Confirm the **paid** Apple Developer Program membership is active (enrollment was pending; a Personal Team can't use Family Controls) | developer.apple.com → Account → Membership | Apple Account, payment, identity checks | Everything below |
| 2 | Note the **Team ID** (10 characters) shown under Membership details, and check the team appears in Xcode → Settings → Accounts (today the account is listed but has no team) | developer.apple.com, Xcode | — | Signing |
| 3 | Free disk space to **≥ 15 GB** (about 47 GB free on 2026-10-10 after cleanup; keep ≥ 15 GB) | System Settings → General → Storage | — | Archives; optional simulator runtime |
| 4 | Decide the final **name** with a trademark lawyer ("Beloved" is NOT CLEARED), then the **bundle prefix** (reverse-DNS on a domain you control) | — | legal advice | Step 5, App IDs, App Store record |

## Stage 2 — Identity in the project (Claude, once you send the values)

5. Set `PL_BUNDLE_ID_PREFIX` and `DEVELOPMENT_TEAM` in `Config/Identity.xcconfig`. Nothing else
   changes: the 4 bundle IDs and the App Group derive from the prefix.

## Stage 3 — Apple Developer portal (you)

| # | Action | Where |
|---|---|---|
| 6 | Register 4 explicit App IDs: `<prefix>`, `<prefix>.ShieldConfiguration`, `<prefix>.ShieldAction`, `<prefix>.ActivityMonitor` | Certificates, Identifiers & Profiles → Identifiers |
| 7 | Enable **Family Controls** and **App Groups** on all 4; create `group.<prefix>` and assign it to all 4 | same |
| 8 | Request **Family Controls (Distribution)** for each of the 4 App IDs using the wording in docs/12 (personal device-usage management; prayer is how the pause is used) | developer.apple.com/contact/request/family-controls-distribution |
| 9 | Wait for Apple's approval (**Apple action**; not guaranteed, timing unknown). The *development* entitlement works for device testing meanwhile | e-mail from Apple |

### Target-by-target signing requirements (checked 2026-10-10: no team, 0 identities, 0 profiles)

| Target | Bundle ID (from `PL_BUNDLE_ID_PREFIX`) | Entitlements file | Capabilities the App ID needs | Profile (automatic signing) | Today |
|---|---|---|---|---|---|
| PrayerLock (app) | `<prefix>` | `App/PrayerLock.entitlements` | Family Controls; App Groups → `group.<prefix>` | iOS App Development, later App Store | BLOCKED: no team |
| ShieldConfiguration | `<prefix>.ShieldConfiguration` | `Extensions/ShieldConfiguration/ShieldConfiguration.entitlements` | Family Controls; App Groups → same group | same | BLOCKED |
| ShieldAction | `<prefix>.ShieldAction` | `Extensions/ShieldAction/ShieldAction.entitlements` | Family Controls; App Groups → same group | same | BLOCKED |
| ActivityMonitor | `<prefix>.ActivityMonitor` | `Extensions/ActivityMonitor/ActivityMonitor.entitlements` | Family Controls; App Groups → same group | same | BLOCKED |

All four use `CODE_SIGN_STYLE = Automatic`, version 1.0.0 (1), deployment target iOS 18.0, and
the same `DEVELOPMENT_TEAM`. The UI-test bundle (`<prefix>.UITests`) needs no capabilities.
Distribution (TestFlight/App Store) additionally needs Family Controls **distribution** approval
for all four IDs. The release gate refuses any archive while the prefix is `unconfigured.*`,
the team is empty, the environment isn't production, or an offered faith has no approved content.

## Stage 4 — Device testing (you + Claude)

| # | Action | Who |
|---|---|---|
| 10 | Connect the iPhone **by cable**, unlock, tap **Trust**, enter passcode; Settings → Privacy & Security → **Developer Mode** on → restart → confirm | you |
| 10a | First signed build: Xcode automatic signing creates the Apple Development certificate and profiles and registers the iPhone — approve the keychain prompt on this Mac | you approve; Claude builds |
| 11 | Signed Debug build to the iPhone; run docs/11 **D1–D42** (Screen Time, relock, midnight, time zone, reboot, revocation, onboarding resume, notifications) and the accessibility pass (VoiceOver, largest text, Reduce Motion, contrast). Record PASS/FAIL per scenario; fix any defects | Claude drives; you perform physical steps (Face ID, waiting through relock windows, reboot, Settings changes) |
| 12 | ~~Install the iOS Simulator runtime~~ — **done 2026-10-09** (iOS 27.0, 24A434). UI tests now run on the simulator (`xcodebuild test … -destination 'platform=iOS Simulator,name=iPhone 17' -parallel-testing-enabled NO`); simulator results never count as Screen Time evidence | done |

## Stage 5 — Content and legal (you + reviewers)

| # | Action | Detail |
|---|---|---|
| 13 | Faith reviewers approve or reject each of the 26 items | `python3 Config/release-content-report.py --items` lists every blocker per item |
| 14 | Editions are now selected and bundled (D48): Tanzil Uthmani (CC BY 3.0, verbatim) + Pickthall, WEB + Hebrew WLC + Greek 1904, Gita Sanskrit (Unlicense) + Arnold. Reviewers verify each bundled text and the daily-verse lists, then set `review.status` to `approved` in `scripture-library.json` / `daily-verses.json` (see docs/26). Still open: verify the Rigveda mantras against a cited edition | `faiths.json` licences recorded with evidence; approvals are human |
| 15 | Replace "Beloved editorial (draft)" author labels with the real author/editor | the gate blocks approved items that still say "draft" |
| 16 | Lawyer reviews the Privacy Policy and Terms of Use; supply a governing-law sentence if wanted | `PrivacyPolicy.md`, `website/content/terms.md` |

Every offered faith needs at least one approved item, or the archive gate fails (by design).

## Stage 6 — Website (you, then Claude verifies)

| # | Action | Detail |
|---|---|---|
| 17 | Create a support mailbox and test that it receives mail | your mail provider |
| 18 | Domain + Netlify (or Cloudflare Pages) site; set `BELOVED_DOMAIN` in Netlify (+ `BELOVED_CLEAN_URLS=true` on Cloudflare). `BELOVED_SUPPORT_EMAIL`, `BELOVED_LEGAL_NAME` and `BELOVED_TERMS_EFFECTIVE_DATE` are already in `netlify.toml` | website/README.md |
| 19 | After deploy: `python3 website/verify_live.py https://<domain>` (add `--clean-urls` on Cloudflare Pages; it fails on unreachable, parked or preview sites and on missing security headers/HSTS); then Claude sets `PL_SUPPORT_URL` / `PL_PRIVACY_POLICY_URL` | — |

## Stage 7 — App Store Connect and TestFlight

| # | Action | Who |
|---|---|---|
| 20 | Accept current agreements; for a free app, no paid-apps agreement or tax/banking is needed | you (App Store Connect → Business) |
| 21 | Create the app record with the cleared name and bundle ID (name availability is only shown here) | you |
| 22 | Archive (gate must pass: real identity, production environment, https URLs, approved content for every offered faith), validate in Organizer, upload. Requires the Family Controls **distribution** approval from step 9 and an Apple Distribution certificate (created by Xcode on first archive) | Claude runs; you approve upload |
| 23 | TestFlight: internal testing first; external testing requires Beta App Review | you add testers |
| 24 | Fill metadata from docs/20: subtitle, description, keywords, promotional text, category, age-rating answers, App Privacy "Data Not Collected", URLs, copyright, review notes, review contact; screenshots from a real device with approved content | you (Claude can draft any text) |
| 25 | Submit for review (**Apple action**: App Review) | you |

## Not needed for this release

Accounts, Sign in with Apple, demo credentials, a backend, API keys, analytics, in-app purchases
or subscriptions, export-compliance documentation (`ITSAppUsesNonExemptEncryption = NO`).
