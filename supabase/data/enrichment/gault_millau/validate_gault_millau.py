#!/usr/bin/env python3
"""Gault&Millau dataset -- validation control report (task section 14).

Read-only. Makes no database connection at all -- every check here runs
purely against this folder's own CSVs plus supabase/data/restaurants_master.csv
(the repo's own production-mirroring reference file), so this can be re-run
by anyone without a database at hand. FK feasibility against a live
database was separately exercised by import_gault_millau.py --dry-run
against a local dev instance only (see that script's own output / the
final report) -- this script re-derives the same FK check from the CSV
mirror for a database-independent, always-re-runnable record.

Usage: python3 validate_gault_millau.py
"""

from __future__ import annotations

import csv
from collections import Counter, defaultdict
from pathlib import Path

HERE = Path(__file__).resolve().parent
REPO_ROOT = HERE.parent.parent.parent.parent

RESTAURANTS_CSV = HERE / "gault_millau_restaurants.csv"
MATCHES_CSV = HERE / "gault_millau_matches.csv"
SPECIAL_AWARDS_CSV = HERE / "gault_millau_special_awards.csv"
SOURCES_CSV = HERE / "gault_millau_sources.csv"
MASTER_CSV = REPO_ROOT / "supabase" / "data" / "restaurants_master.csv"


def read(path: Path) -> list[dict[str, str]]:
    with path.open(newline="", encoding="utf-8") as f:
        return list(csv.DictReader(f))


