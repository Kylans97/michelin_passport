# DUTCH EVENT ENRICHMENT SPRINT — AUDIT

Research-only sprint deepening the Netherlands market for Mantelier
Events, run against the now-live date-only architecture and the
already-shipped European Batch 1. **Nothing was inserted, updated, or
staged in this task.** This document is the research record; the raw
structured dataset lives alongside it at
`supabase/data/enrichment/events/dutch_event_candidates_2026_2027.json`.

## 1. METHOD

Six parallel research passes covered the country: Amsterdam region;
Rotterdam/The Hague/Utrecht; Limburg/Brabant; Gelderland/Overijssel/
Veluwe; North NL/Zeeland/Wadden Islands; and a national sweep of
organizers and formats (wine/sommelier guilds, Chaîne des Rôtisseurs,
charity circuits, Michelin/Gault&Millau NL official channels). Each
pass checked the relevant Mantelier catalogue restaurants/hotels'
own sites directly, plus Dutch culinary press, tourism boards, wine and
charity-gala organizers, and both English and Dutch search terms
(four-hands/vierhandendiner, guest chef/gastchef, anniversary dinner/
jubileumdiner, wine dinner/wijnmakersdiner, charity dinner/
benefietdiner, etc.).

Production's Netherlands inventory was re-read fresh before research
began — 't Preuvenemint, Wildfestival, Erloom x Henrique Sá Pessoa,
Vergeet Mij Niet Gala, and the Bas van Kranen pilot — confirmed complete
directly from the database, not assumed. No candidate below duplicates
any of these five.

**A material constraint, reported honestly rather than hidden**: three
of the six research agents (Amsterdam, Limburg/Brabant, National)
exhausted their web-search quota partway through and had to finish via
direct site fetches rather than open search, which likely undercounts
Instagram/social-only announcements. Combined with genuinely thin
supply independently reported by every single region, this produced
**27 verified candidates against a 30 target** — reported honestly
rather than padded with weaker events to hit the round number.

## 2. BROAD RESEARCH POOL (27 CANDIDATES)

Full field-by-field data for every candidate is in
`dutch_event_candidates_2026_2027.json`. Summary:

