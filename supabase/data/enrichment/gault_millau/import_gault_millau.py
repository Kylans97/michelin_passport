#!/usr/bin/env python3
"""Gault&Millau -- dry-run-only import/upsert script (task section 13).

STATUS: PREPARED. NOT RUN AGAINST ANY PRODUCTION OR REMOTE DATABASE.

This script is deliberately self-contained inside
supabase/data/enrichment/gault_millau/ rather than living in scripts/ or
importing from scripts/import_catalogue.py -- this is an isolated,
not-yet-reviewed workstream (see the guardrails in this folder's README.md
and SCHEMA_DESIGN.md) and should not gain any dependency on, or from, the
production import pipeline until it is explicitly promoted.

Unlike scripts/apply_catalogue_enrichment.py, there is NO --target remote
option here at all -- not a confirm-token gate, an outright absence. The
only connection this script can ever make is to a local Postgres instance,
resolved from GAULT_MILLAU_LOCAL_DSN or a hardcoded local default. Adding
remote/production support is a future, explicit decision for whoever
reviews and promotes this workstream -- not something this script should
make easy to reach for by accident.

What it reads (this folder's own output, nothing outside it):
  gault_millau_restaurants.csv  -- one row per (restaurant, guide_year)
  gault_millau_matches.csv      -- classification against the existing
                                    Chasing Stars catalogue
  gault_millau_special_awards.csv

What it would write, and only ever via INSERT (never UPDATE, never DELETE):
  public.gault_millau_awards          -- only for rows whose
                                          gm_candidate_id resolved to an
                                          EXACT or HIGH_CONFIDENCE match in
                                          gault_millau_matches.csv
  public.gault_millau_special_awards  -- restaurant_id always NULL in this
                                          pass (see note below)

Explicit match validation: REVIEW and NO_MATCH rows have no
existing_restaurant_code at all, so they are structurally unable to
produce a gault_millau_awards row -- there is no fuzzy fallback path a
future edit could accidentally loosen. A restaurant's identity in the
Chasing Stars catalogue is never touched, written, or inferred by this
script; it only resolves an already-existing restaurant_code to its id.

Special-awards restaurant linkage: gault_millau_special_awards.csv carries
a free-text restaurant_name, not a gm_candidate_id, and was never run
through the matching pipeline in gault_millau_matches.csv. Per the task's
explicit instruction ("never overwrite restaurant identity based on a weak
match"), this script does NOT attempt to fuzzy-resolve that name against
the catalogue -- every imported special-award row gets restaurant_id =
NULL (the column is nullable for exactly this reason; see
SCHEMA_DESIGN.md). Resolving these to real restaurants is future,
separately-reviewed work, not a guess made here.

Idempotent: gault_millau_awards relies on the table's own
UNIQUE(restaurant_id, guide_year) constraint (classified ALREADY_PRESENT /
CONFLICT before ever writing, same pattern as
apply_catalogue_enrichment.py). gault_millau_special_awards has
deliberately NO uniqueness constraint (see SCHEMA_DESIGN.md -- multiple
simultaneous winners are real), so this script enforces idempotency itself
by checking for an identical (country_code, guide_year, award_category,
winner_name, restaurant_name_at_time) row before inserting.

Transactional: everything happens inside one transaction. --dry-run
(the default) always rolls back. A real --apply run only commits if every
row classifies cleanly (no CONFLICT, no SKIP_UNRESOLVED_CODE) -- any
problem rolls back the whole transaction, exactly like
apply_catalogue_enrichment.py.

Deferred markets: DEFERRED_COUNTRY_CODES (currently {'DE'}) is excluded by
default, per the 2026-08-11 production-readiness review's launch-scope
decision (Germany has no live 2026 edition, unresolved licensing dispute --
see PRODUCTION_READINESS_REVIEW.md §3). Pass --include-deferred-markets to
override, e.g. for a future re-evaluation once Germany's guide resumes.

Usage:
  python3 import_gault_millau.py --dry-run
  python3 import_gault_millau.py --apply   # still local-only, see above
  python3 import_gault_millau.py --dry-run --include-deferred-markets
"""

