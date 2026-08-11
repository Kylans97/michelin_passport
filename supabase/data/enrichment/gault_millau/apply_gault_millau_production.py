#!/usr/bin/env python3
"""Gault&Millau — production application (task: "SCHEMA MIGRATION + EXISTING-
MATCH IMPORT + REMOTE VERIFICATION").

This is a SEPARATE tool from import_gault_millau.py, deliberately -- that
script was built with no remote/production capability at all, on purpose
(see its own module docstring), mirroring this repo's existing
import_catalogue.py vs apply_catalogue_enrichment.py split ("two
workflows, never mixed"). Rather than retrofitting remote access onto a
script explicitly designed never to have it, this file is new, reuses
import_gault_millau.py's pure CSV-parsing/classification logic (import
only -- no DB code path from that file is ever exercised), and targets
production through a different, narrower channel: it never holds a raw
database connection string or password itself. It only ever WRITES a .sql
file; the actual remote read or write happens by piping that file through
the Supabase CLI's own authenticated channel:

  supabase db query --linked --file <generated>.sql

This keeps every credential inside the CLI's existing, already-trusted
auth (the same mechanism already used for `supabase db push` and
`supabase db dump` in this session) -- this script never sees, stores, or
requests a database password or service-role key.

Two modes:

  --mode dry-run   Generates a read-only SQL file (SELECT statements only)
                    that resolves every launch-scope row against LIVE
                    production restaurant/country identities and reports
                    what WOULD happen (INSERT / ALREADY_PRESENT / CONFLICT
                    / SKIP_UNRESOLVED), with zero writes possible -- the
                    generated file contains no INSERT/UPDATE/DELETE
                    statement at all.

  --mode apply     Generates an idempotent SQL file that performs the
                    actual INSERTs, gated per-row by
                    "INSERT ... SELECT ... WHERE NOT EXISTS (...)" so a
                    restaurant_code that fails to resolve against the live
                    restaurants table silently inserts zero rows for that
                    line (never errors, never guesses an id) and a
                    re-run against already-imported data inserts zero
                    duplicate rows (idempotent by construction, not just
                    by a database constraint). No UPDATE, no DELETE,
                    anywhere in the generated file.

Both modes only ever touch gault_millau_awards / gault_millau_special_awards
via the .sql file they generate -- this script itself makes no other
change, and never touches public.restaurants (no restaurant is ever
created, per the task's explicit "DO NOT add any new restaurant rows").

Deferred markets (Germany) are excluded via the same
DEFERRED_COUNTRY_CODES constant import_gault_millau.py already uses.
gm_024 is excluded because it is classified REVIEW, not
EXACT/HIGH_CONFIDENCE -- structurally absent from load_award_rows()'s
output, the same guarantee import_gault_millau.py already relies on.

Usage:
  python3 apply_gault_millau_production.py --mode dry-run -o /tmp/gm_dry_run.sql
  supabase db query --linked --file /tmp/gm_dry_run.sql

  python3 apply_gault_millau_production.py --mode apply -o /tmp/gm_apply.sql
  supabase db query --linked --file /tmp/gm_apply.sql
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

from import_gault_millau import (
    DEFERRED_COUNTRY_CODES,
    AwardRow,
    SpecialAwardRow,
    load_award_rows,
    load_special_award_rows,
)


def _sql_str(value: str | None) -> str:
    """NULL for None; a single-quoted, escaped SQL string literal otherwise.
    Every value passed here originates from this repo's own reviewed CSVs,
    not external/user input -- doubling embedded single quotes is the
    standard, sufficient escape for a Postgres string literal in this
    trusted-data context."""
    if value is None:
        return "NULL"
    return "'" + value.replace("'", "''") + "'"


def _sql_num(value: float | int | None) -> str:
    return "NULL" if value is None else str(value)


def generate_dry_run_sql(award_rows: list[AwardRow], special_rows: list[SpecialAwardRow]) -> str:
    lines: list[str] = [
        "-- Gault&Millau production dry-run: READ-ONLY. No INSERT/UPDATE/DELETE",
        "-- statement appears anywhere in this file -- grep this file for",
        "-- 'insert'/'update'/'delete' (case-insensitive) to verify before running.",
        "",
        "select 'CORE AWARDS DRY RUN' as section;",
        "select",
        "  gm.restaurant_code,",
        "  gm.guide_year,",
        "  case",
        "    when r.id is null then 'SKIP_UNRESOLVED_CODE'",
        "    when existing.id is not null then 'ALREADY_PRESENT_OR_CONFLICT'",
        "    else 'INSERT'",
        "  end as outcome,",
        "  r.id as resolved_restaurant_id,",
        "  existing.score as existing_score,",
        "  existing.toque_count as existing_toque_count",
        "from (values",
    ]
    value_rows = []
    for r in award_rows:
        value_rows.append(f"  ({_sql_str(r.restaurant_code)}, {r.guide_year}::smallint)")
    lines.append(",\n".join(value_rows))
    lines.append(") as gm(restaurant_code, guide_year)")
    lines.append("left join public.restaurants r on r.restaurant_code = gm.restaurant_code")
    lines.append(
        "left join public.gault_millau_awards existing "
        "on existing.restaurant_id = r.id and existing.guide_year = gm.guide_year;"
    )
    lines.append("")
    lines.append("select 'CORE AWARDS DRY RUN SUMMARY' as section;")
    lines.append("select")
    lines.append("  case")
    lines.append("    when r.id is null then 'SKIP_UNRESOLVED_CODE'")
    lines.append("    when existing.id is not null then 'ALREADY_PRESENT_OR_CONFLICT'")
    lines.append("    else 'INSERT'")
    lines.append("  end as outcome,")
    lines.append("  count(*) as row_count")
    lines.append("from (values")
    lines.append(",\n".join(value_rows))
    lines.append(") as gm(restaurant_code, guide_year)")
    lines.append("left join public.restaurants r on r.restaurant_code = gm.restaurant_code")
    lines.append(
        "left join public.gault_millau_awards existing "
        "on existing.restaurant_id = r.id and existing.guide_year = gm.guide_year"
    )
    lines.append("group by 1;")
    lines.append("")

    lines.append("select 'SPECIAL AWARDS DRY RUN SUMMARY' as section;")
    lines.append("select")
    lines.append("  case when co.country_code is null then 'SKIP_UNRESOLVED_COUNTRY' else 'INSERT' end as outcome,")
    lines.append("  count(*) as row_count")
    lines.append("from (values")
    sa_value_rows = [f"  ({_sql_str(r.country_code)})" for r in special_rows]
    lines.append(",\n".join(sa_value_rows))
    lines.append(") as sa(country_code)")
    lines.append("left join public.countries co on co.country_code = sa.country_code")
    lines.append("group by 1;")
    lines.append("")

    lines.append("select 'GERMANY / GM_024 GUARD (generation-time facts, not a live query)' as section;")
    lines.append(f"-- award_rows loaded: {len(award_rows)} (expected 41, Germany excluded via {sorted(DEFERRED_COUNTRY_CODES)})")
    lines.append(f"-- special_rows loaded: {len(special_rows)} (expected 58, Germany excluded)")
    lines.append(f"-- gm_024 present in award_rows: {'gm_024' in {r.gm_candidate_id for r in award_rows}} (expected False)")

    return "\n".join(lines) + "\n"


def generate_apply_sql(
    award_rows: list[AwardRow], special_rows: list[SpecialAwardRow], *, section: str
) -> str:
    lines: list[str] = [
        "-- Gault&Millau production apply. Idempotent by construction: every",
        "-- statement is INSERT ... SELECT ... WHERE NOT EXISTS (...), so a",
        "-- restaurant_code that fails to resolve inserts nothing (never errors,",
        "-- never guesses an id), and re-running this exact file after a",
        "-- successful run inserts zero additional rows. No UPDATE, no DELETE",
        "-- anywhere in this file.",
        f"-- Section: {section}",
        "",
        "begin;",
        "",
    ]
    if section not in ("core", "core+special"):
        award_rows = []
    for r in award_rows:
        lines.append(
            "insert into public.gault_millau_awards "
            "(restaurant_id, guide_year, score, toque_count, toque_colour, recognition_type, "
            "distinction_label, gault_millau_url)\n"
            "select r.id, "
            f"{r.guide_year}::smallint, {_sql_num(r.score)}, {_sql_num(r.toque_count)}, "
            f"{_sql_str(r.toque_colour)}, {_sql_str(r.recognition_type)}, "
            f"{_sql_str(r.distinction_label)}, {_sql_str(r.gault_millau_url)}\n"
            f"from public.restaurants r where r.restaurant_code = {_sql_str(r.restaurant_code)}\n"
            "and not exists (\n"
            "  select 1 from public.gault_millau_awards g "
            f"where g.restaurant_id = r.id and g.guide_year = {r.guide_year}::smallint\n"
            ");"
        )
    lines.append("")
    if section not in ("special", "core+special"):
        special_rows = []
    for r in special_rows:
        lines.append(
            "insert into public.gault_millau_special_awards "
            "(restaurant_id, country_code, guide_year, award_category, award_category_local_name, "
            "winner_name, restaurant_name_at_time, gault_millau_url, source_url)\n"
            f"select null, {_sql_str(r.country_code)}, {r.guide_year}::smallint, "
            f"{_sql_str(r.award_category)}, {_sql_str(r.award_category_local_name)}, "
            f"{_sql_str(r.winner_name)}, {_sql_str(r.restaurant_name_at_time)}, "
            f"{_sql_str(r.gault_millau_url)}, {_sql_str(r.source_url)}\n"
            "where not exists (\n"
            "  select 1 from public.gault_millau_special_awards s\n"
            f"  where s.country_code = {_sql_str(r.country_code)} and s.guide_year = {r.guide_year}::smallint\n"
            f"  and s.award_category = {_sql_str(r.award_category)}\n"
            f"  and coalesce(s.winner_name, '') = coalesce({_sql_str(r.winner_name)}, '')\n"
            f"  and coalesce(s.restaurant_name_at_time, '') = coalesce({_sql_str(r.restaurant_name_at_time)}, '')\n"
            ");"
        )
    lines.append("")
    lines.append("commit;")
    return "\n".join(lines) + "\n"


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--mode", choices=["dry-run", "apply"], required=True)
    parser.add_argument("--section", choices=["core", "special", "core+special"], default="core+special")
    parser.add_argument("-o", "--output", required=True, type=Path)
    args = parser.parse_args()

    award_rows = load_award_rows(excluded_countries=DEFERRED_COUNTRY_CODES)
    special_rows = load_special_award_rows(excluded_countries=DEFERRED_COUNTRY_CODES)

    if len(award_rows) != 41:
        print(f"ERROR: expected 41 launch-scope core award rows, loaded {len(award_rows)}. Refusing to generate SQL.", file=sys.stderr)
        sys.exit(1)
    if len(special_rows) != 58:
        print(f"ERROR: expected 58 launch-scope special award rows, loaded {len(special_rows)}. Refusing to generate SQL.", file=sys.stderr)
        sys.exit(1)
    if "gm_024" in {r.gm_candidate_id for r in award_rows}:
        print("ERROR: gm_024 present in loaded award rows -- must never be imported. Refusing to generate SQL.", file=sys.stderr)
        sys.exit(1)

    sql = (
        generate_dry_run_sql(award_rows, special_rows)
        if args.mode == "dry-run"
        else generate_apply_sql(award_rows, special_rows, section=args.section)
    )
    args.output.write_text(sql)
    print(f"Wrote {args.mode} SQL ({len(award_rows)} core + {len(special_rows)} special rows) to {args.output}")


if __name__ == "__main__":
    main()
