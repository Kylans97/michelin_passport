#!/usr/bin/env python3
"""Michelin Passport catalogue — GREEN-approved enrichment deployment.

Applies the GREEN-classified rows from the catalogue enrichment workstream
(supabase/data/enrichment/APPROVAL_MANIFEST.md) to an ALREADY POPULATED
catalogue database. This is deliberately a separate tool from
import_catalogue.py, which is for empty targets only and refuses to run
otherwise (assert_tables_empty). This script does the opposite: it assumes
the catalogue rows already exist, resolves everything by restaurant_code /
hotel_code, and never inserts a new restaurant or hotel row, never touches a
current award value, and never writes anything not already GREEN-approved.

Two workflows, never mixed:
  import_catalogue.py            — full import into an EMPTY catalogue
  apply_catalogue_enrichment.py  — incremental enrichment of an EXISTING one

What it writes:
  - Existing-column field fills on restaurants/hotels (cuisine, website_url,
    michelin_url, booking_url) — ONLY where the production cell is currently
    NULL/empty. A non-empty production value that disagrees with the
    GREEN-approved one is a CONFLICT and stops the whole deployment.
  - Historical rows into award_history and worlds_50_best — always inserted
    with is_current = false. A production row already present with a
    different value at the same (entity, guide_year, award_type) or
    (restaurant, year) is a CONFLICT and stops the whole deployment.

What it never touches:
  - restaurants.michelin_stars / hotels.michelin_keys (current award values)
  - address, latitude/longitude, google_place_id, location
  - hotel_restaurants
  - any existing is_current = true award_history row
  - the Hall of Fame seeding path (worlds_50_best_hall_of_fame.csv) — the
    existing mechanism in import_catalogue.py already produces that data
    correctly; see supabase/data/enrichment/GREEN_INTEGRATION_AUDIT.md
    section 2 for why it is deliberately not duplicated here.

Everything runs inside one transaction. --dry-run classifies, validates and
would-write, then rolls back unconditionally. A real run commits only if
every post-deploy check passes; any conflict or failed invariant rolls back
the entire transaction, including a real (non-dry-run) one.

Authoritative sources:
  supabase/data/enrichment/APPROVAL_MANIFEST.md
  supabase/data/enrichment/GREEN_INTEGRATION_AUDIT.md
  docs/Architecture/Michelin_Database/DATA_UPDATE_PROCESS.md

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
ENRICHMENT_DIR = DATA_DIR / "enrichment"

# Field-enrichment sources: the GREEN-filtered proposal ledgers from the
# enrichment workstream. These, not a diff of the master CSVs, are the
# authoritative "what to write" list — a master-CSV diff could pick up an
# unrelated later edit that was never reviewed.
RESTAURANT_FIELDS_CSV = ENRICHMENT_DIR / "field_enrichment" / "restaurants_3star_fields.csv"
HOTEL_FIELDS_CSV = ENRICHMENT_DIR / "field_enrichment" / "hotels_3key_fields.csv"

# Historical-data sources: already GREEN-only, already production-shaped,
# living in supabase/data/ per GREEN_INTEGRATION_AUDIT.md section 1. Hall of
# Fame is deliberately absent from this list — see the module docstring.
WORLDS_50_BEST_HISTORY_CSV = DATA_DIR / "worlds_50_best_history.csv"
RESTAURANT_AWARD_HISTORY_CSV = DATA_DIR / "restaurant_award_history.csv"
HOTEL_AWARD_HISTORY_CSV = DATA_DIR / "hotel_award_history.csv"

# Cuisine reference normalization — resolves the blocker found in the prior
# deployment pass (10 GREEN cuisine field values had no matching cuisines
# row). See supabase/data/enrichment/verification/cuisine_normalization_review.{csv,md}
# for the full evidence and reasoning behind each classification.
CUISINE_NORMALIZATION_REVIEW_CSV = ENRICHMENT_DIR / "verification" / "cuisine_normalization_review.csv"

# Closed allowlists. A field-enrichment row naming anything outside these
# sets fails to load rather than being silently written — this is what keeps
# an award value or identity field structurally unreachable by this script,
# independent of what any CSV happens to contain.
ALLOWED_RESTAURANT_FIELDS = {"cuisine", "website_url", "michelin_url", "booking_url"}
ALLOWED_HOTEL_FIELDS = {"website_url", "michelin_url", "booking_url"}

EXPECTED_RESTAURANT_FIELD_ROWS = 108
EXPECTED_HOTEL_FIELD_ROWS = 41
EXPECTED_W50B_HISTORY_ROWS = 726
EXPECTED_RESTAURANT_HISTORY_ROWS = 120
EXPECTED_HOTEL_HISTORY_ROWS = 6
EXPECTED_CUISINE_REVIEW_ROWS = 10
EXPECTED_GREEN_NEW_CUISINE_ROWS = 7
EXPECTED_AMBER_CUISINE_ROWS = 3

REMOTE_CONFIRM_TOKEN = "APPLY-MICHELIN-ENRICHMENT"


class EnrichmentDeploymentError(Exception):
    """Raised when a conflict, unresolved code, or invariant failure means
    the deployment must stop. Always caught at the call site that still
    holds the open transaction, which rolls back before re-raising."""


# ============================================================
# Records
# ============================================================


@dataclass(frozen=True)
class FieldFill:
    code: str
    field: str
    value: str


@dataclass(frozen=True)
class WorldsBestHistoryRow:
    restaurant_code: str
    year: int
    rank: Optional[int]
    list_type: str


@dataclass(frozen=True)
class AwardHistoryRow:
    code: str  # restaurant_code or hotel_code, depending on which list it's in
    guide_year: int
    award_type: str
    award_value: int


@dataclass(frozen=True)
class RowOutcome:
    """One classified row: what would happen (or did happen) and why.

    action is one of INSERT, UPDATE, ALREADY_PRESENT, CONFLICT,
    SKIP_UNRESOLVED_CODE. Only INSERT/UPDATE outcomes are ever written;
    everything else is report-only.
    """

    key: str
    action: str
    detail: str = ""


# ============================================================
# Loaders — the GREEN filter is applied here, not left to the caller
# ============================================================


def _is_green(row: dict) -> bool:
    return row.get("confidence") == "high" and row.get("status") == "proposed"


def load_restaurant_field_fills() -> list[FieldFill]:
    fills: list[FieldFill] = []
    seen: set[tuple[str, str]] = set()
    for row in read_csv_rows(RESTAURANT_FIELDS_CSV):
        if not _is_green(row):
            continue
        field_name = row["field"].strip()
        if field_name not in ALLOWED_RESTAURANT_FIELDS:
            raise EnrichmentDeploymentError(
                f"GREEN restaurant field row targets a disallowed field {field_name!r} for "
                f"{row['restaurant_code']!r} — refusing to load. Only {sorted(ALLOWED_RESTAURANT_FIELDS)} "
                "may ever be written by this script."
            )
        code = row["restaurant_code"].strip()
        key = (code, field_name)
        if key in seen:
            raise EnrichmentDeploymentError(f"Duplicate GREEN restaurant field row for {key!r} — refusing to load.")
        seen.add(key)
        fills.append(FieldFill(code=code, field=field_name, value=row["proposed_value"]))
    return fills


def load_hotel_field_fills() -> list[FieldFill]:
    fills: list[FieldFill] = []
    seen: set[tuple[str, str]] = set()
    for row in read_csv_rows(HOTEL_FIELDS_CSV):
        if not _is_green(row):
            continue
        field_name = row["field"].strip()
        if field_name not in ALLOWED_HOTEL_FIELDS:
            raise EnrichmentDeploymentError(
                f"GREEN hotel field row targets a disallowed field {field_name!r} for "
                f"{row['hotel_code']!r} — refusing to load. Only {sorted(ALLOWED_HOTEL_FIELDS)} "
                "may ever be written by this script."
            )
        code = row["hotel_code"].strip()
        key = (code, field_name)
        if key in seen:
            raise EnrichmentDeploymentError(f"Duplicate GREEN hotel field row for {key!r} — refusing to load.")
        seen.add(key)
        fills.append(FieldFill(code=code, field=field_name, value=row["proposed_value"]))
    return fills


def load_worlds_50_best_history() -> list[WorldsBestHistoryRow]:
    rows = []
    for row in read_csv_rows(WORLDS_50_BEST_HISTORY_CSV):
        rows.append(
            WorldsBestHistoryRow(
                restaurant_code=row["restaurant_code"].strip(),
                year=int(row["year"].strip()),
                rank=parse_optional_int(row["rank"]),
                list_type=row["list_type"].strip(),
            )
        )
    return rows


def load_restaurant_award_history() -> list[AwardHistoryRow]:
    rows = []
    for row in read_csv_rows(RESTAURANT_AWARD_HISTORY_CSV):
        rows.append(
            AwardHistoryRow(
                code=row["restaurant_code"].strip(),
                guide_year=int(row["guide_year"].strip()),
                award_type=row["award_type"].strip(),
                award_value=int(row["award_value"].strip()),
            )
        )
    return rows


def load_hotel_award_history() -> list[AwardHistoryRow]:
    rows = []
    for row in read_csv_rows(HOTEL_AWARD_HISTORY_CSV):
        rows.append(
            AwardHistoryRow(
                code=row["hotel_code"].strip(),
                guide_year=int(row["guide_year"].strip()),
                award_type=row["award_type"].strip(),
                award_value=int(row["award_value"].strip()),
            )
        )
    return rows


def load_cuisine_normalization_review() -> tuple[list[str], set[str]]:
    """Returns (green_new_names, amber_names) from the reviewed
    classification ledger. GREEN_NEW names are safe to insert into
    public.cuisines as a new reference row. AMBER names are real,
    evidence-backed cuisine descriptions that sit close enough to an
    existing value that a human should decide whether to keep them distinct
    — this script never inserts one and never guesses a merge; the
    restaurant rows that need one are deferred, not blocked and not applied.
    Anything other than GREEN_NEW/AMBER in the file (RED, GREEN_MAP_EXISTING)
    is deliberately not handled here — neither is currently used by any row.
    """
    green_new: list[str] = []
    amber: set[str] = set()
    for row in read_csv_rows(CUISINE_NORMALIZATION_REVIEW_CSV):
        classification = row["classification"].strip()
        name = row["proposed_cuisine"].strip()
        if classification == "GREEN_NEW":
            green_new.append(name)
        elif classification == "AMBER":
            amber.add(name)
        else:
            raise EnrichmentDeploymentError(
                f"cuisine_normalization_review.csv row {name!r} has classification "
                f"{classification!r} — only GREEN_NEW and AMBER are implemented. "
                "A GREEN_MAP_EXISTING or RED row here needs script support added "
                "before this can run, not a silent skip."
            )
    return green_new, amber


# ============================================================
# Code resolution
# ============================================================


def fetch_restaurant_map(cur: psycopg.Cursor) -> dict[str, str]:
    cur.execute("select restaurant_code, id from public.restaurants")
    return {code: str(rid) for code, rid in cur.fetchall()}


def fetch_cuisine_map(cur: psycopg.Cursor) -> dict[str, int]:
    """restaurants.cuisine has no column of that name — it's cuisine_id, a
    foreign key into cuisines(id). GREEN cuisine fills carry a name; this
    resolves it. A name with no matching row is never silently inserted —
    that would add a reference-table row the approval manifest never
    considered — it's classified UNRESOLVED_CUISINE instead."""
    cur.execute("select name, id from public.cuisines")
    return {name: cid for name, cid in cur.fetchall()}


