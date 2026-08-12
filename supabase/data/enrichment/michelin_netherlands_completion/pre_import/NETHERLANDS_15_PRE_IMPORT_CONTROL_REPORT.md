# Netherlands 15-Restaurant Pre-Import Audit -- Control Report

Scope: 15. Pre-import audit rows: 15. Duplicate audit rows: 15. Award plan rows: 15. Hotel plan rows: 5. Dry-run rows: 9.

- [OK] exactly 15 unique candidates in scope -- 15
- [OK] no duplicate candidate_id
- [OK] final composition is 15x1-star, 0x2-star, 0x3-star -- {'1': 15}
- [OK] no withdrawn name present in ready_to_import.csv
- [OK] every candidate has a pre_import audit row
- [OK] every audit row is hard_ready=yes -- []
- [OK] every candidate has a duplicate_audit row, all NO_PRODUCTION_MATCH
- [OK] every candidate has exactly one award_plan row, all is_current=true / guide_year=2026
- [OK] hotel_link_plan covers exactly the 5 plausible-property candidates, 0 confirmed links
- [OK] dry-run: restaurant INSERT=15, SKIP=0, BLOCK=0 -- {('restaurant', 'INSERT'): 15, ('restaurant', 'SKIP'): 0, ('restaurant', 'BLOCK'): 0, ('award', 'INSERT'): 15, ('award', 'SKIP'): 0, ('award', 'BLOCK'): 0, ('hotel_link', 'INSERT'): 0, ('hotel_link', 'SKIP'): 5, ('hotel_link', 'BLOCK'): 0}
- [OK] dry-run: award INSERT=15, SKIP=0, BLOCK=0
- [OK] dry-run: hotel_link INSERT=0, BLOCK=0
- [OK] no withdrawn name appears anywhere in the prepared SQL's data rows
- [OK] prepared SQL is marked PREPARED -- NOT APPLIED
- [OK] prepared SQL is not under supabase/migrations/

TOTAL: 15 OK, 0 ISSUE(S).
