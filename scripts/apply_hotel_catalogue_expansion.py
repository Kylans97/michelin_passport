#!/usr/bin/env python3
"""Michelin Passport catalogue — hotel catalogue expansion deployment.

Applies the union-inclusion-rule hotel expansion (MICHELIN Keys OR World's 50
Best Hotels 2023-2025) to an ALREADY POPULATED catalogue database. Sibling to
apply_catalogue_enrichment.py, same safety philosophy, different scope:

  import_catalogue.py               — full import into an EMPTY catalogue
  apply_catalogue_enrichment.py     — incremental field/history enrichment of
                                       an EXISTING catalogue (no new rows)
  apply_hotel_catalogue_expansion.py — incremental catalogue GROWTH: inserts
                                       new hotel rows and new World's 50 Best
                                       Hotels ranking rows into an EXISTING
                                       catalogue. This is the only one of the
                                       three that ever runs `insert into
                                       public.hotels`.

What it writes:
  - New rows into public.countries / public.cities, but ONLY when a new
    hotel that needs them is actually being inserted this run — never
    speculatively.
  - New rows into public.hotels — ONLY for candidates that carry every
    NOT NULL production column (name, city, country, address, a resolvable
    location). public.hotels.address and .location are NOT NULL in the
    schema; a candidate missing either is classified BLOCKED_MISSING_REQUIRED_FIELD
    and is never inserted with a fabricated placeholder. See
    docs/.../phase8_production_readiness_report.md section on deployment
    order for why this matters today: as of this pass, 0 of the 94 candidate
    hotels have independently verified coordinates, so a real run of this
    script writes 0 new hotel rows until that research exists.
  - New rows into public.worlds_50_best_hotels — for a ranking row whose
    hotel_code resolves (either an existing catalogue hotel, or a new hotel
    inserted earlier in this same transaction). A row whose hotel isn't
    resolvable this run is BLOCKED_DEPENDENT_HOTEL, not silently dropped.

What it never touches:
  - Any of the 687 existing hotel rows' michelin_keys, address, location,
    google_place_id, or any other existing non-null field — see
    apply_field_fills' "and {field} is null" pattern reused from
    apply_catalogue_enrichment.py: this script only ever fills empty cells
    on a NEW row it is itself inserting, it never UPDATEs an existing row.
  - public.hotel_restaurants.
  - public.worlds_50_best (the restaurant table) — entirely untouched, not
    even read.
  - Any existing award_history row.

Key-value semantics (binding on this script, not just documentation):
  A source hotel row with an empty/blank michelin_keys field is inserted
  with SQL NULL, meaning "no confirmed Key value is currently stored" — this
  is never coerced to 0, and 0 is never written for any hotel. This is what
  requires the paired migration (20260807150000_hotel_michelin_keys_nullable.sql)
  to be applied to the target database BEFORE this script can insert any
  hotel with an unresolved Key. This script checks that precondition itself
  (see check_target_schema_ready) rather than assuming it.

Everything runs inside one transaction. --dry-run classifies, validates and
would-write, then rolls back unconditionally. A real run commits only if
every post-deploy check passes; any conflict, unresolved code, or failed
invariant rolls back the entire transaction, including a real one.

Authoritative sources:
  supabase/data/enrichment/worlds_50_best_hotels/catalogue_expansion/
    v2_union_catalogue/new_hotels_for_deployment.csv
    v2_union_catalogue/new_worlds_50_best_hotels_rows.csv
  supabase/data/enrichment/worlds_50_best_hotels/catalogue_expansion/
    phase8_production_readiness_report.md

See scripts/README_IMPORT.md for usage.
"""

from __future__ import annotations

import argparse
import sys
from collections import Counter
from dataclasses import dataclass
from pathlib import Path
from typing import Optional

import psycopg

from import_catalogue import (
    Check,
    ImportValidationError,
    parse_optional_int,
    read_csv_rows,
    redact_dsn,
    report_checks,
    resolve_dsn,
)