def fetch_hotel_map(cur: psycopg.Cursor) -> dict[str, str]:
    cur.execute("select hotel_code, id from public.hotels")
    return {code: str(hid) for code, hid in cur.fetchall()}


# ============================================================
# Invariant snapshot — proves nothing off-limits moved
# ============================================================


def snapshot_invariants(cur: psycopg.Cursor) -> dict:
    """Everything this script must never change, captured before any write
    and re-captured after, so an accidental touch is caught by comparison
    rather than assumed absent."""
    cur.execute("select restaurant_code, michelin_stars from public.restaurants order by restaurant_code")
    stars = tuple(cur.fetchall())
    cur.execute("select hotel_code, michelin_keys from public.hotels order by hotel_code")
    keys = tuple(cur.fetchall())
    cur.execute(
        "select restaurant_code, address, google_place_id, ST_AsText(location) "
        "from public.restaurants order by restaurant_code"
    )
    r_geo = tuple(cur.fetchall())
    cur.execute(
        "select hotel_code, address, google_place_id, ST_AsText(location) from public.hotels order by hotel_code"
    )
    h_geo = tuple(cur.fetchall())
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
    return {
        "stars": stars,
        "keys": keys,
        "r_geo": r_geo,
        "h_geo": h_geo,
        "links": links,
        "current_awards": current_awards,
    }


