# Changelog

Mantelier — documentation changes.

Two passes are recorded. **Pass 1** implemented `ENGINEERING_REVIEW.md`; **Pass 2** implemented the accepted findings of `MAINTAINABILITY_AUDIT.md`. No schema was redesigned in either. One constraint was widened in Pass 1; Pass 2 changed no schema at all.

---

# 2026-10-28 — QA follow-ups applied: Kjolle, Plaza Athénée, Monaco, Peru hotel phones (QA-222, QA-224, QA-227, QA-230)

| | |
|---|---|
| Applied | 2026-10-28, to production, following `supabase/data/enrichment/APPLY_QA_2026-10-28.md` |
| Migrations | None. Ledger unchanged at 102 |
| Data files | Four prepared files, each one transaction with its own guards; none aborted |

All four files' guards were checked read-only against production before anything was written. Afterwards each effect was re-read from production.

**Kjolle** (`kjolle_location/prepared_kjolle_location.sql`, **QA-227**). `rest_0135`'s point moves from the rounded (-12.145, -77.0211), 856 m away, to (-12.1525709, -77.0225397). That is its building, Av. Pedro de Osma 301 in Barranco: OSM node 6228532187, the point Central (`rest_1578`) already uses. Its `google_place_id` is unchanged and still unchecked, since there is no Places API key.

**Plaza Athénée** (`michelin_fr_stars_2026/prepared_plaza_athenee_rename.sql`, **QA-222**). The product owner decided this is a rename, not a closure. `rest_0972` "Jean Imbert au Plaza Athénée" becomes "La Grande Table du Plaza Athénée", and `michelin_url` moves to MICHELIN's current page. Its one star, its single current star row and its link to `hotel_713` are unchanged, as re-checked.

**Monaco** (`michelin_mc_2026/prepared_mc_stars_2026.sql`, **QA-224**). The product owner brought Monaco into scope.
- **Restaurants:** 9 added, `rest_1579`–`rest_1587`, from MICHELIN's 2026 selection, with `inclusion_reason` `michelin_star`. MICHELIN's live Monaco listing ("1-9 of 9") and each restaurant page agree on **1 / 3 / 5**.
- **Star rows:** each restaurant has exactly one current 2026 star row agreeing with `michelin_stars`, as re-checked.
- **City:** all nine use the existing MC city "Monte Carlo"; no city was added. All nine appear in `restaurants_full`.
- **Hotel links:** three `exact` links where MICHELIN's address names the Key hotel. Le Louis XV and Le Grill link to the Hôtel de Paris (`hotel_193`), and Les Ambassadeurs to the Métropole (`hotel_194`).
- **Phones:** 7 of 9 are confirmed on the restaurant's own site. Le Louis XV and Robuchon Monaco stay empty.
- **Elsa** (`rest_1583`) is at Monte-Carlo Beach, which is in Roquebrune-Cap-Martin, France. MICHELIN files it under Monaco, so it is stored as MC. Logged with the two empty phones as **QA-231**, which stays open.

**Peru hotel phones** (`michelin_pe_2026/prepared_pe_hotel_phones.sql`, **QA-230**). The product owner's rule: the hotel's own local line, otherwise the group line its own site shows. Only empty values were filled.
- **Own local line:** Las Casitas, Monasterio, Miraflores Park and Rio Sagrado.
- **Andean group line:** Titilaka, CIRQA, Atemporal and Fausto.
- **Inkaterra group line:** Inkaterra Hacienda Urubamba and La Casona.
- **Still empty:** Antigua Casona San Blas (`hotel_815`) and Tambo del Inka (`hotel_817`). Neither has an own site that could be reached.

The 15 Peruvian Key hotels now hold 13 phones.

---

# 2026-10-28 — Catalogue data applied: MICHELIN France 2026 and Peru (QA-220–QA-225)

| | |
|---|---|
| Applied | 2026-10-28, to production, following `supabase/data/enrichment/APPLY_FR_PE_2026.md` |
| Migrations | `20261019120000_add_fr_2026_star_cities` (82 FR cities), `20261019130000_add_pe_key_hotel_cities` (5 PE cities). Ledger 100 → 102, local and remote in agreement |
| Data files | Three prepared files, each one transaction with its own guards, run in the guide's order; none aborted |

Before anything was written, every pre-write check in the three files was rerun read-only against production with the files' own data, and all passed (recorded in the apply guide). Each file's effect was then measured as before/after counts against production.

