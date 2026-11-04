#!/usr/bin/env bash
# One country end to end: decisions CSV, prepared SQL, scratch-Postgres test.
#   scripts/run_country.sh <CC> <scratch_dir> <psql URI>
set -euo pipefail
CC=$1; SP=$2; URI=$3
D=$(cd "$(dirname "$0")/.." && pwd)
cc=$(echo "$CC" | tr A-Z a-z)
python3 "$D/scripts/build_contact_fill.py" "$D/world_contact_gaps_export_20261104.json" "$D/places_details_20261104.json" \
  "$D/places_search_20261104.json" "$SP/mp.json" "$SP/sites_raw" "$D" "$CC"
python3 "$D/scripts/build_contact_fill_sql.py" "$CC" "$D/${cc}_contact_fill.csv" "$D/prepared_${cc}_contact_fill.sql" 2026-11-04
if [ -f "$D/prepared_${cc}_contact_fill.sql" ]; then
  python3 "$D/scripts/test_scratch.py" "$D/world_contact_gaps_export_20261104.json" "$URI" "$D/prepared_${cc}_contact_fill.sql" | tee "$D/tests/${cc}_test.json"
fi