# ============================================================
# Classification — read-only, decides INSERT / UPDATE / ALREADY_PRESENT / CONFLICT
# ============================================================


def classify_field_fills(
    cur: psycopg.Cursor,
    fills: list[FieldFill],
    code_map: dict[str, str],
    table: str,
    code_column: str,
) -> list[RowOutcome]:
    """table/code_column are fixed literals from the call site (never
    data-derived); f.field is validated against a closed allowlist at load
    time in load_*_field_fills(). Both are required before either is used to
    build a query string below.

    Never call this with field == "cuisine" — that name has no matching
    production column (it's cuisine_id, a foreign key). Use
    classify_cuisine_fills / apply_cuisine_fills for it instead."""
    outcomes = []
    for f in fills:
        if f.field == "cuisine":
            raise EnrichmentDeploymentError(
                "classify_field_fills received a 'cuisine' row — that must go through "
                "classify_cuisine_fills instead, which resolves it to cuisine_id."
            )
        key = f"{f.code}.{f.field}"
        if f.code not in code_map:
            outcomes.append(RowOutcome(key=key, action="SKIP_UNRESOLVED_CODE", detail=f"{code_column}={f.code!r} not found in production"))
            continue
        cur.execute(f"select {f.field} from public.{table} where {code_column} = %s", (f.code,))  # noqa: S608 — field/table validated above
        (current,) = cur.fetchone()
        if current is None or current == "":
            outcomes.append(RowOutcome(key=key, action="UPDATE", detail=f"currently empty, would set to {f.value!r}"))
        elif current == f.value:
            outcomes.append(RowOutcome(key=key, action="ALREADY_PRESENT", detail="identical value already stored"))
        else:
            outcomes.append(
                RowOutcome(key=key, action="CONFLICT", detail=f"production has {current!r}, GREEN proposes {f.value!r}")
            )
    return outcomes


def classify_worlds_50_best(
    cur: psycopg.Cursor, rows: list[WorldsBestHistoryRow], restaurant_map: dict[str, str]
) -> list[RowOutcome]:
    outcomes = []
    for r in rows:
        key = f"{r.restaurant_code}.{r.year}"
        if r.restaurant_code not in restaurant_map:
            outcomes.append(RowOutcome(key=key, action="SKIP_UNRESOLVED_CODE", detail="restaurant_code not found in production"))
            continue
        rid = restaurant_map[r.restaurant_code]
        cur.execute("select rank, list_type from public.worlds_50_best where restaurant_id = %s and year = %s", (rid, r.year))
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
                            f"GREEN proposes (rank={r.rank}, list_type={r.list_type!r})"
                        ),
                    )
                )
    return outcomes