**Cities.** FR 329 → 411, PE 2 → 7. Peru's new rows follow MICHELIN's destinations, so "Arequipa" and "City of Arequipa" are separate cities.

**MICHELIN France 2026** (`michelin_fr_stars_2026/prepared_fr_stars_2026.sql`). Source: MICHELIN's 2026 full list (16 March 2026) and the live listing, matched one-to-one.

- No relabel: the August import already held the 2026 edition.
- **QA-220:** 14 star counts corrected in place, each old value asserted first. Spot check: Maison Lameloise, Le Coquillage and L'Oustau de Baumanière are now three-star; Le Suquet is one-star.
- **QA-223:** 410 `michelin_url` values set to MICHELIN's canonical page.
- 173 restaurants added, `rest_1405`–`rest_1577`, each with a current 2026 star row; 148 of them with a confirmed phone.
- The file's closing checks passed, and were re-checked afterwards: exactly **652** starred, **30 / 80 / 542**. Every starred FR restaurant has exactly one current star row agreeing with `michelin_stars`, none lacks a city, and all 652 appear in `restaurants_full`.
- Not changed, logged: **QA-221** (13 withdrawn since March; the six in production keep their 2026 stars), **QA-222** (`rest_0972` rename waits for a decision), **QA-224** (Monaco out of scope).

**France phones** (`prepared_fr_phone_backfill.sql`): 385 existing restaurants, filling only empty values. FR restaurants with a phone: 151 → 536 (148 of the 151 came from the stars file). **QA-225:** numbers left empty on purpose, with the reason per row.

**Peru** (`michelin_pe_2026/prepared_pe_keys_and_w50b.sql`):

- 14 MICHELIN Key hotels added, `hotel_804`–`hotel_817`. Peru now has 15 Key hotels: **1 three-Key, 4 two-Key, 10 one-Key**, each with exactly one current Key row (guide year 2026) agreeing with the hotel row.
- Palacio Nazarenas (`hotel_745`): its missing Key row added, and `michelin_url` moved to MICHELIN's current page.
- Central added as `rest_1578` (`hall_of_fame`), with 11 World's 50 Best rows: ten ranked years (2013–2023, no 2020 list) and its 2024 hall-of-fame row. Hall-of-fame rows: 6 → 7.
- Mil (`rest_1381`): its 2024 rank added (No. 73).
- Phones: two new hotels (Hotel B, explora Valle Sagrado). The rest stay empty under the confirmed-on-own-site rule; the three Belmond hotels wait for a decision on using their own local line.

Not done here: Google Place IDs for the 173 French restaurants and 14 Peruvian hotels (no Places API key), and the `qa_issues.csv` statuses of QA-220–QA-225, which are unchanged.

---

# 2026-10-28 — Country timezones applied (QA-226)

| | |
|---|---|
| Status | **Applied** 2026-10-28, to production (ledger 98 → 100 with `20261018130000`, local and remote in agreement) |
| Migration | `20261018120000_add_country_timezones` |
| Source | IANA time zone database, tzdata 2025b, `zone.tab`, read from `/usr/share/zoneinfo/zone.tab` on 2026-10-28 |
| Reason | Venue events (phase 3) need a timezone for every event, but no venue and no country stored one. |

**What it adds.** `countries.timezones text[]`, holding every zone `zone.tab` lists for each of the 58 countries in `public.countries`. The values were generated from the file, not typed.

- 44 countries have one zone. The event form uses it as the default.
- 14 have several: AR, AU, BR, CL, CN, DE, EC, ES, ID, MX, MY, NZ, PT and US. The form asks for these instead of assuming one. Spain, for example, lists Europe/Madrid, Africa/Ceuta and Atlantic/Canary.
- France has only Europe/Paris, because IANA gives its overseas regions their own country codes.

**Checks.**

- All 149 distinct zones exist in production's `pg_timezone_names` (read-only, 2026-10-28). The migration also refuses, by itself, any zone its Postgres doesn't know.
- Verified on a full local replay from empty: every country got its zones, and the column became NOT NULL with at least one entry.
- Any later migration that adds a country must give it its zones.

The venue event RPCs (`20261018130000`) refuse a timezone that isn't in the event country's list.

**After applying** (read-only):

- All 58 countries have zones: 44 with one, 14 with several.
- The zones are identical to a fresh local replay's (one md5 over every country's list).