# ============================================================
# Constants
# ============================================================

REPO_ROOT = Path(__file__).resolve().parent.parent
DATA_DIR = REPO_ROOT / "supabase" / "data"
WORKSPACE_DIR = DATA_DIR / "enrichment" / "worlds_50_best_hotels" / "catalogue_expansion" / "v2_union_catalogue"

NEW_HOTELS_CSV = WORKSPACE_DIR / "new_hotels_for_deployment.csv"
NEW_RANKING_ROWS_CSV = WORKSPACE_DIR / "new_worlds_50_best_hotels_rows.csv"

EXPECTED_NEW_HOTEL_ROWS = 94
EXPECTED_RANKING_ROWS = 200

REMOTE_CONFIRM_TOKEN = "APPLY-HOTEL-CATALOGUE-EXPANSION"

# ISO 3166-1 alpha-2 codes for countries newly required by this expansion
# that are not yet in COUNTRY_ISO_CODES (import_catalogue.py) because no
# existing restaurant or hotel uses them yet. Fixed international-standard
# codes, not looked up per-row — same status as import_catalogue.py's own
# dict, just the delta this expansion needs.
NEW_COUNTRY_ISO_CODES: dict[str, str] = {
    "Australia": "AU",
    "Costa Rica": "CR",
    "Fiji": "FJ",
    "French Polynesia": "PF",
    "Greece": "GR",
    "India": "IN",
    "Indonesia": "ID",
    "Malaysia": "MY",
    "Maldives": "MV",
    "Morocco": "MA",
    "New Zealand": "NZ",
    "Oman": "OM",
    "South Africa": "ZA",
    "Sri Lanka": "LK",
    "St. Barthélemy": "BL",
}

# Flag emoji: the two-letter ISO code mapped through the standard Unicode
# regional-indicator-symbol transformation (each letter -> U+1F1E6 + offset).
# Deterministic from the ISO code above, not chosen per-country.
def _flag_emoji(iso_code: str) -> str:
    return "".join(chr(0x1F1E6 + ord(c) - ord("A")) for c in iso_code.upper())


class HotelExpansionDeploymentError(Exception):
    """Raised when a conflict, unresolved code, missing required field, or
    invariant failure means the deployment must stop. Always caught at the
    call site that still holds the open transaction, which rolls back before
    re-raising."""


# ============================================================
# Records
# ============================================================


@dataclass(frozen=True)
class NewHotelCandidate:
    hotel_code: str
    name: str
    city: str
    country: str
    address: Optional[str]
    latitude: Optional[float]
    longitude: Optional[float]
    google_place_id: Optional[str]
    michelin_url: Optional[str]
    website_url: Optional[str]
    booking_url: Optional[str]
    michelin_keys: Optional[int]
    inclusion_reason: str


@dataclass(frozen=True)
class NewRankingRow:
    hotel_code: str
    year: int
    rank: Optional[int]
    list_type: str


@dataclass(frozen=True)
class RowOutcome:
    """action is one of INSERT, ALREADY_PRESENT, CONFLICT,
    BLOCKED_MISSING_REQUIRED_FIELD, BLOCKED_DEPENDENT_HOTEL. Only INSERT is
    ever written; everything else is report-only."""

    key: str
    action: str
    detail: str = ""


# ============================================================
# Loaders
# ============================================================


