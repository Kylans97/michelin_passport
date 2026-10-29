# Changelog

Mantelier — documentation changes.

Two passes are recorded. **Pass 1** implemented `ENGINEERING_REVIEW.md`; **Pass 2** implemented the accepted findings of `MAINTAINABILITY_AUDIT.md`. No schema was redesigned in either. One constraint was widened in Pass 1; Pass 2 changed no schema at all.

---

# 2026-10-29 — Catalogue data applied: MICHELIN Germany 2026 and Italy 2026 (QA-252–QA-259)

| | |
|---|---|
| Applied | 2026-10-29, to production, from branch `claude/lucid-rubin-us4we5` (carried on `data/de-it-2026`) |
| Migration | `20261023130000_add_de_it_2026_star_cities` (330 towns). Ledger 107 → 108, local and remote in agreement |
| Data files | `michelin_de_it/prepared_de_it_stars_2026.sql`, then `michelin_de_it/prepared_aqua_closure.sql`. Each is one transaction with its own guards; neither aborted |

**Before.** Read-only checks against production first, all matching what the file was built from:

- 60 German and 58 Italian restaurants, none of them updated since the export of 2026-10-29 06:31 UTC.
- Germany at 12/47/1 and Italy at 15/37/6 stars.
- Codes `rest_1842`–`2444` free; the highest code was `rest_1841`.
- Only the new migration pending.

**Germany** (MICHELIN Germany 2026, announced 23 June 2026).

- **QA-252, relabel:** the launch rows held 2025 values labelled 2026, the same case as the Netherlands. They are now 2025, which gives Germany 60 rows for 2025.
- **L.A. Jordan:** 2 → 3 stars.
- **Lost stars:** Aqua, bianc and Courtier each carry a current 2026 row with no star.
- **New restaurants:** 281 added.
- **Selection:** Germany is now exactly MICHELIN's live list, **12 / 48 / 278**.

**Italy** (MICHELIN Italia 2026).

- **QA-254:** Tre Olivi corrected 2 → 1.
- **New restaurants:** 322 added.
- **QA-255:** Quattro Passi (3), Santa Elisabetta (2) and Lido 84 (1) keep their stars. They are in the 2026 article but no longer on MICHELIN's site; recheck at Italy 2027 (12 November 2026).
- **Selection:** Italy is now **15 / 38 / 327**, MICHELIN's live list plus those three.

**Both countries.** Checked after the apply:

- **New rows:** 603 restaurants, `rest_1842`–`rest_2444`. 580 of them have a Place ID and 570 a phone.
- **Hotel links:** 66 across Germany and Italy.
- **Star rows:** every starred restaurant has exactly one current star row agreeing with `michelin_stars`, and none lacks a city.
- **Detail view:** all 341 German and 380 Italian restaurants appear in `restaurants_full`.
- **Total:** the catalogue now holds 2,397 starred restaurants.

**Aqua's closure (QA-253).** The product owner chose to enable the optional step that the generated file leaves commented out.

- **How it ran:** from its own file, `prepared_aqua_closure.sql`, guarded on the main file having run, so the generated file stays as reviewed.
- **Result:** `rest_0186` is `permanently_closed`, with the note "Closed after 25 years; last services March 2026 (exact date not confirmed)".
- **Closing date:** `status_since` stays NULL rather than a guessed date.
- **Courtier** stays open: the timing of its reported closure is unclear.

---

# 2026-10-29 — World's 50 Best 51–100 history, 2021–2024: 39 rank-years (QA-249)

| | |
|---|---|
| Applied | 2026-10-29, to production, from branch `data/w50b-history-older` |
| Data file | `worlds_50_best_history_51_100/apply_51_100_rank_years.sql`: one transaction; the identity, free-slot, free-year and exact-count guards all passed |
| Migrations | none |

**Proof, the strict rule (not name).** Each year's official 51–100
announcement story on the50.com (2021, 2023 and 2024) links every ranked
entry to its the50.com profile. A rank-year was applied only when that
linked profile is ours:

- **27:** it equals the `worlds_50_best_url` already proven by phone,
  website or address.
- **12:** the profile shows our phone, own website or street address.

Each rank also matches the official list for that year.

**Before.** A read-only dry run: 39/39 codes carried the expected name,
with no taken places or years. The table held 936 rows.