Not done here: QA-226's status in `qa_issues.csv` is still Open.

---

# 2026-10-28 — Catalogue data applied: MICHELIN Netherlands 2026, World's 50 Best completion, phones, Place IDs (QA-209, QA-216, QA-218)

| | |
|---|---|
| Applied | 2026-10-28, to production, following `supabase/data/enrichment/APPLY_2026-10-28.md` |
| Migrations | `20261016120000_add_worlds_50_best_countries_and_cities`, `20261016130000_add_hotel_phone`, `20261016140000_add_nl_2026_star_cities` — ledger 94 → 97, local and remote in agreement |
| Data files | Seven prepared files, each one transaction with its own guards, run in the guide's order; none aborted |

Each file's effect was measured as before/after counts against production, not taken from the file's own description.

**Reference data.** 3 countries (EC, PA, VN) and 16 cities for the World's 50 Best venues; 5 NL cities (Mierlo, Veeningen, Kortgene, Schin op Geul, Hoog Soeren) for the new Dutch stars. `hotels.phone` added (nullable text, no format constraint), appended to `hotels_full`; the view's grants are unchanged.

**World's 50 Best completion** (`worlds_50_best_2025_2026/prepared_w50b_new_venues_import.sql`). 26 restaurants and 22 hotels added, with 49 ranking rows (26 restaurant, 23 hotel) and 32 `award_history` rows. The ranked lists are now complete: restaurants 2025 at 99, hotels 2025 and 2026 at 100 each. Scope per the same day's 1–100 rule (entry below).

**MICHELIN Netherlands 2026** (`michelin_nl_stars_2026/prepared_nl_stars_2026.sql`), the first application of the QA-217 rule:

- The NL launch rows were relabelled `guide_year` 2026 → 2025 with values unchanged: 118 rows. The file checked first that exactly 120 Dutch 2026 star rows existed and no 2025 ones did.
- 8 restaurants lost their star: their 2025 row became non-current, a 2026 row with `award_value` NULL was written as current, and `michelin_stars` was set to NULL.
- **QA-216:** Graphite by Peter Gast (`rest_0781`) and Zheng (`rest_0782`) appear in neither MICHELIN's 2025 nor 2026 full list. Their 2026 row is now NULL and current, and `michelin_stars` NULL. Before this, Zheng's `michelin_stars` was already NULL with no row recording why, and Graphite still showed one star.
- 18 MICHELIN URLs updated.
- 9 new starred restaurants, `rest_1396`–`rest_1404`, each with a 2026 star row.
- The file's closing checks passed: exactly **1 / 20 / 98** starred (119), and every NL restaurant has exactly one current star row, agreeing with `michelin_stars`. Spot check: De Librije's history reads 1993:1, 1999:2, 2004:3, 2025:3.

**QA-218**, new restaurants left incomplete on purpose: SUIS (`rest_1403`) has its phone left NULL, because its own site and MICHELIN disagree between a Belgian and a Dutch mobile; MICHELIN's postcode 6305 AH is kept. Rozewied (`rest_1402`) stays at Hoofdstraat 35 until it moves in March/April 2027. Both remain open.

**Phones.**

| File | Rows filled |
|---|---|
| `worlds_50_best_2025_2026/prepared_w50b_phone_backfill.sql` | 69 restaurants, 82 hotels |
| `michelin_nl_phones/prepared_nl_phone_backfill.sql` | 100 restaurants |
| `michelin_be_lu_phones/prepared_be_lu_phone_backfill.sql` | 115 restaurants |

The BE/LU file lists 117 numbers but only fills empty fields; 2 of its restaurants already held the identical number from the W50B file run just before. Checked afterwards: all 117 now carry exactly the file's number. The 15 BE/LU restaurants left out stay open under QA-215. Totals after all files: 318 restaurants and 103 hotels with a phone (before: 1 and 0).

**Place IDs** (`place_id_backfill/`). The main file: 74 hotels (73 plus Singita – Kruger National Park, which only exists after the W50B import) and 14 NL restaurants. The nine new NL restaurants: 9 more. Totals: 914 restaurants, 787 hotels. No duplicate Place ID within either table, and no duplicate code.

**QA-209**, Amangalla (`hotel_748`, Galle): the coordinates moved from (6.03306, 80.21667), a wine shop outside the fort, to (6.02861, 80.21700) — OpenStreetMap's building outline at 10 Church Street, within Galle Fort's ramparts, agreeing with Google's pin.

