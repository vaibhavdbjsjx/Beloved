# Brand name shortlist — deep multi-faith naming research (Phase 4)

Date: 2026-10-01. **Research only.** No code, Xcode, package, bundle ID, App Group,
entitlement, asset, configuration, signing or Apple changes. Nothing was bought, reserved or
registered. **This is not legal advice and not trademark clearance.** No statement below means
a name is free to use. It records only what public sources returned on this date. Devote was
rejected for now by the owner (docs/16). Names researched in docs/14–15 are reused only where
cited.

**Evidence labels** (used on every external claim):

| Label | Meaning |
|---|---|
| **[V] verified** | returned directly by a primary source on 2026-10-01: Apple's iTunes Search API, the registry's own RDAP/whois, the website itself, or Apple documentation |
| **[O] search observation** | a search page, a third-party mirror of a register, or an HTTP-status signal. **No result is not proof that nothing exists** |
| **[I] inference** | the researcher's naming-language judgement. Not user-tested; no believer of any faith was consulted |
| **[U] unresolved** | not determined in this phase |

**Conflict classes:** **RED** = same name in the same or overlapping category (prayer,
devotional, wellbeing, focus, screen time, AI companion). **ORANGE** = adjacent category, or a
significant brand, software or domain conflict. **YELLOW** = minor or distant conflict.
**GREEN** = no meaningful conflict found by the searches listed.

---

## 1. Objective

Find a public brand for the app currently called "Prayer Lock" (working name; the repository,
directory and bundle IDs stay unchanged). The app turns the moment of opening a distracting app
into a short prayer, mantra, dua or reflection before an intentional unlock. Christians,
Hindus and Muslims are first-class audiences, with India and the US as launch markets.

Output: a pool of about 100 candidates in six creative directions, the hard filters, and
**exactly five finalists** with evidence. **No finalist is chosen here.** The product owner
makes that decision (§15).

## 2. Product naming requirements

| # | Requirement | Source |
|---|---|---|
| R1 | Equally welcoming to Christian, Hindu and Muslim users; not a sacred term of one faith | product brief (Phase 1); docs/14 |
| R2 | Avoid "Prayer Lock" / "PrayLock" / "lock" | docs/13 §6 — 49 App Store listings use these [V, 2026-10-01] |
| R3 | Suggests pause, intention, turning toward something, or light/inner space — not restriction or punishment | product brief; docs/14 |
| R4 | Easy to say and spell in Indian English, US English and UK English | docs/15 §5 |
| R5 | No conflicting meaning in Hindi/Urdu/Arabic, as far as could be checked | docs/14; [I] |
| R6 | Fits App Store limits: app name 2–30 characters, subtitle ≤ 30 | Apple App Store Connect Help [V, checked in Phase 3] |
| R7 | Room to grow: assistant, journal, premium tier, other faiths later | docs/15 §9 |
| R8 | No same-name app in our category; no famous-brand collision; workable domain and handle options | this phase's hard filters (§5) |

Apple licence context: the Family Controls primary purpose is personal device-usage management
(DPLA §3.3.3(P); docs/12). A brand that reads only as a religious-content app leans on the
subtitle and screenshots to show that purpose [I].

## 3. Search methodology

| Source | What was searched | Status |
|---|---|---|
| **App Store**: Apple iTunes Search API, `entity=software`, `limit=30`, storefronts US, IN, GB | every name in the pool (103). "Exact" = the title equals the name or starts with it followed by a separator (`:`, `-`, `–`, space…). "Category-adjacent" = an exact listing in Health & Fitness, Lifestyle, Reference, Book, Productivity or Medical, or one whose title or genre contains prayer, faith, meditation, focus, screen or similar keywords | ✅ done (scripted; raw JSON kept in the session scratchpad, outside the repo) |
| **Google Play**: public search pages | finalists and reserves: India (`gl=IN`) and US (`gl=US`) | ✅ done for all five finalists in both stores (Turnward/Waystill US results come from docs/15) |
| **Web**: web search plus a fetch of each live homepage | finalists, reserves, and names whose App Store screen was clean | ✅ done |
| **US trademarks**: Trademarkia (third-party mirror of USPTO data) | exact names plus spaced variants ("soul ward", "quiet well"). Positive control: "lightfast" returned 3 marks, so the mirror returns exact hits; docs/15 used "Alcove" (60 hits) | ✅ done. USPTO's own search refuses scripted queries (HTTP 405, Phase 3.5) |
| **India trademarks**: QuickCompany (third-party mirror of IP India data) | exact names. The mirror always returns fuzzy near-matches, which shows it is responding | ✅ done. The official e-register needs a captcha |
| **EUIPO, UK IPO, WIPO Global Brand Database, TMview** | retried once on 2026-10-01: UK IPO HTTP 403; TMview no response (HTTP 000); WIPO and EUIPO return only a JavaScript page shell with no results | ⛔ **not searched** [U] |
| **Domains** | `.com` and `get…/join…/…app.com`: Verisign RDAP (plus whois where needed). `.app`: Google Registry RDAP. `.io` and `.in`: DNS NS lookup via 1.1.1.1. Control `google.*` returned "registered" on every check | ✅ done. `.io` RDAP via rdap.org was **discarded**: it returned 404 even for `github.io`. `.io`/`.in` rest on DNS alone [O] |
| **Social handles** | GitHub (REST API), YouTube (`/@handle`: status code plus channel title), Instagram (page title), X (status code). Negative control `zqxvplk7731neg`: YouTube 404, GitHub 404, X 404, Instagram returns the generic title "Instagram" | ✅ done. GitHub and YouTube are dependable. **Instagram and X are low-confidence signals** [O] |
| Not done | user testing; native-speaker review (Hindi, Urdu, Arabic, Tamil and others); professional clearance; App Store Connect name reservation | [U] |

## 4. Initial candidate pool (103 names; three rounds)