**After.** 975 rows (+39), and all 39 are present as `extended_51_100`.
2021–2024 now hold 74 / 70 / 88 / 86 of 100 places; the rest are
restaurants outside our catalogue, plus the open items below. Current
ranks are unchanged.

**Open, not changed (QA-249):**

- **2022 ×10:** that year's story has no profile links.
- **La Colombe 2021/2023:** the linked profile no longer exists.
- **Labyrinth 2024:** the link differs from our proven URL.
- **Mountain 2024:** not linked.

---

# 2026-10-29 — World's 50 Best history, 2002–2017: 51 Top 50 rank-years matched by name and city (QA-250)

| | |
|---|---|
| Applied | 2026-10-29, to production, from branch `data/w50b-history-older` |
| Data file | `worlds_50_best_history_older_name_match/apply_top_50_rank_years.sql`: one transaction; the identity, free-slot, free-year and exact-count guards all passed |
| Migrations | none |

**Rule exception, decided by the product owner on 2026-10-29.** For
2002–2017 the archive keeps the official lists (name and city) but no
entry pages, so no phone, website or address can prove identity. These
rows are matched by **name and city**. The exception covers this file
only. 51–100 for 2021–2024 (QA-249) still need more, and search, dedupe
and linking still key on code + country.

**Same restaurant, not just same name.** All 61 candidates were checked by
hand.

- **Applied: 51.** Each has the same name and city, or is the same
  restaurant at a new address: Troisgros, Guy Savoy, La Colombe and
  Astrance.
- **Excluded: 5.**
  - "Les Ambassadeurs" ×3 matched "ES" by accident.
  - "Alain Ducasse" 2005/06 is Ducasse au Plaza Athénée.
- **Held: 5.**
  - "Le Meurice" ×3 is Alléno's era, before Ducasse's restaurant there.
  - "Le Jardin des Sens" ×2: continuity with our row isn't confirmed.

**Before.** A read-only dry run: 51/51 codes carried the expected name,
with no taken places or years. The table held 885 rows.

**After.** 936 rows (+51), and all 51 are present as `top_50`. Current
ranks are unchanged.

---

# 2026-10-28 — World's 50 Best history, batch 2: 13 Top 50 rank-years, 2017–2019 and 2022 (QA-250)

| | |
|---|---|
| Applied | 2026-10-28, to production, from branch `data/w50b-history-gaps` |
| Data file | `worlds_50_best_history_batch_2/apply_top_50_rank_years.sql`: one transaction; the identity, free-slot, free-year and exact-count guards all passed |
| Migrations | none |

**Source.** The archived `theworlds50best.com/previous-list` page holds
every year from 2002 to 2019 in one timeline. Each year's block was
accepted only by its heading, its known No.1, and an exact match against
every row we already held for that year. 2016 is excluded: the official
block is mis-numbered (two No.22s, two No.23s, no No.18 or No.37).

**Proof per row.** Year-specific archived entry pages for 2017–2019
(`/The-List-<year>/…`) state the rank, and identity comes from our phone,
own website or street address on that page. Le Clarence 2022 matched by
address, checked by hand: "31 Av." vs our "31 Avenue".

**Rows added:**

- Mirazur 2017 No.4, 2018 No.3, 2019 No.1.
- The Clove Club 2017 No.26, 2018 No.33, 2019 No.27.
- Alléno Paris au Pavillon Ledoyen 2017 No.31, 2018 No.29, 2019 No.25.
- Nerua 2019 No.32, A Casa do Porco 2019 No.39 and Leo 2019 No.49.
- Le Clarence 2022 No.28.

**Before.** A read-only dry run: 13/13 codes carried the expected name,
and no place or restaurant-year was taken. The table held 872 rows.

**After.** 885 rows (+13), and all 13 are present as `top_50`. Current
ranks are unchanged.

**Open, not changed:**

- **Name-only matches:** 61 older Top 50 places
  (`top_50_name_city_review.csv`) and 53 places at 51–100 for 2021–2024
  (QA-249) match only by name and city. They wait for a rule decision.
- **Not covered:** 51–100 for 2013–2019.
- **QA-251:** Mirazur (No.1 in 2019) has no Hall of Fame row and reads
  `is_hall_of_fame = false`.

---

# 2026-10-28 — World's 50 Best history: 29 missing Top 50 rank-years, 2021–2024 (QA-246)

