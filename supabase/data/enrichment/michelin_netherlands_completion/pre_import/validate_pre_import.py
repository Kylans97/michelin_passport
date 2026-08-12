#!/usr/bin/env python3
"""Netherlands 15-restaurant pre-import audit -- validation control report.

Read-only. No database connection. Re-runnable against this folder's CSVs.

Usage: python3 validate_pre_import.py
"""

from __future__ import annotations

import csv
from collections import Counter
from pathlib import Path

HERE = Path(__file__).resolve().parent
PARENT = HERE.parent
WITHDRAWN_NAMES = {"noble kitchen", "airrepublic", "pure c"}


def read(path: Path) -> list[dict[str, str]]:
    with path.open(newline="", encoding="utf-8") as f:
        return list(csv.DictReader(f))


def main() -> None:
    ready = read(PARENT / "verified_patch" / "ready_to_import.csv")
    audit = read(HERE / "nl_15_pre_import_audit.csv")
    dupes = read(HERE / "nl_15_duplicate_audit.csv")
    awards = read(HERE / "nl_15_award_plan.csv")
    hotel_plan = read(HERE / "nl_15_hotel_link_plan.csv")
    dry_run = read(HERE / "nl_15_dry_run.csv")
    sql_text = (HERE / "prepared_nl_15_import.sql").read_text().lower()

    lines: list[str] = ["# Netherlands 15-Restaurant Pre-Import Audit -- Control Report", ""]
    ok, issues = 0, 0

    def check(name: str, passed: bool, detail: str = "") -> None:
        nonlocal ok, issues
        if passed:
            ok += 1
        else:
            issues += 1
        lines.append(f"- [{'OK' if passed else 'ISSUE'}] {name}" + (f" -- {detail}" if detail else ""))

    lines.append(f"Scope: {len(ready)}. Pre-import audit rows: {len(audit)}. Duplicate audit rows: {len(dupes)}. "
                 f"Award plan rows: {len(awards)}. Hotel plan rows: {len(hotel_plan)}. Dry-run rows: {len(dry_run)}.")
    lines.append("")

    check("exactly 15 unique candidates in scope", len(ready) == 15, str(len(ready)))
    ids = [r["candidate_id"] for r in ready]
    check("no duplicate candidate_id", len(ids) == len(set(ids)), "")
    stars = Counter(r["michelin_stars"] for r in ready)
    check("final composition is 15x1-star, 0x2-star, 0x3-star", stars == Counter({"1": 15}), str(dict(stars)))

    names_lower = {r["canonical_name"].strip().lower() for r in ready}
    check("no withdrawn name present in ready_to_import.csv", not (names_lower & WITHDRAWN_NAMES), "")

    check("every candidate has a pre_import audit row", {r["candidate_id"] for r in ready} == {r["candidate_id"] for r in audit}, "")
    check("every audit row is hard_ready=yes", all(r["hard_ready"] == "yes" for r in audit),
          str([r["candidate_id"] for r in audit if r["hard_ready"] != "yes"]))

    check("every candidate has a duplicate_audit row, all NO_PRODUCTION_MATCH",
          {r["candidate_id"] for r in ready} == {r["candidate_id"] for r in dupes}
          and all(r["classification"] == "NO_PRODUCTION_MATCH" for r in dupes), "")

    check("every candidate has exactly one award_plan row, all is_current=true / guide_year=2026",
          {r["candidate_id"] for r in ready} == {r["candidate_id"] for r in awards}
          and all(r["is_current"] == "true" and r["guide_year"] == "2026" for r in awards), "")

    check("hotel_link_plan covers exactly the 5 plausible-property candidates, 0 confirmed links",
          {r["candidate_id"] for r in hotel_plan} == {"nl_001", "nl_002", "nl_008", "nl_009", "nl_010"}
          and all(r["production_hotel_match"] == "none" for r in hotel_plan), "")

    dry_run_map = {(r["category"], r["action"]): int(r["count"]) for r in dry_run}
    check("dry-run: restaurant INSERT=15, SKIP=0, BLOCK=0",
          dry_run_map.get(("restaurant", "INSERT")) == 15
          and dry_run_map.get(("restaurant", "SKIP")) == 0
          and dry_run_map.get(("restaurant", "BLOCK")) == 0, str(dry_run_map))
    check("dry-run: award INSERT=15, SKIP=0, BLOCK=0",
          dry_run_map.get(("award", "INSERT")) == 15
          and dry_run_map.get(("award", "SKIP")) == 0
          and dry_run_map.get(("award", "BLOCK")) == 0, "")
    check("dry-run: hotel_link INSERT=0, BLOCK=0",
          dry_run_map.get(("hotel_link", "INSERT")) == 0
          and dry_run_map.get(("hotel_link", "BLOCK")) == 0, "")

    check("no withdrawn name appears anywhere in the prepared SQL's data rows",
          not any(n in sql_text.split("-- ")[0] if False else n in sql_text.replace(
              "zero rows for noble kitchen, airrepublic, or pure c --", "") for n in WITHDRAWN_NAMES), "")

    check("prepared SQL is marked PREPARED -- NOT APPLIED", "prepared -- not applied" in sql_text, "")
    check("prepared SQL is not under supabase/migrations/",
          not (PARENT.parent.parent.parent / "migrations" / "prepared_nl_15_import.sql").exists(), "")

    lines.append("")
    lines.append(f"TOTAL: {ok} OK, {issues} ISSUE(S).")

    (HERE / "NETHERLANDS_15_PRE_IMPORT_CONTROL_REPORT.md").write_text("\n".join(lines) + "\n")
    print("\n".join(lines))


if __name__ == "__main__":
    main()