def classify_award_history(
    cur: psycopg.Cursor, rows: list[AwardHistoryRow], code_map: dict[str, str], entity_type: str
) -> list[RowOutcome]:
    outcomes = []
    for r in rows:
        key = f"{entity_type}.{r.code}.{r.guide_year}.{r.award_type}"
        if r.code not in code_map:
            outcomes.append(RowOutcome(key=key, action="SKIP_UNRESOLVED_CODE", detail=f"{entity_type}_code not found in production"))
            continue
        eid = code_map[r.code]
        cur.execute(
            "select award_value, is_current from public.award_history "
            "where entity_type = %s and entity_id = %s and guide_year = %s and award_type = %s",
            (entity_type, eid, r.guide_year, r.award_type),
        )
        existing = cur.fetchone()
        if existing is None:
            outcomes.append(RowOutcome(key=key, action="INSERT"))
        else:
            existing_value, existing_is_current = existing
            if existing_is_current:
                # Structurally shouldn't happen — every source guide_year is
                # historical by construction (see GREEN_INTEGRATION_AUDIT.md
                # section 3) — but treated as a hard-stop conflict rather
                # than assumed impossible.
                outcomes.append(
                    RowOutcome(
                        key=key,
                        action="CONFLICT",
                        detail="an existing CURRENT award row already occupies this (entity, guide_year, award_type) slot",
                    )
                )
            elif existing_value == r.award_value:
                outcomes.append(RowOutcome(key=key, action="ALREADY_PRESENT"))
            else:
                outcomes.append(
                    RowOutcome(
                        key=key,
                        action="CONFLICT",
                        detail=f"production has award_value={existing_value}, GREEN proposes {r.award_value}",
                    )
                )
    return outcomes


def classify_cuisine_references(cur: psycopg.Cursor, green_new_names: list[str], cuisine_map: dict[str, int]) -> list[RowOutcome]:
    """Only ever called with GREEN_NEW names — AMBER names never reach this
    function, so this script can never insert one, by construction rather
    than by a runtime check. A name already present (this run or a prior
    one) classifies ALREADY_PRESENT; a name never seen before classifies
    INSERT. There is no CONFLICT case for a plain name-only reference row —
    the closest equivalent, a duplicate insert, is caught by the
    catalogue's own UNIQUE(name) constraint if this classification and the
    apply step ever disagree, which aborts the transaction rather than
    silently succeeding."""
    outcomes = []
    for name in green_new_names:
        if name in cuisine_map:
            outcomes.append(RowOutcome(key=name, action="ALREADY_PRESENT", detail=f"cuisines.id={cuisine_map[name]} already exists"))
        else:
            outcomes.append(RowOutcome(key=name, action="INSERT", detail="no existing cuisines row for this name"))
    return outcomes


def classify_cuisine_fills(
    cur: psycopg.Cursor,
    fills: list[FieldFill],
    restaurant_map: dict[str, str],
    cuisine_map: dict[str, int],
    amber_cuisine_names: set[str],
) -> list[RowOutcome]:
    """Dedicated path for field == 'cuisine' rows: resolves the proposed
    name to cuisines.id and compares against restaurants.cuisine_id — see
    classify_field_fills' docstring for why these can't share a code path.

    cuisine_map is expected to already include every GREEN_NEW cuisine name
    (inserted or confirmed present by classify_cuisine_references/
    apply_cuisine_references, called earlier in the same transaction) —
    see run_deployment. A name still missing from cuisine_map at this point
    is either a known AMBER deferral (reported, does not block the rest of
    the deployment) or a genuinely unexpected name (reported, DOES block —
    it was never reviewed at all)."""
    outcomes = []
    for f in fills:
        key = f"{f.code}.cuisine"
        if f.code not in restaurant_map:
            outcomes.append(RowOutcome(key=key, action="SKIP_UNRESOLVED_CODE", detail=f"restaurant_code={f.code!r} not found in production"))
            continue
        if f.value not in cuisine_map:
            if f.value in amber_cuisine_names:
                outcomes.append(
                    RowOutcome(
                        key=key,
                        action="DEFERRED_AMBER_CUISINE",
                        detail=(
                            f"cuisine {f.value!r} is classified AMBER in cuisine_normalization_review.csv — "
                            "held back pending human review, not applied, does not block the rest of this deployment"
                        ),
                    )
                )
            else:
                outcomes.append(
                    RowOutcome(
                        key=key,
                        action="UNRESOLVED_CUISINE",
                        detail=(
                            f"cuisine {f.value!r} has no row in public.cuisines and is not a recognized AMBER "
                            "deferral — unreviewed, unexpected, blocks the whole deployment"
                        ),
                    )
                )
            continue
        proposed_id = cuisine_map[f.value]
        cur.execute(
            "select r.cuisine_id, c.name from public.restaurants r left join public.cuisines c on c.id = r.cuisine_id "
            "where r.restaurant_code = %s",
            (f.code,),
        )
        existing_id, existing_name = cur.fetchone()
        if existing_id is None:
            outcomes.append(RowOutcome(key=key, action="UPDATE", detail=f"currently empty, would set to {f.value!r} (cuisine_id={proposed_id})"))
        elif existing_id == proposed_id:
            outcomes.append(RowOutcome(key=key, action="ALREADY_PRESENT", detail="identical cuisine already stored"))
        else:
            outcomes.append(
                RowOutcome(key=key, action="CONFLICT", detail=f"production has {existing_name!r}, GREEN proposes {f.value!r}")
            )
    return outcomes


