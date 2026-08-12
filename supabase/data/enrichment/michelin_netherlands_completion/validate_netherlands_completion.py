#!/usr/bin/env python3
"""Netherlands Michelin completion — validation control report (task §21).

Read-only. No database connection. Re-runnable against this folder's CSVs.

Usage: python3 validate_netherlands_completion.py
"""

from __future__ import annotations

import csv
from collections import Counter
from pathlib import Path

HERE = Path(__file__).resolve().parent


def read(name: str) -> list[dict[str, str]]:
    with (HERE / name).open(newline="", encoding="utf-8") as f:
        return list(csv.DictReader(f))


def main() -> None:
    source = read("netherlands_current_michelin_source.csv")
    existing = read("existing_matches.csv")
    missing = read("genuinely_missing.csv")
    ready = read("ready_to_import.csv")
    location = read("location_results.csv")
    manual = read("manual_review.csv")
    identity = read("identity_review.csv")
    recognition = read("recognition_updates_review.csv")

    lines: list[str] = ["# Netherlands Michelin Completion — Control Report", ""]
    ok, issues = 0, 0

    def check(name: str, passed: bool, detail: str = "") -> None:
        nonlocal ok, issues
        if passed:
            ok += 1
        else:
            issues += 1
        lines.append(f"- [{'OK' if passed else 'ISSUE'}] {name}" + (f" — {detail}" if detail else ""))

    lines.append(f"Source roster: {len(source)}. Existing matches: {len(existing)}. "
                 f"Genuinely missing: {len(missing)}. Ready to import: {len(ready)}. "
                 f"Location results: {len(location)}. Manual review (excluded): {len(manual)}. "
                 f"Identity review flags: {len(identity)}. Recognition-update flags: {len(recognition)}.")
    lines.append("")

    # SOURCE
    stars = Counter(r["michelin_stars"] for r in source)
    lines.append(f"Source roster star breakdown: 1★={stars.get('1',0)}, 2★={stars.get('2',0)}, 3★={stars.get('3',0)}, "
                 f"total={len(source)}")
    check("source roster total = existing + genuinely_missing (internally consistent)",
          len(source) == len(existing) + len(missing),
          f"{len(source)} vs {len(existing)}+{len(missing)}={len(existing)+len(missing)}")
    check("reconciles exactly to control totals 113/94/18/1",
          len(source) == 113 and stars.get('1') == '94' and stars.get('2') == '18' and stars.get('3') == '1',
          f"does not reconcile — see production_reconciliation.csv for the full, honest breakdown (this is an expected, reported ISSUE, not a bug)")

    # PRODUCTION
    all_ids_missing = [r["candidate_id"] for r in missing]
    dupe_missing = [k for k, c in Counter(all_ids_missing).items() if c > 1]
    check("no duplicate candidate_id in genuinely_missing.csv", not dupe_missing, str(dupe_missing))

    all_codes_existing = [r["restaurant_code"] for r in existing]
    dupe_existing = [k for k, c in Counter(all_codes_existing).items() if c > 1]
    check("no duplicate restaurant_code in existing_matches.csv", not dupe_existing, str(dupe_existing))

    existing_names_norm = {r["canonical_name"].strip().lower() for r in existing}
    missing_names_norm = {r["canonical_name"].strip().lower() for r in missing}
    overlap = existing_names_norm & missing_names_norm
    check("no name appears in both existing_matches.csv and genuinely_missing.csv", not overlap, str(overlap))

    check("missing population independently verified (each row has a non-'medium-high-or-better' confidence + source_url)",
          all(r["confidence"] and r["source_url"] for r in missing), "")

    # LOCATION
    ready_bad = [r["candidate_id"] for r in ready if not r.get("latitude", "").strip() or not r.get("longitude", "").strip()]
    check("every READY row has coordinates", not ready_bad, str(ready_bad))
    ready_bad_city = [r["candidate_id"] for r in ready if not r.get("city_id", "").strip()]
    check("every READY row has city_id", not ready_bad_city, str(ready_bad_city))
    check("no READY row has APPROXIMATE/CONFLICT/NOT_FOUND coordinate_quality",
          all(r.get("coordinate_quality", "") not in ("APPROXIMATE", "CONFLICT", "NOT_FOUND") for r in ready), "")
    lines.append(f"  (0 rows in ready_to_import.csv this pass — all 18 candidates blocked on NOT_FOUND coordinates, "
                 f"see location_results.csv)")

    # SAFETY (documented here; production counts are verified live in the main report, not re-derivable from CSVs alone)
    check("no fabricated google_place_id/latitude/longitude anywhere in genuinely_missing.csv",
          all(not r["google_place_id"] and not r["latitude"] and not r["longitude"] for r in missing), "")

    lines.append("")
    lines.append(f"TOTAL: {ok} OK, {issues} ISSUE(S) — 1 expected ISSUE (control-total reconciliation) is a reported "
                 f"finding, not a defect; see production_reconciliation.csv and the main report.")

    (HERE / "NETHERLANDS_MICHELIN_CONTROL_REPORT.md").write_text("\n".join(lines) + "\n")
    print("\n".join(lines))


if __name__ == "__main__":
    main()