Directions: **U** spiritual-universal · **P** pause/intentionality · **J** journey/path ·
**L** light/inner space · **A** ancient-language (meanings from standard dictionaries; see
notes) · **I** invented/brandable. Round 1 = 83 names; round 2 = 8 coinages (mostly "-ward"
forms, after "Turnward" screened clean); round 3 = 12 coinages, added after a late conflict
removed Soulward (§6).

| Dir | Names |
|---|---|
| U (9) | Pilgrim, Refuge, Vow, Awe, Offering, Reverent, Kindred, Sanctuary, Hallowed |
| P (14) | Heed, Tarry, Linger, Await, Hush, Stillness, Steady, Attend, Tend, Kneel, Respite, Interval, *Stillward, Quietward, Hushward* ← round 3 |
| J (16) | Waypoint, Lodestar, Homeward, Sojourn, Trailhead, Compass, Northlight, Pathwise, **Turnward**, **Waystill**, Heartward, Soulward, Wellspring, *Dawnward, Duskward, Seekward* ← round 3 |
| L (20) | Lamplight, Lamplit, Candlelit, Beacon, Daybreak, Dawnlight, Shelter, Hearth, Oasis, Grove, Courtyard, Nook, Lumina, Radiance, *Hearthward, Lampstill, Lampway, Stillwick, **Dawnstill**, Stillmere* ← round 3 |
| A (19) | Viram (Sanskrit/Hindi *virāma*, cessation), Fursat (Urdu/Hindi from Arabic, free time), Mora (Latin, delay), Statio (Latin, a standing still), Quies (Latin, rest), Eirene (Greek, peace), Ataraxia (Greek, untroubled calm), Askesis (Greek, training), Pneuma (Greek, breath/spirit), Hesper (Greek, evening star), Saaya (Urdu/Hindi from Persian, shade), Aman (Arabic, safety; Urdu/Hindi, peace), Asha (Sanskrit, hope), Sakina (Arabic, tranquillity), Dhyana (Sanskrit, meditation), Shalom (Hebrew, peace), Ruach (Hebrew, breath/spirit), Sankalpa (Sanskrit, resolve), Prana (Sanskrit, life-breath) |
| I (25) | Kneelight, Hushlight, Stillhaven, **Quietwell**, Lampwise, Dawnhold, Haltwise, Truewell, Presentia, Lumenkeep, Stillhour, Kindlewell, Hallowmark, Lightfast, Wakelight, Hushhour; *round 2:* **Lampward**, Prayward, Breathward, Lightkeep, Stillwell, Wellstill, Restward, Kindward |

Ancient-language meanings are standard dictionary senses as the researcher understands them.
They have **not** been checked by native speakers [U]. None of the five finalists depends on a
non-English meaning.

## 5. Elimination criteria (hard filters)

| Code | Filter | Typical evidence |
|---|---|---|
| **F1** | Same-name app in our or an overlapping category (**RED**) | App Store / Google Play listing |
| **F2** | Crowded: ≥ 10 exact or prefixed App Store titles across US/IN/GB, so no distinctiveness | iTunes API counts |
| **F3** | Sacred or technical term of one faith or tradition, or a practice not shared by all three | dictionary meaning; [I] |
| **F4** | Negative, wrong or culturally loaded meaning in a launch-market language | [I]; flagged for native review |
| **F5** | Hard to spell or pronounce for Indian/US/UK users | [I] |
| **F6** | Famous-brand collision, or an exact-name active software/tech business (**ORANGE**+) | web, homepage, registry |
| **F7** | Weak fit: generic, harsh, off-meaning, or weaker than a sibling coinage in the same symbol family | [I] |
| **F8** | (tie-break only) `.com`, `.app` and the get/app variants all held by others | RDAP |

A name passes only if it clears F1–F7. The five finalists clear them on the evidence in §7–§13.
They still carry the ORANGE and YELLOW findings listed there.

## 6. Eliminated names and reasons (98)

App Store counts are exact/prefixed titles across US+IN+GB [V, iTunes Search API, 2026-10-01].

**Same-category conflicts (F1, RED)**

| Name | Evidence |
|---|---|
| **Soulward** *(late elimination; had been provisionally shortlisted)* | soulward.app was registered 2026-09-27 [V, Google Registry RDAP]. It is live as "Soulward", an AI recovery companion for addiction with iOS and Android betas and Apple sign-in [V, homepage]. Also: soulward.com is listed for sale [V, redirects to HugeDomains]; YouTube @soulward is a tarot channel [O]; GitHub and X handles are taken [O] |
| Heed | "Heed : Dhikr & Screen Time" — an Islamic screen-time app, the same product category |
| Ruach | "Ruach - Christian Screen Time" — same category; also F3 (Hebrew/biblical term) |
| Sankalpa | "Sankalp: PrayLock & Panchang" — same category (docs/13 §6); also F3 |
| Prayward | exact app "Prayward" (Lifestyle) |
| Stillness | "Stillness: Prayer & Breathwork"; 13 titles |
| Tarry | "Tarry: Prayer App"; also F3 (King James register) |
| Kneel / Kneelight | "Kneel: Daily Prayer & Devotion"; also "Kneel: D/s & Chastity" (adult connotation); F3 (kneeling reads as Christian in English [I]) |
| Dawnlight | "DawnLight: Daily Devotion" |
| Lamplight | "Lamplight: Cozy Focus Rooms" (Productivity); "Lamplight - Bible Stories" |
| Lamplit | "LampLit - Bible Reading Plans" (Reference) |
| Statio | "Statio - Bible & Journal" |
| Sojourn | "Sojourn: Topical Bible Study"; 14 titles |
| Wellspring | "Wellspring - Daily Devotionals"; 14 titles |
| Shalom | "Shalom: Bible Chat & Prayer"; 24 titles; F3 |
| Sakina | "Sakina - Islamic Wellness" and others (24 titles); F3 (Quranic term) |
| Eirene | "Eirene Christian Well-Being AI" (27 ratings); F5 |
| Quies | "Quies - Meditate & Journal"; "Quies: Private Journal & Mood" |
| Lodestar | "Lodestar: Stoic Reflection" (Health & Fitness); 11 titles |
| Pilgrim | "Pilgrim — Mindful Walking"; 13 titles |
| Stillhaven | "Stillhaven: Grief Journal"; "StillHaven" (Health & Fitness) |
| Stillwell | "Stillwell: Burnout Reset" (Health & Fitness) |
| Stillward | exact app "Stillward" (Bordosan LLC, Health & Fitness) |
| Heartward | "Heartward: Breakup Recovery" (Health & Fitness) |
| Hushhour | "HushHour – Pomodoro" (a focus timer), on iOS and Google Play |
| Stillhour | "Stillhour: Fasting Timer" (Health & Fitness) |
| Daybreak | "Daybreak - Alcohol Support"; 19 titles (also F2) |

