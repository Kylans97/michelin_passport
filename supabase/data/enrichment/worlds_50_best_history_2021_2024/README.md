# World's 50 Best history gaps, 2021–2024 (QA-246)

2026-10-28, `data/w50b-history-gaps`. **Not applied.** Production is
unchanged until `apply_top_50_rank_years.sql` is reviewed and run.

## Finding

`worlds_50_best` is **accurate but incomplete**. For 2021–2024, every rank
we hold matches the official list; there are zero mismatches. But we hold
only 56, 60, 68 and 65 of the 100 slots in those years. Many restaurants
carry just one row, typically their latest appearance, so Award History
misses earlier years. Example: A Casa do Porco had only 2025 (No.83), and
was also No.17 in 2021, No.7 in 2022, No.12 in 2023 and No.27 in 2024.

Of the 142 missing slots in those four years:

| | Slots | What happens |
|---|---|---|
| Top 50, restaurant in our catalogue, proven | **29** | `top_50_rank_years.csv` `apply=yes` → `apply_top_50_rank_years.sql` |
| Top 50, in catalogue, not proven (Le Clarence 2022) | 1 | `apply=no`; its entry page shows none of our phone, website or address |
| 51–100, restaurant in our catalogue | 55 | `extended_51_100_review.csv`: name and city only, so not applied (see below) |
| Restaurant not in our catalogue | 66 | Nothing to do: unstarred and not currently ranked, so out of scope |

Years before 2021 weren't checked. The same pattern almost certainly holds
there (QA-250).

## Source and proof

**Official lists:** archived copies of `theworlds50best.com/list/1-50` (the
page lists all 100) from the Wayback Machine. One snapshot per year, taken
after that year's announcement: 2021-11-09, 2022-09-04, 2023-09-05,
2024-10-02. Each snapshot's No.1 confirms its year: Noma, Geranium,
Central, Disfrutar. All four, with ranks, names and locations, are in
`official_lists_2021_2024.csv`. The live site (the50.com) couldn't be
used: its previous-list pages ignore the year in the address and print
every year unlabelled.

**A row is applied only when both hold:**
1. **Rank and year:** the official entry page's title states that exact
   year and rank ("Hof Van Cleve | The World's 50 Best Restaurants 2021 |
   Ranked No. 36"). Entry-page URLs are reused across years, so an archive
   snapshot can carry another year's text. That happened for 6 pages. Three
   were fixed by finding the right snapshot (the snapshot is recorded in
   `source`).
2. **Identity**, never the name: the entry page shows our phone, our own
   website domain or our street + house number (`evidence`). For the other
   3 drifted pages (Nobelhart & Schmutzig 2024, Oteque 2024, The Clove Club
   2022), identity comes from the restaurant's own the50.com profile,
   already tied to it by phone or website in `guide_source_links`. That
   profile states the same rank and year, which the official list confirms
   at that slot.

51–100 entries have no entry pages; the list shows only name and city.
Under the never-match-on-name rule those 55 stay in review (QA-249). A link for
each could come from the 51–100 press release or a restaurant's own
profile line.

## The SQL

`apply_top_50_rank_years.sql` (regenerate with `generate_apply_sql.py`):
one transaction. It aborts if any code no longer carries its expected name,
if any (year, rank) slot is taken, if any restaurant already has a row
that year, or if the insert count isn't exactly 29. A read-only dry run on
2026-10-28 passed all of these (29 / 0 / 0 / 0).

It changes history only: `restaurants_full.worlds_50_best_rank` reads the
latest list year (2025), so no current rank changes.

`verify_slots.py` is the checker, kept so the method can be audited and
rerun.