Not done here: the `qa_issues.csv` statuses of QA-209, QA-216 and QA-218 are unchanged.

---

# 2026-10-28 — `guide_year` launch label (QA-217)

| | |
|---|---|
| Files | `DATABASE_ARCHITECTURE.md` (award_history, `guide_year`); `DATA_UPDATE_PROCESS.md` (same paragraph) |
| Reason | MICHELIN labels the Netherlands selection of 5 October 2026 as the 2026 edition. The Dutch rows seeded at launch also carry `guide_year = 2026`, but hold the 2025 edition's values (verified against MICHELIN's 2025 full list). The unique key left no room for real 2026 rows. |

Both documents now say the launch label can be wrong for a country, and give the rule decided by the user. Before a country's next update, check MICHELIN's own edition label. If it collides, relabel that country's launch rows to the edition they actually reflect, with values unchanged. Then write the new edition's rows on change only. Never overwrite a launch value to make room.

The Netherlands data that applies this is prepared in `supabase/data/enrichment/michelin_nl_stars_2026/` and has **not been applied yet**. The data entry (QA-216, QA-218) is written here when it is. *(Applied the same day; see the entry above.)*

Same day, `DATABASE_ARCHITECTURE.md` scope rule: condition 2 ("on the current World's 50 Best list") now says it means the full 1–100 ranking, the extended 51–100 included. This was the user's decision when completing the 2025 restaurant list (`supabase/data/enrichment/worlds_50_best_2025_2026/`). Hotels were widened the same day in `CLAUDE.md`: ranked hotels are in scope with or without a Key.

---

# Pass 2 — maintainability audit

## P1 — Profile bootstrap documented

| | |
|---|---|
| Files | `DATABASE_ARCHITECTURE.md` §4.1 (new) and §4; `DATABASE_IMPORT_GUIDE.md` §2; `START_HERE.md` |
| Reason | `profiles.id` referenced `auth.users` and nothing said how the row was created. Every user-table read policy calls `profile_is_visible(user_id)`, which returns false with no profile row, so a signed-up user could read none of their own data — presenting as an empty application rather than an error. |

New §4.1 gives the `handle_new_user()` trigger in full, with `SECURITY DEFINER` and `SET search_path` and why each is required. It settles the three open questions:

- **Username unknown at signup.** `username` is nullable and `raw_user_meta_data ->> 'username'` returns NULL for an absent key, so one trigger serves both flows without branching. A profile with a NULL username is fully functional; every policy keys on `id`.
- **UNIQUE handling.** Enforced at update, not at signup. `text UNIQUE` permits multiple NULLs — the one place PostgreSQL treating NULLs as distinct is wanted rather than worked around, in contrast to §2.2.
- **Do not pre-check availability.** The read policy hides other users' private rows, so a lookup reports a taken name as available and the `UPDATE` fails anyway. Attempt the write and catch SQLSTATE `23505`. Never put username selection in the trigger: a `23505` there aborts the `auth.users` insert and no account is created.

Both implementation orders now name the trigger as part of step 10.

## P2 — Backup and recovery defined

| | |
|---|---|
| Files | `DEPLOYMENT.md` §9 (new); `DATABASE_ARCHITECTURE.md` §4; `DATA_UPDATE_PROCESS.md` §8; `START_HERE.md` |
| Reason | Two documents instructed the reader to restore from backup. Neither defined one. |

Placed in `DEPLOYMENT.md` alone, with the others referencing §9.3 — the instruction was to avoid duplicated operational documentation.

§9 states PITR as a **hard requirement** rather than a precaution, with the reason stated plainly: the accepted mitigation for the polymorphic-reference risk is *detect, then restore*, so without PITR the second half does not exist and the documented protection is fictional. Detection also lags — orphans surface on the next regression run — which sets the minimum recovery window at seven days.

The recovery procedure ends where the external codes earn their place: a restored catalogue row carries a new UUID, so `visits.entity_id` is remapped through `restaurant_code`.

## P3 — `DEPLOYMENT.md` created

| | |
|---|---|
| File | `DEPLOYMENT.md` (new, 11 sections) |
| Reason | Environment variables, secrets, migration tooling, storage configuration, monitoring and local seeding were absent from all nine documents, and none belongs in the schema reference or the import guide. |

Covers environments, project creation, extensions, secrets inventory, `service_role` handling, migrations, local development, storage, scheduled jobs, backup, monitoring and a deployment checklist. It restates no schema and points at the existing documents by section.