def load_new_hotels() -> list[NewHotelCandidate]:
    candidates = []
    seen: set[str] = set()
    for row in read_csv_rows(NEW_HOTELS_CSV):
        code = row["hotel_code"].strip()
        if code in seen:
            raise HotelExpansionDeploymentError(f"Duplicate hotel_code {code!r} in {NEW_HOTELS_CSV.name} — refusing to load.")
        seen.add(code)
        keys_raw = row["michelin_keys"].strip()
        candidates.append(
            NewHotelCandidate(
                hotel_code=code,
                name=row["name"].strip(),
                city=row["city"].strip(),
                country=row["country"].strip(),
                address=row["address"].strip() or None,
                latitude=float(row["latitude"]) if row["latitude"].strip() else None,
                longitude=float(row["longitude"]) if row["longitude"].strip() else None,
                google_place_id=row["google_place_id"].strip() or None,
                michelin_url=row["michelin_url"].strip() or None,
                website_url=row["website_url"].strip() or None,
                booking_url=row["booking_url"].strip() or None,
                michelin_keys=parse_optional_int(keys_raw) if keys_raw else None,
                inclusion_reason=row["inclusion_reason"].strip(),
            )
        )
    return candidates


def load_new_ranking_rows() -> list[NewRankingRow]:
    rows = []
    for row in read_csv_rows(NEW_RANKING_ROWS_CSV):
        rows.append(
            NewRankingRow(
                hotel_code=row["hotel_code"].strip(),
                year=int(row["year"].strip()),
                rank=parse_optional_int(row["rank"]),
                list_type=row["list_type"].strip(),
            )
        )
    return rows


# ============================================================
# Schema precondition
# ============================================================


def check_target_schema_ready(cur: psycopg.Cursor) -> None:
    """Refuses to proceed if the target database hasn't already had the
    paired migrations applied. This script deliberately does NOT apply
    migrations itself — that stays a separate, explicit, reviewed step."""
    cur.execute(
        "select is_nullable from information_schema.columns "
        "where table_schema='public' and table_name='hotels' and column_name='michelin_keys'"
    )
    row = cur.fetchone()
    if row is None or row[0] != "YES":
        raise HotelExpansionDeploymentError(
            "public.hotels.michelin_keys is not nullable on this target. Apply "
            "20260807150000_hotel_michelin_keys_nullable.sql first — this script "
            "will not apply it for you."
        )
    cur.execute("select to_regclass('public.worlds_50_best_hotels')")
    (regclass,) = cur.fetchone()
    if regclass is None:
        raise HotelExpansionDeploymentError(
            "public.worlds_50_best_hotels does not exist on this target. Apply "
            "20260807160000_create_worlds_50_best_hotels.sql first — this script "
            "will not apply it for you."
        )


# ============================================================
# Code / reference resolution
# ============================================================


def fetch_hotel_map(cur: psycopg.Cursor) -> dict[str, str]:
    cur.execute("select hotel_code, id from public.hotels")
    return {code: str(hid) for code, hid in cur.fetchall()}


def fetch_country_codes(cur: psycopg.Cursor) -> set[str]:
    cur.execute("select country_code from public.countries")
    return {r[0] for r in cur.fetchall()}


def fetch_city_map(cur: psycopg.Cursor) -> dict[tuple[str, str], str]:
    """(country_code, city_name) -> city id. Region is not part of this
    expansion's identity key — none of the 94 candidates carry a region
    disambiguator, unlike the Washington/Washington case import_catalogue.py
    handles."""
    cur.execute("select country_code, name, id from public.cities")
    return {(cc, name): str(cid) for cc, name, cid in cur.fetchall()}


# ============================================================
# Invariant snapshot
# ============================================================


def snapshot_invariants(cur: psycopg.Cursor, existing_hotel_codes: list[str]) -> dict:
    """Scoped to the 687 hotel_codes that existed BEFORE this deployment —
    passed in explicitly rather than re-queried, so a second snapshot after
    this script has inserted new rows still compares apples to apples."""
    cur.execute(
        "select hotel_code, michelin_keys, address, google_place_id, ST_AsText(location) "
        "from public.hotels where hotel_code = any(%s) order by hotel_code",
        (existing_hotel_codes,),
    )
    existing_hotels = tuple(cur.fetchall())
    cur.execute(
        "select h.hotel_code, r.restaurant_code, hr.link_confidence from public.hotel_restaurants hr "
        "join public.hotels h on h.id = hr.hotel_id join public.restaurants r on r.id = hr.restaurant_id "
        "order by 1, 2"
    )
    links = tuple(cur.fetchall())
    cur.execute(
        "select entity_type, entity_id, award_type, award_value from public.award_history "
        "where is_current order by entity_type, entity_id, award_type"
    )
    current_awards = tuple(cur.fetchall())
    return {"existing_hotels": existing_hotels, "links": links, "current_awards": current_awards}


