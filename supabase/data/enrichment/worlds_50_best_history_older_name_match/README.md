# World's 50 Best history, 2002–2017, matched by name and city (QA-250)

2026-10-29, `data/w50b-history-older`. **Applied to production 2026-10-29**:
51 rows inserted, all guards passed (885 → 936 rows), and recorded in
the Michelin_Database CHANGELOG.

## A deliberate exception to "never match on name"

Decided by the product owner on 2026-10-29. For these years the archive
holds the official list (name and city) but no entry pages, so there is
no phone, website or address left to prove identity. Older Top 50 places
may therefore be matched by **name and city**. Newer places, 51–100 for
2021–2024 (QA-249), still need more than that.

The exception covers only this file. It doesn't change the rule anywhere
else: search, dedupe and linking still key on code + country.

## What was matched, and what wasn't

The 61 candidates come from
`../worlds_50_best_history_batch_2/top_50_name_city_review.csv`: official
2002–2017 Top 50 places, accepted per year by heading, known winner and an
exact fingerprint (2016 excluded). Each was checked by hand for being the
**same restaurant**, not just the same name (`decision`, `basis` in
`top_50_rank_years.csv`):

| Decision | Places | |
|---|---|---|
| apply | 51 | Same name and same city; or the same restaurant at a new address: Troisgros Roanne → Ouches, Guy Savoy rue Troyon → Monnaie de Paris, La Colombe Constantia Uitsig → Silvermist, Astrance within Paris |
| exclude | 5 | Not our restaurant: "Les Ambassadeurs" ×3 (matched "ES" by accident); "Alain Ducasse" 2005/06 is Ducasse au Plaza Athénée, not Le Meurice |
| hold | 5 | "Le Meurice" ×3 (2004/05/08) is Yannick Alléno's era, before our Restaurant Le Meurice Alain Ducasse, the same pattern as the Plaza Athénée successor case. "Le Jardin des Sens" ×2: the Pourcels' original closed, and continuity with our row isn't confirmed |

## The SQL

`apply_top_50_rank_years.sql` (regenerate with `generate_apply_sql.py`):
one transaction with the same guards as batches 1 and 2. A read-only dry
run passed: 51/51 codes carry the expected name, no taken places or years,
and no duplicates. The table held 885 rows.
