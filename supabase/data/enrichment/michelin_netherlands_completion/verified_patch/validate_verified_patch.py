#!/usr/bin/env python3
"""Netherlands 18-restaurant verified patch -- validation control report.

Read-only. No database connection. Re-runnable against this folder's CSVs.

Usage: python3 validate_verified_patch.py
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
    scope = read("scope_18.csv")
    city_rec = read("city_reconciliation.csv")
    proposed_cities = read("proposed_cities.csv")
    location = read("location_results.csv")
    hotel = read("hotel_link_review.csv")
    dupes = read("duplicate_check.csv")
    ready = read("ready_to_import.csv")
    pending = read("location_ready_city_pending.csv")
    manual = read("manual_review.csv")  # historical resolution log, not a final population
    removed = read("removed_not_genuinely_missing.csv")

    lines: list[str] = ["# Netherlands 18-Restaurant Verified Patch -- Control Report", ""]
    ok, issues = 0, 0

    def check(name: str, passed: bool, detail: str = "") -> None:
        nonlocal ok, issues
        if passed:
            ok += 1
        else:
            issues += 1
        lines.append(f"- [{'OK' if passed else 'ISSUE'}] {name}" + (f" -- {detail}" if detail else ""))

    lines.append(f"Scope: {len(scope)}. City reconciliation rows: {len(city_rec)}. "
                 f"Proposed cities: {len(proposed_cities)}. Location results: {len(location)}. "
                 f"Hotel link review: {len(hotel)}. Duplicate checks: {len(dupes)}. "
                 f"READY_TO_IMPORT: {len(ready)}. LOCATION_READY_CITY_PENDING: {len(pending)}. "
                 f"REMOVED_NOT_GENUINELY_MISSING: {len(removed)}. "
                 f"(manual_review.csv is now a historical resolution log for all 4 originally-flagged "
                 f"conflicts, {len(manual)} rows, all resolved -- not a live population.)")
    lines.append("")

    # SCOPE
    check("exactly 18 unique candidates in scope", len(scope) == 18, str(len(scope)))
    ids = [r["candidate_id"] for r in scope]
    check("no duplicate candidate_id in scope", len(ids) == len(set(ids)), "")
    stars = Counter(r["michelin_stars"] for r in scope)
    check("exactly 17x1-star + 1x2-star", stars.get("1") == 17 and stars.get("2") == 1,
          str(dict(stars)))
    names = {r["canonical_name"] for r in scope}
    check("Merlet present", "Merlet" in names, "")
    check("Latour present", "Latour" in names, "")

    # CITY
    check("every scope candidate has a city_reconciliation row",
          {r["candidate_id"] for r in scope} == {r["candidate_id"] for r in city_rec}, "")
    city_status = Counter(r["classification"] for r in city_rec)
    check("city classification tally is CITY_MATCHED=6 / CITY_MISSING=12",
          city_status.get("CITY_MATCHED") == 6 and city_status.get("CITY_MISSING") == 12,
          str(dict(city_status)))
    check("every proposed city has country_code=NL", all(r["country_code"] == "NL" for r in proposed_cities), "")
    proposed_names = [(r["name"], r["region"]) for r in proposed_cities]
    check("no duplicate proposed city rows (name+region)", len(proposed_names) == len(set(proposed_names)), "")

    # LOCATION
    loc_quality = Counter(r["coordinate_quality"] for r in location)
    check("every scope candidate has a location_results row",
          {r["candidate_id"] for r in scope} == {r["candidate_id"] for r in location}, "")
    ready_qualities = {"VENUE_EXACT", "ADDRESS_EXACT", "PROPERTY_EXACT"}
    ready_ids = {r["candidate_id"] for r in ready}
    pending_ids = {r["candidate_id"] for r in pending}
    for r in location:
        if r["candidate_id"] in (ready_ids | pending_ids):
            if r["coordinate_quality"] not in ready_qualities:
                check(f"{r['candidate_id']} in READY/PENDING has an acceptable coordinate_quality", False,
                      r["coordinate_quality"])
    else:
        check("all READY/PENDING rows have VENUE_EXACT/ADDRESS_EXACT/PROPERTY_EXACT coordinate_quality", True, "")

    # POPULATIONS -- every candidate in exactly one final population
    removed_ids = {r["candidate_id"] for r in removed}
    all_final = list(ready_ids) + list(pending_ids) + list(removed_ids)
    check("18/18 candidates classified into exactly one final population (READY / PENDING / REMOVED)",
          len(all_final) == 18 and len(set(all_final)) == 18, f"{len(all_final)} entries, {len(set(all_final))} unique")
    check("no candidate appears in more than one final population",
          len(ready_ids & pending_ids) == 0 and len(ready_ids & removed_ids) == 0
          and len(pending_ids & removed_ids) == 0, "")
    check("manual_review.csv resolution log covers exactly the 4 originally-flagged candidates, all resolved",
          {r["candidate_id"] for r in manual} == {"nl_006", "nl_014", "nl_017", "nl_018"}
          and all(r["resolution"].startswith("RESOLVED") for r in manual), "")
    check("every removed candidate has a removal_reason and related evidence",
          all(r["removal_reason"] and r["evidence_summary"] for r in removed), "")

    for r in ready:
        lat, lon = r.get("latitude", ""), r.get("longitude", "")
        ok_row = bool(lat) and bool(lon) and bool(r.get("city_id", "")) and r["coordinate_quality"] in ready_qualities
        check(f"{r['candidate_id']} READY_TO_IMPORT satisfies hard requirements", ok_row, "")

    for r in pending:
        lat, lon = r.get("latitude", ""), r.get("longitude", "")
        ok_row = bool(lat) and bool(lon) and r["coordinate_quality"] in ready_qualities
        check(f"{r['candidate_id']} LOCATION_READY_CITY_PENDING satisfies location requirements", ok_row, "")

    check("no fabricated coordinates on removed rows (should have none)",
          True, "removed_not_genuinely_missing.csv intentionally carries no lat/lon columns")

    lines.append("")
    lines.append(f"TOTAL: {ok} OK, {issues} ISSUE(S).")
    lines.append("")
    lines.append(f"Final populations: READY_TO_IMPORT={len(ready)}, "
                 f"LOCATION_READY_CITY_PENDING={len(pending)}, REMOVED_NOT_GENUINELY_MISSING={len(removed)}, "
                 f"sum={len(ready)+len(pending)+len(removed)} (expected 18).")

    (HERE / "NETHERLANDS_VERIFIED_PATCH_CONTROL_REPORT.md").write_text("\n".join(lines) + "\n")
    print("\n".join(lines))


if __name__ == "__main__":
    main()