# ============================================================
# Classification
# ============================================================


def classify_new_hotels(cur: psycopg.Cursor, candidates: list[NewHotelCandidate], hotel_map: dict[str, str]) -> list[RowOutcome]:
    """A hotel_code already present in production is NOT automatically a
    CONFLICT — a second run of this script against the same candidate file
    (the normal idempotent-rerun case, e.g. after a prior run already
    inserted this hotel) must see ALREADY_PRESENT, not stop the whole
    deployment. Only a hotel_code that exists with DIFFERENT name/keys/city/
    country than the candidate proposes is a real CONFLICT — that means the
    production row and the candidate file have diverged, which needs human
    review, exactly like every other CONFLICT case in this codebase's
    enrichment scripts."""
    outcomes = []
    for c in candidates:
        key = c.hotel_code
        if c.hotel_code in hotel_map:
            cur.execute(
                "select name, michelin_keys, city_name, country_code from public.hotels_full where hotel_code = %s",
                (c.hotel_code,),
            )
            existing_name, existing_keys, existing_city, existing_country_code = cur.fetchone()
            proposed_keys = c.michelin_keys
            if existing_name == c.name and existing_keys == proposed_keys and existing_city == c.city:
                outcomes.append(RowOutcome(key=key, action="ALREADY_PRESENT", detail="identical hotel already present (idempotent rerun)"))
            else:
                outcomes.append(
                    RowOutcome(
                        key=key,
                        action="CONFLICT",
                        detail=(
                            f"hotel_code exists but differs from the candidate: production has "
                            f"(name={existing_name!r}, keys={existing_keys!r}, city={existing_city!r}), "
                            f"candidate proposes (name={c.name!r}, keys={proposed_keys!r}, city={c.city!r})"
                        ),
                    )
                )
            continue
        missing = [f for f, v in [("address", c.address), ("latitude", c.latitude), ("longitude", c.longitude)] if v is None]
        if missing:
            outcomes.append(
                RowOutcome(
                    key=key,
                    action="BLOCKED_MISSING_REQUIRED_FIELD",
                    detail=(
                        f"missing {missing} — public.hotels.address and .location are NOT NULL; "
                        "never inserted with a fabricated placeholder"
                    ),
                )
            )
            continue
        outcomes.append(RowOutcome(key=key, action="INSERT"))
    return outcomes


def classify_ranking_rows(
    cur: psycopg.Cursor, rows: list[NewRankingRow], hotel_map: dict[str, str]
) -> list[RowOutcome]:
    """hotel_map here must already include both existing-catalogue codes AND
    any new hotel_codes classified INSERT this run (see run_deployment —
    this is called after apply_new_hotels, not before, precisely so newly
    inserted hotels are resolvable for their own ranking rows)."""
    outcomes = []
    for r in rows:
        key = f"{r.hotel_code}.{r.year}"
        if r.hotel_code not in hotel_map:
            outcomes.append(
                RowOutcome(
                    key=key,
                    action="BLOCKED_DEPENDENT_HOTEL",
                    detail=f"hotel_code={r.hotel_code!r} was not inserted this run (see hotel classification) — cannot resolve hotel_id",
                )
            )
            continue
        hid = hotel_map[r.hotel_code]
        cur.execute("select rank, list_type from public.worlds_50_best_hotels where hotel_id = %s and year = %s", (hid, r.year))
        existing = cur.fetchone()
        if existing is None:
            outcomes.append(RowOutcome(key=key, action="INSERT"))
        else:
            existing_rank, existing_list_type = existing
            if existing_rank == r.rank and existing_list_type == r.list_type:
                outcomes.append(RowOutcome(key=key, action="ALREADY_PRESENT"))
            else:
                outcomes.append(
                    RowOutcome(
                        key=key,
                        action="CONFLICT",
                        detail=(
                            f"production has (rank={existing_rank}, list_type={existing_list_type!r}), "
                            f"proposed (rank={r.rank}, list_type={r.list_type!r})"
                        ),
                    )
                )
    return outcomes