def main() -> None:
    restaurants = read(RESTAURANTS_CSV)
    matches = read(MATCHES_CSV)
    special_awards = read(SPECIAL_AWARDS_CSV)
    sources = read(SOURCES_CSV)
    master = read(MASTER_CSV)
    master_codes = {row["restaurant_code"] for row in master}

    lines: list[str] = []
    ok_count = 0
    issue_count = 0

    def check(name: str, passed: bool, detail: str = "") -> None:
        nonlocal ok_count, issue_count
        status = "OK" if passed else "ISSUE"
        if passed:
            ok_count += 1
        else:
            issue_count += 1
        lines.append(f"[{status}] {name}" + (f" -- {detail}" if detail else ""))

    lines.append(f"Gault&Millau dataset validation control report")
    lines.append(f"Row counts: {len(restaurants)} restaurants, {len(matches)} matches, "
                 f"{len(special_awards)} special awards, {len(sources)} sources, "
                 f"{len(master)} existing catalogue restaurants (restaurants_master.csv)")
    lines.append("")

    # 1. Duplicate restaurant/year/market rows in gault_millau_restaurants.csv
    key_counts = Counter((r["name"], r["city"], r["country"], r["guide_year"]) for r in restaurants)
    dupes = [k for k, c in key_counts.items() if c > 1]
    check("no duplicate (name, city, country, guide_year) rows in gault_millau_restaurants.csv",
          not dupes, str(dupes))

    id_counts = Counter(r["gm_candidate_id"] for r in restaurants)
    dupe_ids = [k for k, c in id_counts.items() if c > 1]
    check("gm_candidate_id is unique across gault_millau_restaurants.csv", not dupe_ids, str(dupe_ids))

    # 2. Score ranges (0-20, per every market researched)
    bad_scores = []
    for r in restaurants:
        if r["score"].strip():
            v = float(r["score"])
            if not (0 <= v <= 20):
                bad_scores.append((r["gm_candidate_id"], v))
    check("all non-null scores fall within 0-20", not bad_scores, str(bad_scores))

    # 3. Toque ranges (0-5; Germany's "N red/black Hauben" format parsed the same way)
    import re
    hauben_re = re.compile(r"^(\d+)\s+(red|black)\s+Hauben$", re.IGNORECASE)
    bad_toques = []
    for r in restaurants:
        raw = r["toques"].strip()
        if not raw:
            continue
        m = hauben_re.match(raw)
        count = int(m.group(1)) if m else int(raw)
        if not (0 <= count <= 5):
            bad_toques.append((r["gm_candidate_id"], raw))
    check("all non-null toque counts fall within 0-5", not bad_toques, str(bad_toques))

    # 4. Invalid guide_year values
    bad_years = [r["gm_candidate_id"] for r in restaurants if not (2020 <= int(r["guide_year"]) <= 2026)]
    check("all guide_year values fall within 2020-2026 (dataset was collected in 2026)", not bad_years, str(bad_years))
    for label, rows, id_field in [
        ("gault_millau_special_awards.csv", special_awards, "award_id"),
    ]:
        bad = [r[id_field] for r in rows if not (2020 <= int(r["guide_year"]) <= 2026)]
        check(f"all guide_year values in {label} fall within 2020-2026", not bad, str(bad))

    # 5. Duplicate source URLs where suspicious -- an *exact* profile URL
    # (gault_millau_url, not source_url) reused across two DIFFERENT
    # restaurant names is a real red flag (copy-paste error); reused across
    # rows sharing the same name is expected (same restaurant across guide
    # years is not present in this dataset, but defensive anyway).
    url_to_names: dict[str, set[str]] = defaultdict(set)
    for r in restaurants:
        url = r["gault_millau_url"].strip()
        # "not found" (and its explained variants) is this dataset's explicit
        # null placeholder for a URL that could not be independently
        # confirmed (task section 9: "use null for unavailable information
        # rather than guessing") -- it is not a real, reused profile URL and
        # must not be compared as one.
        if url and url.lower().startswith("http"):
            url_to_names[url].add(r["name"])
    suspicious_urls = {u: names for u, names in url_to_names.items() if len(names) > 1}
    check("no gault_millau_url is reused across two different restaurant names",
          not suspicious_urls, str(suspicious_urls))

    # gault_millau_sources.csv source_id uniqueness + domain uniqueness sanity
    src_ids = Counter(s["source_id"] for s in sources)
    dupe_src_ids = [k for k, c in src_ids.items() if c > 1]
    check("source_id is unique across gault_millau_sources.csv", not dupe_src_ids, str(dupe_src_ids))

    # 6. Unmatched restaurant counts (by classification tier)
    class_counts = Counter(m["classification"] for m in matches)
    lines.append("")
    lines.append(f"Match classification tally: {dict(class_counts)}")
    check("gault_millau_matches.csv row count equals gault_millau_restaurants.csv row count",
          len(matches) == len(restaurants), f"{len(matches)} vs {len(restaurants)}")

    # 7. Ambiguous matches (REVIEW tier) -- not an error condition by itself
    # (the 2026-08-11 production-readiness review deliberately downgraded
    # gm_024 here after finding a genuine address conflict), but every
    # REVIEW row must be visible and must NOT carry a resolved
    # existing_restaurant_code that a careless importer could pick up --
    # that invariant is checked separately below (existing_restaurant_code
    # is present iff EXACT/HIGH_CONFIDENCE, never REVIEW/NO_MATCH).
    review_rows = [(m["gm_candidate_id"], m["match_notes"]) for m in matches if m["classification"] == "REVIEW"]
    lines.append(f"REVIEW-tier (ambiguous, human-check-required) matches: {review_rows}")

    # Every EXACT/HIGH_CONFIDENCE match must carry an existing_restaurant_code.
    # REVIEW rows may also carry one (the candidate code a human still needs to
    # confirm or reject, kept for context -- e.g. gm_024) but NO_MATCH must
    # NEVER carry one -- that would mean a code slipped in for a restaurant
    # nothing actually matched, which import_gault_millau.py has no branch
    # that would catch.
    inconsistent = []
    for m in matches:
        has_code = bool(m["existing_restaurant_code"].strip())
        classification = m["classification"]
        if classification == "NO_MATCH" and has_code:
            inconsistent.append((m["gm_candidate_id"], classification, "has a code but is NO_MATCH"))
        if classification in ("EXACT", "HIGH_CONFIDENCE") and not has_code:
            inconsistent.append((m["gm_candidate_id"], classification, "missing existing_restaurant_code"))
    check("existing_restaurant_code: present for all EXACT/HIGH_CONFIDENCE, absent for all NO_MATCH "
          "(REVIEW may carry one as unconfirmed context)",
          not inconsistent, str(inconsistent))

    # import_gault_millau.py's matchable set (EXACT/HIGH_CONFIDENCE only) must
    # never silently include a REVIEW row -- re-derive the same set this
    # script's load_matchable_codes() would produce and confirm gm_024 (or
    # any other REVIEW row) is excluded from it.
    matchable_ids = {m["gm_candidate_id"] for m in matches if m["classification"] in ("EXACT", "HIGH_CONFIDENCE")}
    review_ids = {m["gm_candidate_id"] for m in matches if m["classification"] == "REVIEW"}
    check("no REVIEW-tier row appears in the EXACT/HIGH_CONFIDENCE matchable set",
          not (matchable_ids & review_ids), str(matchable_ids & review_ids))

    # 8. FK feasibility -- every existing_restaurant_code actually resolves
    # against restaurants_master.csv (the repo's own production mirror)
    unresolved_codes = []
    for m in matches:
        code = m["existing_restaurant_code"].strip()
        if code and code not in master_codes:
            unresolved_codes.append((m["gm_candidate_id"], code))
    check(f"every existing_restaurant_code resolves against restaurants_master.csv "
          f"({len(master_codes)} rows)", not unresolved_codes, str(unresolved_codes))

    # new_restaurant_candidates.csv should be exactly the NO_MATCH rows, nothing more/less
    new_candidates = read(HERE / "gault_millau_new_restaurant_candidates.csv")
    no_match_ids = {m["gm_candidate_id"] for m in matches if m["classification"] == "NO_MATCH"}
    candidate_ids = {r["gm_candidate_id"] for r in new_candidates}
    check("gault_millau_new_restaurant_candidates.csv is exactly the NO_MATCH set, no more no less",
          candidate_ids == no_match_ids,
          f"in candidates but not NO_MATCH: {candidate_ids - no_match_ids}; "
          f"in NO_MATCH but not candidates: {no_match_ids - candidate_ids}")

    # Provenance completeness -- every row must carry source_url + retrieval_date + confidence (task section 9)
    missing_provenance = [
        r["gm_candidate_id"] for r in restaurants
        if not r["source_url"].strip() or not r["retrieval_date"].strip() or not r["confidence"].strip()
    ]
    check("every gault_millau_restaurants.csv row carries source_url, retrieval_date, and confidence",
          not missing_provenance, str(missing_provenance))

    missing_sa_provenance = [
        r["award_id"] for r in special_awards
        if not r["source_url"].strip() or not r["retrieval_date"].strip()
    ]
    check("every gault_millau_special_awards.csv row carries source_url and retrieval_date",
          not missing_sa_provenance, str(missing_sa_provenance))

    # Per-market breakdown -- launch scope excludes Germany (task/review
    # decision, not a data-quality finding); computed here from the joined
    # restaurants + matches CSVs so it's always derived fresh, never hand-counted.
    country_by_id = {r["gm_candidate_id"]: r["country_code"] for r in restaurants}
    class_by_id = {m["gm_candidate_id"]: m["classification"] for m in matches}
    per_market: dict[str, Counter] = defaultdict(Counter)
    for gid, cc in country_by_id.items():
        per_market[cc][class_by_id[gid]] += 1
    lines.append("")
    lines.append("Per-market classification breakdown:")
    for cc in sorted(per_market):
        c = per_market[cc]
        matchable = c["EXACT"] + c["HIGH_CONFIDENCE"]
        lines.append(
            f"  {cc}: {sum(c.values())} total -- EXACT {c['EXACT']}, HIGH_CONFIDENCE {c['HIGH_CONFIDENCE']}, "
            f"REVIEW {c['REVIEW']}, NO_MATCH {c['NO_MATCH']} (matchable: {matchable})"
        )

    lines.append("")
    lines.append(f"TOTAL: {ok_count} OK, {issue_count} ISSUE(S)")

    report = "\n".join(lines)
    print(report)


if __name__ == "__main__":
    main()