from __future__ import annotations

import argparse
import csv
import os
import re
import sys
from collections import Counter
from dataclasses import dataclass
from pathlib import Path
from typing import Optional

import psycopg

HERE = Path(__file__).resolve().parent

RESTAURANTS_CSV = HERE / "gault_millau_restaurants.csv"
MATCHES_CSV = HERE / "gault_millau_matches.csv"
SPECIAL_AWARDS_CSV = HERE / "gault_millau_special_awards.csv"

MATCHABLE_CLASSIFICATIONS = {"EXACT", "HIGH_CONFIDENCE"}

# Launch-scope decision from the 2026-08-11 production-readiness review
# (PRODUCTION_READINESS_REVIEW.md §3): Germany has no live 2026 edition, the
# site is down, and the licensing dispute is unresolved -- excluded from
# the initial production import by default. Not a data-quality judgment
# about the 15 German rows themselves (12 EXACT, 3 HIGH_CONFIDENCE, all
# otherwise clean) -- purely a market-readiness one. Pass
# --include-deferred-markets to override for a future re-evaluation.
DEFERRED_COUNTRY_CODES = {"DE"}

# No remote/production DSN exists anywhere in this file -- see module
# docstring. This is the only connection target this script can reach.
LOCAL_DSN = os.environ.get(
    "GAULT_MILLAU_LOCAL_DSN", "postgresql://postgres:postgres@127.0.0.1:54322/postgres"
)


class ImportError_(Exception):
    """Raised for any condition that should stop the run without writing."""


@dataclass(frozen=True)
class AwardRow:
    gm_candidate_id: str
    restaurant_code: str
    country_code: str
    guide_year: int
    score: Optional[float]
    toque_count: Optional[int]
    toque_colour: Optional[str]
    recognition_type: str
    distinction_label: Optional[str]
    gault_millau_url: Optional[str]


@dataclass(frozen=True)
class SpecialAwardRow:
    award_id: str
    country_code: str
    guide_year: int
    award_category: str
    award_category_local_name: Optional[str]
    winner_name: Optional[str]
    restaurant_name_at_time: Optional[str]
    gault_millau_url: Optional[str]
    source_url: Optional[str]


@dataclass(frozen=True)
class Outcome:
    key: str
    action: str  # INSERT / ALREADY_PRESENT / CONFLICT / SKIP_UNRESOLVED_CODE
    detail: str = ""


# ============================================================
# Parsing helpers
# ============================================================


def _clean(value: str) -> Optional[str]:
    value = value.strip()
    return value if value else None


def _parse_score(value: str) -> Optional[float]:
    value = value.strip()
    return float(value) if value else None


HAUBEN_RE = re.compile(r"^(\d+)\s+(red|black)\s+Hauben$", re.IGNORECASE)


def _parse_toques(value: str) -> tuple[Optional[int], Optional[str]]:
    """'5' -> (5, None). '5 red Hauben' -> (5, 'red'). '' -> (None, None).

    The Hauben-with-colour format is Germany-only (see research_dach.md) --
    every other market's toques cell is a bare integer string.
    """
    value = value.strip()
    if not value:
        return None, None
    m = HAUBEN_RE.match(value)
    if m:
        return int(m.group(1)), m.group(2).lower()
    return int(value), None


def _recognition_type(distinction: str) -> str:
    d = distinction.strip()
    if "Toques d'Or" in d:
        return "unscored_top_tier"
    if "H!P" in d:
        return "unscored_casual"
    return "scored"


# ============================================================
# Loaders
# ============================================================


def load_matchable_codes() -> dict[str, str]:
    """gm_candidate_id -> existing_restaurant_code, for EXACT/HIGH_CONFIDENCE
    rows only. REVIEW and NO_MATCH rows have no existing_restaurant_code in
    the source CSV at all and are simply absent from this map -- there is
    no branch of this script that could accidentally treat them as
    matched."""
    codes: dict[str, str] = {}
    with MATCHES_CSV.open(newline="", encoding="utf-8") as f:
        for row in csv.DictReader(f):
            if row["classification"] not in MATCHABLE_CLASSIFICATIONS:
                continue
            code = row["existing_restaurant_code"].strip()
            if not code:
                raise ImportError_(
                    f"{row['gm_candidate_id']}: classified {row['classification']} but has no "
                    "existing_restaurant_code -- inconsistent source data, refusing to proceed."
                )
            codes[row["gm_candidate_id"]] = code
    return codes