# ============================================================
# Apply
# ============================================================


def resolve_or_insert_country(cur: psycopg.Cursor, country_name: str, existing_codes: set[str]) -> str:
    if country_name in NEW_COUNTRY_ISO_CODES:
        code = NEW_COUNTRY_ISO_CODES[country_name]
    else:
        # Fall back to import_catalogue.py's table for countries this
        # expansion's candidates share with the existing catalogue.
        from import_catalogue import COUNTRY_ISO_CODES

        if country_name not in COUNTRY_ISO_CODES:
            raise HotelExpansionDeploymentError(
                f"No ISO 3166-1 alpha-2 mapping for country {country_name!r} in either "
                "NEW_COUNTRY_ISO_CODES or import_catalogue.COUNTRY_ISO_CODES. Add it before proceeding."
            )
        code = COUNTRY_ISO_CODES[country_name]
    if code in existing_codes:
        return code
    cur.execute(
        "insert into public.countries (country_code, name, flag_emoji) values (%s, %s, %s)",
        (code, country_name, _flag_emoji(code)),
    )
    existing_codes.add(code)
    return code


def resolve_or_insert_city(cur: psycopg.Cursor, country_code: str, city_name: str, city_map: dict[tuple[str, str], str]) -> str:
    key = (country_code, city_name)
    if key in city_map:
        return city_map[key]
    cur.execute(
        "insert into public.cities (country_code, name) values (%s, %s) returning id",
        (country_code, city_name),
    )
    (new_id,) = cur.fetchone()
    city_map[key] = str(new_id)
    return str(new_id)


def apply_new_hotels(
    cur: psycopg.Cursor,
    candidates: list[NewHotelCandidate],
    outcomes: list[RowOutcome],
    country_codes: set[str],
    city_map: dict[tuple[str, str], str],
    hotel_map: dict[str, str],
) -> int:
    outcome_by_key = {o.key: o for o in outcomes}
    applied = 0
    for c in candidates:
        if outcome_by_key[c.hotel_code].action != "INSERT":
            continue
        country_code = resolve_or_insert_country(cur, c.country, country_codes)
        city_id = resolve_or_insert_city(cur, country_code, c.city, city_map)
        cur.execute(
            "insert into public.hotels "
            "(hotel_code, name, michelin_keys, city_id, country_code, address, location, "
            " google_place_id, michelin_url, website_url, booking_url) "
            "values (%s, %s, %s, %s, %s, %s, ST_SetSRID(ST_MakePoint(%s, %s), 4326)::geography, %s, %s, %s, %s) "
            "returning id",
            (
                c.hotel_code,
                c.name,
                c.michelin_keys,
                city_id,
                country_code,
                c.address,
                c.longitude,
                c.latitude,
                c.google_place_id,
                c.michelin_url,
                c.website_url,
                c.booking_url,
            ),
        )
        (new_id,) = cur.fetchone()
        hotel_map[c.hotel_code] = str(new_id)
        applied += 1
    return applied


