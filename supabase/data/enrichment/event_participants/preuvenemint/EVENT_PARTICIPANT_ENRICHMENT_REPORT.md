# Preuvenemint Event Participant Enrichment — Pilot Report

Status: research complete, evidence documented, and the one approved EXACT_MATCH (Tout a Fait) is **APPLIED and VERIFIED in production** — see §13 for the full application/verification record. Noon, Le Philippe, and Enigma remain `NO_MATCH`, unlinked, and uncreated — deferred catalogue-expansion candidates. §1–§12 below are the original pre-application research and are preserved unmodified. Git-wise, this artifact itself (and the rest of the Events UI workstream it accompanies) is still uncommitted, pending final workstream sign-off.

---

## 1. Event record (production, read-only)

| Field | Value |
|---|---|
| event_id | `75d341a4-41d9-4e76-b47c-936048ae54a4` |
| name | `'t Preuvenemint` |
| city | Maastricht |
| country | NL |
| venue_name | Vrijthof |
| start_at | 2026-08-27 16:00 UTC |
| end_at | 2026-08-30 22:00 UTC |
| official_url | https://preuvenemint.nl/en |
| ticket_url | https://shop.celebratix.io/?c=2ghv4 |
| status | upcoming |
| current event_restaurants count | 0 |
| current event_hotels count | 0 |

**Exactly one Preuvenemint event row exists in production** — confirmed via `name ilike '%preuvenemint%' or name ilike '%preuvenement%'`, which returned this single row. No STOP condition was triggered.

## 2. Restaurant catalogue audit (production, read-only)

- Total restaurants: **1,362**
- Netherlands: **120**
- Maastricht: **5** (the catalogue is a curated Michelin/recognition-focused list, not a general restaurant directory — every Maastricht row present has `inclusion_reason = 'michelin_star'`)
- Canonical matching fields available on `restaurants_full`: `name`, `restaurant_code`, `city_name`, `country_code`, `address`, `website_url`, `michelin_url`, `latitude`/`longitude`, `google_place_id`, `status`.

The 5 Maastricht restaurants (all 1 Michelin star): Au Coin des Bons Enfants (rest_0011), Beluga loves you (rest_0012), Chateau Neercanne (rest_0022), Studio (rest_0101), Tout a Fait (rest_0109).

## 3. Source research

**Official pages found (Tier 1):**
- https://preuvenemint.nl/en — event overview, dates
- https://preuvenemint.nl/en/deelnemers-en-gerechten — the full 2026 participant roster (20 names, primary source for this pilot)
- https://preuvenemint.nl/deelnemers/tout-a-fait-2 — Tout à Fait's own participant page (used for the one exact match's direct evidence)
- https://preuvenemint.nl/en/plattegrond — interactive site map (partially JS-rendered; a static fetch surfaced only 4 of the 20 names, all already covered by the main participants page, so it was not needed as a primary source)

**Programme/PDF sources:** none found or needed — the official site's participant page was complete and sufficient (confirmed no pagination/"load more" beyond the 20 listed names).

**Tier 2 (used for cross-validation only, never as a standalone source for a match):**
- https://www.chapeaumagazine.com/gastronomie/nieuwe-namen-preuvenemint-2026/ — an editorial food-magazine article explicitly about the *2026* edition's new/returning names, used to (a) confirm the official page's roster is current-edition and complete, (b) resolve one combined-stand pairing (De Oesterbazen & Les Trois Seaux), and (c) corroborate Tout à Fait's 25-consecutive-year participation.
- Independent web searches confirming Noon, Le Philippe, and Enigma are real, currently-operating Maastricht restaurants (used only to classify participant_type, never to attempt a match — none of the three exist in the production catalogue).

**Source quality:** every participant in the raw dataset traces to the official event site; every restaurant-type participant not already matched was independently verified as a real business before being recorded as `restaurant`/`NO_MATCH` rather than left unclassified.