def load_award_rows(*, excluded_countries: set[str]) -> list[AwardRow]:
    matchable = load_matchable_codes()
    rows: list[AwardRow] = []
    with RESTAURANTS_CSV.open(newline="", encoding="utf-8") as f:
        for row in csv.DictReader(f):
            code = matchable.get(row["gm_candidate_id"])
            if code is None:
                continue  # REVIEW / NO_MATCH -- see load_matchable_codes
            country_code = row["country_code"].strip()
            if country_code in excluded_countries:
                continue  # deferred market (e.g. Germany) -- see DEFERRED_COUNTRY_CODES
            toque_count, toque_colour = _parse_toques(row["toques"])
            rows.append(
                AwardRow(
                    gm_candidate_id=row["gm_candidate_id"],
                    restaurant_code=code,
                    country_code=country_code,
                    guide_year=int(row["guide_year"]),
                    score=_parse_score(row["score"]),
                    toque_count=toque_count,
                    toque_colour=toque_colour,
                    recognition_type=_recognition_type(row["distinction"]),
                    distinction_label=_clean(row["distinction"]),
                    gault_millau_url=_clean(row["gault_millau_url"]),
                )
            )
    return rows


def load_special_award_rows(*, excluded_countries: set[str]) -> list[SpecialAwardRow]:
    rows: list[SpecialAwardRow] = []
    with SPECIAL_AWARDS_CSV.open(newline="", encoding="utf-8") as f:
        for row in csv.DictReader(f):
            country_code = row["country_code"].strip()
            if country_code in excluded_countries:
                continue  # deferred market (e.g. Germany) -- see DEFERRED_COUNTRY_CODES
            rows.append(
                SpecialAwardRow(
                    award_id=row["award_id"],
                    country_code=country_code,
                    guide_year=int(row["guide_year"]),
                    award_category=row["award_category"].strip(),
                    award_category_local_name=_clean(row["award_category_local_name"]),
                    winner_name=_clean(row["winner_name"]),
                    restaurant_name_at_time=_clean(row["restaurant_name"]),
                    gault_millau_url=None,
                    source_url=_clean(row["source_url"]),
                )
            )
    return rows


# ============================================================
# Resolution against the (local) database
# ============================================================


def fetch_restaurant_map(cur: psycopg.Cursor) -> dict[str, str]:
    cur.execute("select restaurant_code, id from public.restaurants")
    return {code: str(rid) for code, rid in cur.fetchall()}


def fetch_country_codes(cur: psycopg.Cursor) -> set[str]:
    cur.execute("select country_code from public.countries")
    return {row[0] for row in cur.fetchall()}


def table_exists(cur: psycopg.Cursor, table: str) -> bool:
    cur.execute(
        "select 1 from information_schema.tables where table_schema='public' and table_name=%s",
        (table,),
    )
    return cur.fetchone() is not None


# ============================================================
# Classification
# ============================================================