**Crowded (F2)**: Refuge 22 · Kindred 26 · Sanctuary 14 (incl. "Sanctuary Psychic Reading",
1,562 ratings) · Vow 12 · Hush 24 · Steady 25 · Tend 19 · Interval 15 · Linger 12 ·
Waypoint 24 · Compass 26 · Beacon 25 · Oasis 20 · Grove 14 · Hearth 12 · Nook 15 ·
Lumina 22 · Radiance 16 · Mora 15 · Aman 20 · Prana 26 (also F3).

**Single-tradition or sacred terms (F3)**: Hallowed (Lord's Prayer phrase; close to Hallow, an
existing category brand — docs/14 §3) · Pneuma (Christian theological term for Spirit) ·
Dhyana (Hindu/Buddhist/yogic term) · Hallowmark (also F6, see below). The F1 entries above
also cover Ruach, Shalom, Sakina and Sankalpa.

**Wrong or loaded meaning (F4)**: Saaya (the Hindi/Urdu idiom *bhoot ka saaya*, "a ghost's
shadow" [I]) · Fursat (means leisure or free time, the opposite of intention [I]) · Candlelit
(romantic-dinner connotation [I]) · Viram (common Indian given name; Sanskrit/Hindi lean;
also the name of the Devanagari *virama* sign [I]) · Quietward ("quiet ward" reads as a
hospital or psychiatric ward [I]; quietward.com is registered [V]; Instagram @quietward is
taken [O]) · Duskward ("toward dusk" can read as decline or ending [I]; duskward.com is
registered [V]).

**Spelling or pronunciation (F5)**: Ataraxia · Askesis (also an ascetic connotation; "Askesis –
Gym Tracker" exists) · Eirene.

**Famous-brand or tech-business collisions (F6)**

| Name | Evidence |
|---|---|
| Trailhead | Salesforce Trailhead, a major software learning brand [O, [trailhead.salesforce.com](https://trailhead.salesforce.com/)] |
| Courtyard | Courtyard by Marriott [O] |
| Nook | Barnes & Noble NOOK e-reader and app [O]; also F2 |
| Aman | Aman resorts [O]; also F2 |
| Kindlewell | Amazon Kindle [I] |
| Hallowmark | sounds close to Hallmark [I] |
| Lumenkeep | "Lumen" is already a category brand ("Prayer Lock: Lumen", docs/14) |
| *Lightward* (extra variant checked alongside Lightfast; not counted in the 103) | software company plus "Lightward AI" (Phase 4 web search) [O] |
| Presentia | "Presentia AI" and other businesses; key domains registered [O] |
| Lampwise | UK lighting retailer with its own app [O] |
| Wakelight | federal IT contractor that holds wakelight.com [O] |
| Hesper | Hesper.io, Hesper Technologies, Hesper IT Labs (India); `.com`, `.app` and variants registered [O] |
| Northlight | Northlight AI (northlight.ai); `.com`, `.app` and variants registered [O] |
| Lightfast | getlightfast.com redirects to lightfast.ai, an AI software company ("People and Machines, Working Together") [V, homepage]. lightfast.com (2001), lightfast.app (2025), getlightfast.com and lightfastapp.com (2026) are all registered [V, RDAP]; lightfast.io is on Vercel [V, DNS]; GitHub org "lightfast" exists [O]. The word "fast" also reads as speed, or as a food-fasting tracker ("LifeFast: Fasting Tracker" on Google Play US) [O] |
| Hushward | hushward.com redirects to Alertify, a noise-monitoring product [V]; `.app`, `.io`, get and join registered [V/O] |
| Seekward | seekward.com is live as "SeekWard - Opportunities for everyone" [V] |

**Weak fit or weaker sibling (F7)**: Awe (7 titles, incl. "Awe Well"; too short to be
distinctive) · Offering (financial or "collection" sense; "offering-counting") · Reverent
(adjective; "Reverent Lutheran") · Await (countdown) · Attend (attendance or HR sense) · Respite
(respite care) · Homeward (relocation or pets; 8 titles) · Pathwise ("Pathwise AI",
"PathWise: Trip Planner & AI") · Shelter (homelessness or animal-shelter sense) · Asha (very
common Indian given name; also the acronym of India's ASHA community health-worker programme
— general knowledge, not re-verified here [I]) · Hushlight (exact medical app "Hushlight -
Contraction Timer"; "hush" means silencing, which the app doesn't do) · Dawnhold · Haltwise ·
Truewell · Breathward · Wellstill · Restward · Kindward · Lightkeep (exact finance app
"LightKeep - Budget & Expenses") · Dawnward (game "Dawnward: Craft & Survive"; dawnward.com
redirects to Rogue Fish Media [V]; same symbol as Dawnstill) · Hearthward (`.com`/`.app`
registered [V]) · Lampway (`.com`/`.app` registered [V]; reads like a lighting store [I]) ·
Stillwick (`.com`/`.app` registered [V]; "wick" is obscure [I]) · Stillmere (game "Stillmere"
in IN/GB; "mere" is obscure in India [I]).

**Reserve (eliminated from the five, not for a conflict)**: **Lampstill** ("a lamp held
still"; compare a lamp in a windless place, Bhagavad Gita 6.19). App Store 0 exact [V];
Trademarkia 0 results [O]; no web brand found [O]; lampstill.com shows "No match" in Verisign
whois [V]; `.app` has no registration record [V]. It was kept out only because Lampward
already represents the lamp symbol. YouTube @lampstill exists (empty channel) and Instagram
@lampstill is taken [O]. The owner can swap it in without new research beyond §15.

## 7. Final five (alphabetical — order implies nothing)

### Dawnstill

- **NAME**: Dawnstill (DAWN-stil). Coined.
- **MEANING**: *dawn* + *still*: the stillness of dawn, before the day's noise begins.
- **WHY IT FITS**: the shield moment becomes a small dawn. It is a quiet beginning before
  the feed, which matches "pause → prayer → intentional unlock" [I].
- **MULTI-FAITH FIT**: dawn is a named prayer time in all three. Islam: *Fajr*, the dawn
  prayer. Hinduism: *Brahma muhurta* and the morning *sandhya*. Christianity: morning prayer
  and Lauds, and Mark 1:35 (prayer "very early in the morning"). No scripture is claimed by the
  word itself [I]. See §8.
- **APP STORE CONFLICTS**: 0 exact titles (US/IN/GB) [V] → **GREEN**. Prefix neighbour
  "DawnLight: Daily Devotion" [V] → **YELLOW**.
- **GOOGLE PLAY CONFLICTS**: no exact match (US, IN) [O]. "Dawn: AI for mental wellbeing"
  (Sword Health) appears for this query in the US [O] → **YELLOW** (prefix only, but an
  AI-wellbeing product).
- **WEB/BRAND CONFLICTS**: no product or company found [O]. Results are personal handles, and
  "Dawn Still" reads as a person's name (Instagram @dawnstill is "Dawn Still") [O] →
  **YELLOW**. *Dawn* is also the name of a major Pakistani English-language newspaper
  ([dawn.com](https://www.dawn.com/)), relevant for South Asian users [I] → **YELLOW**.
- **TRADEMARK FINDINGS**: US mirror: 0 results for "dawnstill" [O]. India mirror: no exact;
  nearest are Dawnsil (cl. 21), Dawntide (cl. 18), and Downstall/Downstaller (Sourcenext,
  cl. 9/42 — different words, visually close) [O] → **GREEN** at screening level. EU/UK/WIPO
  [U].
- **DOMAIN FINDINGS**: dawnstill.com "No match" in Verisign whois [V]; `.app`,
  getdawnstill.com, joindawnstill.com and dawnstillapp.com have no registration record [V];
  `.io` and `.in` NXDOMAIN [O] → **GREEN** (a snapshot; nothing reserved).
- **SOCIAL FINDINGS**: GitHub free [O]; YouTube @dawnstill is an unrelated personal channel
  [O]; Instagram @dawnstill is a person [O]; X @dawnstill appears taken [O] → **YELLOW**.
- **RISKS**: reads as a person's name; may imply morning-only use although the app works all
  day; the "Dawn" prefix is common in wellbeing apps; shares "-still" with Waystill [I].
- **POSSIBLE APP STORE FORM**: `Dawnstill: Prayer, Mantra, Dua` (30) — with "&" it is 31 and
  over the limit. `Dawnstill: Prayerful Pause` (26) + subtitle `A prayerful pause before apps`
  (29).

### Lampward

- **NAME**: Lampward (LAMP-werd). Coined.
- **MEANING**: *lamp* + *-ward* (Old English *-weard*, "toward"): toward the lamp, toward
  the light.
- **WHY IT FITS**: each shield is a turn toward the light instead of the feed. The name
  suggests direction, not restriction [I].
- **MULTI-FAITH FIT**: the lamp is a central symbol in all three. Hinduism: the *diya* in
  aarti and Diwali, and the lamp in a windless place (Gita 6.19). Christianity: Psalm 119:105
  ("a lamp to my feet") and Matthew 5:15. Islam: the lamp in the Light Verse (Quran 24:35)
  [I]. See §8.
- **APP STORE CONFLICTS**: 0 exact titles (US/IN/GB) [V] → **GREEN**.
- **GOOGLE PLAY CONFLICTS**: no exact match (IN: torch/lamp utilities; US: unrelated titles)
  [O] → **GREEN**.
- **WEB/BRAND CONFLICTS**: lampward.com is live as **"引燈 Lampward｜六十甲子籤線上求籤"**, a
  Chinese-language online temple fortune-stick (divination) site [V]. That is spiritual-adjacent,
  and divination conflicts with Christian and Islamic teaching [I] → **ORANGE**. Separately,
  "Lampward" is an indie game alpha on itch.io (Lonernight) [O] → **YELLOW**.
- **TRADEMARK FINDINGS**: US mirror: 0 results for "lampward" [O]. India mirror: no exact;
  near Lampard/Lampara/Lampart and Landward (cl. 12, withdrawn) [O] → **GREEN** at screening
  level. EU/UK/WIPO [U].
- **DOMAIN FINDINGS**: `.com` registered 2026-09-03 (Cloudflare), the divination site [V]
  → **ORANGE**. `.app`, getlampward.com, joinlampward.com and lampwardapp.com have no
  registration record [V]; `.io`/`.in` NXDOMAIN [O].
- **SOCIAL FINDINGS**: GitHub free [O]; YouTube @lampward is an unrelated Korean vlog [O];
  Instagram and X look the same as the nonexistent-handle control (likely unclaimed, low
  confidence) [O] → **YELLOW**.
- **RISKS**: the exact-name `.com` belongs to a divination service, so search results may mix
  in fortune-telling. "ward" can evoke a hospital ward or an Indian municipal ward. The `.com`
  was registered only four weeks ago, so ownership intent is unknown [I/U].
- **POSSIBLE APP STORE FORM**: `Lampward: Prayer, Mantra & Dua` (30). `Lampward: Prayerful
  Pause` (25) + subtitle `Pause, pray, then open apps` (27).

### Quietwell

- **NAME**: Quietwell (KWY-ut-wel). Coined.
- **MEANING**: *quiet* + *well* (a spring or source of water; the word also echoes
  "well-being").
- **WHY IT FITS**: a quiet source to draw from before opening an app; refreshment, not
  punishment [I].
- **MULTI-FAITH FIT**: wells are sacred places in all three. Islam: Zamzam. Christianity:
  Jacob's well (John 4). Hinduism: temple tanks, *kunds* and stepwells [I]. See §8.
- **APP STORE CONFLICTS**: 0 exact titles (US/IN/GB) [V] → **GREEN**.
- **GOOGLE PLAY CONFLICTS**: no exact match (IN, US). The "Quiet…" field is crowded with
  wellness and focus apps: Quietly, Quiet Mind, Quiet Focus, "Quiet Hours: Focus & Silence",
  QuietKeep, "SleepWell by Wellell" [O] → **YELLOW**.
- **WEB/BRAND CONFLICTS**: **Quiet Well Project**, a non-denominational organisation for
  yoga, meditation and spiritual growth (podcast "Linger Here", a book), holds quietwell.com
  [V, homepage] → **ORANGE** (adjacent field; no app found). "Qwell", a former New Jersey
  meditation studio reported as permanently closed [O] → **YELLOW**.
- **TRADEMARK FINDINGS**: US mirror: 0 results for "quietwell" [O]. "quiet well" returns many
  QUIET marks, including QUIET (Zbay LLC, cl. 9/38, messaging software) [O]. India mirror: no
  exact; near Quinowell, Quikwell (cl. 5) and "Quiet Cell" (Sony, cl. 9) [O] → **YELLOW**
  (QUIET-formative marks in software classes; for a professional to assess).
- **DOMAIN FINDINGS**: `.com` registered 2014-02-23 (GoDaddy) and redirects to the Quiet Well
  Project site [V] → **ORANGE**. `.app` and get/join/app `.com` variants have no registration
  record [V]; `.io`/`.in` NXDOMAIN [O].
- **SOCIAL FINDINGS**: GitHub free [O]; YouTube @quietwell exists ("Quietwell", no content)
  [O]; Instagram @quietwell exists [O]; X @quietwell appears taken [O] → **ORANGE** (main
  handles held by others).
- **RISKS**: the "-well" ending reads as generic wellness and may blur into sleep and
  meditation apps. An exact-name spiritual-wellness organisation exists. Most handles are
  taken [I/O].
- **POSSIBLE APP STORE FORM**: `Quietwell: Prayer, Mantra, Dua` (30) — the "&" form is 31 and
  over the limit. `Quietwell: Prayerful Pause` (26) + subtitle `Spiritual Digital Wellbeing`
  (27).

### Turnward

- **NAME**: Turnward (TURN-werd). Coined.
- **MEANING**: *turn* + *-ward*: turning toward.
- **WHY IT FITS**: the moment of opening an app becomes a turn toward God, intention or
  meaning [I].
- **MULTI-FAITH FIT**: resonant in Christianity (*metanoia*, turning) and Islam (*tawbah*,
  turning back to God). Neutral in Hinduism (inward turning, *pratyahara*). Overall the
  resonance leans Abrahamic, and "turning" may evoke **religious conversion**, which is
  sensitive in India (docs/15 §4) [I].
- **APP STORE CONFLICTS**: 0 exact titles (US/IN/GB; re-run in this phase) [V] → **GREEN**.
- **GOOGLE PLAY CONFLICTS**: no exact match: US (docs/15) and IN (this phase) [O] →
  **GREEN**.
- **WEB/BRAND CONFLICTS**: **Turnward**, an active US B2B SaaS ("The LinkedIn Engagement
  Marketplace for Lead Magnets"; LaunchpadFast LLC per docs/15), dominates search results [V,
  homepage] → **ORANGE** (exact name, software, different market).
- **TRADEMARK FINDINGS**: no exact result in the US or India mirrors (docs/15) [O].
  **TURNWORD** (Hyperbotic LLC, cl. 41/42, word-game software, filed 2026-09-11) is a
  sound-alike → **ORANGE**. Turnwind Aviation (India, cl. 42) → **YELLOW** (docs/15) [O].
- **DOMAIN FINDINGS**: `.com` registered 2026-08-20 (Namecheap), the SaaS above [V] →
  **ORANGE**. `.app` and get/join/app `.com` variants have no registration record [V];
  `.io`/`.in` NXDOMAIN [O].
- **SOCIAL FINDINGS**: GitHub free (API 404) [O]; YouTube @turnward not found [O]; Instagram
  had no profile (docs/15) [O]; X @turnward appears taken (HTTP 200 vs control 404; docs/15
  could not determine this) [O] → **YELLOW**.
- **RISKS**: an exact-name software company; a TURNWORD application in software classes; the
  conversion connotation; an Abrahamic lean [I/O].
- **POSSIBLE APP STORE FORM**: `Turnward: Prayer, Mantra & Dua` (30) + subtitle `A prayerful
  pause before apps` (29).

### Waystill

- **NAME**: Waystill (WAY-stil). Coined.
- **MEANING**: *way* + *still*: stillness on the way, or a still point on the path.
- **WHY IT FITS**: a pause on the path through the day before continuing into an app [I].
- **MULTI-FAITH FIT**: path (*marga*, *sirat*, "the Way") and stillness (*dhyana*,
  *sakinah*, Psalm 46:10) are shared ideas. Biblically literate users may read it as
  **subtly Christian** (Psalm 46:10, John 14:6). "Still" also names a distilling apparatus,
  which is notable for Muslim users (docs/15 §4–5) [I].
- **APP STORE CONFLICTS**: 0 exact titles (US/IN/GB; re-run in this phase) [V] → **GREEN**.
- **GOOGLE PLAY CONFLICTS**: no exact match: US (docs/15) and IN (this phase) [O] →
  **GREEN**.
- **WEB/BRAND CONFLICTS**: waystill.com is an outdoor-gear store (sleeping bags) [V,
  homepage] → **ORANGE** (exact name, different category). Also a 2018 song, "The Waystill"
  (docs/15) → **YELLOW**.
- **TRADEMARK FINDINGS**: no exact result in the US or India mirrors (docs/15) [O].
  **STILLWAY** (Stillway Inc, cl. 42 workflow SaaS, filed 2026-04-08) → **ORANGE**. **Waysil**
  (India, Axido Transportation, cl. 39/42, filed 2026-05-21) → **YELLOW/ORANGE** (docs/15) [O].
- **DOMAIN FINDINGS**: `.com` registered 2026-08-24 (Tucows), the store [V] → **ORANGE**.
  `.app` and get/join/app `.com` variants have no registration record [V]; `.io`/`.in`
  NXDOMAIN [O].
- **SOCIAL FINDINGS**: GitHub taken (API 200) [O]; YouTube @waystill exists [O]; Instagram
  @waystill is a men's-clothing store (docs/15) [O]; X looks the same as the control (likely
  unclaimed, low confidence) [O] → **ORANGE**.
- **RISKS**: retail owner of the `.com` and Instagram; near marks in software classes; a
  Christian-leaning reading; the "still" / distilling association; may be split as "Way Still"
  or misspelled "Waystil" [I/O].
- **POSSIBLE APP STORE FORM**: `Waystill: Prayer, Mantra & Dua` (30) + subtitle `Pause, pray,
  then open apps` (27).

## 8. Multi-faith analysis (naming-language analysis — not theological judgement; no believer consulted)

| Name | Christianity | Hinduism | Islam | Other / future faiths | Lean [I] |
|---|---|---|---|---|---|
| Dawnstill | morning prayer, Lauds; Mark 1:35 | *Brahma muhurta*, morning *sandhya*, Ushas (dawn) | *Fajr* (dawn prayer) | dawn practice in Judaism (*Shacharit*), Sikhism (*Amrit vela*), Buddhism (morning chanting) | balanced; time-of-day symbol shared by all three |
| Lampward | Psalm 119:105; "light of the world" | *diya*, aarti, Diwali; Gita 6.19 | Light Verse (24:35): lamp, niche, glass | menorah (Judaism); Buddhist lamp offerings | balanced; lamp is concrete in all three |
| Quietwell | Jacob's well (John 4); "living water" | temple tanks, *kunds*, stepwells | Zamzam | wells and springs widely sacred | balanced; but "well" reads first as wellness [I] |
| Turnward | *metanoia*, repentance as turning | inward turning (*pratyahara*) — weaker | *tawbah* (turning back) | *teshuvah* (Judaism) | Abrahamic lean; conversion connotation in India |
| Waystill | "Be still" (Ps 46:10); "the Way" (Jn 14:6) | *marga*, *dhyana* | *sirat*, *sakinah* | Tao ("the Way"), Buddhist path | subtle Christian reading; distilling association |

Every reading above is a hypothesis. It needs user testing with Christian, Hindu and Muslim
users in India and the US, plus native-speaker review for Hindi, Urdu, Arabic and at least one
South Indian language [U].

## 9. App Store analysis (iTunes Search API, US/IN/GB, 2026-10-01) [V]

| Name | Exact titles | Category-adjacent | Notable neighbours |
|---|---|---|---|
| Dawnstill | 0 | 0 | "DawnLight: Daily Devotion" (Lifestyle; found in the Dawnlight screen) |
| Lampward | 0 | 0 | — |
| Quietwell | 0 | 0 | — |
| Turnward | 0 | 0 | — |
| Waystill | 0 | 0 | — |

Same-category conflicts found elsewhere in the pool show how crowded the space is: "Heed :
Dhikr & Screen Time", "Ruach - Christian Screen Time", "Stillness: Prayer & Breathwork",
"Kneel: Daily Prayer & Devotion", "Prayward", "Tarry: Prayer App" (§6). The API returns at
most 30 results per storefront and does not show names reserved but unreleased in App Store
Connect. Whether App Store Connect will accept a given name can only be seen inside a
developer account [U].

App name ≤ 30 and subtitle ≤ 30 characters (Apple App Store Connect Help [V]). The lengths in
§7 were counted programmatically. "Prayer, Mantra & Dua" fits after an 8-letter name
(Lampward, Turnward, Waystill) but not after a 9-letter one (Dawnstill, Quietwell → 31).

## 10. Google Play analysis (public search pages) [O]

| Name | India (`gl=IN`) | US (`gl=US`) | Class |
|---|---|---|---|
| Dawnstill | no exact; "Dawn…" games and a fintech app | no exact; **"Dawn: AI for mental wellbeing" (Sword Health)** | YELLOW |
| Lampward | no exact; torch/lamp utilities (LotusLamp X, Magic Lantern) | no exact; unrelated (lead4ward, Openlight Media Torch) | GREEN |
| Quietwell | no exact; Quietide, Quiet Mind, SleepWell by Wellell, Quietly, Quiet Focus | no exact; Quietly, Quiet Hours, Quiet Focus, QuietKeep, Tranquility Well SPA | YELLOW |
| Turnward | no exact; unrelated (MyTurn, Track Ur Ward, Turn App) | no exact (docs/15) | GREEN |
| Waystill | no exact; unrelated (WTi, WayShot, WiWit) | no exact (docs/15) | GREEN |

Search pages show only the top results, and the Play package namespace was not checked [U].

## 11. Trademark findings (screening only — not clearance) [O]

| Name | US (Trademarkia mirror) | India (QuickCompany mirror) | Nearest marks of concern | Class |
|---|---|---|---|---|
| Dawnstill | 0 results | no exact | Downstall/Downstaller (Sourcenext, 9/42) — different words | GREEN |
| Lampward | 0 results | no exact | none in 9/41/42/45 | GREEN |
| Quietwell | 0 results; "quiet well" → many QUIET marks (Zbay, cl. 9/38 software; Quiet, Inc., 41/42) | no exact; Quiet Cell (Sony, cl. 9), Quinowell/Quikwell (cl. 5) | QUIET-formative software marks | YELLOW |
| Turnward | no exact (docs/15) | no exact (docs/15) | **TURNWORD** (Hyperbotic, 41/42, filed 2026-09-11); Turnwind Aviation (cl. 42) | ORANGE |
| Waystill | no exact (docs/15) | no exact (docs/15) | **STILLWAY** (Stillway Inc, cl. 42); **Waysil** (India, 39/42) | ORANGE |

Also searched: "soulward" (US 0; India no exact — Soulware, Soulwrap, Southward); "soul ward"
(noise; no exact); "lightfast" (US: 3 dead marks — LIGHTFAST TECHNOLOGY ×2, Veil Cosmetics,
cl. 3; LIGHTFAST INTERNET SERVICE, cl. 38; India no exact); "lampstill" (US 0).

Limits: the mirrors may lag the official registers. Phonetic and conceptual similarity is a
legal judgement. EUIPO, UK IPO, WIPO and TMview were **not searched** (§3). Common-law
(unregistered) rights from the businesses in §13 are not captured by register searches [U].
Classes to clear professionally: at least 9, 41, 42 and 45 in the US, India, UK and EU.

## 12. Domain findings (registry snapshot 2026-10-01; nothing bought or reserved)

"No record" = the registry's RDAP returned 404 (Verisign / Google Registry), or whois said
"No match" [V]. `.io`/`.in` = DNS only [O]; NXDOMAIN means no delegation, not proof of being
unregistered.

| Name | `.com` | `.app` | `.io` | `.in` | get…`.com` | join…`.com` | …app`.com` |
|---|---|---|---|---|---|---|---|
| Dawnstill | **no record** (whois "No match") | no record | NXDOMAIN | NXDOMAIN | no record | no record | no record |
| Lampward | registered 2026-09-03, Cloudflare — divination site | no record | NXDOMAIN | NXDOMAIN | no record | no record | no record |
| Quietwell | registered 2014-02-23, GoDaddy — Quiet Well Project | no record | NXDOMAIN | NXDOMAIN | no record | no record | no record |
| Turnward | registered 2026-08-20, Namecheap — B2B SaaS | no record | NXDOMAIN | NXDOMAIN | no record | no record | no record |
| Waystill | registered 2026-08-24, Tucows — outdoor gear | no record | NXDOMAIN | NXDOMAIN | no record | no record | no record |
| *Soulward (eliminated)* | registered 2018, listed for sale | **registered 2026-09-27 — recovery app** | NXDOMAIN | NXDOMAIN | no record | no record | no record |

Observation [I]: four of the six `.com`/`.app` registrations above were made in August–
September 2026. Registration of attractive coined names is active, so this table can go stale
within days. The same applies to any name chosen later.

## 13. Social / brand findings [O]

| Name | GitHub | YouTube | Instagram | X | Other brand use |
|---|---|---|---|---|---|
| Dawnstill | free | @dawnstill — unrelated personal channel | taken — "Dawn Still" (person) | appears taken | personal-name reading; *Dawn* newspaper (Pakistan) |
| Lampward | free | @lampward — unrelated Korean vlog | likely unclaimed (low confidence) | likely unclaimed (low confidence) | divination site on `.com`; itch.io game alpha |
| Quietwell | free | @quietwell — "Quietwell", no content | taken | appears taken | Quiet Well Project (spiritual wellness); Qwell (closed studio) |
| Turnward | free | not found | no profile (docs/15) | appears taken | B2B SaaS "Turnward" |
| Waystill | taken | @waystill exists | taken — clothing store (docs/15) | likely unclaimed (low confidence) | outdoor-gear store; 2018 song |

TikTok and Facebook were not checked [U]. Instagram and X results are HTTP-level signals only.

## 14. Risk register

| # | Risk | Names | Severity | Mitigation / next check |
|---|---|---|---|---|
| 1 | No EU/UK/WIPO search; US/India results come from third-party mirrors | all five | high (unknown) | professional clearance (cl. 9, 41, 42, 45; US, IN, UK, EU) |
| 2 | Exact-name business holds the `.com` | Lampward (divination), Quietwell (spiritual wellness), Turnward (SaaS), Waystill (retail) | ORANGE | brand on `.app` plus a get/app `.com`; assess common-law rights |
| 3 | Sound-alike or reversed marks in software classes | Turnward (TURNWORD), Waystill (STILLWAY, Waysil), Quietwell (QUIET marks) | ORANGE / YELLOW | attorney similarity opinion |
| 4 | Faith-lean readings: conversion (Turnward), subtly Christian (Waystill) | Turnward, Waystill | ORANGE [I] | user testing in India and the US |
| 5 | Personal-name reading; "Dawn" prefix crowding (Sword Health "Dawn" AI wellbeing app) | Dawnstill | YELLOW | user testing; Play/App Store re-check before filing |
| 6 | Divination association through search results | Lampward | ORANGE | check how lampward.com ranks over time; consider handles and `.app` |
| 7 | Generic-wellness reading; crowded "Quiet…" field | Quietwell | YELLOW | recall testing |
| 8 | Domains and handles can be taken at any time (four recent registrations seen) | all | high | owner may secure assets right after choosing (a purchase is the owner's decision) |
| 9 | Name meanings in Hindi/Urdu/Arabic/Tamil not reviewed by native speakers | all | unknown | native-speaker review |
| 10 | App Store Connect uniqueness not testable outside an account | all | unknown | reserve the name in App Store Connect once a paid team exists (docs/12) |
| 11 | Late-surfacing conflicts (Soulward's `.app` launched 4 days before this search) | all | medium | repeat the full screen on the chosen name immediately before committing to it |
| 12 | Descriptor "Prayer, Mantra & Dua" doesn't fit after 9-letter names | Dawnstill, Quietwell | low | "Prayer, Mantra, Dua" (30) or "Prayerful Pause" |

## 15. Final decision still pending

**No name is selected.** The five finalists — Dawnstill, Lampward, Quietwell, Turnward,
Waystill — are presented alphabetically. Each has a different symbol (dawn, lamp, well, turn,
path) and a different risk profile. None is described as preferred.

Decisions for the product owner:

1. Choose one of the five (or Lampstill from reserve, §6), or ask for a further round.
2. Then run a **deeper clearance check on that one name**: a professional trademark search
   (US, India, UK, EU, WIPO; classes 9, 41, 42, 45); a fresh App Store and Google Play check;
   registry checks; a common-law/web review; native-speaker review; and user testing with
   Christian, Hindu and Muslim users.
3. Only after that: securing domains and handles (the owner's purchase decision), the final
   bundle prefix (docs/12) and App Store Connect name reservation. **None of this has been
   done or started.**

The working name "Prayer Lock", the `unconfigured.prayerlock` placeholder and all project
identifiers stay unchanged until the owner decides.

## 16. Sources

All accessed 2026-10-01.

**App Store**: Apple iTunes Search API, `https://itunes.apple.com/search?term=<name>&entity=software&limit=30&country=<us|in|gb>`,
for every name in §4 (scripted). App name and subtitle limits: Apple App Store Connect Help
(cited in docs/14).

**Google Play** (search pages):
[dawnstill US](https://play.google.com/store/search?q=dawnstill&c=apps&hl=en&gl=US),
[dawnstill IN](https://play.google.com/store/search?q=dawnstill&c=apps&hl=en&gl=IN),
[lampward US](https://play.google.com/store/search?q=lampward&c=apps&hl=en&gl=US),
[lampward IN](https://play.google.com/store/search?q=lampward&c=apps&hl=en&gl=IN),
[quietwell US](https://play.google.com/store/search?q=quietwell&c=apps&hl=en&gl=US),
[quietwell IN](https://play.google.com/store/search?q=quietwell&c=apps&hl=en&gl=IN),
[turnward IN](https://play.google.com/store/search?q=turnward&c=apps&hl=en&gl=IN),
[waystill IN](https://play.google.com/store/search?q=waystill&c=apps&hl=en&gl=IN),
[soulward IN](https://play.google.com/store/search?q=soulward&c=apps&hl=en&gl=IN),
[lightfast US](https://play.google.com/store/search?q=lightfast&c=apps&hl=en&gl=US);
Turnward/Waystill US: docs/15 §6.

**US trademarks (Trademarkia, USPTO data)**:
[dawnstill](https://www.trademarkia.com/search/trademarks?query=dawnstill),
[lampward](https://www.trademarkia.com/search/trademarks?query=lampward),
[quietwell](https://www.trademarkia.com/search/trademarks?query=quietwell),
[quiet well](https://www.trademarkia.com/search/trademarks?query=quiet%20well),
[soulward](https://www.trademarkia.com/search/trademarks?query=soulward),
[soul ward](https://www.trademarkia.com/search/trademarks?query=soul%20ward),
[lightfast](https://www.trademarkia.com/search/trademarks?query=lightfast),
[lampstill](https://www.trademarkia.com/search/trademarks?query=lampstill);
Turnward, Waystill, TURNWORD, STILLWAY: docs/15 §7 and its sources.

**India trademarks (QuickCompany, IP India data)**:
[dawnstill](https://www.quickcompany.in/trademarks?q=dawnstill),
[lampward](https://www.quickcompany.in/trademarks?q=lampward),
[quietwell](https://www.quickcompany.in/trademarks?q=quietwell),
[soulward](https://www.quickcompany.in/trademarks?q=soulward),
[lightfast](https://www.quickcompany.in/trademarks?q=lightfast);
Turnward, Waystill, Waysil, Turnwind: docs/15 §7.

**Not searched (attempted 2026-10-01)**: UK IPO trade-mark text search (HTTP 403); TMview API
(no response); WIPO Global Brand Database and EUIPO eSearch (JavaScript shells, no results
returned).

**Websites and brands**: [soulward.app](https://soulward.app/);
[soulward.com → HugeDomains](https://soulward.com/); [lampward.com](https://lampward.com/);
[Lampward on itch.io](https://lonernight.itch.io/lampward);
[quietwell.com → Quiet Well Project](https://sites.google.com/view/onthethreshold1/home);
[Qwell Meditation & Wellness Studio](https://qwellmeditationstudio.com/);
[turnward.com](https://turnward.com/); [waystill.com](https://waystill.com/);
[getlightfast.com → lightfast.ai](https://lightfast.ai/); [hushward.com → Alertify](https://www.alertify.io/);
[seekward.com](https://seekward.com/); [dawnward.com → Rogue Fish Media](https://www.RogueFishMedia.com/);
[Salesforce Trailhead](https://trailhead.salesforce.com/); [Dawn (newspaper)](https://www.dawn.com/).
Web searches: "Dawnstill", "Lampstill", "Lightfast" (app/company/brand), "Lampward" itch.io,
"Qwell" meditation studio. Earlier Phase 4 web searches (Lightward, Presentia, Lampwise,
Wakelight, Hesper, Northlight, Heartward, Courtyard, Nook, Aman) are recorded only as search
observations [O] and are not re-linked here.

**Domains**: Verisign RDAP `https://rdap.verisign.com/com/v1/domain/<name>.com`; Google
Registry RDAP `https://pubapi.registry.google/rdap/domain/<name>.app`; `whois` (Verisign) for
dawnstill.com and lampstill.com; `dig NS <name>.io|.in @1.1.1.1`; homepage fetches with curl.

**Social**: `https://api.github.com/users/<name>`; `https://www.youtube.com/@<name>`;
`https://www.instagram.com/<name>/`; `https://x.com/<name>`; negative control `zqxvplk7731neg`.

**Internal**: docs/10 (competitive landscape), docs/12 (signing), docs/13 §6 ("Prayer Lock"
collisions), docs/14 (naming research; existing category brands Hallow, Lumen, Abide, Dwell,
Sanctum), docs/15 (Turnward/Waystill validation), docs/16 (Devote).

**Scripture references** (cited by chapter and verse only): Psalm 46:10; Psalm 119:105;
Matthew 5:15; Mark 1:35; John 4; John 14:6; Quran 24:35; Bhagavad Gita 6.19.
