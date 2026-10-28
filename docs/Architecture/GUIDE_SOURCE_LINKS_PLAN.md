# Guide source links and award history — findings and data plan

2026-10-28. Branch `feature/guide-sources`. Production was only read; no
migration was written and nothing was changed in Supabase.

## What production holds today

| Guide | Award data | Per-venue page URL |
|---|---|---|
| MICHELIN | `restaurants.michelin_stars`, `hotels.michelin_keys`, `award_history` | `restaurants.michelin_url` (1,008 of 1,581), `hotels.michelin_url` (137 of 811) |
| World's 50 Best, restaurants | `worlds_50_best` (843 rows, 2002–2025, 143 restaurants) | **none stored anywhere** |
| World's 50 Best, hotels | `worlds_50_best_hotels` (293 rows, 2023–2026, 134 hotels) | **none stored anywhere** |
| Gault&Millau | `gault_millau_awards` (41 rows, 2026 edition only) | `gault_millau_awards.gault_millau_url`: 33 real URLs, **8 hold placeholder text** |

The 8 placeholders are all Austrian rows from the 2026 import: Döllerer,
Ikarus, Mraz & Sohn, Obauer, Silvio Nickol Gourmet Restaurant, Stüva and
Taubenkobel read `not found`, and Konstantin Filippou reads `not found
(guessed slug 404'd)`. The import CSV used `"not found"` as a placeholder
and it was written through as text instead of NULL.
`gault_millau_special_awards.gault_millau_url` is empty on all 58 rows.

Spot check: the stored De Librije URL
(`https://www.gault-millau.nl/en/restaurants/de-librije-zwolle`) resolves to
De Librije, Spinhuisplein 1, Zwolle, showing 19.5. That matches the row.

## What the app does now (this branch, app-only)

- **Gault&Millau on Restaurant Detail.** The latest edition shows as a hero
  badge (`Gault&Millau · 19.5/20`), and a **Gault&Millau** action in the
  utility row opens the stored page. That action only appears when the
  value is an absolute http(s) URL (`GaultMillauAward.profileUrl`), so the
  8 placeholders show the award but no link.
- **Award History** now has a Gault&Millau section, one row per edition,
  under MICHELIN and World's 50 Best. The "Award history" action also
  appears for a restaurant whose only history is Gault&Millau.
- Like the MICHELIN link, these appear whichever way the restaurant was
  opened (Guides, Explore, search, Passport). The app has no "opened
  from guide X" state, and showing a verified source link in only one
  entry path would hide it from the others.

MICHELIN and World's 50 Best were already in Award History, and nothing
was filtered out. De Librije has 4 MICHELIN transitions (1993→2025) and 10
World's 50 Best years (2010–2021). It has no hero rank badge because its
last ranking was 2021 and `restaurants_full.worlds_50_best_rank` reads only
the latest list year. That is correct, not a bug.

## Status, 2026-10-28 (after the go-ahead to prepare)

Prepared and committed, **not applied**. Production is unchanged.
- Migration `supabase/migrations/20261021120000_add_worlds_50_best_urls.sql`
  adds `worlds_50_best_url` to `restaurants` and `hotels` and appends it to
  `restaurants_full`/`hotels_full`. A static check against production
  confirms both views keep all 47/43 live columns in place and only
  append the new one. It was not replay-tested: this machine has no
  Docker for a local stack.
- Data, sourced and verified, in
  `supabase/data/enrichment/guide_source_links/` (method in its README):
  113/143 restaurant and 123/134 hotel World's 50 Best URLs, 7/8 Austrian
  Gault&Millau URLs, 21 toque counts. `apply_guide_source_links.sql` does
  all of it in one transaction with row-count guards, and a read-only dry
  run matched every count.
- The site is now **the50.com**; `theworlds50best.com` 301-redirects
  there. Per-venue profiles (`discovery/Establishments/...`) also exist
  for venues no longer ranked, so they are what's stored.
- New findings: QA-232 to QA-236 in `supabase/data/qa_issues.csv`.
  Notably, Award History is missing 9 verified-restaurant rank-years
  (QA-234), and profile rank lines can contradict the official lists
  (QA-235).

Order to go live: apply the migration → run the data SQL → ship the app
change below. The app change can't merge before the migration is live.

## Missing data — original proposal

### 1. World's 50 Best venue pages (needs a migration + data)

The official site has a stable per-establishment profile that doesn't
depend on the year, e.g.
`https://www.theworlds50best.com/discovery/Establishments/Netherlands/Zwolle/De-Librije.html`.
The yearly list pages (`/the-list/1-50`, `/hotels/list/2025`) are not
per-venue. Hotel profile URLs were not confirmed in this pass and need
their own check before they are sourced.

Proposed schema (one migration, named after the highest migration in the
ledger at the time; currently after `20261020120000` on
`feature/editorial-selection`):

```sql
alter table public.restaurants add column worlds_50_best_url text unique;
alter table public.hotels      add column worlds_50_best_url text unique;
-- then recreate restaurants_full / hotels_full so r.* / h.* pick them up
-- (both are `select r.*` views, which freeze their column list at create).
```

A URL is a property of the venue, not of a year, so it sits on the venue
next to `michelin_url` and not on `worlds_50_best` rows. No new function
is involved, so no `revoke execute` is needed. The catalogue's RLS is
unchanged.

**Sourcing and verification, per venue (143 restaurants, 134 hotels):**
1. Start from the venue's name in the official list page for a year it is
   ranked in, and follow the link from that list. Never build the slug
   from our own name.
2. Open the profile and confirm that its name, city and country match our
   row (code + country, never the name alone; IGNIV and La Brezza are
   multi-location brands).
3. Record `restaurant_code`/`hotel_code`, URL, retrieval date and the list
   page it was reached from in a staging CSV under
   `supabase/data/enrichment/worlds_50_best_urls/`. Anything ambiguous goes
   into `qa_issues.csv`, not the CSV.
4. Apply as a reviewed data update, logged in the Michelin_Database
   CHANGELOG.

App change once the data lands: add `worlds50BestUrl` to `Restaurant` and
`Hotel`, select it in `restaurantFullColumns`/the hotel column list, and
add a **50 Best** utility action on both detail screens. Do this only
after the migration is live. A build that selects a column which doesn't
exist yet fails the whole query.

### 2. Gault&Millau placeholders (data correction, no migration)

```sql
update public.gault_millau_awards
   set gault_millau_url = null
 where gault_millau_url !~ '^https?://';   -- expected: 8 rows
```

This needs a `qa_issues.csv` id and a Michelin_Database CHANGELOG entry.
The app already ignores these values, so it is cleanup, not a fix the
app depends on. Separately, those 8 restaurants' real pages on
`gaultmillau.at` can be looked up by the same verification steps as
above. "guessed slug 404'd" is a reminder that a slug must never be
guessed.

### 3. Toque counts missing on Benelux/CH rows (data, no migration)

On the simulator check, De Librije's own Gault&Millau page shows
**19.5/20 with 5 toques**, but its row has `toque_count` NULL, as does
every BE, CH and NL row except GEM. The app shows only the score, so
nothing is wrong on screen; the toques simply aren't in the data. Fill
them per restaurant from each row's own `gault_millau_url` page, the same
way, and log the source in the Michelin_Database CHANGELOG.

### 4. Hotels and Gault&Millau

Gault&Millau has no hotel table, and nothing here calls for one.