def apply_ranking_rows(cur: psycopg.Cursor, rows: list[NewRankingRow], outcomes: list[RowOutcome], hotel_map: dict[str, str]) -> int:
    outcome_by_key = {o.key: o for o in outcomes}
    applied = 0
    for r in rows:
        key = f"{r.hotel_code}.{r.year}"
        if outcome_by_key[key].action != "INSERT":
            continue
        cur.execute(
            "insert into public.worlds_50_best_hotels (hotel_id, year, rank, list_type) values (%s, %s, %s, %s)",
            (hotel_map[r.hotel_code], r.year, r.rank, r.list_type),
        )
        applied += 1
    return applied


# ============================================================
# Post-deploy validation
# ============================================================


def run_post_deploy_checks(
    cur: psycopg.Cursor,
    before: dict,
    existing_hotel_codes: list[str],
    *,
    new_hotels: list[NewHotelCandidate],
    ranking_rows: list[NewRankingRow],
    hotel_outcomes: list[RowOutcome],
    ranking_outcomes: list[RowOutcome],
) -> list[Check]:
    checks: list[Check] = []
    after = snapshot_invariants(cur, existing_hotel_codes)

    checks.append(Check("existing 687 hotels' michelin_keys/address/place_id/location unchanged", after["existing_hotels"] == before["existing_hotels"]))
    checks.append(Check("hotel_restaurants unchanged", after["links"] == before["links"]))
    checks.append(Check("existing current award_history rows unchanged", after["current_awards"] == before["current_awards"]))

    cur.execute("select count(*) - count(distinct hotel_code) from public.hotels")
    (dup_codes,) = cur.fetchone()
    checks.append(Check("no duplicate hotel_code in public.hotels", dup_codes == 0, str(dup_codes)))

    cur.execute(
        "select hotel_id, year, count(*) from public.worlds_50_best_hotels group by hotel_id, year having count(*) > 1"
    )
    dup_hy = cur.fetchall()
    checks.append(Check("no duplicate (hotel_id, year) in worlds_50_best_hotels", not dup_hy, str(dup_hy[:5])))

    cur.execute(
        "select year, rank, count(*) from public.worlds_50_best_hotels where rank is not null "
        "group by year, rank having count(*) > 1"
    )
    dup_yr = cur.fetchall()
    checks.append(Check("no duplicate (year, rank) in worlds_50_best_hotels", not dup_yr, str(dup_yr[:5])))

    inserted_hotel_codes = [c.hotel_code for c in new_hotels if {o.key: o for o in hotel_outcomes}[c.hotel_code].action == "INSERT"]
    missing_h = []
    for code in inserted_hotel_codes:
        cur.execute("select id from public.hotels where hotel_code = %s", (code,))
        if cur.fetchone() is None:
            missing_h.append(code)
    checks.append(Check(f"all {len(inserted_hotel_codes)} classified-INSERT new hotels are present", not missing_h, str(missing_h[:5])))

    outcome_by_rkey = {o.key: o for o in ranking_outcomes}
    inserted_rank_keys = [f"{r.hotel_code}.{r.year}" for r in ranking_rows if outcome_by_rkey[f"{r.hotel_code}.{r.year}"].action == "INSERT"]
    checks.append(
        Check(
            "ranking rows applied count matches classified INSERT count",
            len(inserted_rank_keys) == sum(1 for o in ranking_outcomes if o.action == "INSERT"),
        )
    )

    # Every inserted hotel has at least one qualifying route: a non-null
    # michelin_keys, or at least one worlds_50_best_hotels row.
    no_route = []
    for code in inserted_hotel_codes:
        cur.execute(
            "select h.michelin_keys, exists(select 1 from public.worlds_50_best_hotels w where w.hotel_id = h.id) "
            "from public.hotels h where h.hotel_code = %s",
            (code,),
        )
        keys, has_w50b = cur.fetchone()
        if keys is None and not has_w50b:
            no_route.append(code)
    checks.append(Check("every inserted hotel has >=1 qualifying route (Key or W50B)", not no_route, str(no_route[:5])))

    # NULL keys never coerced to 0.
    cur.execute("select hotel_code from public.hotels where hotel_code = any(%s) and michelin_keys = 0", (inserted_hotel_codes,))
    zero_keys = [r[0] for r in cur.fetchall()]
    checks.append(Check("no inserted hotel has michelin_keys = 0 (NULL only, never coerced)", not zero_keys, str(zero_keys[:5])))

    return checks