def classify_awards(
    cur: psycopg.Cursor, rows: list[AwardRow], restaurant_map: dict[str, str]
) -> list[Outcome]:
    outcomes = []
    for r in rows:
        key = f"{r.restaurant_code}.{r.guide_year}"
        rid = restaurant_map.get(r.restaurant_code)
        if rid is None:
            outcomes.append(
                Outcome(key=key, action="SKIP_UNRESOLVED_CODE", detail="restaurant_code not found in this database")
            )
            continue
        cur.execute(
            "select score, toque_count, toque_colour, recognition_type, distinction_label "
            "from public.gault_millau_awards where restaurant_id = %s and guide_year = %s",
            (rid, r.guide_year),
        )
        existing = cur.fetchone()
        if existing is None:
            outcomes.append(Outcome(key=key, action="INSERT"))
            continue
        e_score, e_toque, e_colour, e_type, e_label = existing
        same = (
            (e_score is None and r.score is None or (e_score is not None and r.score is not None and float(e_score) == r.score))
            and e_toque == r.toque_count
            and e_colour == r.toque_colour
            and e_type == r.recognition_type
            and e_label == r.distinction_label
        )
        if same:
            outcomes.append(Outcome(key=key, action="ALREADY_PRESENT"))
        else:
            outcomes.append(
                Outcome(
                    key=key,
                    action="CONFLICT",
                    detail=f"existing row differs: score={e_score}, toques={e_toque}/{e_colour}, type={e_type}",
                )
            )
    return outcomes


def classify_special_awards(
    cur: psycopg.Cursor, rows: list[SpecialAwardRow], country_codes: set[str]
) -> list[Outcome]:
    outcomes = []
    for r in rows:
        key = r.award_id
        if r.country_code not in country_codes:
            outcomes.append(
                Outcome(key=key, action="SKIP_UNRESOLVED_CODE", detail=f"country_code {r.country_code!r} not in public.countries")
            )
            continue
        cur.execute(
            "select 1 from public.gault_millau_special_awards where country_code = %s and guide_year = %s "
            "and award_category = %s and coalesce(winner_name, '') = coalesce(%s, '') "
            "and coalesce(restaurant_name_at_time, '') = coalesce(%s, '')",
            (r.country_code, r.guide_year, r.award_category, r.winner_name, r.restaurant_name_at_time),
        )
        if cur.fetchone() is not None:
            outcomes.append(Outcome(key=key, action="ALREADY_PRESENT"))
        else:
            outcomes.append(Outcome(key=key, action="INSERT"))
    return outcomes


# ============================================================
# Apply -- only ever INSERT, never UPDATE, never DELETE
# ============================================================


def apply_awards(
    cur: psycopg.Cursor, rows: list[AwardRow], outcomes: list[Outcome], restaurant_map: dict[str, str]
) -> int:
    by_key = {o.key: o for o in outcomes}
    applied = 0
    for r in rows:
        key = f"{r.restaurant_code}.{r.guide_year}"
        if by_key[key].action != "INSERT":
            continue
        cur.execute(
            "insert into public.gault_millau_awards "
            "(restaurant_id, guide_year, score, toque_count, toque_colour, recognition_type, "
            "distinction_label, gault_millau_url) values (%s, %s, %s, %s, %s, %s, %s, %s)",
            (
                restaurant_map[r.restaurant_code],
                r.guide_year,
                r.score,
                r.toque_count,
                r.toque_colour,
                r.recognition_type,
                r.distinction_label,
                r.gault_millau_url,
            ),
        )
        applied += 1
    return applied


def apply_special_awards(cur: psycopg.Cursor, rows: list[SpecialAwardRow], outcomes: list[Outcome]) -> int:
    by_key = {o.key: o for o in outcomes}
    applied = 0
    for r in rows:
        if by_key[r.award_id].action != "INSERT":
            continue
        cur.execute(
            "insert into public.gault_millau_special_awards "
            "(restaurant_id, country_code, guide_year, award_category, award_category_local_name, "
            "winner_name, restaurant_name_at_time, gault_millau_url, source_url) "
            "values (null, %s, %s, %s, %s, %s, %s, %s, %s)",
            (
                r.country_code,
                r.guide_year,
                r.award_category,
                r.award_category_local_name,
                r.winner_name,
                r.restaurant_name_at_time,
                r.gault_millau_url,
                r.source_url,
            ),
        )
        applied += 1
    return applied


# ============================================================
# Orchestration
# ============================================================


def _print_summary(label: str, outcomes: list[Outcome]) -> None:
    print(f"  {label}: {dict(Counter(o.action for o in outcomes))}")


