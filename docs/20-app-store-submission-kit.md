# Beloved — App Store submission kit

Prepared 2026-10-05 for App Store Connect. Text is ready to paste **once the blockers in
docs/19 §17 are resolved**. Every claim below describes what the code does today. Re-check
it against the build you submit, and change it if the build changes.

## 1. App information

| Field | Value / guidance |
|---|---|
| Name (≤ 30) | Must be unique on the App Store; plain "Beloved" is already used by another app (docs/19 §2). Candidate: **Beloved: Prayer Before Apps** (27). Availability is shown only inside App Store Connect |
| Subtitle (≤ 30) | **A pause for prayer before apps** (30) |
| Primary category | Lifestyle (matches `LSApplicationCategoryType`). Alternative: Health & Fitness — owner decision |
| Secondary category | Productivity (optional) |
| Age rating | Answer the questionnaire truthfully (see §1a). Do not pre-select a rating |
| Privacy Policy URL | `https://<your-domain>/privacy.html` (from `website/build.py`) |
| Support URL | `https://<your-domain>/support.html` |
| Marketing URL | Optional — `https://<your-domain>/` (home page from `website/build.py`) |
| Terms of Use | Apple's standard EULA applies. The site also publishes `https://<your-domain>/terms.html` (needs legal review); a custom EULA in App Store Connect is not needed |
| Promotional text (≤ 170) | **Pause before the apps you choose, and take a moment for prayer, scripture, a mantra, a dua or quiet reflection. Private by design — no account.** (143). Editable without a new build |
| What's New | First version: not shown for 1.0. Later versions: describe only changes in that build |
| Copyright | `2026 <legal name of the developer>` |
| Export compliance | `ITSAppUsesNonExemptEncryption = NO` is already in Info.plist (the app makes no network connections and uses only iOS-provided data protection) |
| Content rights | The app shows third-party text only from editions with cleared rights (public domain or licensed). Answer according to the editions actually shipped (docs/19 §10) |

### 1a. Age-rating answers (true for this build; re-check the live questionnaire)

| Question group | Answer | Basis |
|---|---|---|
| Violence, sexual content, nudity, profanity, horror, drugs/alcohol/tobacco, mature themes | None | Content is prayers, scripture and reflections |
| Gambling, simulated gambling, contests | None / No | — |
| Medical or treatment information | None | App makes no health claims |
| Unrestricted web access | No | No web view or browser |
| User-generated content, messaging, chat | No | No accounts, no sharing |
| Advertising | No | No ads or ad SDKs |
| Parental controls | No | Family Controls is used with *individual* authorization for the user's own device, not to supervise others |
| Age assurance | No | — |

### 1b. App Review contact checklist (enter in App Store Connect only)

- [ ] First and last name of the review contact
- [ ] Phone number reachable during review
- [ ] E-mail address
- [ ] Copyright holder legal name (also used on the website)

## 2. Description (use only when every offered faith ships approved content)

> Beloved turns the moment you reach for a distracting app into a moment of prayer.
>
> Choose the apps, categories and websites you want to use more intentionally. When you open one, Beloved places a calm pause in front of it. Tap Begin and you're invited into a short moment — a prayer, a passage of scripture, a mantra, a dua or a quiet reflection — and then a simple question: what's your intention for the next few minutes? Afterwards your apps open for the time you've chosen.
>
> • Made for Christian, Hindu and Muslim users — or choose not to say, and use faith-neutral moments of breath and intention.
> • Every passage shows what it is and where it comes from: scripture with its reference and edition, traditional prayers, and clearly labelled reflections.
> • Today's observances for your tradition, with estimated dates marked as estimates.
> • Journey: a gentle record of your moments — consistency over perfection.
> • Private by design: no account, no ads, no tracking. Everything stays on your iPhone, and you can delete it at any time.
>
> What Beloved can't do: iOS doesn't let apps block phone calls, silence other apps' notifications or turn on Focus. Beloved pauses the apps, categories and websites you choose, using Apple's Screen Time technology with your permission.

Keywords (≤ 100, 93 used): `prayer,screen time,focus,dua,mantra,bible,devotional,pause,faith,christian,muslim,hindu,dhikr`.
Add "quran" only once approved Quran text ships.

Screenshots: capture from a **real device** running the release build with approved content
(Today, the shield, a moment, Protection, Journey). Never mock up features or content the
build doesn't have (2.3).

## 3. App Privacy (App Store Connect → App Privacy)

- **Data collection: "No, we do not collect data from this app."** → label "Data Not Collected",
  if the Cloudflare Worker and Google Gemini continue to process Premium Companion messages only
  to service the request in real time and do not retain them. Apple defines "collect" as
  transmitting data off the device in a way that lets the developer or third-party partner access
  it longer than needed to service the real-time request; it also says immediately discarded server
  requests do not need to be disclosed in App Privacy answers.
