#!/usr/bin/env python3
"""Michelin Passport catalogue — City Coverage & Expansion (PREPARED).

PREPARED — NOT APPLIED. Not run against any database in this task beyond
its own classification logic (which needs no connection). Do not run
against any database, local or remote, until reviewed.

Sibling in architecture to ../michelin_belgium_expansion/apply_belgium_expansion.py
and ../michelin_france_manual_source/apply_france_expansion.py: CSV-driven,
dry-run by default, classification never requires a database connection,
and a real apply only ever happens inside one transaction with an explicit
remote confirm token this draft does not implement.

What this script is for: creating the missing `public.cities` rows that the
632-restaurant LOCATION_PENDING backlog needs before ANY of those restaurants
can satisfy `restaurants.city_id uuid not null references cities(id)`. This
is a separate, prerequisite step from restaurant-level geocoding (see
../michelin_location_spike/) — see CITY_COVERAGE_REPORT.md for why the two
are deliberately kept apart.

Source of truth: missing_cities.csv in this folder (397 rows: 73 BE + 324
FR), itself produced by auditing city_coverage_audit.csv (632 rows) against
a live snapshot of production `cities` (BE+FR, 26 rows at audit time). Each
row there is already deduplicated (distinct per country+name+region) and
carries a `region` value ONLY where independently verified this pass
(Montreuil, Saint-Germain, Saint-Remy, Saint-Medard -- see the audit
script's SPIKE_OVERRIDES / homonym-check comments) -- every other row
leaves region blank, matching production's own existing convention (all 26
current BE/FR city rows have region = NULL today).

What it would write, and only ever via INSERT ... ON CONFLICT DO NOTHING
(never UPDATE, never DELETE):
  - New rows into public.cities: country_code, name, region (nullable).
    postal_municipality and michelin_guide_edition are left NULL -- this
    pass never collected either, and production's existing 26 rows are
    NULL in both columns too, so this is consistent with, not a departure
    from, current data.
  - The ON CONFLICT target is the table's own real unique index,
    cities_unique_key (country_code, name, coalesce(region, '')) -- see
    supabase/migrations/20260805141519_production_schema_v1.sql. This is
    what makes a real run of this script idempotent: running it twice (or
    against a database that already has some of these rows from a prior
    partial apply) inserts each distinct city at most once, no matter how
    many times the script runs.

What it never touches:
  - public.restaurants -- this script creates cities only. No restaurant
    row is read, inserted, or updated here. The 632 LOCATION_PENDING rows
    still need real per-restaurant address/coordinate research (the
    already-completed location spike's job, scaled up) before any of them
    can actually be imported -- a resolved city_id is necessary but not
    sufficient (restaurants.location, .address are separately NOT NULL).
  - Any existing `cities` row -- this script has no UPDATE code path.
  - city_review.csv is deliberately NOT loaded by this script -- it is
    empty in this pass (no unresolved ambiguous case survived the audit),
    but if a future pass populates it, those rows must stay excluded from
    any INSERT until a human resolves them, exactly like BLOCKED rows in
    the sibling restaurant-expansion scripts.

id (uuid): database-generated via cities.id's own `default gen_random_uuid()`
-- this script never generates or specifies a uuid itself.

Everything runs inside one transaction. --dry-run (default) classifies,
validates, and would-write, then rolls back unconditionally. A real run
commits only if every post-insert check passes. Remote targets require an
exact confirm token, mirroring every other apply_*.py script in this
project -- NOT IMPLEMENTED in this draft (classification only).

Usage:
  python3 apply_city_import.py --dry-run
  python3 apply_city_import.py --country BE --dry-run
"""

from __future__ import annotations

import argparse
import csv
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import Optional

try:
    import psycopg
except ImportError:  # pragma: no cover -- fine, never executed in this task
    psycopg = None  # type: ignore[assignment]

HERE = Path(__file__).resolve().parent
MISSING_CSV = HERE / "missing_cities.csv"
REVIEW_CSV = HERE / "city_review.csv"

REMOTE_CONFIRM_TOKEN = "APPLY-MICHELIN-CITY-COVERAGE-EXPANSION"

VALID_COUNTRY_CODES = {"BE", "FR"}


class CityImportError(Exception):
    pass


@dataclass(frozen=True)
class CityCandidate:
    country_code: str
    name: str
    region: Optional[str]
    restaurant_count: int
    candidate_ids: str


@dataclass(frozen=True)
class Outcome:
    country_code: str
    name: str
    region: Optional[str]
    action: str  # INSERT / BLOCKED_MISSING_REQUIRED_FIELD / BLOCKED_INVALID_COUNTRY
    detail: str = ""