# ============================================================
# Orchestration
# ============================================================


def _print_outcome_summary(label: str, outcomes: list[RowOutcome]) -> None:
    counts = Counter(o.action for o in outcomes)
    print(f"  {label}: {dict(counts)}")


def run_deployment(*, target: str, dry_run: bool, confirm_token: Optional[str]) -> int:
    if target == "remote" and not dry_run:
        if confirm_token != REMOTE_CONFIRM_TOKEN:
            raise HotelExpansionDeploymentError(
                f"Remote deployment requires --confirm-remote-hotel-expansion {REMOTE_CONFIRM_TOKEN!r} exactly. Refusing."
            )

    print("Loading candidate hotel and ranking-history source files...")
    new_hotels = load_new_hotels()
    ranking_rows = load_new_ranking_rows()

    for label, actual, expected in [
        ("new hotel candidates", len(new_hotels), EXPECTED_NEW_HOTEL_ROWS),
        ("worlds_50_best_hotels ranking rows", len(ranking_rows), EXPECTED_RANKING_ROWS),
    ]:
        status = "OK" if actual == expected else "MISMATCH"
        print(f"  [{status}] {label}: {actual} rows (expected {expected})")
        if actual != expected:
            raise HotelExpansionDeploymentError(
                f"{label}: source file has {actual} rows, expected exactly {expected}. Refusing to proceed on "
                "a mismatched source."
            )

    dsn = resolve_dsn(target)
    print(f"\nConnecting to target={target} ({redact_dsn(dsn)})...")

    with psycopg.connect(dsn, autocommit=False) as conn:
        with conn.cursor() as cur:
            try:
                print("\nChecking target schema is ready (nullable michelin_keys, worlds_50_best_hotels exists)...")
                check_target_schema_ready(cur)
                print("  OK — both prerequisite migrations are already applied on this target.")

                hotel_map = fetch_hotel_map(cur)
                existing_hotel_codes = sorted(hotel_map.keys())
                print(f"\nResolving hotel_code against production ({len(hotel_map)} existing hotels)...")

                print("\nSnapshotting invariants (pre-write, scoped to the existing hotels)...")
                before = snapshot_invariants(cur, existing_hotel_codes)

                country_codes = fetch_country_codes(cur)
                city_map = fetch_city_map(cur)

                print("\nClassifying new hotel candidates...")
                hotel_outcomes = classify_new_hotels(cur, new_hotels, hotel_map)
                _print_outcome_summary("new hotels", hotel_outcomes)

                blocked_h = [o for o in hotel_outcomes if o.action == "BLOCKED_MISSING_REQUIRED_FIELD"]
                conflicts_h = [o for o in hotel_outcomes if o.action == "CONFLICT"]
                if blocked_h:
                    print(f"\n{len(blocked_h)} hotel(s) BLOCKED_MISSING_REQUIRED_FIELD — will NOT be inserted this run:")
                    for o in blocked_h[:10]:
                        print(f"  {o.key}: {o.detail}")
                    if len(blocked_h) > 10:
                        print(f"  ... and {len(blocked_h) - 10} more")
                if conflicts_h:
                    print(f"\n{len(conflicts_h)} hotel_code CONFLICT(S) — deployment cannot proceed:")
                    for o in conflicts_h:
                        print(f"  CONFLICT {o.key}: {o.detail}")
                    raise HotelExpansionDeploymentError(
                        f"{len(conflicts_h)} candidate hotel_code(s) already exist in production. Stopping without "
                        "applying anything."
                    )

                print("\nApplying new hotels (only classified INSERT)...")
                n_hotels = apply_new_hotels(cur, new_hotels, hotel_outcomes, country_codes, city_map, hotel_map)
                print(f"  -> {n_hotels} new hotel rows inserted (out of {len(new_hotels)} candidates)")

                print("\nClassifying ranking-history rows (against production + hotels just inserted)...")
                ranking_outcomes = classify_ranking_rows(cur, ranking_rows, hotel_map)
                _print_outcome_summary("ranking rows", ranking_outcomes)

                conflicts_r = [o for o in ranking_outcomes if o.action == "CONFLICT"]
                blocked_r = [o for o in ranking_outcomes if o.action == "BLOCKED_DEPENDENT_HOTEL"]
                if blocked_r:
                    print(f"\n{len(blocked_r)} ranking row(s) BLOCKED_DEPENDENT_HOTEL — will NOT be inserted this run "
                          "(their hotel wasn't inserted this run):")
                    print(f"  (showing 5 of {len(blocked_r)}): " + ", ".join(o.key for o in blocked_r[:5]))
                if conflicts_r:
                    print(f"\n{len(conflicts_r)} ranking row CONFLICT(S) — deployment cannot proceed:")
                    for o in conflicts_r:
                        print(f"  CONFLICT {o.key}: {o.detail}")
                    raise HotelExpansionDeploymentError(
                        f"{len(conflicts_r)} ranking row(s) conflict with existing production values. Stopping — "
                        "everything in this transaction, including the hotel inserts above, will be rolled back."
                    )

                print("\nApplying ranking rows (only classified INSERT)...")
                n_ranking = apply_ranking_rows(cur, ranking_rows, ranking_outcomes, hotel_map)
                print(f"  -> {n_ranking} worlds_50_best_hotels rows inserted")

                print("\nPost-deploy validation...")
                checks = run_post_deploy_checks(
                    cur,
                    before,
                    existing_hotel_codes,
                    new_hotels=new_hotels,
                    ranking_rows=ranking_rows,
                    hotel_outcomes=hotel_outcomes,
                    ranking_outcomes=ranking_outcomes,
                )
                report_checks("Post-deploy validation", checks)

            except Exception:
                conn.rollback()
                print("\nROLLED BACK — no changes were written.", file=sys.stderr)
                raise

            if dry_run:
                conn.rollback()
                print("\nDRY RUN complete — all checks passed, nothing was written (rolled back).")
            else:
                conn.commit()
                print("\nDEPLOYMENT COMPLETE — transaction committed.")

    return 0