# ============================================================
# Apply — only ever acts on INSERT/UPDATE outcomes
# ============================================================


def apply_field_fills(
    cur: psycopg.Cursor,
    fills: list[FieldFill],
    outcomes: list[RowOutcome],
    table: str,
    code_column: str,
) -> int:
    outcome_by_key = {o.key: o for o in outcomes}
    applied = 0
    for f in fills:
        outcome = outcome_by_key[f"{f.code}.{f.field}"]
        if outcome.action != "UPDATE":
            continue
        # The "and {field} is null" clause is a second, self-contained guard
        # against overwriting a non-empty cell — correct even if something
        # else wrote to this row between classification and this statement.
        cur.execute(
            f"update public.{table} set {f.field} = %s where {code_column} = %s and {f.field} is null",  # noqa: S608
            (f.value, f.code),
        )
        if cur.rowcount != 1:
            raise EnrichmentDeploymentError(
                f"Expected to update exactly 1 row for {code_column}={f.code!r} {f.field}, "
                f"affected {cur.rowcount} instead — aborting rather than risk a partial or racing write."
            )
        applied += 1
    return applied


def apply_cuisine_references(
    cur: psycopg.Cursor,
    green_new_names: list[str],
    outcomes: list[RowOutcome],
    cuisine_map: dict[str, int],
) -> int:
    """Inserts only the names classified INSERT. Never specifies an id —
    cuisines.id is `smallint generated always as identity`, so PostgreSQL
    assigns it; RETURNING id captures the assigned value so the very next
    step (restaurant field enrichment, in the same transaction) can use it
    immediately. Mutates cuisine_map in place with every GREEN_NEW name's id
    (both freshly inserted and already-present), which is what unblocks
    classify_cuisine_fills for exactly the rows this review approved."""
    outcome_by_key = {o.key: o for o in outcomes}
    applied = 0
    for name in green_new_names:
        outcome = outcome_by_key[name]
        if outcome.action != "INSERT":
            continue
        cur.execute("insert into public.cuisines (name) values (%s) returning id", (name,))
        (new_id,) = cur.fetchone()
        cuisine_map[name] = new_id
        applied += 1
    return applied


def apply_cuisine_fills(
    cur: psycopg.Cursor,
    fills: list[FieldFill],
    outcomes: list[RowOutcome],
    cuisine_map: dict[str, int],
) -> int:
    outcome_by_key = {o.key: o for o in outcomes}
    applied = 0
    for f in fills:
        outcome = outcome_by_key[f"{f.code}.cuisine"]
        if outcome.action != "UPDATE":
            continue
        cur.execute(
            "update public.restaurants set cuisine_id = %s where restaurant_code = %s and cuisine_id is null",
            (cuisine_map[f.value], f.code),
        )
        if cur.rowcount != 1:
            raise EnrichmentDeploymentError(
                f"Expected to update exactly 1 row for restaurant_code={f.code!r} cuisine_id, "
                f"affected {cur.rowcount} instead — aborting rather than risk a partial or racing write."
            )
        applied += 1
    return applied


def apply_worlds_50_best(
    cur: psycopg.Cursor,
    rows: list[WorldsBestHistoryRow],
    outcomes: list[RowOutcome],
    restaurant_map: dict[str, str],
) -> int:
    outcome_by_key = {o.key: o for o in outcomes}
    applied = 0
    for r in rows:
        if outcome_by_key[f"{r.restaurant_code}.{r.year}"].action != "INSERT":
            continue
        cur.execute(
            "insert into public.worlds_50_best (restaurant_id, year, rank, list_type) values (%s, %s, %s, %s)",
            (restaurant_map[r.restaurant_code], r.year, r.rank, r.list_type),
        )
        applied += 1
    return applied


def apply_award_history(
    cur: psycopg.Cursor,
    rows: list[AwardHistoryRow],
    outcomes: list[RowOutcome],
    code_map: dict[str, str],
    entity_type: str,
) -> int:
    outcome_by_key = {o.key: o for o in outcomes}
    applied = 0
    for r in rows:
        key = f"{entity_type}.{r.code}.{r.guide_year}.{r.award_type}"
        if outcome_by_key[key].action != "INSERT":
            continue
        cur.execute(
            "insert into public.award_history (entity_type, entity_id, guide_year, award_type, award_value, is_current) "
            "values (%s, %s, %s, %s, %s, false)",
            (entity_type, code_map[r.code], r.guide_year, r.award_type, r.award_value),
        )
        applied += 1
    return applied