Three operational hazards are named because each fails silently: a signed URL is a bearer token and survives a later privacy change, so expiry is short; deleting a `photos` row does not delete the object, and Storage is billed by volume; a cron job is not part of the migration set and does not survive a project rebuild.

## C1 — NULL semantics unified

| | |
|---|---|
| Files | `DATABASE_ARCHITECTURE.md` §3.3 and its column table; `START_HERE.md`; `VALIDATION_REPORT.md` |
| Reason | The column comment and `START_HERE.md` said NULL meant MICHELIN had not assessed the venue. Two paragraphs below, the same document said Wing is in a covered guide and unstarred — and Wing carries NULL. The short definition was wrong for one of the seven rows it defined, and it was the version a developer reads. |

One sentence now appears identically in all three documents:

> A NULL `michelin_stars` means the venue does not currently hold a MICHELIN star. It covers two situations: venues in countries where MICHELIN awards no stars, and venues inside a covered guide that are currently unstarred. `inclusion_reason` records why the row exists and is what distinguishes the two.

The banned phrasing appears nowhere except `MAINTAINABILITY_AUDIT.md`, which quotes it as the defect it found.

## C2 — Google ratings decision recorded

| | |
|---|---|
| File | `DATABASE_ARCHITECTURE.md` §14 |
| Reason | A pinned decision that appeared in no document. Eight of the nine accepted decisions were written down; this one was not, and storing a Google rating is a natural-looking addition for anyone wiring up the Places API. |

Four reasons recorded: volatile with no refresh trigger, third-party licensed with retention restrictions, already reachable through the Places API via `google_place_id`, and the product reason — `visits.rating` is what every statistic is built from, so a Google rating on the same screen would compete with the user's own.

## C3 — Settled architectural decisions

| | |
|---|---|
| File | `START_HERE.md` (new section) |
| Reason | The immutable decisions existed only inside two review documents, which a newcomer reasonably reads as historical artifacts rather than binding constraints. |

Nine decisions, one line each, pointing at `ARCHITECTURE_REVIEW.md` for the argument. Framed so a change can be recognised as a reversal rather than an improvement.

## C4 — Document ownership clarified

| | |
|---|---|
| Files | `START_HERE.md`; headers of `DATABASE_ARCHITECTURE.md`, `VALIDATION_REPORT.md`, `DATABASE_IMPORT_GUIDE.md` |
| Reason | The tie-breaker deferred to `DATABASE_ARCHITECTURE.md` for every disputed fact, but the facts that actually conflict are dataset counts, which that document barely mentions. |

Three subjects, three owners: schema and security to `DATABASE_ARCHITECTURE.md`, dataset statistics and row counts to `VALIDATION_REPORT.md`, orientation to `START_HERE.md`. `ARCHITECTURE_REVIEW.md` and `ENGINEERING_REVIEW.md` are labelled decision records — read for *why*, never implement from.

## T1 — Dated instructions replaced with a permanent rule

| | |
|---|---|
| Files | `DATA_UPDATE_PROCESS.md` §1 and §4; `DATABASE_IMPORT_GUIDE.md` §9.2; `VALIDATION_REPORT.md`; `ARCHITECTURE_REVIEW.md` §4 |
| Reason | Four documents carried live instructions keyed to a single date, which would read as current guidance indefinitely after passing. |

Replaced with the rule the date was an instance of: *the restaurant ranked No.1 in a given year is elevated into the Hall of Fame when the following year's list publishes, and leaves the ranking permanently at that moment.* Stated once in `DATA_UPDATE_PROCESS.md` §4 and referenced elsewhere. The update calendar no longer names a month.

The date survives in `ARCHITECTURE_REVIEW.md` §4 as a historical problem statement, which the audit permitted; that item is now marked **RESOLVED**, as is item 5.

## T2 — Volatile counts concentrated

| | |
|---|---|
| Files | `DATABASE_ARCHITECTURE.md` §2.1, §3.4, §5, §6, §9, §11, §13; `DATA_UPDATE_PROCESS.md` §11; `START_HERE.md` |
| Reason | Counts that change on the first guide update were repeated across up to five documents. A maintainer updates the ones they remember; the consistency audits compare documents to each other and pass when all are equally stale. |

Incidental counts replaced with timeless wording — "every catalogue row" rather than a total, "a small table" rather than 68, "the QA log" rather than an entry count.