| | |
|---|---|
| Applied | 2026-10-28, to production, from branch `data/w50b-history-gaps` |
| Data file | `worlds_50_best_history_2021_2024/apply_top_50_rank_years.sql`: one transaction; the identity, free-slot, free-year and exact-count guards all passed |
| Migrations | none |

**Finding.** `worlds_50_best` was accurate but incomplete. For 2021–2024
every rank we held matched the official list, but only 56/60/68/65 of the
100 places were held. Restaurants often had only their latest appearance.

**Source.** Archived official lists (`theworlds50best.com/list/1-50`,
Wayback snapshots from 2021-11-09, 2022-09-04, 2023-09-05 and
2024-10-02). Each snapshot's No.1 fixes its year. The live the50.com
previous-list pages ignore the year, so they couldn't be used.

**Proof per row.** The official entry page states that exact year and
rank. Identity comes from that page's phone, own website or street
address, or, for 3 rows, from the restaurant's own verified the50.com
profile stating the same rank-year. Never from the name.

**Before.** A read-only dry run:

- 29/29 codes carried the expected name.
- No (year, rank) place and no restaurant-year was already taken.
- The table held 843 rows.

**After.** Checked directly:

- **Rows:** 872 (+29), and all 29 are present as `top_50`.
- **Places held** for 2021–2024: 63 / 69 / 75 / 71.
- **Current ranks unchanged:** `restaurants_full.worlds_50_best_rank` still
  reads the 2025 list. A Casa do Porco now reads 2021 No.17, 2022 No.7,
  2023 No.12, 2024 No.27 and 2025 No.83.

**Open, not changed:**

- **Le Clarence 2022:** its entry page shows none of our contact details.
- **QA-249:** 55 places at 51–100 can be matched only by name.
- **QA-250:** every year other than 2021–2024 is unchecked.
- **QA-247:** resolved, no change (Le Calandre 2023 is No.41, as stored).

---

# 2026-10-28 — Guide source links applied: World's 50 Best URLs, Gault&Millau URLs and toques (QA-244–QA-248)

| | |
|---|---|
| Applied | 2026-10-28, to production, from branch `feature/guide-sources` (main merged in first) |
| Migration | `20261021120000_add_worlds_50_best_urls`: `worlds_50_best_url` (nullable, UNIQUE) on `restaurants` and `hotels`, appended to `restaurants_full`/`hotels_full`. Ledger 104 → 105, local and remote in agreement |
| Data file | `guide_source_links/apply_guide_source_links.sql`: one transaction, every step guarded by its expected row count; none aborted |

**Before.** Read-only checks against production first:

- Only this migration was pending.
- Every code in the data still named the venue it was researched for (113 + 123 + 7 + 22, none changed or missing).
- Each step's `WHERE` clause matched exactly the expected rows (8 / 7 / 21 / 113 / 123).

**World's 50 Best.** Source: the official site, now **the50.com** (`theworlds50best.com` redirects there), via its own sitemap. Method in `guide_source_links/README.md`.

- **Proof:** a page was accepted only with the right type (Restaurant or Hotel) and country, plus a match that doesn't depend on the name: one of our own ranks, our phone, our own website, or our street and house number.
- **Applied:** 113 of 143 restaurants and 123 of 134 hotels now carry `worlds_50_best_url`.
- **Open:** 30 restaurants and 11 hotels are left NULL (QA-248).

**Gault&Millau.**

- **QA-244:** the 8 Austrian `"not found"` placeholders are NULL. Then 7 real gaultmillau.at pages were filled, each verified on title (city, Hauben, score) and on street and postcode; Obauer stays NULL. `gault_millau_url` now holds 40 real URLs and no placeholders.
- **QA-245:** 21 Belgian and Dutch toque counts were filled from each restaurant's own page, only where the page score equals ours. `toque_count` went from 13 to 34 rows.

**After.** Checked directly:

- **Columns:** 113 / 123 URLs, and `restaurants_full` serves all 113.
- **De Librije:** reads 19.5, 5 toques, with all three guide links.
- **Views:** both keep `security_invoker`, and `anon` can read the new column, as with every catalogue column.

**Open, not changed:**
- **QA-246:** 9 World's 50 Best rank-years on verified profiles are missing from `worlds_50_best`, so Award History lacks them. They need confirming against each year's official list first.
- **QA-247:** profile rank lines contradict the official lists in three places, and our data matches the lists. Le Calandre 2023 is unchecked.

