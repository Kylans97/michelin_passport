# Regional 50 Best lists — shared guide tables and first import (2026-11-16)

Status: **PREPARED, NOT APPLIED.** Waiting on the product owner's approval
to apply the migration and then the data file to production.

Decided by the product owner on 2026-11-16: "Begin met de drie regionale
50 Best-lijsten (Azië, Noord-Amerika, Latijns-Amerika) en de gedeelde
tabellen". Design: `docs/Architecture/GUIDE_INVENTORY.md`.

## What is here

| File | What it does |
|---|---|
| `supabase/migrations/20261101410000_add_shared_guide_tables.sql` | `guides`, `guide_awards`, `guide_venue_links`, `guide_coverage`, the view `guide_awards_current`; RLS public read, no client write. No function, so no revoke is needed. |
| `prepared_regional_50_best_import.sql` | 3 guide rows, 111 `guide_awards` rows, 111 `guide_venue_links` rows, 3 `guide_coverage` rows. One transaction with guards. |
| `regional_50_best_matches.csv` | All 250 list entries: rank, the publisher's page, match status, catalogue code + country, match basis and note. |
| `_source/official_regional_lists.csv` | The three lists as read from the50.com on 2026-11-16. |
| `_source/venue_page_contacts.csv` | Address, phone and website from each 1–50 venue page (150). |
| `_source/discovery_page_contacts.csv` | Address and website from the50.com discovery pages for the 51–100 entries that had a catalogue candidate. |

## Source

Only the publisher's own site, the50.com, on 2026-11-16. Edition years are
the ones each page declares (`<meta name="list-year">`):

| List | Edition | Announced | Pages |
|---|---|---|---|
| Asia's 50 Best Restaurants | 2026 | 2026-03-25 (Hong Kong) | https://www.the50.com/restaurants/best-in-asia/list/1-50 and /51-100 |
| North America's 50 Best Restaurants | 2026 (2nd edition) | 2026-05-28 (New Orleans) | https://www.the50.com/restaurants/best-in-north-america/list/1-50 |
| Latin America's 50 Best Restaurants | **2025** | not verified, so `announced_on` is NULL | https://www.the50.com/restaurants/best-in-latin-america/list/1-50 and /51-100 |

Latin America 2025 is the current edition until the 2026 list on
**1 December 2026** (Guadalajara). That list is a second, small data file
on these tables, nothing more; the site's coverage note already says it is
coming.

Each list page carries all its entries; 100 / 50 / 100 distinct ranks. No.
1: The Chairman (Hong Kong), Smyth (Chicago), El Chato (Bogotá). Only the
1–50 entries link a venue page.

## Result

| List | Entries | In catalogue, ranked | Not in catalogue | Held back |
|---|---|---|---|---|
| Asia 2026 | 100 | **51** (36 of 1–50, 15 of 51–100) | 46 | 3 (QA-490) |
| North America 2026 | 50 | **32** | 18 | 0 |
| Latin America 2025 | 100 | **28** (23 of 1–50, 5 of 51–100) | 72 | 0 |
| **Total** | 250 | **111** | 136 | 3 |

All 111 matched rows are `status = open`. Lookups returning a wrong record: 0.

**Not in the catalogue is not added.** A regional ranking does not make a
restaurant eligible (the scope rule in `DATABASE_ARCHITECTURE.md` §3.3 is
MICHELIN star, the global 50 Best 1–100, its hall of fame, or the
Selection), so the 136 are listed in the CSV and nothing else. Whether
they should enter is a product decision, not a side effect of this import.

## How entries were matched

Names only proposed candidates (same city, or a name hit anywhere with
evidence). A match was accepted on:

- **website, phone or address** from the publisher's page agreeing with
  the catalogue row — the venue page for 1–50, the discovery page for
  51–100;
- **prior_rank_row** — the row already carries that restaurant's global 50
  Best ranks, set when that list was matched, and the city agrees. Used
  where the address disagreed (see QA-491) and nothing else on the page
  could be compared.