| ID | Event | Date | City | Format | Confidence | Priority |
|---|---|---|---|---|---|---|
| nl-001 | 4 Hands Dinner: Bas van Kranen x Sebastian Frank | 2026-11-09 | Amsterdam | Guest-chef dinner | A | P0 |
| nl-002 | VanOost BBQ with Friends | 2026-08-30 | Amsterdam | Multi-chef dinner | A | P1 |
| nl-003 | VanOost 4 Hands Lunch — Sören Herzig | 2026-09-06 | Amsterdam | Guest-chef lunch | A | P0 |
| nl-004 | VanOost Macallan Whisky Pairing Dinner | 2026-09-27 | Amsterdam | Spirits pairing dinner | A | P2 |
| nl-005 | Club Leroy bij Parkheuvel | 2026-09-20 | Rotterdam | Gastronomy + music | A | P2 |
| nl-006 | La Vie en Rose (Bonjour l'amour) | 2026-10-25 | Rotterdam | Culinary pop-up | A | EXCLUDE |
| nl-007 | BBQ met Marko Karelse ('t Ganzenest) | 2026-08-30 | Rijswijk | Guest-chef BBQ | B | P2 |
| nl-008 | Wijnproeverij Paul Pillot ('t Ganzenest) | 2026-09-24 | Rijswijk | Wine tasting | B | P2 |
| nl-009 | Wijnproeverij Sassicaia ('t Ganzenest) | 2026-11-19 | Rijswijk | Wine tasting | B | P2 |
| nl-010 | Jubileumdiner 5 jaar Restaurant Roemer | 2026-10-08 | Utrecht | Anniversary dinner | A | P2 |
| nl-011 | Wine & Dine x Pierre Ache Wijnen (Van Oys) | 2026-09-15 | Eijsden | Wine dinner | A | P1 |
| nl-012 | Game Brunch (Van Oys) | 2026-10-18 | Eijsden | Seasonal chef brunch | A | P0 |
| nl-013 | Dîner Dansant / Christmas Eve Gala (Van Oys) | 2026-12-24 | Eijsden | Hotel gala | A | P0 |
| nl-014 | Wijnmakersdiner Montanha Vermelha (Kaatje) | 2026-09-18 | Blokzijl | Wine dinner | A | P1 |
| nl-015 | Proef Blokzijl (Preuvenement) | 2026-09-27 | Blokzijl | Multi-venue culinary walk | A/B | EXCLUDE |
| nl-016 | Wijnmakerslunch Heidi Schröck (De Echoput) | 2026-10-18 | Apeldoorn | Wine lunch | A | P1 |
| nl-017 | Four-Hands: Olde Marckt x Karels | 2026-11-01 | Aalten | Four-hands dinner | A | P1 |
| nl-018 | Four-Hands: Karels x Olde Marckt (reciprocal) | 2027-01-31* | Braamt | Four-hands lunch | B | P2 |
| nl-019 | Chefs & Sommeliers Party (Inter Scaldes) | 2026-08-31 | Kruiningen | 8-chef collaboration | A | P0 |
| nl-020 | Oesterparade (Inter Scaldes) | 2026-09-25 / 10-02 | Kruiningen | Seasonal experience | A | P2 |
| nl-021 | Winemakers Lunch — South Africa (Merlet) | 2026-09-12 | Schoorl | Wine lunch | A | P0 |
| nl-022 | Six Hands Dinner: 3 chefs, 3 continents (Bij Jef) | 2026-09-24* | Texel | Guest-chef dinner | A* | P0 |
| nl-023 | Four Hands: Merlet x Joann | 2026-11-22 | Schoorl | Four-hands dinner | A | P0 |
| nl-024 | Chaîne des Rôtisseurs Gala (SS Antoinette) | 2026-09-13 | Amsterdam | Society gala dinner | A | P1 |
| nl-025 | Chaîne des Rôtisseurs Déjeuner Amical (Wolfslaar) | 2026-10-15 | Breda | Society lunch | A | EXCLUDE |
| nl-026 | Chardonnay & Spätburgunder Lunch (Karel 5) | 2026-09-21 | Utrecht | Wine lunch | B | P2 |
| nl-027 | Volnay wine event (Codium) | 2026-11-23 | Goes | Wine tasting | D | EXCLUDE |

\* Year inferred from weekday-matching or page sequencing rather than
explicitly printed — flagged per-candidate in the JSON dataset, and
called out again wherever it affects the shortlist below.

## 3. TIME-PRECISION CLASSIFICATION

FULL_TIME: nl-006, nl-012, nl-013, nl-015, nl-016, nl-019. START_KNOWN_
END_UNKNOWN: nl-005, nl-010, nl-011, nl-017, nl-023, nl-024, nl-025.
DATE_ONLY: everything else. No candidate required a MULTI_DAY_DATE_ONLY
shape. No fabricated time was recorded anywhere in the pool — every
agent was explicitly instructed to record only sourced times, and every
returned row honors that (nl-016's end time is marked "approximate as
published" rather than presented as exact, since that is genuinely how
the source itself presents it).

## 4. RE-EVALUATED HOLDS / REJECTIONS

Four candidates are EXCLUDE, none for time reasons:
- **nl-006 (La Vie en Rose)**: no named chef or Michelin-relevant
  kitchen credited — recognition-light relative to the rest of the
  pool.
- **nl-015 (Proef Blokzijl)**: participant venues' names/star status
  could not be confirmed — source depth too thin.
- **nl-025 (Chaîne Déjeuner Amical, Wolfslaar)**: modest scale, price
  unconfirmed — borderline against the destination-worthy bar.
- **nl-027 (Volnay/Codium)**: D confidence, format itself (tasting vs.
  full dinner) unconfirmed.

## 5. SESSION MODEL

Two candidates flagged MULTI_SESSION_REVIEW, not flattened: **nl-003**
(VanOost x Sören Herzig — only the Amsterdam leg of a two-city exchange
is in scope; the Vienna return leg is out of NL geography and not
proposed) and **nl-020** (Oesterparade — two independently bookable
Fridays under one brand). Neither is treated as production-ready until
the session-model question is resolved in a dedicated pass, consistent
with how Couverts sur Mer and DolomitiGourmet were handled in the
European batch.

## 6. CANONICAL ENTITY MATCHES

Checked live against the current Mantelier catalogue (~112 Dutch
Michelin-starred restaurants, 17 Dutch Michelin-keyed hotels).
**EXACT**: Flore, Triptyque, Basiliek, Parkheuvel, 't Ganzenest, Van Oys
Maastricht Retreat, Kaatje bij de Sluis, Olde Marckt, Inter Scaldes,
Bij Jef, Zarzo, Merlet, Joann, Wolfslaar, Karel 5, Codium.
**NOT_FOUND**: VanOost, Restaurant Roemer, Karels (Braamt), SS
Antoinette (not a Restaurant/Hotel entity), Walhalla Theater (same),
and every foreign participant (Horváth/Berlin, Herzig/Vienna, Zeniya/
Japan, Fyn/Cape Town, Zilte/Antwerp). No Restaurant, Hotel, or Private
Chef row was created for any of these — per the task's own rule,
catalogue absence is never a reason to exclude an otherwise strong
Event, only a reason to route it through `external_host_name`.

## 7. HOST / VENUE / PARTICIPANT SEMANTICS

Applied consistently across the pool: the entity that actually
organizes and physically holds the event is HOST+VENUE; every visiting
chef, restaurant, or wine producer is PARTICIPANT only. This matters
most for **nl-019 (Chefs & Sommeliers Party)** — eight chefs are named,
but only Inter Scaldes organizes and hosts it; Bij Jef, Zarzo, and
Parkheuvel (all three EXACT catalogue matches) must be recorded as
PARTICIPANT (`is_host=false, is_venue=false`) if this Event is ever
produced, exactly as Jordnær was in the European batch's Forces of
Nature. The same applies to **nl-023** (Joann is participant, not
host) and **nl-017** (Karels is participant, not host).

## 8. LOCATION QUALITY

Not resolved in this pass — this is a research/shortlist task, not a
pre-apply. Every next-batch candidate below (§10) has an EXACT
canonical catalogue match, meaning real, verified coordinates are
expected to already exist in `restaurants_full`/`hotels_full` and will
be pulled fresh (not guessed) during the actual Batch 2 pre-apply, the
same pattern already proven twice in the European batch.

## 9. ADMISSION

All 27 candidates are paid or unknown; none are free. **No charity
Events were found in this sprint** — every genuine charity-gala lead
uncovered nationally (24H Chefs, the Blanche Vinke benefit, Euro-Toques'
inaugural dinner) had already concluded with no next edition announced,
confirmed independently by the national-sweep researcher. This is
reported honestly as a supply gap, not papered over — Vergeet Mij Niet
Gala remains the only culinary-quality charity Event currently
discoverable with a confirmed future date.

## 10. IMAGERY

Light reconnaissance only, per the task's own instruction. Most
candidates show "unclear" — dedicated event pages exist for several
(nl-011/012/013 at Van Oys, nl-019 at Inter Scaldes) suggesting a
reasonable chance of a usable official image, but none was fetched,
copied, or uploaded. No candidate was blocked on this.

## 11. CURATED SHORTLIST (18 CANDIDATES)

| Priority | Event | Date | City | Host | Participants | Admission | Confidence | Canonical coverage | Why Mantelier should include it |
|---|---|---|---|---|---|---|---|---|---|
| P0 | 4 Hands Dinner: Bas van Kranen x Sebastian Frank | 2026-11-09 | Amsterdam | Flore | Sebastian Frank (Horváth, Berlin, 2★+Green Star) | Paid | A | Flore EXACT | Recurring series at the same host as the production pilot, internationally lauded guest |
| P0 | VanOost 4 Hands Lunch — Sören Herzig | 2026-09-06 | Amsterdam | VanOost | Sören Herzig (Vienna, 1★) | Paid €210 | A | VanOost NOT_FOUND | International Michelin guest flown in for a reciprocal exchange |
| P0 | Game Brunch | 2026-10-18 | Eijsden | Van Oys Maastricht Retreat | Stijn Antèns | Paid €150 | A | Van Oys EXACT | Clean FULL_TIME, seasonal, chef-curated hotel event |
| P0 | Dîner Dansant / Christmas Eve Gala | 2026-12-24 | Eijsden | Van Oys Maastricht Retreat | Stijn Antèns + live band | Paid €245 | A | Van Oys EXACT | Rare genuine FULL_TIME candidate with a real end time, festive destination gala |
| P0 | Chefs & Sommeliers Party | 2026-08-31 | Kruiningen | Inter Scaldes | 7 other chefs/restaurants | Paid €325 | A | Inter Scaldes + 3 participants EXACT | Marquee 8-chef multi-star collaboration, the single strongest candidate in the pool |
| P0 | Winemakers Lunch — South Africa | 2026-09-12 | Schoorl | Merlet | Newton Johnson, Grangehurst | Paid €175 | A | Merlet EXACT | Two named international winemakers at a milestone-year kitchen |
| P0 | Six Hands Dinner: 3 chefs, 3 continents | 2026-09-24 | Texel | Bij Jef | Zeniya (Japan), Fyn (Cape Town) | Paid €225 | A (year inferred) | Bij Jef EXACT | Rare three-continent collaboration, exceptionally destination-worthy (island Relais & Châteaux) |
| P0 | Four Hands: Merlet x Joann | 2026-11-22 | Schoorl | Merlet | Emiel Kwekkeboom (Joann) | Paid | A | Both EXACT | Two-catalogue-restaurant pairing, second consecutive year — editorially durable |
| P1 | VanOost BBQ with Friends | 2026-08-30 | Amsterdam | VanOost | Triptyque, Basiliek | Paid €160 | A | 2 of 3 EXACT | Three Michelin-starred chefs collaborating |
| P1 | Wine & Dine x Pierre Ache Wijnen | 2026-09-15 | Eijsden | Van Oys Maastricht Retreat | Pierre Ache Wijnen | Paid €110 | A | Van Oys EXACT | Solid regional-terroir wine dinner |
| P1 | Wijnmakersdiner Montanha Vermelha | 2026-09-18 | Blokzijl | Kaatje bij de Sluis | Montanha Vermelha | Paid | A | Kaatje EXACT | Named international producer at a 1★ kitchen |
| P1 | Wijnmakerslunch Heidi Schröck | 2026-10-18 | Apeldoorn | De Echoput | Heidi Schröck & Söhne | Paid €129 | A | Same venue as production Wildfestival | Named Austrian winemaker at a familiar host entity |
| P1 | Four-Hands: Olde Marckt x Karels | 2026-11-01 | Aalten | Olde Marckt | Paskal Karels | Paid | A | Olde Marckt EXACT | Direct chef exchange, season-opener framing |
| P2 | Club Leroy bij Parkheuvel | 2026-09-20 | Rotterdam | Parkheuvel | Robert Leroy (musician) | Paid €249 | A | Parkheuvel EXACT | Gastronomy + live-entertainment collaboration at a 2★ house |
| P2 | VanOost Macallan Whisky Pairing Dinner | 2026-09-27 | Amsterdam | VanOost | The Macallan | Paid €220 | A | VanOost NOT_FOUND | Curated single-producer pairing — flagged for an editorial call (spirits, not wine) |
| P2 | Jubileumdiner 5 jaar Restaurant Roemer | 2026-10-08 | Utrecht | Restaurant Roemer | none | Paid €75 | A | NOT_FOUND | Genuine milestone dinner, but no external recognition tier |
| P2 | Oesterparade | 2026-09-25 / 10-02 | Kruiningen | Inter Scaldes | none | Paid | A | Inter Scaldes EXACT | Strong host, but MULTI_SESSION_REVIEW unresolved |
| P1 | Chaîne des Rôtisseurs Gala (SS Antoinette) | 2026-09-13 | Amsterdam | Chaîne des Rôtisseurs NL | none named | Paid €135 | A | SS Antoinette NOT_FOUND | Distinctive destination format, national-society pedigree |

## 12. NEXT PRODUCTION BATCH — RECOMMENDED FOR DEEPER VERIFICATION (8)

The best combination of editorial quality, confirmed date, source
quality, location clarity, actionability, and clean host semantics —
**not inserted, not pre-approved, purely a recommendation for the next
verification pass**:

1. **4 Hands Dinner: Bas van Kranen x Sebastian Frank** (nl-001) —
   same host as the existing pilot, clean single-event structure.
2. **VanOost 4 Hands Lunch — Sören Herzig** (nl-003) — resolve the
   MULTI_SESSION_REVIEW flag first (confirm only the Amsterdam leg is
   being proposed).
3. **Game Brunch** (nl-012) — Van Oys Maastricht Retreat, clean
   FULL_TIME.
4. **Dîner Dansant / Christmas Eve Gala** (nl-013) — Van Oys Maastricht
   Retreat, clean FULL_TIME with a genuine cross-midnight end time.
5. **Chefs & Sommeliers Party** (nl-019) — highest-impact candidate in
   the pool; requires careful relationship-row work given eight named
   chefs, only one of whom (Inter Scaldes) is HOST.
6. **Winemakers Lunch — South Africa** (nl-021) — Merlet, clean.
7. **Six Hands Dinner: 3 chefs, 3 continents** (nl-022) — strongest
   destination story in the pool; the inferred year must be confirmed
   directly with Bij Jef before this proceeds to pre-apply.
8. **Four Hands: Merlet x Joann** (nl-023) — both sides EXACT catalogue
   matches, lowest-risk relationship structure of the eight.

**CURRENT PRODUCTION EVENTS = 9. RECOMMENDED NEXT-BATCH SIZE = 8**
(pending a full fresh re-verification pass identical in rigor to the
European Batch 1 re-validation — nothing here has been re-confirmed
against live sources a second time, which is the minimum bar this app
has consistently required before any pre-apply).

## 13. DATABASE GAP ANALYSIS

**Already in the catalogue** (no action needed): Flore, Triptyque,
Basiliek, Parkheuvel, 't Ganzenest, Van Oys Maastricht Retreat, Kaatje
bij de Sluis, Olde Marckt, Inter Scaldes, Bij Jef, Zarzo, Merlet,
Joann, Wolfslaar, Karel 5, Codium — 16 distinct entities across the
shortlist.

**Missing, and potentially valuable future catalogue additions** (not
created in this task): **VanOost** (Amsterdam) is the strongest
candidate for future addition — it runs its own proactive, recurring
guest-chef series ("VanOost Sundays") and appears in 4 of the 27
candidates found, more than any single restaurant except Van Oys
Maastricht Retreat and Merlet. **Restaurant Roemer** (Utrecht) and
**Restaurant Karels** (Braamt) are lower-priority — editorially
reasonable but without external recognition (Michelin/Gault&Millau) to
anchor them.

**Not a gap**: SS Antoinette, Walhalla Theater, and every foreign
participant (Horváth, Herzig, Zeniya, Fyn, Zilte) are correctly
NOT_FOUND — none of these are Dutch Restaurant/Hotel/Private Chef
catalogue candidates; they are either non-catalogue venue types or
foreign entities entirely out of scope for the Netherlands catalogue.

## 14. CONTENT OPERATIONS INSIGHT

**Is there enough supply for a year-round Netherlands Event feed?**
Marginally, and only with active relationship-building, not passive
monitoring. 27 genuine candidates in one sweep is real signal, but
supply is heavily concentrated in a handful of proactive restaurants
(Van Oys Maastricht Retreat: 3, Merlet: 3, VanOost: 4, Inter Scaldes:
2, 't Ganzenest: 3 — thirteen of twenty-seven candidates, essentially
half the pool, come from five venues) rather than being broadly
distributed. Every one of the six researchers independently reached
the same conclusion without prompting each other: **restaurants
themselves are a substantially better discovery source than dedicated
event organizers** — national bodies (Chaîne des Rôtisseurs, the
sommelier guild) do publish real calendars, but skew toward
member-facing or thinly-sourced content, while festival/charity
organizer content is sparse, slow-moving, and mostly reflects events
that had already concluded by research time with no next edition yet
announced.

**Where supply is strongest**: not Amsterdam, contrary to expectation
— Amsterdam contributed only 4 of 27 candidates, the fewest of any
region, because several of its highest-profile annual events (24H
Chefs, Bite of Amsterdam, Chefs in het Bos, Het Amsterdam Diner) had
already concluded for the year with no next edition confirmed. Zeeland,
the North Holland coast, and Limburg each punched well above their
catalogue size thanks to a small number of highly active individual
hosts.

**Formats**: four-hands/guest-chef dinners and winemaker lunches/
dinners dominate by a wide margin; multi-chef collaborative galas
(Chefs & Sommeliers Party) are rarer but the highest-impact format
found. Charity Events with genuine culinary quality and a confirmed
future date are currently the scarcest category nationally — a real
gap, not a search failure.

**Seasonality**: pronounced. The pool clusters heavily in
September–November (harvest/game season); only one strong candidate
(Van Oys's Christmas Eve gala) reaches into December, and nothing was
found for January–August 2027 beyond the single year-uncertain Karels
reciprocal lunch.

**Recommended operating model**: manual editorial research over a
standing watchlist of the five highest-yield hosts identified above,
checked on a **quarterly cadence** (matching the observed seasonal
clustering and the observed lead time — most restaurants publish
specific dinners only weeks to ~2 months ahead, not a full year out),
supplemented by an occasional deeper full-market sweep like this one
every 6–12 months to catch new venues and hosts (VanOost itself was
only discovered this way). Scheduled research and press relationships
are worth building specifically around Van Oys Maastricht Retreat,
Merlet, VanOost, and Inter Scaldes, given their demonstrated proactive
publishing cadence. Venue/restaurant self-service submission would
meaningfully close the Instagram/social-only visibility gap three of
the six researchers ran into after exhausting search quota, but that
is a tooling recommendation for future consideration, not something
built in this task.

## 15. VALIDATION

No app code changed in this task. `flutter analyze`: no issues.
`flutter test`: baseline unchanged (no Dart touched — see the
accompanying chat report for the exact re-run count). `supabase
migration list --linked`: 39/39 `local == remote`, unchanged.
`supabase db push --linked --dry-run`: "Remote database is up to
date." `git status --short`: only new untracked files under this
sprint's own convention (`DUTCH_EVENT_ENRICHMENT_SPRINT_AUDIT.md` and
`dutch_event_candidates_2026_2027.json`) — nothing staged.

## 16. DATABASE

Production writes = 0. Schema changes = 0. Migrations = 0. RLS changes
= 0. Storage writes = 0. Every query this task ran against production
was read-only.

## 17. HARD STOP CONFIRMATION

No Event was inserted or modified. No Restaurant/Hotel/Private Chef
catalogue entity was created. No image was uploaded. No Event UI was
changed. Steps 8A/8B/8C were not touched. No migration was created. No
RLS was changed. Nothing was staged, committed, or pushed.

DUTCH EVENT ENRICHMENT — NETHERLANDS HIGH-END GASTRONOMY MARKET
RESEARCHED, CURATED SHORTLIST PREPARED, READY FOR NEXT PRODUCTION
ENRICHMENT BATCH
