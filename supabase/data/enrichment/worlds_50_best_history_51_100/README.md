# World's 50 Best 51–100 history, 2021–2024 (QA-249)

2026-10-29, `data/w50b-history-older`. **Applied to production 2026-10-29**:
39 rows inserted, all guards passed (936 → 975 rows), and recorded in
the Michelin_Database CHANGELOG.

## Proof: stricter than name and city

The newer 51–100 places keep the full rule: no name-only matches. The
official 51–100 lists for 2021–2024 give only name and city, but each
year's official **51–100 announcement story** on the50.com links every
ranked entry ("No.67" …) to that restaurant's the50.com profile:

- 2021: `worlds-50-best-restaurants-2021-51-100-list`
- 2023: `the-worlds-50-best-restaurants-2023-51-100-list`
- 2024: `the-worlds-50-best-restaurants-2024-51-100-list`

**A rank-year is applied only when** the story pairs that "No.N" heading
with a profile link, and that profile is ours by something other than its
name:

- **27:** the link equals the `worlds_50_best_url` we already proved by
  phone, website or address (`guide_source_links`). Old-domain links were
  compared after normalising the domain and accents.
- **12:** we had no proven URL, so the linked profile was fetched and
  showed our phone, own website or street + house number, the same test
  the URL matcher uses. These are Nerua, The Jane, Epicure, Le Clarence ×2,
  La Grenouillère ×2, Alléno ×2, Flocons de Sel ×2 and Kei.

Each rank also sits at that place on the official list for the year
(`../worlds_50_best_history_2021_2024/official_lists_2021_2024.csv`).

## Not applied: 14 (`rank_years.csv`, `apply=no`)

| | Places | Why |
|---|---|---|
| 2022 | 10 | That year's story ("in pictures") has no profile links |
| La Colombe 2021, 2023 | 2 | The linked profile no longer exists, so there's nothing to prove it with. Note that its sibling La Petite Colombe was a wrong-record trap earlier |
| Labyrinth 2024 | 1 | The linked profile URL (no city segment) differs from our proven one |
| Mountain 2024 | 1 | The story doesn't link this entry |

## The SQL

`apply_51_100_rank_years.sql` (regenerate with `generate_apply_sql.py`)
inserts the 39 as `extended_51_100`, in one transaction with the usual
guards. A read-only dry run passed: 39/39 codes carry the expected name,
with no taken places or years and no duplicates.