Look-alikes ruled out: Narisawa Tokyo, not Narisawa Shanghai (shares the
website only); Huniik, not La Barra de Huniik (next door, 417 vs 415-B);
Gaggan at Louis Vuitton is not Gaggan; Jungsik Seoul is not Jungsik New
York; Wing is not Wing Lei; no Sushi Shunji or Sushi Saito row exists,
whatever other sushi counters share Tokyo.

City-name differences, same place: Le Chique (listed Cancún, at Hotel
Xcaret Arte, Playa del Carmen), Lunario (Valle de Guadalupe / El Porvenir),
Mil (Moray / Cusco), Albi (Washington DC / Washington), Somni (Los Angeles
/ West Hollywood), The Pine (Collingwood / Creemore).

### Held back — QA-490

| Rank | Entry | Why |
|---|---|---|
| Asia 6 | Meet the Bund | Venue page: 56F West Tower, Raffles City The Bund, Hongkou. Catalogue rest_2739: The Bund Finance Center, 600 Zhongshan Dong Er Road. Not settled which venue the regional rank belongs to. |
| Asia 69 | Co- | Discovery: Shangdu Fashion Plaza, 3128 Chunxi Road. Catalogue rest_2679: Chinese Financial Center, 33 Jiaozi Avenue. No website to settle it. |
| Asia 70 | Vea | No publisher page with an address (no venue link on 51–100, no discovery page found). |

That is why Asia's coverage row is `partial`.

### Stale-looking catalogue addresses — QA-491

Matched on other evidence, but the publisher's address differs from ours:
The Chairman, Den, Lasai, Celele, Boragó, Mayta, Em, Baan Tepa. Several are
moves the catalogue has not caught up with. Identity is not in doubt; the
address and point should be re-verified in an enrichment pass. Not fixed
here.

## Local test

`supabase start` (CLI 2.122.0) on a scratch copy of `supabase/` (no
`.temp/`), own project id and ports. Every migration replayed without
error, the new one last. Fixture: the 111 matched `restaurants` rows,
exported read-only from production, loaded with
`session_replication_role = replica`.

- Run 1 of `prepared_regional_50_best_import.sql`: committed, every guard
  and post-check passed. 111 `guide_awards`, 111 `guide_venue_links`, 3
  `guide_coverage`. The (guide, rank, code, country) set read back is
  identical to `regional_50_best_matches.csv`.
- Run 2: refused by the guard ("already present"), nothing changed.
- `guide_awards_current` returns the 111 rows; No. 1 per list as above.
- As `anon`: select works on the view and every table; insert into
  `guides` is refused. As `authenticated`: delete from `guide_awards` is
  refused. RLS is on for all four tables.

Not tested: the apply against production itself; the app and site do not
read these tables yet (a separate step).

## To apply (after approval)

1. `supabase db push --linked` — applies `20261101410000` only (check
   `supabase migration list --linked` first; nothing else may be pending).
   If the CLI hangs after "Applying migration…", check for
   `public.guide_awards` in production before anything else; never re-run
   on output alone.
2. `supabase db query --linked --file supabase/data/enrichment/regional_50_best/prepared_regional_50_best_import.sql`
3. Verify the three counts (51 / 32 / 28) and the coverage rows in
   production; confirm `supabase migration list --linked` shows local and
   remote in agreement.
4. Log it in the Michelin_Database CHANGELOG with QA-490 / QA-491.

## Next

- Latin America's 50 Best 2026 on 1 December 2026: same pipeline.
- Show the rankings: the app's restaurant page and award history, and the
  site's restaurant pages and `/guides`, read `guide_awards_current` and
  `guide_coverage`. Never in gold.
- La Liste: permission request drafted in
  `docs/Architecture/guide_inventory/LA_LISTE_PERMISSION_REQUEST.md`, not sent.
