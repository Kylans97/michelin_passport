#!/usr/bin/env python3
"""Belgium/France 573-record pre-import audit -- validation control report.

Read-only. No database connection. Re-runnable against this folder's CSVs.
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
    master = read("be_fr_pre_import_master.csv")
    be = read("be_pre_import_approved.csv")
    fr = read("fr_pre_import_approved.csv")
    review = read("pre_import_review.csv")
    dupes = read("duplicate_audit.csv")
    evidence = read("evidence_audit.csv")
    recognition = read("recognition_discrepancy_audit.csv")
    hotel = read("hotel_link_plan.csv")
    award = read("award_plan.csv")
    dry_be = read("dry_run_be.csv")
    dry_fr = read("dry_run_fr.csv")

    lines: list[str] = ["# Belgium/France 573-Record Pre-Import Audit -- Control Report", ""]
    ok, issues = 0, 0

    def check(name: str, passed: bool, detail: str = "") -> None:
        nonlocal ok, issues
        if passed:
            ok += 1
        else:
            issues += 1
        lines.append(f"- [{'OK' if passed else 'ISSUE'}] {name}" + (f" -- {detail}" if detail else ""))

    check("exactly 573 unique candidates in master", len(master) == 573 and len({r['candidate_id'] for r in master}) == 573, str(len(master)))
    check("BE = 100, FR = 473", len(be) == 100 and len(fr) == 473, f"BE={len(be)} FR={len(fr)}")
    check("all master rows classified APPROVED_FOR_IMPORT", all(r["classification"] == "APPROVED_FOR_IMPORT" for r in master), "")
    check("0 rows in pre_import_review.csv (no unresolved blockers)", len(review) == 0, str(len(review)))
    check("be+fr = master", {r["candidate_id"] for r in be} | {r["candidate_id"] for r in fr} == {r["candidate_id"] for r in master}, "")

    stars = Counter(r["michelin_stars_final"] for r in master)
    check("combined final star composition is 493x1 / 62x2 / 18x3", stars == Counter({"1": 493, "2": 62, "3": 18}), str(dict(stars)))
    be_stars = Counter(r["michelin_stars_final"] for r in be)
    check("BE final star composition is 96x1 / 4x2", be_stars == Counter({"1": 96, "2": 4}), str(dict(be_stars)))
    fr_stars = Counter(r["michelin_stars_final"] for r in fr)
    check("FR final star composition is 397x1 / 58x2 / 18x3", fr_stars == Counter({"1": 397, "2": 58, "3": 18}), str(dict(fr_stars)))

    corrected = [r for r in master if r["star_corrected"] == "yes"]
    check("exactly 4 star corrections applied", len(corrected) == 4, str([r["candidate_id"] for r in corrected]))

    check("6 recognition discrepancies documented", len(recognition) == 6, str(len(recognition)))
    check("evidence audit covers exactly the 16 inline-evidence candidates, all PASS", len(evidence) == 16 and all(r["result"] == "PASS" for r in evidence), "")

    check("hotel_link_plan covers exactly 6 verified links (1 BE + 5 FR)", len(hotel) == 6, str(len(hotel)))
    check("award_plan covers both countries with guide_year=2026/is_current=true", len(award) == 2 and all(r["guide_year"] == "2026" and r["is_current"] == "true" for r in award), "")

    dry_be_map = {(r["category"], r["action"]): int(r["count"]) for r in dry_be}
    dry_fr_map = {(r["category"], r["action"]): int(r["count"]) for r in dry_fr}
    check("BE dry-run: restaurant INSERT=100, SKIP=0, BLOCK=0",
          dry_be_map.get(("restaurant", "INSERT")) == 100 and dry_be_map.get(("restaurant", "SKIP")) == 0
          and dry_be_map.get(("restaurant", "BLOCK")) == 0, "")
    check("FR dry-run: restaurant INSERT=473, SKIP=0, BLOCK=0",
          dry_fr_map.get(("restaurant", "INSERT")) == 473 and dry_fr_map.get(("restaurant", "SKIP")) == 0
          and dry_fr_map.get(("restaurant", "BLOCK")) == 0, "")

    for name in ("prepared_be_michelin_import.sql", "prepared_fr_michelin_import.sql"):
        text = (HERE / name).read_text().lower()
        check(f"{name} is marked PREPARED -- NOT APPLIED", "prepared -- not applied" in text, "")
        check(f"{name} is not under supabase/migrations/", not (HERE.parent.parent.parent / "migrations" / name).exists(), "")

    lines.append("")
    lines.append(f"TOTAL: {ok} OK, {issues} ISSUE(S).")

    (HERE / "BE_FR_PRE_IMPORT_CONTROL_REPORT.md").write_text("\n".join(lines) + "\n")
    print("\n".join(lines))


if __name__ == "__main__":
    main()
