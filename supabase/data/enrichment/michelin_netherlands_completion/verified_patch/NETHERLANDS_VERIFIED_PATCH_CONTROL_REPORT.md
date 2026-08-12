# Netherlands 18-Restaurant Verified Patch -- Control Report

Scope: 18. City reconciliation rows: 18. Proposed cities: 12. Location results: 18. Hotel link review: 7. Duplicate checks: 18. READY_TO_IMPORT: 15. LOCATION_READY_CITY_PENDING: 0. REMOVED_NOT_GENUINELY_MISSING: 3. (manual_review.csv is now a historical resolution log for all 4 originally-flagged conflicts, 4 rows, all resolved -- not a live population.)

- [OK] exactly 18 unique candidates in scope -- 18
- [OK] no duplicate candidate_id in scope
- [OK] exactly 17x1-star + 1x2-star -- {'1': 17, '2': 1}
- [OK] Merlet present
- [OK] Latour present
- [OK] every scope candidate has a city_reconciliation row
- [OK] city classification tally is CITY_MATCHED=6 / CITY_MISSING=12 -- {'CITY_MISSING': 12, 'CITY_MATCHED': 6}
- [OK] every proposed city has country_code=NL
- [OK] no duplicate proposed city rows (name+region)
- [OK] every scope candidate has a location_results row
- [OK] all READY/PENDING rows have VENUE_EXACT/ADDRESS_EXACT/PROPERTY_EXACT coordinate_quality
- [OK] 18/18 candidates classified into exactly one final population (READY / PENDING / REMOVED) -- 18 entries, 18 unique
- [OK] no candidate appears in more than one final population
- [OK] manual_review.csv resolution log covers exactly the 4 originally-flagged candidates, all resolved
- [OK] every removed candidate has a removal_reason and related evidence
- [OK] nl_003 READY_TO_IMPORT satisfies hard requirements
- [OK] nl_015 READY_TO_IMPORT satisfies hard requirements
- [OK] nl_016 READY_TO_IMPORT satisfies hard requirements
- [OK] nl_014 READY_TO_IMPORT satisfies hard requirements
- [OK] nl_001 READY_TO_IMPORT satisfies hard requirements
- [OK] nl_002 READY_TO_IMPORT satisfies hard requirements
- [OK] nl_004 READY_TO_IMPORT satisfies hard requirements
- [OK] nl_005 READY_TO_IMPORT satisfies hard requirements
- [OK] nl_007 READY_TO_IMPORT satisfies hard requirements
- [OK] nl_008 READY_TO_IMPORT satisfies hard requirements
- [OK] nl_009 READY_TO_IMPORT satisfies hard requirements
- [OK] nl_010 READY_TO_IMPORT satisfies hard requirements
- [OK] nl_011 READY_TO_IMPORT satisfies hard requirements
- [OK] nl_012 READY_TO_IMPORT satisfies hard requirements
- [OK] nl_013 READY_TO_IMPORT satisfies hard requirements
- [OK] no fabricated coordinates on removed rows (should have none) -- removed_not_genuinely_missing.csv intentionally carries no lat/lon columns

TOTAL: 31 OK, 0 ISSUE(S).

Final populations: READY_TO_IMPORT=15, LOCATION_READY_CITY_PENDING=0, REMOVED_NOT_GENUINELY_MISSING=3, sum=18 (expected 18).