**Near-miss.** QA ids: this branch first numbered its issues QA-232 to QA-236, which main had already used for the Spanish and Belgian work. The clash was caught at the merge and renumbered to QA-244 to QA-248 before anything was applied.

---

# 2026-10-28 — Catalogue data applied: MICHELIN Spain 2026 and Belgium & Luxembourg 2026 (QA-232–QA-243)

| | |
|---|---|
| Applied | 2026-10-28, to production, from branch `claude/lucid-rubin-us4we5` (Spain, with the Belgian work merged in) |
| Migrations | `20261019140000_add_es_2026_star_cities` (123 ES towns), `20261019150000_add_be_2026_star_cities` (7 BE cities), in one `db push`. Ledger 102 → 104, local and remote in agreement |
| Data files | `michelin_es_stars/prepared_es_stars_2026.sql`, then `michelin_be_lu_stars_2026/prepared_be_lu_stars_2026.sql`, then `place_id_backfill/prepared_place_id_backfill_be_stars_2026.sql`. Each is one transaction with its own guards; none aborted |

**Before.** Read-only checks against production first:

- Only the two migrations were pending.
- Codes `rest_1588`–`1839` were free; the highest code was `rest_1587`.
- Spain held 57 restaurants (16/36/5), Belgium 120 (2/22/96) and Luxembourg 12 (2/10), as both files expect.

**MICHELIN Spain 2026.** Source: MICHELIN's live listing and every restaurant's own page (296 read), reconciled with the 2026 full-list article (25 November 2025). See `ES_STARS_2026_REPORT.md`.

- **Selection:** Spain now matches MICHELIN's live listing exactly, **16 / 37 / 243** (296 restaurants).
- **Star rows:** every starred ES restaurant has exactly one current star row agreeing with `michelin_stars`. None lacks a city, and all 296 appear in `restaurants_full`.
- **New restaurants:** 239 added, `rest_1588`–`rest_1826`, each with a MICHELIN URL. 235 of them have a confirmed Place ID and 232 a confirmed phone.
- **Existing rows:** every ES restaurant now has a `michelin_url` (35 filled); the file also filled 46 empty phones.
- **Hotel links:** Spain now has 23 hotel links, 13 of them new.
- **Open:**
  - **QA-232:** DiverXO and ABaC coordinates.
  - **QA-233:** two pins more than 500 m from Google's record.
  - **QA-234:** 10 one-stars MICHELIN has since removed from its site.
  - **QA-235:** Cap Vermell's Key level.
  - **QA-236:** Aponiente's phone.
  - **QA-237:** phones still missing.
  - **QA-238:** eight restaurants Google shows as temporarily closed.
  - **QA-239:** two restaurants without their own Google record.

**MICHELIN Belgium & Luxembourg 2026.** See `BE_LU_STARS_2026_REPORT.md`.

- **Lost stars:** six restaurants starred in 2025 and absent from 2026: La Durée, Ralf Berendsen, Bar Bulot Zedelgem, Mémoire, Table d'Amis and Aurum by Gary Kirchens. Each now carries a closed 2025 row with its old value and a current 2026 row with `award_value` NULL; `michelin_stars` is NULL. Re-read for all six.
- **QA-241:** Le Lys (`rest_1368`) has its missing current 2026 one-star row.
- **MICHELIN URLs:** 16 filled.
- **New restaurants:** 13 added, `rest_1827`–`rest_1839`, each with a 2026 row. All 13 got their confirmed Place ID from the second file.
- **Selection:** Belgium is now **2 / 20 / 105** (133 restaurants) and Luxembourg **2 / 10**, MICHELIN's 2026 full list. Each starred restaurant has one matching current row.
- **Open:**
  - **QA-240:** La Paix, Kommilfoo and La Table de Manon keep their stars.
  - **QA-242:** Philippe Fauchet's phone.
  - **QA-243:** Héliport Brasserie is shown as temporarily closed on Google.

**Near-miss.** This was caught and fixed before anything was applied.

- **The collision:** the Belgian work had first picked `rest_1405`–`1417`, which France 2026 took on production. Its Place ID file checked only that each code existed, so it would have put Belgian Google records on 13 French restaurants.
- **The fix:** Belgium was renumbered, and every prepared Place ID file now checks each code's MICHELIN page before writing.
- **After the apply:** `rest_1405`–`1417` are still the same 13 French rows.

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