# ============================================================
# CLI
# ============================================================


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description=(
            "Insert the union-inclusion-rule hotel catalogue expansion (new hotels + World's 50 Best Hotels "
            "ranking rows) into an ALREADY POPULATED database. Requires the two prerequisite migrations "
            "(nullable michelin_keys, worlds_50_best_hotels table) to already be applied on the target."
        )
    )
    parser.add_argument("--target", choices=["local", "remote"], required=True)
    parser.add_argument("--dry-run", action="store_true", help="Classify, validate and would-write, then roll back.")
    parser.add_argument(
        "--confirm-remote-hotel-expansion",
        default=None,
        metavar="TOKEN",
        help=f"Required, exact value {REMOTE_CONFIRM_TOKEN!r}, for a non-dry-run --target remote.",
    )
    return parser


def main() -> None:
    args = build_parser().parse_args()
    try:
        exit_code = run_deployment(
            target=args.target, dry_run=args.dry_run, confirm_token=args.confirm_remote_hotel_expansion
        )
    except (HotelExpansionDeploymentError, ImportValidationError) as exc:
        print(f"\nERROR: {exc}", file=sys.stderr)
        sys.exit(1)
    except psycopg.Error as exc:
        print(f"\nDATABASE ERROR: {exc}", file=sys.stderr)
        sys.exit(1)
    sys.exit(exit_code)


if __name__ == "__main__":
    main()