- Disclose clearly in the privacy policy, review notes and in-app copy that Premium Companion
  messages are sent to Beloved's Cloudflare Worker and Google Gemini. The server keeps only a
  daily message count per subscription for 48 hours.
- No tracking, ads, analytics SDKs, crash-reporting SDKs or third-party app libraries are present.
- **Re-answer** before shipping any version that stores server-side conversations, uses messages
  for analytics/training under Beloved's control, adds accounts, or changes the AI provider terms.

## 4. Accessibility (Accessibility Nutrition Labels)

Voluntary for now. Indicate a feature only after every common task (first launch, the moment,
protection setup, Settings) has been completed with it **on a device**
([overview](https://developer.apple.com/help/app-store-connect/manage-app-accessibility/overview-of-accessibility-nutrition-labels)).
Candidates to test: Larger Text, Dark Interface, Reduced Motion, Sufficient Contrast,
VoiceOver. Captions and Audio Descriptions don't apply (no video or audio).

## 5. App Review information

- **Sign-in required:** No. There are no accounts and no demo account.
- **Contact:** the owner's name, phone and e-mail (entered in App Store Connect only, never in
  the repository).
- **Notes** (paste; about 2,100 characters). Before pasting, confirm step 4 on a device (docs/13 assumption A2):

> Beloved is a personal device-usage management app (Family Controls, individual authorization). The user chooses apps to use more intentionally; opening one shows a Screen Time shield that invites a short prayer or reflection before the apps are opened for a chosen time. There is no account. Beloved Premium is an auto-renewable subscription for the optional AI Companion; free Screen Time pauses, scripture, daily verse and the verified prayer library remain free.
>
> Please test on a physical iPhone (Screen Time shields don't appear in Simulator).
>
> 1. Launch Beloved → Get started → choose a faith (or "I'd rather not say") → Continue through the setup screens. Setup ends with a summary; tap Start using Beloved.
> 2. On "Choose where to pause": tap Allow Screen Time access and confirm with Face ID / passcode, then Choose apps and pick an app (e.g. Safari or Photos). Turn Protection on. You can also do this later in the Protection tab.
> 3. Optionally allow notifications (used only to bring you from the shield to your moment). This can be changed later in Settings → Notifications.
> 4. Open the chosen app. Beloved's shield appears: "You chose to protect …". Tap Begin.
>    • iOS 26.5 and later: Beloved asks iOS to open the app at the moment, and also posts a notification "Your moment is ready" as a fallback.
>    • Earlier iOS: tap that notification (or open Beloved) to begin.
> 5. Complete the moment (the finish button becomes available after a few seconds), choose an intention or Skip, then tap Done. The protected app is now open for the duration set under Protection → After a moment (default shown there). After that time Beloved re-applies the pause.
> 6. "Not now" on the shield closes the protected app.
> 7. You can also start a moment any time from Today → Begin a moment.
> 8. Companion: free users receive on-device library answers. Premium subscribers can send messages to the cloud Companion; those messages go to Beloved's Cloudflare Worker and Google Gemini for the reply. The app and privacy policy disclose this before use. Beloved's server stores no conversations, only a daily message count per subscription for 48 hours.
> 9. Settings → Delete all my data removes everything stored on the device and all pauses. Settings → Privacy Policy shows the full policy offline.
>
> Limitations stated in the app: iOS doesn't allow apps to block calls, silence notifications or enable Focus, and Beloved doesn't claim to. iOS can't schedule re-locks shorter than 15 minutes, so very short unlocks end after the chosen minutes of use or 15 minutes at most (explained on the Protection screen). Screen Time access can be revoked in the Settings app at any time; Beloved then shows "Protection is paused".

## 6. Family Controls

- The distribution entitlement must be approved for **all four** bundle IDs (app + three
  extensions) before TestFlight or App Store builds (docs/12). Use the use-case wording in
  docs/12.
- Keep the store listing, the review notes and the entitlement request consistent: personal
  device-usage management first, with prayer as the way the pause is used (DPLA §3.3.3(P),
  docs/09).

## 7. Pre-submission checklist (tick on the submitted build)

- [ ] Identity set; the archive's "Validate release readiness" phase passed (no placeholder
      identity, content for every offered faith).
- [ ] Family Controls distribution approved for 4 bundle IDs; signed archive validated in
      Xcode Organizer.
- [ ] docs/11 device test plan run on iOS 18.x and 26.5+, results recorded.
- [ ] Privacy and support pages live over HTTPS; `PL_SUPPORT_URL` / `PL_PRIVACY_POLICY_URL`
      set; "Help & support" link opens.
- [ ] App Privacy = Data Not Collected; age rating answered; review notes pasted.
- [ ] Screenshots from a real device; description matches the shipped content.
- [ ] Trademark advice on the name obtained; the App Store Connect name accepted.