**Retained deliberately:** every expected value in `DATABASE_IMPORT_GUIDE.md` §10, because assertions require numbers; everything in `VALIDATION_REPORT.md`, which owns them; the orientation table in `START_HERE.md`, now carrying a line stating the figures describe the launch dataset and naming the authoritative source; and structural counts that change only when a documented decision changes — ten shared Place IDs, seven null-star rows, eleven Hall of Fame members.

## T3 — Validation report versioned

| | |
|---|---|
| File | `VALIDATION_REPORT.md` |
| Reason | An inherently point-in-time artifact, listed as current documentation with no indication of what it described or when. |

Header carries dataset version `2026.07`, generation date, source data revision, validation version and a supersedes field. It states the report is not amended when the catalogue changes: a guide update produces a new run, a new dataset version and a new report, and a report whose version does not match the database is a historical record.

## Not implemented

**T4** (§14 completeness) and **T5** (review-document shelf-life headers) were excluded by instruction. T4 would have documented MICHELIN Selected, media and social features, which the project's YAGNI position excludes. The substance of T5 was absorbed into C4, which labels both reviews as decision records.

---

# Pass 1 — engineering review

## Blocking findings

### B1 — Row Level Security specified

| | |
|---|---|
| File | `DATABASE_ARCHITECTURE.md` |
| Section | **§15 Security and access control** (new, ~200 lines) |
| Reason | RLS was named in two implementation orders and defined nowhere. On Supabase, PostgREST exposes every `public` table over HTTP and the `anon` key ships inside the Flutter binary, so following the documentation exactly produced a database in which any user could read, edit and delete any other user's data. |

Covers all thirteen tables. Roles and what each may do; the eight catalogue tables as public-read with no write policy; a single `profile_is_visible()` function implementing the visibility rule once; per-table read, insert, update and delete policies for `profiles`, `visits`, `wishlist`, `photos` and `follows`; `service_role` behaviour and where its key may live; storage bucket policies; and verification queries.

Three implementation details are called out because each produces a working-looking but wrong result: `SECURITY DEFINER` is required to avoid `infinite recursion detected in policy`; `SET search_path = public` is required or a caller can substitute their own `profiles` table; and `WITH CHECK` is required alongside `USING` on `UPDATE` or a user can reassign their own row to another user.

Two interactions were decided rather than left open:

- **`photos.is_public` is subordinate to `profiles.is_public`.** A public photo on a private profile stays private. The reverse composition would leak the existence, timing and location of a private user's visit through a single image.
- **`follows` grants no read access.** `follows` has no approval column and a row is created unilaterally by the follower, so granting access would make `is_public = false` meaningless. Recorded as an open product decision in `ACTION_TRIAGE.md` §5a rather than solved by inventing a column.

**Supporting changes:** `DATABASE_IMPORT_GUIDE.md` §2 makes RLS step 11 of twelve and states it is not optional; §12 adds it to common mistakes. `DATA_UPDATE_PROCESS.md` §1a specifies maintenance-process authentication. `START_HERE.md` adds both to the must-know list.

### B2 — Polymorphic references: mitigation, not foreign keys

| | |
|---|---|
| Files | `DATABASE_ARCHITECTURE.md` §4, `DATA_UPDATE_PROCESS.md` §8, `START_HERE.md` |
| Reason | The architecture relied on a process promise — "the maintenance process never deletes a catalogue row" — to protect four tables PostgreSQL cannot protect. |

**The review recommended real foreign keys on `visits`, `wishlist` and `photos`. That recommendation was declined**, because polymorphic user tables are a pinned architectural decision and the instruction is to prefer documentation over schema change.

What replaced it:

1. §4 now states plainly what the database does *not* enforce and what happens when the promise fails: a `DELETE` succeeds, orphans every dependent row, raises no error, and the data cannot be reconstructed.
2. Three named mitigations, all mandatory: the catalogue is append-and-amend only; only `service_role` can write to it, so an accidental delete cannot originate from the application; the regression suite scans for orphans.
3. `DATA_UPDATE_PROCESS.md` §8 adds check 10 — four orphan queries across `visits`, `wishlist`, `photos` and `award_history` — with a note that this check is the enforcement, and that a row returned means the loss has already occurred and the response is a restore, not a cleanup.