**Current-edition confirmation:** the participants page and Tout à Fait's own page reference the 2026 dates (27–30 August 2026) matching the production event row exactly; the Chapeau Magazine article is explicitly titled/dated for the 2026 edition and explicitly separates "new," "returning," and "not returning" participants — confirming no prior-edition participant was mixed in.

## 4. Participants

- **Total raw participants (official 2026 roster):** 20
- **Restaurant candidates** (participant_type = `restaurant`): 4 — Tout à Fait, Noon, Le Philippe, Enigma
- **Non-restaurant participants:** 16 — 2 bars (The Mestreechter Brandslang, Bali Bar; Royal Steaks & Cocktails also classified as bar/temporary concept), 5 producer/vendor (Coffeelovers, Sauter Wijnen, De Oesterbazen & Les Trois Seaux, Thiessen Wijnkoopers, Goessens Professionals in Wine & WY., IJsbaas — six, see full list in `participant_source.csv`), 3 caterers (2 Taste, Friet Elite, Bufkes), 1 organization (Amphitryon), 1 specialty shop ('t Rommedoeke), 2 sponsors (Aperol, FIER by Bidfood).
- **Ambiguous candidates:** 0 requiring `MANUAL_REVIEW` — every restaurant-type candidate resolved cleanly (see §5). One non-restaurant candidate (`2 Taste`) has an unconfirmed exact business identity, documented as a note in `participant_source.csv` rather than as an ambiguous restaurant match, since it was never a restaurant-eligible candidate to begin with.

## 5. Matching

| Classification | Count |
|---|---|
| EXACT_MATCH | 1 |
| PROBABLE_MATCH | 0 |
| MANUAL_REVIEW | 0 |
| NO_MATCH (restaurant-type) | 3 |
| NOT_A_RESTAURANT | 16 |

Zero `PROBABLE_MATCH`/`MANUAL_REVIEW` rows is a genuine result, not an oversight: each of the 4 restaurant-type candidates independently resolved to either a confident exact match (Tout à Fait — name, city, chef, and Michelin-URL slug all agree) or a confident no-match backed by independent confirmation that the business is real but simply absent from the current catalogue (Noon, Le Philippe, Enigma). No case presented conflicting evidence.

## 6. Exact matches

| Event display name | Production name | restaurant_code | City | Michelin stars (production) | Source |
|---|---|---|---|---|---|
| Tout à Fait | Tout a Fait | rest_0109 | Maastricht | 1 | https://preuvenemint.nl/deelnemers/tout-a-fait-2 |

**Match evidence:** name matches exactly once the one diacritic difference (à → a) is normalized; city matches (Maastricht); chef-patron name "Bart Ausems" matches between the official event page and independent research; production's `michelin_url` slug (`tout-a-fait`) matches the restaurant name; production's stored address (St. Servaasklooster 13, Maastricht) is consistent with the event source's location description ("in hartje Maastricht," "op het Vrijthof"). The event source's own Michelin mention ("Al jaren bekroond met een Michelinster") and Chapeau Magazine's "25th consecutive year" detail were used only to corroborate that this is a genuine, long-standing participant — **never as the source of the star count itself**, which is read from production only (§10 of the task).

Full evidence record: `exact_matches.csv`.

## 7. MICHELIN AT THIS EVENT — preview

From the 1 `EXACT_MATCH`:

- Total matched restaurant participants: 1
- Michelin-starred matches: 1
- 1★: 1
- 2★: 0
- 3★: 0
- Non-starred matched restaurants: 0 (not applicable — the catalogue only contains starred restaurants for Maastricht)

**Exact preview of what Event Detail's "MICHELIN AT THIS EVENT" section would show if this link were applied:**

```
MICHELIN AT THIS EVENT

Tout a Fait                    ★
```

No other rows — this is not a fabrication, it is the literal, complete output of `michelinStarredParticipants()` given exactly one linked, currently-starred restaurant.

## 8. Review items

- **Manual-review candidates:** none (see §5 for why).
- **Probable matches:** none.
- **Missing production restaurants (real restaurants, no catalogue entry):** Noon (Griend 7, Wyck, Maastricht — a well-regarded gastrobar, not currently Michelin-recognized), Le Philippe (Havenstraat 19, Maastricht — chef Danny Vanderhoven, newly opened this year, not currently Michelin-recognized in this location), Enigma (Sint Bernardusstraat 20, Maastricht — Gault&Millau 13.5/20, opened March 2024, not currently Michelin-recognized). These are recorded in `participant_matches.csv` as `NO_MATCH` with full evidence — **no new restaurant rows were created**; this is input for a future, separate catalogue-expansion decision, not this task.
- **Exact unresolved questions:** whether "2 Taste" is a standalone catering business distinct from the unrelated "Taste2day" found in search (documented as a note, not a restaurant-eligible ambiguity — it was never classified as `restaurant` type, so this doesn't block or affect any linking decision).

## 9. Prepared linking

- **SQL artifact filename:** `link_event_restaurants.sql`
- **Insert count:** 1 row
- **Duplicate protection:** `on conflict (event_id, restaurant_id) do nothing`, matching `event_restaurants`' own `unique(event_id, restaurant_id)` constraint — safe to re-run.
- **Confirmation SQL not applied:** confirmed — no `supabase db push`/`db query --linked` write call was made against `event_restaurants` at any point in this task; the table's row count for this event remains 0 in production (re-verified after building the artifacts, immediately before writing this report).

## 10. Data quality

- **Duplicate validation:** `participant_source.csv` — 20 rows, 20 unique `participant_display_name` values (verified programmatically). `exact_matches.csv` — 1 row, 1 unique `(event_id, restaurant_id)` pair.
- **FK validation:** both `event_id` (`75d341a4-41d9-4e76-b47c-936048ae54a4`) and `restaurant_id` (`8edbcee4-8120-4de2-9bf2-6f47a74d48ac`) re-confirmed to exist live in production via a direct join query immediately before finalizing this report; the restaurant's `status` is `open` (not withdrawn/closed).
- **Source-evidence coverage:** the one exact match has a direct official-source URL, verbatim evidence text, explicit match reasoning, and a `verified_at` date in `exact_matches.csv` — no invisible linking.
- **Correction made during validation:** an initial transcription of the production restaurant query mismatched a UUID — the id used in the first draft of `participant_matches.csv`/`exact_matches.csv`/`link_event_restaurants.sql` for "Tout a Fait" was actually **Au Coin des Bons Enfants**'s id (`9dafc6f2-b26d-4d8e-b5c0-0c8682768dda`), a copy error made while transcribing two adjacent JSON rows from the same query result. This was caught during the mandatory validation pass (§23 of the task) by re-querying the recorded id and finding its `name` didn't match, then corrected to the true id (`8edbcee4-8120-4de2-9bf2-6f47a74d48ac`) across all three files and re-validated via a fresh join query confirming both the name and the event/restaurant pair now agree. No incorrect id was ever applied to production — this was caught entirely within the preparation stage.

## 11. Safety

- No restaurant writes: confirmed — every restaurant query this task ran was read-only (`select`).
- No event writes: confirmed.
- No Michelin writes: confirmed — `michelin_stars`/`michelin_url` were only read, never modified; no award was inferred from the event website.
- No award_history writes: confirmed — that table was not touched or queried.
- No hotel writes: confirmed — `event_hotels`/`hotels_full` were not touched.
- No attendance writes: confirmed — `event_attendance` was not touched.
- No Flutter changes: confirmed — no `lib/`/`test/` file was modified.
- No migrations: confirmed — no file was added to `supabase/migrations/`.
- Nothing staged: confirmed (`git diff --cached` empty).
- Nothing committed: confirmed.
- Nothing pushed: confirmed.

## 12. Reusability

**What can be automated:** fetching the official participant-roster page and diffing it against the previous pilot's `participant_source.csv` (to surface only new/changed names each edition); normalized-name pre-matching against the country/city-scoped slice of the production catalogue (a `city_name ilike` + Levenshtein-style pre-filter would narrow candidates quickly, as it effectively did here by hand); the FK/duplicate/status validation pass in §10 is fully mechanical and should always run before any SQL artifact is finalized — this pilot's own caught transcription error is the concrete argument for never skipping it.

**What should remain human-reviewed:** every `EXACT_MATCH` before it's applied to production (this pilot's own one-line mistake, caught only because a validation pass existed, is the reason); anything landing in `PROBABLE_MATCH`/`MANUAL_REVIEW` by construction; any case where a participant's own description implies a business type (restaurant vs. caterer vs. sponsor activation) that isn't unambiguous from the name alone — this pilot needed real judgment for `2 Taste`, `Royal Steaks & Cocktails`, and the shared `De Oesterbazen & Les Trois Seaux` stand, and a fully automated pass would likely misclassify at least one of these.

**What evidence should always be retained:** the exact official source URL and verbatim quoted text per participant (not a paraphrase), the match reasoning in plain language (not just a similarity score), and an explicit `verified_at`/`reviewer_status` field so a future audit can tell whether a link was ever actually reviewed by a person or is still `pending_human_review` (as this pilot's one candidate currently is).

**Recommendation:** do not build a generalized crawler yet. This pilot needed exactly two fetches of the official site, one Tier-2 cross-check, and three targeted verification searches — a fixed, repeatable checklist (per new edition: re-fetch the participants page, diff against last time, re-run the same 4-classification matching pass) is sufficient at this scale and preserves the human-review points above. A generalized system would only be justified if this pilot process is repeated across many more events with materially larger participant rosters.

---

## 13. Applied status (added post-approval — original research above is unmodified)

Following user approval (`CHASING STARS — PREUVENEMINT PARTICIPANT APPLY + EVENT ENRICHMENT STANDARD`), the Tout à Fait / Tout a Fait link was applied to production on 2026-08-16, following the full re-resolve → re-verify → duplicate-check → write → post-write-verify sequence now codified in `docs/Architecture/EVENT_PARTICIPANT_ENRICHMENT_STANDARD.md`.

- **Relationship status:** `APPLIED / VERIFIED`
- **event_restaurants row id:** `bb66395c-e9f4-4870-b4ce-82c8cc9debf9`
- **Freshly re-resolved event_id (independent of this report/CSVs):** `75d341a4-41d9-4e76-b47c-936048ae54a4` — matched §1 exactly.
- **Freshly re-resolved restaurant_id (via `restaurant_code = rest_0109`, independent of this report/CSVs):** `8edbcee4-8120-4de2-9bf2-6f47a74d48ac` — matched `exact_matches.csv` exactly (both were independently correct; see `docs/Architecture/EVENT_PARTICIPANT_ENRICHMENT_STANDARD.md` §8 for why this was re-derived rather than copied).
- **Post-write verification:** exactly 1 row in `event_restaurants` for this event; JOIN resolves to Tout a Fait / rest_0109 / Maastricht / 1 star / status open; verified through both a direct query mirroring `EventsRepository.loadLinkedVenues`'s exact shape and the live PostgREST REST endpoint (anon key).
- **Full applied-status detail:** `applied_status.csv`.
- **Noon / Le Philippe / Enigma:** remain `NO_MATCH`, unlinked, **not created** — recorded as catalogue-expansion candidates per the newly established standard's §11, not acted on further by this task.

No content in §1–§12 above was altered — this section is additive only, preserving the original research as it stood before production application.

---

PREUVENEMINT EVENT PARTICIPANT ENRICHMENT — APPLIED AND VERIFIED FOR TOUT A FAIT; NOON/LE PHILIPPE/ENIGMA REMAIN DEFERRED CATALOGUE-EXPANSION CANDIDATES
