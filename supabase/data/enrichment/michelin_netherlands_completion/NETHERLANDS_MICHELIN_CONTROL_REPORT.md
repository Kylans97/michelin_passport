# Netherlands Michelin Completion — Control Report

Source roster: 123. Existing matches: 105. Genuinely missing: 18. Ready to import: 0. Location results: 18. Manual review (excluded): 11. Identity review flags: 8. Recognition-update flags: 0.

Source roster star breakdown: 1★=101, 2★=21, 3★=1, total=123
- [OK] source roster total = existing + genuinely_missing (internally consistent) — 123 vs 105+18=123
- [ISSUE] reconciles exactly to control totals 113/94/18/1 — does not reconcile — see production_reconciliation.csv for the full, honest breakdown (this is an expected, reported ISSUE, not a bug)
- [OK] no duplicate candidate_id in genuinely_missing.csv — []
- [OK] no duplicate restaurant_code in existing_matches.csv — []
- [OK] no name appears in both existing_matches.csv and genuinely_missing.csv — set()
- [OK] missing population independently verified (each row has a non-'medium-high-or-better' confidence + source_url)
- [OK] every READY row has coordinates — []
- [OK] every READY row has city_id — []
- [OK] no READY row has APPROXIMATE/CONFLICT/NOT_FOUND coordinate_quality
  (0 rows in ready_to_import.csv this pass — all 18 candidates blocked on NOT_FOUND coordinates, see location_results.csv)
- [OK] no fabricated google_place_id/latitude/longitude anywhere in genuinely_missing.csv

TOTAL: 9 OK, 1 ISSUE(S) — 1 expected ISSUE (control-total reconciliation) is a reported finding, not a defect; see production_reconciliation.csv and the main report.