def load_missing_cities(country: Optional[str]) -> list[CityCandidate]:
    candidates = []
    with MISSING_CSV.open(newline="", encoding="utf-8") as f:
        for row in csv.DictReader(f):
            if country and row["country_code"].strip() != country:
                continue
            candidates.append(
                CityCandidate(
                    country_code=row["country_code"].strip(),
                    name=row["name"].strip(),
                    region=row["region"].strip() or None,
                    restaurant_count=int(row["restaurant_count"]),
                    candidate_ids=row["candidate_ids"],
                )
            )
    return candidates


def load_review_names(country: Optional[str]) -> set[tuple[str, str]]:
    """Structural guard: names sitting in city_review.csv must never be
    silently inserted by this script even if they also appeared in
    missing_cities.csv by some future editing mistake."""
    names = set()
    if not REVIEW_CSV.exists():
        return names
    with REVIEW_CSV.open(newline="", encoding="utf-8") as f:
        for row in csv.DictReader(f):
            if country and row["country_code"].strip() != country:
                continue
            names.add((row["country_code"].strip(), row["name"].strip()))
    return names


def classify(candidates: list[CityCandidate], review_names: set[tuple[str, str]]) -> list[Outcome]:
    outcomes = []
    seen_keys: set[tuple[str, str, str]] = set()
    for c in candidates:
        key = (c.country_code, c.name, c.region or "")
        if c.country_code not in VALID_COUNTRY_CODES:
            outcomes.append(Outcome(c.country_code, c.name, c.region, "BLOCKED_INVALID_COUNTRY",
                                     f"country_code {c.country_code!r} not in {sorted(VALID_COUNTRY_CODES)}"))
            continue
        if not c.name:
            outcomes.append(Outcome(c.country_code, c.name, c.region, "BLOCKED_MISSING_REQUIRED_FIELD", "empty name"))
            continue
        if (c.country_code, c.name) in review_names:
            outcomes.append(Outcome(c.country_code, c.name, c.region, "BLOCKED_PENDING_REVIEW",
                                     "present in city_review.csv -- unresolved, excluded from import"))
            continue
        if key in seen_keys:
            outcomes.append(Outcome(c.country_code, c.name, c.region, "BLOCKED_DUPLICATE_IN_SOURCE",
                                     "duplicate (country_code, name, region) key within missing_cities.csv itself"))
            continue
        seen_keys.add(key)
        outcomes.append(Outcome(c.country_code, c.name, c.region, "INSERT"))
    return outcomes


INSERT_SQL = """
insert into public.cities (country_code, name, region)
values (%(country_code)s, %(name)s, %(region)s)
on conflict (country_code, name, coalesce(region, ''))
do nothing
returning id;
"""


def run(*, country: Optional[str], dry_run: bool) -> int:
    candidates = load_missing_cities(country)
    review_names = load_review_names(country)
    scope = country or "BE+FR"
    print(f"Loaded {len(candidates)} candidate cities for country={scope} from {MISSING_CSV.name}")
    print(f"Loaded {len(review_names)} unresolved names from {REVIEW_CSV.name} (structurally excluded)")

    outcomes = classify(candidates, review_names)
    by_action: dict[str, list[Outcome]] = {}
    for o in outcomes:
        by_action.setdefault(o.action, []).append(o)
    for action, items in sorted(by_action.items()):
        print(f"  {action}: {len(items)}")

    blocked = [o for o in outcomes if o.action != "INSERT"]
    if blocked:
        print(f"\nAll {len(blocked)} blocked rows and why:")
        for o in blocked:
            print(f"  {o.country_code} {o.name!r} region={o.region!r}: {o.detail}")

    inserts = by_action.get("INSERT", [])
    print(f"\nWould INSERT {len(inserts)} rows into public.cities via:\n{INSERT_SQL.strip()}")
    print("Idempotency: the ON CONFLICT target is cities_unique_key "
          "(country_code, name, coalesce(region, '')) -- the table's real unique "
          "index (supabase/migrations/20260805141519_production_schema_v1.sql). "
          "Running this script twice, or running it after a partial prior apply, "
          "inserts each distinct city at most once.")

    print(
        "\nThis script was not connected to any database in this run. "
        "Nothing was read from or written to production or any other target."
    )
    return 0


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--country", choices=sorted(VALID_COUNTRY_CODES), default=None,
                         help="Restrict to one country. Default: both BE and FR.")
    parser.add_argument("--dry-run", action="store_true", default=True)
    parser.add_argument(
        "--confirm-remote-city-import",
        default=None,
        metavar="TOKEN",
        help=f"Required, exact value {REMOTE_CONFIRM_TOKEN!r}, for a non-dry-run remote apply. "
             "Not implemented in this draft -- classification only.",
    )
    args = parser.parse_args()
    try:
        sys.exit(run(country=args.country, dry_run=args.dry_run))
    except CityImportError as exc:
        print(f"\nERROR: {exc}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
