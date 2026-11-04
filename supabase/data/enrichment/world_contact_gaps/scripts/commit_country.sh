#!/usr/bin/env bash
# Refresh the shared JSON snapshots and progress.csv, then commit and push the given countries.
set -euo pipefail
SP=$1; shift
D=$(cd "$(dirname "$0")/.." && pwd)
cp "$SP/mp.json" "$D/michelin_pages_parsed_20261104.json"
cp "$SP/sites_raw/index.json" "$D/sites_index_20261104.json"
python3 "$D/scripts/progress.py" "$D/world_contact_gaps_export_20261104.json" "$D"
if grep -l "$GOOGLE_PLACES_API_KEY" "$D"/*.json "$D"/*.csv "$D"/*.sql 2>/dev/null; then echo "API key found in output" >&2; exit 1; fi
cd "$D"
git add -A .
git commit -q -m "World contact gaps: $* (prepared, not applied)

Fill-only proposal from the 2026-11-04 export: decisions per row in
<cc>_contact_fill.csv, prepared_<cc>_contact_fill.sql tested on scratch
Postgres (applies, re-run is a no-op, a renamed row aborts).

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01PyW3xgLL4CvAGrfMip6jkb"
for i in 1 2 3 4; do git push -q -u origin claude/world-contact-gaps && break || sleep $((2**i)); done
git log --oneline -1