def run(*, apply: bool, include_deferred: bool) -> int:
    excluded_countries = set() if include_deferred else set(DEFERRED_COUNTRY_CODES)
    print(f"Connecting to LOCAL database only ({LOCAL_DSN.split('@')[-1]})...")
    if excluded_countries:
        print(f"Excluding deferred market(s): {sorted(excluded_countries)} (pass --include-deferred-markets to override)")
    with psycopg.connect(LOCAL_DSN, autocommit=False) as conn:
        with conn.cursor() as cur:
            for table in ("gault_millau_awards", "gault_millau_special_awards"):
                if not table_exists(cur, table):
                    raise ImportError_(
                        f"public.{table} does not exist in this database. The migration "
                        "(20260811120000_create_gault_millau_awards.sql) is PREPARED — NOT APPLIED; "
                        "apply it to a local/throwaway database yourself first if you want to "
                        "exercise this script. This script will never apply it for you."
                    )

            try:
                print("Loading source CSVs (this folder only)...")
                award_rows = load_award_rows(excluded_countries=excluded_countries)
                special_rows = load_special_award_rows(excluded_countries=excluded_countries)
                print(f"  {len(award_rows)} gault_millau_awards candidate rows (EXACT/HIGH_CONFIDENCE matches only, deferred markets excluded)")
                print(f"  {len(special_rows)} gault_millau_special_awards candidate rows (deferred markets excluded)")

                restaurant_map = fetch_restaurant_map(cur)
                country_codes = fetch_country_codes(cur)
                print(f"  resolved against {len(restaurant_map)} restaurants, {len(country_codes)} countries")

                print("\nClassifying...")
                a_outcomes = classify_awards(cur, award_rows, restaurant_map)
                _print_summary("gault_millau_awards", a_outcomes)
                s_outcomes = classify_special_awards(cur, special_rows, country_codes)
                _print_summary("gault_millau_special_awards", s_outcomes)

                all_outcomes = a_outcomes + s_outcomes
                conflicts = [o for o in all_outcomes if o.action == "CONFLICT"]
                unresolved = [o for o in all_outcomes if o.action == "SKIP_UNRESOLVED_CODE"]

                if conflicts:
                    print(f"\n{len(conflicts)} CONFLICT(S):")
                    for o in conflicts:
                        print(f"  CONFLICT {o.key}: {o.detail}")
                if unresolved:
                    print(f"\n{len(unresolved)} UNRESOLVED:")
                    for o in unresolved:
                        print(f"  {o.action} {o.key}: {o.detail}")
                if conflicts or unresolved:
                    raise ImportError_(
                        f"{len(conflicts)} conflict(s), {len(unresolved)} unresolved row(s) -- stopping without applying."
                    )

                print("\nApplying (within transaction)...")
                n_a = apply_awards(cur, award_rows, a_outcomes, restaurant_map)
                print(f"  gault_millau_awards: {n_a} rows inserted")
                n_s = apply_special_awards(cur, special_rows, s_outcomes)
                print(f"  gault_millau_special_awards: {n_s} rows inserted")

            except Exception:
                conn.rollback()
                print("\nROLLED BACK -- no changes were written.", file=sys.stderr)
                raise

            if apply:
                conn.commit()
                print("\nAPPLIED to LOCAL database -- transaction committed. (Never run with --apply against production; there is no option to.)")
            else:
                conn.rollback()
                print("\nDRY RUN complete -- nothing was written (rolled back).")
    return 0


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--dry-run", action="store_true", help="Explicit no-op -- dry-run is already the default. Kept for symmetry with --apply.")
    parser.add_argument("--apply", action="store_true", help="Commit instead of the default dry-run rollback. LOCAL DATABASE ONLY -- see module docstring.")
    parser.add_argument(
        "--include-deferred-markets",
        action="store_true",
        help=f"Include markets deferred by the production-readiness review ({sorted(DEFERRED_COUNTRY_CODES)}). "
        "Off by default -- see DEFERRED_COUNTRY_CODES.",
    )
    args = parser.parse_args()
    try:
        sys.exit(run(apply=args.apply, include_deferred=args.include_deferred_markets))
    except (ImportError_, psycopg.Error) as exc:
        print(f"\nERROR: {exc}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
