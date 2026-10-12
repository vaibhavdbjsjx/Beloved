# Brand & product-name research (Phase 3)

Research date: 2026-10-01. **Research only — no code, configuration, bundle IDs, App Groups,
entitlements, signing, or Apple requests were changed or made.** This is a practical commercial
naming assessment, **not legal advice and not trademark clearance.**

Methods and their limits:
- **App Store**: public iTunes Search API, storefronts US, India (IN), UK (GB), 50 results per
  term per storefront; "exact/prefix" = listing name equals the term or starts with it.
- **Google Play**: public search pages (US) for selected names.
- **Domains**: official registry RDAP (Verisign for `.com`, Google Registry for `.app`) +
  `whois` + an HTTP fetch of the homepage. "Available-looking" = no registration record at
  query time; it can change any minute and is not a reservation.
- **Web**: general web search for companies/products using the name.
- **Trademarks**: the USPTO search API refused programmatic queries (HTTP 405); no trademark
  database was searched. Indian, UK/EU, and WIPO searches were not performed. → see §12.
- **Social handles**: not checked (platforms block automated lookups).

---

## 1. Current market naming landscape

**The descriptive space is saturated.** A combined US/IN/GB App Store search found **49
listings** whose names contain "Prayer Lock", "PrayLock", or "Christian Focus" — Christian
(e.g. "Prayer Lock: Bible App Blocker", "Christian Prayer Lock: Bible", "Scroll The Bible:
Prayer Lock"), Muslim ("prayer lock: muslim focus", "Muslim Prayer Lock: Awwal", "Prayer Lock:
Noor", "Sajda: Salah Prayer Lock", "Khushu: Muslim Prayer Lock"), and Hindu ("Sankalp: PrayLock
& Panchang", plus "Dharma Lock: Hindu Prayer App" found earlier). Most have small rating counts
(a few hundred).

The neighbouring descriptive phrases are also taken *in this exact category*:

| Phrase | Existing App Store listings (examples) |
|---|---|
| Pray First | "Pray First: Reduce Screen Time", "Pray First - Pray to Unlock", "Pray First – Prayer Life Plans" |
| Prayer Pause | "Prayer Pause: Screen Time", "prayer pause: focus on God", "Prayer Pause - Habit Tracker" |
| Sacred Pause | "Sacred Pause: Daily Prayer", "Sacred Pause: Prayer & Focus", "Sacred Pause" |
| Pause and Pray | "Pause and Pray App", "Pause and Pray : Prayer Habit" |
| Christian Focus | "BibleScroll: Christian Focus", "Prayer First: Christian Focus", "Prayer Key: Christian Focus", "FaithLock:pray,Christian focus" |

The named competitor **"prayer lock: christian focus" (Covenant Studios LLC)** does not resolve
in the US/IN/GB App Store today (lookup id 6744703926 → 0 results), but **is live on Google
Play** under that name.

**Category leaders use short brands plus a descriptor**, not descriptive names: "Opal: Screen
Time Control" (14.5k ratings), "one sec | screen time + focus" (7.1k), "ScreenZen", "Brick",
"Abide: Bible Prayer Meditation" (122k), "Pillars: Prayer Times & Qibla", "Sajda: Prayer Times,
Quran", "Muslim Pro".

## 2. Why "Prayer Lock" is problematic

| Issue | Evidence |
|---|---|
| Not distinctive | 49 similar listings across three storefronts; one competitor still trades on Google Play with the name |
| App Review risk | Guideline 2.3.7 (unique names, no competitor-name stuffing) and 4.1 (copycats; others' brand/product names) |
| Weak trademark | "Prayer" + "Lock" describes the function; descriptive names are generally hard to protect and easy to collide with (not legal advice) |
| Tone | "Lock" frames the product as punishment; the product principle is a user-chosen, non-shaming pause |
| Scope | Narrows the brand to one mechanism (blocking); the roadmap includes calendar, reflection, journal, assistant |
| Namespace | The bundle namespace `com.prayerlock.*` is used by another developer ("Prayer Lock - Quiet Time") |

What "Prayer Lock" does well: instant clarity and keyword match. Both can be kept without the
brand carrying them — in the App Store descriptor, subtitle, and keyword field (without naming
competitors).

**Assessment:** suitable only as an internal working name.

## 3. Naming strategy

| Option | For | Against | Evidence |
|---|---|---|---|
| **A — keep "Prayer Lock"** | clarity; search match | saturation; review/trademark exposure; punitive tone | §1, §2 |
| **B — broader descriptive spiritual name** | clarity without "lock" | every natural phrase screened is already used in this category | Pray First, Prayer Pause, Sacred Pause, Pause and Pray (§1) |
| **C — short distinctive brand + descriptive App Store suffix** | distinctiveness; stronger trademark position (coined/arbitrary names are generally easier to protect); room to expand beyond blocking | must build meaning through design and copy; discoverability depends on the suffix, subtitle, and keywords | category leaders (§1); App Store screens (§6) |

Evidence points toward **C**, but this document does not pick a name. Constraints applied to
every candidate:
- no word owned by one tradition (excluded: Selah, Amen, Om, Salah, Sukoon, Shanti, Kairos, Mala, Vesper, Noor);
- not "lock", "block", "focus", "prayer" in the brand itself (they go in the descriptor);
- 1–3 syllables, spelled as said, no awkward meaning in Hindi/Urdu/Arabic known to us;
- avoids existing category brands (Abide, Hallow, Dwell, Sanctum, Lumen).

## 4. Candidate names

About 40 names were screened, across the requested categories (Spiritual/Peace, Digital
wellbeing, Spiritual+technology, Premium abstract, Universal faith). Most were eliminated by
evidence:

| Eliminated | Reason (evidence) |
|---|---|
| Stillpoint, Threshold, Ember, Lull, Halcyon, Lumora, Revere, Amana | crowded App Store (13–40 exact/prefix listings each) |
| Vigil, First Light / Firstlight, Devote, Orison, Kindlight, Devota | existing Christian prayer/Bible apps with that name |
| Sukoon | 26 listings including "Sukoon: Quran & Salah Lock" |
| Pausa, Pausely, Interlude | existing screen-time/phone-addiction apps with that name |
| Stillward | an app named exactly "Stillward" exists |
| Stillmark | stillmark.com = Bitcoin venture firm; stillmarkapp.com = "Stillmark – The Rite" |
| Inlume | inlume.app = active product ("INLUME — Private beta"); .com/.app taken |
| Dawnlit | dawnlit.com = "Dawn Lit — An AI lab in Seattle" (confusion with our assistant); "lit" slang |
| Hushpath | .com and .app registered (.com listed for sale) |
| Inward, Quietude, Beforehand, Intently, Intenta, Lantern, Eastward, Stillwise, Oriens, Dawnward | existing meditation/sleep/planner/VPN/game apps or weak fit |
| Kneelwell, Lumenwell, Wicklight | quality: kneeling isn't shared by all three; "Lumen" collides with "Prayer Lock: Lumen"; "wick" reads poorly |

**Shortlist (5):** Turnward · Waystill · Oriel · Alcove · Pauseway.

| Name | Category | Meaning / story |
|---|---|---|
| **Turnward** | C / E (coined) | "turning toward" — away from the feed, toward prayer |
| **Waystill** | A / D (coined) | "way" (path) + "still" (stillness): a still point on the way |
| **Oriel** | A / E (real word) | an oriel is a projecting window of light; in medieval English also a small oratory |
| **Alcove** | A / E (real word) | a quiet niche; from Arabic *al-qubba* via Spanish; prayer niches exist in mosques (mihrab), temples (shrine niches) and churches (chapel alcoves) |
| **Pauseway** | B (coined) | "the way of the pause" — the most literal |

## 5. Candidate analysis

Notes on each shortlisted name against the criteria. These are tradeoffs, not scores.

| Criterion | Turnward | Waystill | Oriel | Alcove | Pauseway |
|---|---|---|---|---|---|
| Memorability / pronunciation | 2 syllables, spelled as said | 2 syllables; can be misread "way still" (= "yet") | 3 syllables; *OR-ee-el*; some will say "Oreo-l" | 2 syllables, common word | 2 syllables, obvious |
| Clarity of purpose | medium (turning) | low–medium | low (needs subtitle) | low–medium (quiet place) | high (pause) |
| Spiritual resonance | medium | medium | medium–high (light, oratory) | high (prayer niche in all three) | low |
| Premium / visual potential | arrow-turning-inward mark | path + still-water mark | window-of-light mark | arch/niche silhouette shared by mosque, temple, church | weaker; generic "pause" glyph |
| US usability | good | good | good (word is obscure) | good | good |
| India usability | good in English-speaking audience; see conversion caution (§8) | good | neutral; unfamiliar word | good; familiar word | good |
| Distinctiveness (App Store) | **0** exact/prefix listings | **0** | 3 (camera, ERP, Welsh-letters app) | 7 + "Mind Alcove: AI Mental Health" | 0 exact, but "Pause…" blockers abound |
| Google Play (US) | no exact match | no exact match | two "Oriel" apps (Indian consultancy) + "The Oriel" | 8 incl. "Mind Alcove" | no exact match; many "Pause…" blockers |
| Domain potential (§7) | .com taken (B2B); .app free-looking | .com taken (sleeping bags); .app free-looking | .com for sale (marketplace); .app taken | all taken | .com taken (dormant); .app free-looking |
| Main conflict | Turnward (LinkedIn marketplace); "Turnward Compass" Android app | Waystill outdoor-gear store (registered Aug 2026) | common business name (education, optics, ERP) | Mind Alcove (wellbeing, featured by Apple); Alcove VR wellbeing company (India) | Pauseway UK meditation subscription; Pauseaway wellness brand |
| Trademark | **not searched** | **not searched** | **not searched** | **not searched** | **not searched** |

## 6. Competitor / conflict findings

| Name | Exact/near apps | Companies / brands | Confusion risk |
|---|---|---|---|
| Turnward | none (App Store, Play) | turnward.com — LinkedIn engagement marketplace; GitHub privacy page for a "Turnward Compass" Android app | low–medium (different fields) |
| Waystill | none (App Store, Play) | waystill.com — outdoor sleeping-bag retailer | low (different field), but owns the .com |
| Oriel | 3 App Store, 2–3 Play (none in wellbeing) | widely used business name | medium (generic name, weak ownability) |
| Alcove | 7 App Store, 8 Play; "Mind Alcove: AI Mental Health" | Alcove (VR wellbeing, Kolkata; acquired); Alcove vault/wallet apps | **high in wellbeing** |
| Pauseway | none exact; "Pausely" ×8 incl. two blockers | Pauseway meditation-for-remote-workers service (UK); Pauseaway (@pauseaway) | **high in wellness**; blends with "Pause…" blockers |

Not reproduced: any competitor's branding, icons, text, or screenshots.

## 7. Domain findings (2026-10-01; indicators only)

| Name | .com | .app | Other |
|---|---|---|---|
| Turnward | registered — active B2B site | **not registered (available-looking)** | getturnward.com, turnwardapp.com available-looking |
| Waystill | registered 2026-08-24 — active outdoor-gear store | **available-looking** | getwaystill.com available-looking |
| Oriel | registered — redirects to a domain marketplace (Atom; for sale) | registered (no response) | getoriel.com registered |
| Alcove | registered 2021 (no response) | registered (403) | getalcove.com, alcoveapp.com registered |
| Pauseway | registered 2025-05-04 (GoDaddy; no response) | **available-looking** | getpauseway.com, pausewayapp.com available-looking |

`.ai` was not checked: the assistant is a feature, not the brand. Nothing was purchased, and no
ownership is claimed.

## 8. Multi-faith compatibility

Test listing: *"A digital wellbeing app that helps Christians, Hindus and Muslims pause before
distracting apps and spend a meaningful moment in prayer, reflection or devotion."*

| Name | Makes sense? | Inclusive? | Favours a faith? | Respectful? | Expands (Judaism, Buddhism, Sikhism…)? |
|---|---|---|---|---|---|
| Turnward | yes — turning toward prayer | mostly | no vocabulary from any one faith; **but "turning" can evoke religious conversion**, a sensitive subject in India (several states have anti-conversion laws) — test with Hindu and Muslim users | yes | yes |
| Waystill | yes — a still moment on the way | yes | no; "the way/path" is shared (Christian "the Way", Islamic *sirat*/*sharia* "path", Hindu *marga*) | yes | yes |
| Oriel | needs the subtitle | yes | the word has English-church history (oratory); some will hear the archangel **Uriel** (Abrahamic) | yes | yes |
| Alcove | yes — a quiet place to pray | **strongly** — the prayer niche exists in mosques, temples and churches; the word itself comes from Arabic | no | yes | yes |
| Pauseway | yes — functional | yes | no | yes, but secular-sounding | yes |

"Prayer Lock" itself: "prayer" works across all three (prarthana, dua/salah, prayer). For some
Muslim users "prayer" means *salah*, which this app doesn't replace. "Lock" reads as
restriction.

## 9. App Store naming strategy (all checked against the 30-character limits)

Pattern: **Brand + descriptor** in the app name; the subtitle carries the multi-faith promise;
the keyword field carries search terms (prayer, mantra, dua, bible, quran, screen time, app
blocker) — never competitors' names.

| Brand | App Store name (≤30) | Subtitle options (≤30) |
|---|---|---|
| Turnward | `Turnward: A Moment of Prayer` (28) | `Your faith, before your feed` (28) · `Prayer, mantra & dua moments` (28) |
| Waystill | `Waystill: A Moment of Prayer` (28) | `Find stillness on your way` (26) · `Prayer, mantra & dua moments` (28) |
| Oriel | `Oriel: Prayerful Screen Time` (28) | `A window of prayer each day` (27) · `Stillness before the scroll` (27) |
| Alcove | `Alcove: Prayerful Screen Time` (29) | `Stillness before the scroll` (27) · `A moment of devotion first` (26) |
| Pauseway | `Pauseway: Prayer Screen Time` (28) | `Your faith, before your feed` (28) |

Avoided on purpose: "Pray First", "Sacred Pause", "Pause & Pray", "Faith & Focus",
"Christian Focus", and anything containing "Lock".

## 10. Bundle ID strategy (proposal only — nothing changed)

```
com.<reverse-domain-you-control>.<brandslug>                      app
com.<reverse-domain-you-control>.<brandslug>.ShieldConfiguration
com.<reverse-domain-you-control>.<brandslug>.ShieldAction
com.<reverse-domain-you-control>.<brandslug>.ActivityMonitor
com.<reverse-domain-you-control>.<brandslug>.UITests
group.com.<reverse-domain-you-control>.<brandslug>                App Group
```
- The prefix should come from a domain or legal entity **you control** (not `com.prayerlock`,
  which another developer uses, and not the placeholder `unconfigured.prayerlock`).
- **Bundle IDs are permanent once an app ships; App Store names can change.** Two options:
  1. brand-based slug, decided after the brand (ties identity together);
  2. a neutral, permanent product slug under the company prefix, chosen now (unblocks App IDs
     and the entitlement request; the brand can follow later). Extension IDs must keep the
     app's ID as their prefix either way.
- The only file to change later is `Config/Identity.xcconfig` (`PL_BUNDLE_ID_PREFIX`); the
  extension suffixes and App Group already derive from it.

## 11. Recommended shortlist (for your decision — no winner chosen)

| Name | Strongest point | Biggest risk |
|---|---|---|
| **Turnward** | clean App Store/Play; .app available-looking; clear "turning toward" story | .com held by an active B2B company; conversion connotation in India needs user testing |
| **Waystill** | clean App Store/Play; .app available-looking; neutral shared "path" metaphor | meaning is subtle; .com is a newly launched outdoor-gear brand |
| **Oriel** | elegant, light/window imagery; .com is purchasable (listed for sale) | generic business name, weaker to own; Uriel association; unfamiliar word |
| **Alcove** | best multi-faith story (prayer niche in all three; Arabic-derived word) | crowded in wellbeing ("Mind Alcove", featured by Apple); every domain taken |
| **Pauseway** | clearest function | wellness name conflicts; blends into many "Pause…" blockers; least spiritual |

## 12. Risks and unresolved questions

1. **No trademark search was performed** (the USPTO API refused automated queries). Before any
   commitment, run a clearance search (US — USPTO; India — Trade Marks Registry; UK/EU —
   UKIPO/EUIPO; WIPO Global Brand Database) for the chosen name, ideally through a
   professional, focused on software/app and wellness classes.
2. App Store Connect app-name availability can only be confirmed inside a developer account
   (app record names must be unique).
3. Domain status can change at any moment; "available-looking" is not a reservation.
4. Social handles (Instagram, X, TikTok, YouTube) were not checked.
5. Hindi/Urdu/Arabic/Tamil meaning checks were done from general knowledge only; native-speaker
   review is needed for the chosen name.
6. User testing with Christian, Hindu and Muslim participants should check comprehension and
   connotation (especially Turnward's "turning").
7. The App Store seller name shows the developer account's name (individual or organization);
   it should fit the brand.

### Sources
iTunes Search API (US/IN/GB queries listed above); Google Play search pages (US);
[Mind Alcove — App Store](https://apps.apple.com/us/app/mind-alcove-ai-mental-health/id1549845703);
[Mind Alcove — Google Play](https://play.google.com/store/apps/details?id=com.mindalcove.mental.health.app);
[Alcove — Tracxn profile](https://tracxn.com/d/companies/alcove/__8FU7BVfgUEUWKngGdbn-628oMm4AvwaLSKwenEjmFRk);
[turnward.com](https://turnward.com/);
[Turnward Compass privacy (GitHub)](https://github.com/autumnwing/turnward-privacy);
[pauseway.com](https://pauseway.com/), [Pauseaway](https://pauseaway.com/about-pauseaway/);
[stillmark.com](https://www.stillmark.com/); [dawnlit.com](https://dawnlit.com/);
[inlume.app](https://www.inlume.app/); [waystill.com](https://waystill.com/);
Verisign and Google Registry RDAP; `whois`.