# ============================================================
# Post-deploy validation
# ============================================================


def run_post_deploy_checks(
    cur: psycopg.Cursor,
    before: dict,
    *,
    restaurant_fills: list[FieldFill],
    hotel_fills: list[FieldFill],
    w50b_history: list[WorldsBestHistoryRow],
    r_award_history: list[AwardHistoryRow],
    h_award_history: list[AwardHistoryRow],
    restaurant_map: dict[str, str],
    hotel_map: dict[str, str],
    cuisine_map: dict[str, int],
    green_new_cuisines: list[str],
    amber_cuisines: set[str],
) -> list[Check]:
    checks: list[Check] = []
    after = snapshot_invariants(cur)

    cur.execute("select name from public.cuisines")
    all_cuisine_names = [r[0] for r in cur.fetchall()]
    dupe_cuisines = [n for n, c in Counter(all_cuisine_names).items() if c > 1]
    checks.append(Check("no duplicate cuisine names in public.cuisines", not dupe_cuisines, str(dupe_cuisines)))

    missing_refs = [n for n in green_new_cuisines if n not in all_cuisine_names]
    checks.append(
        Check(f"cuisine references: all {len(green_new_cuisines)} GREEN_NEW names now exist", not missing_refs, str(missing_refs))
    )

    checks.append(Check("current restaurant michelin_stars unchanged", after["stars"] == before["stars"]))
    checks.append(Check("current hotel michelin_keys unchanged", after["keys"] == before["keys"]))
    checks.append(Check("restaurant address / google_place_id / location unchanged", after["r_geo"] == before["r_geo"]))
    checks.append(Check("hotel address / google_place_id / location unchanged", after["h_geo"] == before["h_geo"]))
    checks.append(Check("hotel_restaurants unchanged", after["links"] == before["links"]))
    checks.append(Check("existing current award_history rows unchanged", after["current_awards"] == before["current_awards"]))

    non_cuisine_restaurant_fills = [f for f in restaurant_fills if f.field != "cuisine"]
    cuisine_fills = [f for f in restaurant_fills if f.field == "cuisine"]

    for label, fills, table, code_col in [
        ("restaurant field enrichment", non_cuisine_restaurant_fills, "restaurants", "restaurant_code"),
        ("hotel field enrichment", hotel_fills, "hotels", "hotel_code"),
    ]:
        missing = []
        for f in fills:
            cur.execute(f"select {f.field} from public.{table} where {code_col} = %s", (f.code,))  # noqa: S608
            row = cur.fetchone()
            if row is None or row[0] != f.value:
                missing.append(f"{f.code}.{f.field}")
        checks.append(Check(f"{label}: all {len(fills)} GREEN values represented", not missing, str(missing[:5])))

    applicable_cuisine_fills = [f for f in cuisine_fills if f.value not in amber_cuisines]
    deferred_cuisine_fills = [f for f in cuisine_fills if f.value in amber_cuisines]

    missing_c = []
    for f in applicable_cuisine_fills:
        proposed_id = cuisine_map.get(f.value)
        cur.execute("select cuisine_id from public.restaurants where restaurant_code = %s", (f.code,))
        row = cur.fetchone()
        if proposed_id is None or row is None or row[0] != proposed_id:
            missing_c.append(f"{f.code}.cuisine")
    checks.append(
        Check(
            f"restaurant cuisine enrichment: all {len(applicable_cuisine_fills)} non-deferred GREEN values represented",
            not missing_c,
            str(missing_c[:5]),
        )
    )

    still_null = []
    for f in deferred_cuisine_fills:
        cur.execute("select cuisine_id from public.restaurants where restaurant_code = %s", (f.code,))
        row = cur.fetchone()
        if row is None or row[0] is not None:
            still_null.append(f"{f.code}.cuisine")
    checks.append(
        Check(
            f"restaurant cuisine enrichment: all {len(deferred_cuisine_fills)} AMBER-deferred rows correctly left untouched",
            not still_null,
            str(still_null[:5]),
        )
    )

    missing_w = []
    for r in w50b_history:
        rid = restaurant_map.get(r.restaurant_code)
        if rid is None:
            missing_w.append(r.restaurant_code)
            continue
        cur.execute("select rank, list_type from public.worlds_50_best where restaurant_id = %s and year = %s", (rid, r.year))
        row = cur.fetchone()
        if row is None or row[0] != r.rank or row[1] != r.list_type:
            missing_w.append(f"{r.restaurant_code}.{r.year}")
    checks.append(Check(f"worlds_50_best: all {len(w50b_history)} GREEN rows represented", not missing_w, str(missing_w[:5])))

    for label, rows, code_map, entity_type in [
        ("restaurant award history", r_award_history, restaurant_map, "restaurant"),
        ("hotel award history", h_award_history, hotel_map, "hotel"),
    ]:
        missing_a = []
        for r in rows:
            eid = code_map.get(r.code)
            if eid is None:
                missing_a.append(r.code)
                continue
            cur.execute(
                "select award_value from public.award_history where entity_type = %s and entity_id = %s "
                "and guide_year = %s and award_type = %s and is_current = false",
                (entity_type, eid, r.guide_year, r.award_type),
            )
            row = cur.fetchone()
            if row is None or row[0] != r.award_value:
                missing_a.append(f"{r.code}.{r.guide_year}")
        checks.append(Check(f"{label}: all {len(rows)} GREEN rows represented", not missing_a, str(missing_a[:5])))

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
            raise EnrichmentDeploymentError(
                f"Remote deployment requires --confirm-remote-enrichment {REMOTE_CONFIRM_TOKEN!r} exactly. Refusing."
            )

    print("Loading GREEN-approved enrichment source files...")
    restaurant_fills = load_restaurant_field_fills()
    hotel_fills = load_hotel_field_fills()
    w50b_history = load_worlds_50_best_history()
    r_award_history = load_restaurant_award_history()
    h_award_history = load_hotel_award_history()
    green_new_cuisines, amber_cuisines = load_cuisine_normalization_review()

    for label, actual, expected in [
        ("restaurant field fills", len(restaurant_fills), EXPECTED_RESTAURANT_FIELD_ROWS),
        ("hotel field fills", len(hotel_fills), EXPECTED_HOTEL_FIELD_ROWS),
        ("worlds_50_best history", len(w50b_history), EXPECTED_W50B_HISTORY_ROWS),
        ("restaurant award history", len(r_award_history), EXPECTED_RESTAURANT_HISTORY_ROWS),
        ("hotel award history", len(h_award_history), EXPECTED_HOTEL_HISTORY_ROWS),
        ("cuisine review: GREEN_NEW", len(green_new_cuisines), EXPECTED_GREEN_NEW_CUISINE_ROWS),
        ("cuisine review: AMBER", len(amber_cuisines), EXPECTED_AMBER_CUISINE_ROWS),
    ]:
        status = "OK" if actual == expected else "MISMATCH"
        print(f"  [{status}] {label}: {actual} rows (expected {expected})")
        if actual != expected:
            raise EnrichmentDeploymentError(
                f"{label}: source file has {actual} rows, expected exactly {expected}. Refusing to proceed on "
                "a mismatched source — find out why the source file changed rather than adjusting this number."
            )

    dsn = resolve_dsn(target)
    print(f"\nConnecting to target={target} ({redact_dsn(dsn)})...")

    with psycopg.connect(dsn, autocommit=False) as conn:
        with conn.cursor() as cur:
            try:
                print("\nSnapshotting invariants (pre-write)...")
                before = snapshot_invariants(cur)
                print(
                    f"  {len(before['stars'])} restaurants, {len(before['keys'])} hotels, "
                    f"{len(before['links'])} hotel-restaurant links, {len(before['current_awards'])} current awards"
                )

                print("\nResolving restaurant_code / hotel_code / cuisine against production...")
                restaurant_map = fetch_restaurant_map(cur)
                hotel_map = fetch_hotel_map(cur)
                cuisine_map = fetch_cuisine_map(cur)
                print(
                    f"  {len(restaurant_map)} restaurants, {len(hotel_map)} hotels, "
                    f"{len(cuisine_map)} cuisines found in production"
                )

                non_cuisine_restaurant_fills = [f for f in restaurant_fills if f.field != "cuisine"]
                cuisine_fills = [f for f in restaurant_fills if f.field == "cuisine"]

                print("\nClassifying...")
                # Cuisine reference rows first, and applied before anything
                # else — "immediately before restaurant field enrichment" —
                # so cuisine_map already carries every GREEN_NEW id by the
                # time classify_cuisine_fills runs.
                # Classified AND applied here, immediately, not deferred to
                # the general "Applying..." phase below: classify_cuisine_fills
                # (right after this) needs cuisine_map to already carry every
                # GREEN_NEW id, which only exists once these rows are
                # actually written — a read of a same-transaction write, not
                # a separate step. dry_run still governs the transaction's
                # final commit/rollback, so this is exactly as reversible as
                # everything else the script writes.
                cr_outcomes = classify_cuisine_references(cur, green_new_cuisines, cuisine_map)
                _print_outcome_summary("cuisine reference rows (GREEN_NEW only)", cr_outcomes)
                n_cr = apply_cuisine_references(cur, green_new_cuisines, cr_outcomes, cuisine_map)
                print(f"  -> {n_cr} cuisine reference rows inserted immediately (before restaurant field enrichment)")

                rf_outcomes = classify_field_fills(cur, non_cuisine_restaurant_fills, restaurant_map, "restaurants", "restaurant_code")
                _print_outcome_summary("restaurant field fills (website/michelin/booking url)", rf_outcomes)
                cf_outcomes = classify_cuisine_fills(cur, cuisine_fills, restaurant_map, cuisine_map, amber_cuisines)
                _print_outcome_summary("restaurant cuisine fills", cf_outcomes)
                hf_outcomes = classify_field_fills(cur, hotel_fills, hotel_map, "hotels", "hotel_code")
                _print_outcome_summary("hotel field fills", hf_outcomes)
                w50b_outcomes = classify_worlds_50_best(cur, w50b_history, restaurant_map)
                _print_outcome_summary("worlds_50_best history", w50b_outcomes)
                rah_outcomes = classify_award_history(cur, r_award_history, restaurant_map, "restaurant")
                _print_outcome_summary("restaurant award history", rah_outcomes)
                hah_outcomes = classify_award_history(cur, h_award_history, hotel_map, "hotel")
                _print_outcome_summary("hotel award history", hah_outcomes)

                all_outcomes = cr_outcomes + rf_outcomes + cf_outcomes + hf_outcomes + w50b_outcomes + rah_outcomes + hah_outcomes
                conflicts = [o for o in all_outcomes if o.action == "CONFLICT"]
                unresolved = [o for o in all_outcomes if o.action in ("SKIP_UNRESOLVED_CODE", "UNRESOLVED_CUISINE")]
                deferred = [o for o in all_outcomes if o.action == "DEFERRED_AMBER_CUISINE"]
                total_counts = Counter(o.action for o in all_outcomes)
                print(f"\nOverall: {dict(total_counts)}")

                if conflicts:
                    print(f"\n{len(conflicts)} CONFLICT(S) — deployment cannot proceed:")
                    for o in conflicts:
                        print(f"  CONFLICT {o.key}: {o.detail}")
                    raise EnrichmentDeploymentError(
                        f"{len(conflicts)} row(s) conflict with existing production values. Stopping without "
                        "applying anything. Each needs explicit human review before this can be re-run."
                    )
                if unresolved:
                    print(f"\n{len(unresolved)} UNRESOLVED ROW(S) — deployment cannot proceed:")
                    for o in unresolved:
                        print(f"  {o.action} {o.key}: {o.detail}")
                    raise EnrichmentDeploymentError(
                        f"{len(unresolved)} row(s) reference a restaurant_code/hotel_code/cuisine not present in "
                        "production and not a recognized AMBER deferral. Stopping without applying anything."
                    )
                if deferred:
                    print(f"\n{len(deferred)} DEFERRED (known AMBER cuisine, not blocking) — will NOT be applied this run:")
                    for o in deferred:
                        print(f"  {o.action} {o.key}: {o.detail}")

                if total_counts.get("INSERT", 0) == 0 and total_counts.get("UPDATE", 0) == 0:
                    print("\n0 required new writes — every GREEN-approved row is already represented in production.")

                print("\nApplying...")
                print(f"  cuisine reference rows: {n_cr} inserted (already applied above, before classification)")
                n_rf = apply_field_fills(cur, non_cuisine_restaurant_fills, rf_outcomes, "restaurants", "restaurant_code")
                print(f"  restaurant field fills (website/michelin/booking url): {n_rf} cells updated")
                n_cf = apply_cuisine_fills(cur, cuisine_fills, cf_outcomes, cuisine_map)
                print(f"  restaurant cuisine fills: {n_cf} cells updated ({len(deferred)} deferred, not applied)")
                n_hf = apply_field_fills(cur, hotel_fills, hf_outcomes, "hotels", "hotel_code")
                print(f"  hotel field fills: {n_hf} cells updated")
                n_w50b = apply_worlds_50_best(cur, w50b_history, w50b_outcomes, restaurant_map)
                print(f"  worlds_50_best history: {n_w50b} rows inserted")
                n_rah = apply_award_history(cur, r_award_history, rah_outcomes, restaurant_map, "restaurant")
                print(f"  restaurant award history: {n_rah} rows inserted")
                n_hah = apply_award_history(cur, h_award_history, hah_outcomes, hotel_map, "hotel")
                print(f"  hotel award history: {n_hah} rows inserted")

                print("\nPost-deploy validation...")
                checks = run_post_deploy_checks(
                    cur,
                    before,
                    restaurant_fills=restaurant_fills,
                    hotel_fills=hotel_fills,
                    w50b_history=w50b_history,
                    r_award_history=r_award_history,
                    h_award_history=h_award_history,
                    restaurant_map=restaurant_map,
                    hotel_map=hotel_map,
                    cuisine_map=cuisine_map,
                    green_new_cuisines=green_new_cuisines,
                    amber_cuisines=amber_cuisines,
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
            "Apply GREEN-approved catalogue enrichment to an ALREADY POPULATED database. "
            "Never point this at an empty target — use import_catalogue.py for that."
        )
    )
    parser.add_argument("--target", choices=["local", "remote"], required=True)
    parser.add_argument("--dry-run", action="store_true", help="Classify, validate and would-write, then roll back.")
    parser.add_argument(
        "--confirm-remote-enrichment",
        default=None,
        metavar="TOKEN",
        help=f"Required, exact value {REMOTE_CONFIRM_TOKEN!r}, for a non-dry-run --target remote.",
    )
    return parser


def main() -> None:
    args = build_parser().parse_args()
    try:
        exit_code = run_deployment(target=args.target, dry_run=args.dry_run, confirm_token=args.confirm_remote_enrichment)
    except (EnrichmentDeploymentError, ImportValidationError) as exc:
        print(f"\nERROR: {exc}", file=sys.stderr)
        sys.exit(1)
    except psycopg.Error as exc:
        print(f"\nDATABASE ERROR: {exc}", file=sys.stderr)
        sys.exit(1)
    sys.exit(exit_code)


if __name__ == "__main__":
    main()
