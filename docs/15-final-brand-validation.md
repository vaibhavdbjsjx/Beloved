# Final brand validation (Phase 3.5)

Date: 2026-10-01. Research only — no code, Xcode, entitlement, bundle-ID, App Group, package,
asset, signing, or Apple changes. **This is not legal clearance.** Nothing below means a name is
"available" or "safe"; it records what public searches returned on this date. Builds on
docs/14 without repeating it.

## 1. Methodology

| Source | What was searched | Status |
|---|---|---|
| App Store (iTunes Search API, US/IN/GB) | exact names, spaced/reversed variants, descriptors | ✅ done |
| Google Play (US search pages) | the 5 names | ✅ done |
| Web search | names, India-specific uses, alcohol/"still" association | ✅ done |
| **USPTO data** via Trademarkia (third-party mirror) | exact names + variants (Stillway, Turnword, Pause Away); "Alcove" as a positive control (60 hits) proves zero results are meaningful | ✅ done — USPTO's own search refused programmatic queries (HTTP 405) |
| **IP India data** via QuickCompany (third-party mirror) | the 5 names (+ near matches it surfaced); "Alcove" control (453 hits) | ✅ done — official e-register not used (captcha/JavaScript) |
| **EUIPO, UK IPO, WIPO Global Brand Database, TMview** | — | ⛔ **not completed**: APIs require authentication or block scripts ("Missing Authentication Token", HTTP 403/000); the browser route failed its policy check 4 times |
| Domains | registry RDAP (Verisign `.com`, Google `.app`), whois, homepage fetch, DNS | ✅ `.com`/`.app`; `.in` registry didn't respond → DNS only |
| Social handles | GitHub and YouTube (reliable 200/404), Instagram (profile metadata) | ✅ partial — X and TikTok couldn't be determined |
| Web archive | pauseway.com capture history (Wayback CDX) | ✅ done |
| Not done | user testing, native-speaker review, professional clearance | — |

Sections 2–5 and 8–10 are **naming-language analysis by the researcher, not user research**.
They state likely interpretations and must be validated with real users (see §14).

## 2. Candidate interpretation

**Name alone** (no icon, no descriptor):

| Name | Likely first reading |
|---|---|
| Turnward | direction or change — a navigation, habit or self-improvement app; nothing points to prayer or screen time |
| Waystill | calm on a journey — a travel, outdoors or meditation app (an outdoor-gear brand already uses waystill.com) |
| Oriel | a person's name (also a Hebrew given name), a college, or a company; no product cue |
| Alcove | furniture, real estate or a hotel; in India, a Kolkata property developer and a serviced-apartment chain |
| Pauseway | a break or "pause" tool — closest to the function, but no spiritual cue |

**All five are abstract to a first-time viewer. The descriptor has to carry the meaning.**

**Descriptor test** (shown as the App Store name `[Name]: descriptor`; all fit 30 characters
except where noted):

| Descriptor | What it communicates | Evidence |
|---|---|---|
| Prayer & Focus | prayer + productivity; "focus" reads as a timer as easily as an app pause | **25** App Store listings already use these words ("Sakina: Prayer & Focus", "Uplift: Prayer & Focus", "PrayLock: Focus & Prayer") — a commodity |
| Faith & Focus | vaguer; "faith" is general | **6** listings ("Rooted: Faith & Focus", "Ignite: Faith & Focus", "Quran Mode: Focus & Faith") |
| Prayer, Mantra & Dua | **clearest multi-faith signal**: names the core practice of each tradition; no screen-time cue | **0** listings; exactly 30 characters with either surviving name |
| Spiritual Digital Wellbeing | names the category, but reads as jargon; "Digital Wellbeing" is also Google's Android feature name, familiar in India | **0** listings; **37 characters as a name suffix (too long)**, 27 as a subtitle |

The most understandable pairing in this analysis splits the job: the **name descriptor** carries
the faiths, the **subtitle** carries the screen-time behaviour. For example:
`[Name]: Prayer, Mantra & Dua` + subtitle `A prayerful pause before apps` (29) or
`Spiritual Digital Wellbeing` (27). Note: "Dua" may be unfamiliar to non-Muslims, and listing
order can imply priority (App Store localizations could reorder it).