**Residual risk, stated for the record.** These mitigations detect the failure; they do not prevent it. A developer with `service_role` access who deletes a catalogue row still destroys user data, and the regression suite reports it only on the next run. The foreign key would have made the `DELETE` fail. That trade is now documented rather than implicit, which was the actual defect.

### B3 — Import guide made executable

| | |
|---|---|
| File | `DATABASE_IMPORT_GUIDE.md` |
| Section | **§5 Staging schema** (new); §7.1, §7.2, §7.3, §8, §9.2, §10.2 rewritten; §6–§12 renumbered |
| Reason | Four objects appeared in SQL and were defined nowhere, so the guide could not be followed end to end despite claiming to allow a build from scratch. |

`staging_hotels`, `staging_restaurants`, `staging_links` and `country_bounds` now have full `CREATE TABLE` definitions in a dedicated `staging` schema, with load statements and a note on which columns are discarded. `city_text` and `country_text` are defined as staging columns and the §7.3 resolution query is rewritten to join through staging, which it previously could not do — the earlier version referenced `r.city_text` on the production table, where no such column exists.

`country_bounds` gets two population routes — Natural Earth shapefile, or `ST_MakeEnvelope` rows — plus a coverage assertion, because an unpopulated country is silently unchecked. This matters more than its size: §10.2 is the only test that catches a reversed `ST_MakePoint`, the most damaging silent error in the build.

Three problems were found while making the examples executable, and fixed:

- **`COPY` reads an empty CSV field as `''`, not `NULL`.** On a `UNIQUE` column the second empty `google_place_id` raises a duplicate key error that reads like a real collision. Every nullable text column is now wrapped in `nullif(col,'')`.
- The old §6.2 added temporary `lat`/`lng` columns to the production tables. Coordinates now come from staging and the production tables are never altered.
- §9.2 read `staging_restaurants` after §6 implied it was gone. The lifecycle is now explicit: staging is dropped in §11, after validation.

---

## Cheap fixes

### D1 — Filenames and cross-references

| | |
|---|---|
| Files | all |
| Reason | Every document referenced `DATABASE_ARCHITECTURE.md` while the file was named `DATABASE_ARCHITECTURE_v2_0.md`. No cross-reference resolved. |

Four files renamed to drop the `_v2_0` suffix. All superseded `_v1_1` copies deleted. Version now lives in git history, not in filenames — which also removes the contradiction of a document set that had scrubbed every internal version reference while announcing its version seven times in the file listing.

### D2 — Denormalised `country_code`

| | |
|---|---|
| Files | `DATABASE_IMPORT_GUIDE.md` §10.6 (new), `DATA_UPDATE_PROCESS.md` §8 check 9 |
| Reason | `country_code` on both catalogue tables is derivable through `city_id`, and nothing enforced agreement. |

No constraint added, as instructed. Two regression queries assert `hotels.country_code = cities.country_code` and the same for `restaurants`. The denormalisation stays because it buys the `(country_code, michelin_keys)` index that a join could not.

### D3 — `guide_year` given one meaning

| | |
|---|---|
| Files | `DATABASE_ARCHITECTURE.md` §3.5, `DATA_UPDATE_PROCESS.md` §3 |
| Reason | The architecture implied a guide edition; the update process said rows are written on change. Both could not hold. |

Four paragraphs now appear **verbatim in both documents**: the definition, the consequence that an unchanged venue carries one row indefinitely, and the statement that seeded 2026 rows are a launch limitation rather than historical truth, so a "held since" feature is only meaningful for post-launch changes.

### D4 — `venue_status` enum retained

| | |
|---|---|
| File | `DATABASE_ARCHITECTURE.md` §3.1 |
| Reason | The review flagged it as the schema's only enum among seven constrained vocabularies and recommended conversion to `text` with a `CHECK`. |

**Not converted, and the review's own argument was overstated.** It claimed `ALTER TYPE … ADD VALUE` has transactional restrictions; that was true before PostgreSQL 12 and the target is 15 or later. With the migration objection removed, the enum's advantages stand: `status` is read on nearly every catalogue query and is the one such column that benefits from a fixed-width representation.

§3.1 now documents why it is the exception and gives the statement for adding a value, with the caveat that a value cannot be removed once added.

---

## Maintenance risks

### M1 — `inclusion_reason` gained `hall_of_fame`

| | |
|---|---|
| File | `DATABASE_ARCHITECTURE.md` §3.3 |
| Reason | The scope rule has three qualifying conditions; the constraint offered values for two. |