## 3. Three-second test (icon + name + subtitle + first screenshot)

| Name | Passes in ~3 s? | Why |
|---|---|---|
| Turnward | only with the descriptor + a shield screenshot | the name gives no prayer or screen-time cue; the icon (turning arrow) suggests navigation unless paired with a lamp/pause motif |
| Waystill | only with the descriptor + a shield screenshot | the name suggests calm or travel; the subtitle must say "before apps" |
| Oriel | weakest | the name reads as a person or company |
| Alcove | weak | real-estate/hotel association, strongest in India |
| Pauseway | partly | "Pause" signals the mechanism; the spiritual purpose must come from the descriptor |

The first screenshot should show the system shield ("You chose to protect [App]. Take a moment
before opening it.") next to the prayer moment. That image explains the product better than any
of these names.

## 4. Multi-faith analysis (naming language — not theological judgement; no believer is represented)

| Name | Christian | Hindu | Muslim | Judaism / Sikhism / Buddhism |
|---|---|---|---|---|
| Turnward | natural — "turning toward God" (repentance, *metanoia*) | neutral; nothing Hindu-specific (inward turning appears in yoga as *pratyahara*); **"turning" may evoke religious conversion, sensitive in India** | resonant — *tawbah* literally means turning (back) to God; same conversion ambiguity ("turning to Islam") | Judaism: *teshuvah* (return); Sikhism neutral; Buddhism neutral. The resonance leans Abrahamic |
| Waystill | natural — echoes "Be still" (Psalm 46:10) and "the Way" (John 14:6), so biblically literate users may read it as **subtly Christian** | neutral — path (*marga*) and stillness (*dhyana*) | neutral — path (*sirat*) and tranquility (*sakinah*) | Judaism (Psalms) natural; Sikhism (path, *sehaj*) neutral; Buddhism (the Way, stillness) natural |
| Oriel | neutral; English church history (oriel as oratory) | neutral | neutral | sounds like the archangel *Uriel* (Jewish/Christian tradition); "Oriel" is also a Hebrew given name — Abrahamic association |
| Alcove | natural (chapel alcove) | natural (shrine niche) | natural (mihrab niche; Arabic-derived word) | natural for all |
| Pauseway | neutral | neutral | neutral | neutral — but secular-sounding |

No name sounded disrespectful or commercialised in this analysis. None of the five uses any
faith's sacred vocabulary.

## 5. India / international analysis

| Name | Indian English | US | UK | Obvious issues found |
|---|---|---|---|---|
| Turnward | "turn-vard" (common w/v merger) — fine | TURN-werd | TERN-wud | can be heard as "toward"; "ward" also means a hospital ward or an Indian municipal ward (minor). No awkward Hindi/Urdu/Arabic meaning known |
| Waystill | "vay-still" — fine | WAY-stil | WAY-stil | may be split as "Way Still" or misspelled "Waystil"; "still" also means a distilling apparatus (no liquor brand by this name was found; minor, but notable for Muslim users). No awkward meaning known |
| Oriel | "o-REEL" or "OR-ee-el" — inconsistent | OR-ee-ul | OR-ee-ul | reads as a person's name; Hebrew name; Indian software company "Oriel" |
| Alcove | familiar; "AL-kohv" | AL-kohv | AL-kohv | Indian real-estate and serviced-apartment brands |
| Pauseway | "pauz-vay" — fine | PAWZ-way | PAWZ-way | none beyond the crowded "pause" field |

## 6. Searchability

| Name | What dominates search now |
|---|---|
| Turnward | **web: dominated by Turnward**, an active US B2B LinkedIn-marketing SaaS (LaunchpadFast LLC, with a public API). App Store: 0 results. Google Play: no exact match |
| Waystill | web: no dominant owner (a 2018 song, "The Waystill"; an outdoor-gear store launched Aug 2026). App Store: 0 results. Google Play: no exact match |
| Oriel | web: dictionary word, Oxford college, many companies, including India's Oriel Infonet Solutions (software, with an "Oriel" app on both stores) |
| Alcove | dictionary meaning plus real estate, hospitality and apps (incl. "Mind Alcove", an AI mental-health app featured by Apple) |
| Pauseway | "pause" is generic; Pauseaway (wellness brand); a UK meditation service used pauseway.com (archive captures 2018–Jul 2025) |

Ownership of search results is not claimed for any name.

## 7. Trademark / business conflict screen

| Name | Exact-name findings | Near-name findings | Software/wellness? | Jurisdiction | Status |
|---|---|---|---|---|---|
| **Turnward** | no USPTO-data result; no IP India-data result. Unregistered business use: turnward.com (B2B SaaS) | **TURNWORD** — Hyperbotic LLC, classes 41/42 (word-game software), filed 2026-09-11 (sound-alike); "Turnwind Aviation" class 42 (2026); "Turnworld" class 7 | business use is software (marketing SaaS); TURNWORD is software (games) | US; India | TURNWORD live/pending; Turnward business active |
| **Waystill** | no USPTO-data result; no IP India-data result. Business use: waystill.com outdoor gear; @waystill Instagram (clothing store) | **STILLWAY** (reversed) — Stillway Inc, class 42 workflow SaaS, filed 2026-04-08; Pre-Paid Legal Services (classes 35/36/45, 2025). **Waysil** — Axido Transportation, classes 39/42, filed 2026-05-21 | Stillway and Waysil are class 42 software | US; India | all live/pending |
| **Oriel** | US: 50 results incl. **Vibe, Inc. — classes 9/42 (software/AI), filed 2025-08-27**; Newport Corp class 9 (registered). India: 353 results incl. **Oriel Infonet Solutions — class 9, registered (2004)**; "Oriel" class 41 registered (2009) | Oriele (class 14) | **yes — software, both markets** | US; India | live/registered and pending |
| **Alcove** | US: 60 results incl. **AARP — class 9 downloadable software (registered)**, Alcove Labs class 42 SaaS (registered), LivingLab class 42 (registered), Aleo Labs classes 9/36/42 (pending 2026). India: 453 results incl. Alcove class 9 (registered 2021), Alcove Designs class 42 (Ready for Examination, Jan 2026), Marriott class 43 (2026) | Mind Alcove (app) | **yes — software, both markets** | US; India | live/registered and pending |
| **Pauseway** | no USPTO-data result; no IP India-data result. Business use: UK meditation service (archive captures 2018–Jul 2025; now not responding; current registration created May 2025, which suggests a re-registration) | **PAUSE**: 4,532 US results incl. PAUSE MEDITATION LLC (class 41, registered), PAUSE HOLDINGS (class 44 wellness, registered); India "Pausewear" class 25 | **yes — wellness/meditation** | US; UK (business); India | live/registered (PAUSE); UK service unclear/historical |

EU/UK/WIPO registers were **not** searched (see §1). All findings require professional
trademark clearance before reliance.

## 8. Domain ecosystem (does not reserve or buy anything)

| Name | .com | .app | .in | get/app variants | Handles |
|---|---|---|---|---|---|
| Turnward | appears registered — active B2B SaaS (Cloudflare DNS) | no registration record (available-looking); no DNS | DNS: NXDOMAIN; registry could not be confirmed | getturnward.com, turnwardapp.com, getturnward.app available-looking | GitHub: no account found; YouTube @turnward: no channel found; Instagram: no profile found; X/TikTok: could not be determined |
| Waystill | appears registered — outdoor-gear store (created 2026-08-24) | available-looking; no DNS | NXDOMAIN; registry could not be confirmed | getwaystill.com, waystillapp.com, getwaystill.app available-looking | GitHub: taken; YouTube @waystill: exists; Instagram @waystill: a men's-clothing store; X/TikTok: could not be determined |
| Oriel | appears registered (listed for sale on a marketplace) | appears registered | — | getoriel.com registered | GitHub, YouTube, Instagram taken |
| Alcove | appears registered | appears registered | — | all checked variants registered | GitHub, YouTube, Instagram taken |
| Pauseway | appears registered (creation date May 2025, archive captures since 2018; no response) | available-looking | — | variants available-looking | GitHub: none; YouTube @pauseway: exists; Instagram: a personal account |

## 9. Product architecture

| | Turnward | Waystill |
|---|---|---|
| App Store name | `Turnward: Prayer, Mantra & Dua` (30) | `Waystill: Prayer, Mantra & Dua` (30) |
| Subtitle | `A prayerful pause before apps` (29) | `Spiritual Digital Wellbeing` (27) |
| Icon concept | a curved stroke turning inward toward a small steady flame | a horizon line with a single still point of light above a path |
| Home-screen label | Turnward | Waystill |
| AI assistant | Turnward Companion | Waystill Guide |
| Premium tier | Turnward Plus | Waystill Plus |
| Future products | Turnward Journal; Family (parent-guided pauses — would need `.child` authorization and a separate review); Apple Watch ("turn" reminders); web (turnward.app) | Waystill Journal; meditation and stillness series; scripture-study paths ("ways"); Watch; web (waystill.app) |
| Supports expansion? | yes — "turning toward" fits reflection, habit, education | yes — "way" fits study paths, "still" fits meditation |

Eliminated names in brief (for completeness): Oriel (`Oriel: Prayer, Mantra & Dua`, 27),
Alcove (`Alcove: Prayer, Mantra & Dua`, 28) and Pauseway (`Pauseway: Prayer, Mantra & Dua`,
30) would structure the same way. Their problems are conflicts, not architecture.

## 10. Pronunciation

| Name | Guide | Needs repeated explanation? |
|---|---|---|
| Turnward | TURN-werd | rarely (spelled as said) |
| Waystill | WAY-stil | sometimes (one word or two; one "l" or two) |
| Oriel | OR-ee-ul | yes (stress varies by speaker) |
| Alcove | AL-kohv | no |
| Pauseway | PAWZ-way | rarely |

## 11. Memory and search characteristics (no scores, no ranking)

| | Turnward | Waystill | Oriel | Alcove | Pauseway |
|---|---|---|---|---|---|
| Syllables | 2 | 2 | 3 | 2 | 2 |
| Unusual spelling | no | slightly ("ll") | no | no | no |
| Dictionary word | no (transparent compound) | no (transparent compound) | yes (rare) | yes (common) | no (compound of a common word) |
| Unique in App Store search | yes (0 results) | yes (0) | no (3) | no (7+) | exact yes; "pause" field crowded |
| Unique in web search | no (exact-name B2B company) | mostly (no dominant owner) | no | no | no |
| Phonetic simplicity | high | high | medium | high | high |
| Visual distinctiveness (wordmark) | "rnw" cluster is distinctive | double "ll" ascenders | short, elegant | common shape | "Pause" prefix generic |

## 12. Eliminated names (evidence)

| Name | Serious problem(s) |
|---|---|
| **Oriel** | **direct software conflicts in both markets**: India — Oriel Infonet Solutions, class 9 registered (2004), selling an "Oriel" ERP plus mobile apps on both stores; US — Vibe, Inc. class 9/42 software/AI application (2025), Newport class 9 registered. Also reads as a person's name; Hebrew name association; every domain and handle taken |
| **Alcove** | **software trademarks in both markets** (US: AARP class 9 registered, Alcove Labs and LivingLab class 42 registered; India: class 9 registered, class 42 pending); a wellness app ("Mind Alcove") featured by Apple; India search dominated by real estate and serviced apartments; every domain and handle taken |
| **Pauseway** | **wellness/meditation conflicts**: a UK meditation service used the name (active until at least Jul 2025); the "PAUSE" root has 4,532 US results including registered meditation (class 41) and wellness (class 44) marks; it blends into many "Pause…" screen-time apps; weakest spiritual meaning; YouTube and Instagram handles taken |

Not generated: a secondary candidate set. The brief asks for one only if all five fail; two
passed with caveats. More can be generated and screened on request.

## 13. Final shortlist (no winner chosen)

| | **Turnward** | **Waystill** |
|---|---|---|
| For | 0 App Store / Play results; no exact USPTO-data or IP India-data result; clean handles on GitHub, YouTube and Instagram (as checked); `.app`, `get-.com` available-looking; spelled as said | 0 App Store / Play results; no exact USPTO-data or IP India-data result; web search has no dominant owner; `.app`, `get-.com` available-looking; supports meditation and study expansions |
| Against | **exact-name active software business** (US B2B SaaS) dominates web search and holds the `.com`; **TURNWORD** sound-alike application in classes 41/42; "turning" may evoke **conversion**, sensitive in India; Abrahamic-leaning resonance | **STILLWAY** (class 42 SaaS) and **Waysil** (India, classes 39/42) are near names; the `.com` and `@waystill` handles belong to unrelated retailers; can read as subtly Christian (Psalm 46:10 / John 14:6); "still" can evoke distilling |
| Comprehension | needs descriptor + screenshot | needs descriptor + screenshot |

## 14. Remaining risks

1. **No EU, UK, or WIPO search** was completed; US and India results come from third-party
   mirrors that may lag the official registers. Professional clearance is required (classes 9,
   41, 42, 45 at minimum; US, India, UK, EU).
2. **No user testing.** The interpretations in §2–§5 are hypotheses. Test with Christian,
   Hindu and Muslim users in India and the US: name recall, meaning, the conversion
   connotation (Turnward), Christian-leaning reading (Waystill).
3. Phonetic similarity judgements (Turnward/TURNWORD, Waystill/Waysil) are for a trademark
   professional to assess.
4. Domain status can change at any moment; `.in` registry status couldn't be confirmed.
5. X/TikTok handles were not determined.
6. The App Store Connect app name must be reserved inside a developer account; uniqueness there
   wasn't checked.
7. The descriptor "Prayer, Mantra & Dua" names three practices. Adding faiths later needs a
   different descriptor or per-locale variants.

## 15. Questions requiring your decision

1. **Proceed with professional trademark clearance** on Turnward and/or Waystill (US, India,
   UK/EU)? Or ask for a secondary set first, because both carry the caveats in §13?
2. Are the **conversion connotation** (Turnward) and the **subtle Christian resonance**
   (Waystill) acceptable risks for an India-first, multi-faith launch, pending user testing?
3. Is **descriptor-led comprehension** acceptable — an abstract brand plus
   "Prayer, Mantra & Dua" plus a screen-time subtitle?
4. Unchanged from docs/14: the reverse-DNS prefix/company you control; individual vs
   organization developer account; brand-based vs neutral permanent bundle ID slug.

### Sources
iTunes Search API (US/IN/GB); Google Play search (US); Trademarkia searches (USPTO data):
[turnward](https://www.trademarkia.com/search/trademarks?query=turnward),
[waystill](https://www.trademarkia.com/search/trademarks?query=waystill),
[oriel](https://www.trademarkia.com/search/trademarks?query=oriel),
[alcove](https://www.trademarkia.com/search/trademarks?query=alcove),
[pauseway](https://www.trademarkia.com/search/trademarks?query=pauseway),
[stillway](https://www.trademarkia.com/search/trademarks?query=stillway),
[turnword](https://www.trademarkia.com/search/trademarks?query=turnword),
[pause away](https://www.trademarkia.com/search/trademarks?query=pause%20away);
QuickCompany searches (IP India data):
[turnward](https://www.quickcompany.in/trademarks?q=turnward),
[waystill](https://www.quickcompany.in/trademarks?q=waystill),
[oriel](https://www.quickcompany.in/trademarks?q=oriel),
[alcove](https://www.quickcompany.in/trademarks?q=alcove),
[pauseway](https://www.quickcompany.in/trademarks?q=pauseway);
[Oriel Infonet Solutions](https://www.orielsoftware.com/);
[Alcove Realty](https://www.alcoverealty.in/legacy); [Alcove Service Apartments](https://www.alcove.co.in/);
[turnward.com](https://turnward.com/); [waystill.com](https://waystill.com/);
Wayback CDX (pauseway.com); Verisign/Google Registry RDAP; whois; DNS (1.1.1.1).