**This is the one schema change in this pass.** It is one value in a `CHECK` on a table that does not yet exist, and it fixes a correctness defect rather than a preference: without it, a hall-of-fame restaurant is stored as `worlds_50_best` while being — by definition, since members are ineligible — absent from that list. Central would be recorded as something it demonstrably is not.

The column is also now documented as recording the **primary** reason a row exists, with the explicit warning that filtering it does not enumerate World's 50 Best restaurants; query the `worlds_50_best` table for that.

### M2 — `hotels_full` specified

| | |
|---|---|
| File | `DATABASE_ARCHITECTURE.md` §5 |
| Reason | The application reads the views rather than the tables, and one of the two views was a single sentence naming two columns without defining them. |

`has_michelin_restaurant`, `restaurant_count` and the four resolved reference fields now have definitions, to the same standard as `restaurants_full`.

### M3 — Scheduled refresh documented

| | |
|---|---|
| Files | `DATA_UPDATE_PROCESS.md` §13 (new), `DATABASE_ARCHITECTURE.md` §5, `DATABASE_IMPORT_GUIDE.md` §1 |
| Reason | "Refreshed nightly" named no mechanism, and `pg_cron` was absent from the extensions list. |

New §13 covers the required unique index, `REFRESH MATERIALIZED VIEW CONCURRENTLY` and what happens without it, the `cron.schedule` call with a concrete cadence, the instruction to stagger views and to avoid catalogue update windows, and verification against `cron.job_run_details`.

The failure mode is called out because it is invisible from the application: a failed refresh leaves the view serving stale contents, so the symptom is statistics that stop moving rather than an error.

### M4 — Code formats reconciled with the naming convention

| | |
|---|---|
| File | `DATABASE_ARCHITECTURE.md` §11 |
| Reason | `hotel_001` and `rest_0001` disagree in prefix style and digit width, in a section stating "never abbreviate". |

The codes are frozen — 193 QA entries and 38 manual actions reference them. §11 now states that they predate the convention, that the convention governs schema identifiers only, and gives the exact widths (`hotel_%03d`, `rest_%04d`) so a formatting script cannot generate a code that matches nothing.

---

## Correction made during this pass

While writing §7.3 of the import guide I justified joining `cities` on `country_code` by asserting that fourteen city names occur in more than one country. **That figure was fabricated.** Checked against the data: **zero** city names occur in more than one country.

The advice is still correct and the justification is now the accurate one — `cities` is unique on `(country_code, name, region)`, not on `name`, so a name-only join happens to succeed today and would break silently on the first city added to a second country. Corrected in both places it appeared.

---

## Files changed

| File | Change |
|---|---|
| `DATABASE_ARCHITECTURE.md` | §15 added; §3.1, §3.3, §3.5, §4, §5, §11 revised. Renamed. |
| `DATABASE_IMPORT_GUIDE.md` | §5 added; §1, §2, §7, §8, §9.2, §10, §11, §12 revised; §6–§12 renumbered |
| `DATA_UPDATE_PROCESS.md` | §1a and §13 added; §3 and §8 revised |
| `START_HERE.md` | Implementation order; three must-know entries. Renamed. |
| `ACTION_TRIAGE.md` | §5a added. Renamed. |
| `VALIDATION_REPORT.md` | Release note on the widened constraint. Renamed. |
| `ARCHITECTURE_REVIEW.md` | Unchanged in substance |
| `ENGINEERING_REVIEW.md` | Status banner |
| `CHANGELOG.md` | New |


---

## Current document set

| File | Role |
|---|---|
| `START_HERE.md` | Orientation, settled decisions, document ownership |
| `DATABASE_ARCHITECTURE.md` | Schema, conventions, security model |
| `DATABASE_IMPORT_GUIDE.md` | Building the catalogue |
| `DATA_UPDATE_PROCESS.md` | Guide updates, closures, regression suite |
| `DEPLOYMENT.md` | Environments, secrets, storage, backup, monitoring |
| `VALIDATION_REPORT.md` | Dataset `2026.07` validation |
| `ACTION_TRIAGE.md` | Open data work |
| `ARCHITECTURE_REVIEW.md` | Decision record — schema |
| `ENGINEERING_REVIEW.md` | Decision record — implementation readiness |
| `MAINTAINABILITY_AUDIT.md` | Decision record — maintainability |
| `CHANGELOG.md` | This file |
