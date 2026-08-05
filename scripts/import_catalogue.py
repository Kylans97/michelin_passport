#!/usr/bin/env python3
"""Michelin Passport catalogue importer.

Loads countries, cities, cuisines, hotels, restaurants, hotel_restaurants,
award_history and worlds_50_best from the CSV files in supabase/data/ into
a PostgreSQL database, in that order, inside one transaction.

Authoritative sources for every rule implemented here:
  docs/Architecture/Michelin_Database/DATABASE_ARCHITECTURE.md
  docs/Architecture/Michelin_Database/DATABASE_IMPORT_GUIDE.md
  docs/Architecture/Michelin_Database/VALIDATION_REPORT.md
  docs/Architecture/Michelin_Database/DATA_UPDATE_PROCESS.md

See scripts/README_IMPORT.md for usage, safety rules and a list of
confirmed discrepancies between those documents and the actual CSV files.
"""

from __future__ import annotations

import argparse
import csv
import os
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import Optional
from urllib.parse import urlsplit

import psycopg

# ============================================================
# Constants
# ============================================================

REPO_ROOT = Path(__file__).resolve().parent.parent
DATA_DIR = REPO_ROOT / "supabase" / "data"

HOTELS_CSV = DATA_DIR / "hotels_master.csv"
RESTAURANTS_CSV = DATA_DIR / "restaurants_master.csv"
LINKS_CSV = DATA_DIR / "hotel_restaurant_links.csv"
HALL_OF_FAME_CSV = DATA_DIR / "worlds_50_best_hall_of_fame.csv"

# supabase/data/restaurants_pending_manual_review.csv is deliberately never
# read. It holds only La Paix (rest_0158), quarantined until its corrected
# Anderlecht address and coordinates are available (DATABASE_IMPORT_GUIDE.md
# section 7.4). This import loads 774 restaurants, not 775.

GUIDE_YEAR = 2026  # DATABASE_IMPORT_GUIDE.md section 9.1 — launch award_history rows.

CATALOGUE_TABLES_IN_ORDER = [
    "countries",
    "cities",
    "cuisines",
    "hotels",
    "restaurants",
    "hotel_restaurants",
    "award_history",
    "worlds_50_best",
]

REMOTE_CONFIRM_TOKEN = "IMPORT-MICHELIN-CATALOGUE"

# The Supabase CLI's own local development connection string. It is fixed
# and identical on every machine that runs `supabase start` (see
# `supabase status`, or supabase/config.toml for the port) and is not a
# secret — Supabase publishes it in their own documentation. It never
# points anywhere but the local Docker Postgres container. A developer
# whose local stack uses different settings can override it with the
# LOCAL_DATABASE_URL environment variable.
LOCAL_DEFAULT_DSN = "postgresql://postgres:postgres@127.0.0.1:54322/postgres"

# Source counts asserted by DATABASE_IMPORT_GUIDE.md section 1 / this task.
EXPECTED_HOTELS_ROWS = 687
EXPECTED_RESTAURANTS_ROWS = 774
EXPECTED_LINKS_ROWS = 68

EXPECTED_STAR_DISTRIBUTION = {3: 121, 2: 340, 1: 306, 0: 7}
EXPECTED_KEY_DISTRIBUTION = {3: 36, 2: 161, 1: 490}
EXPECTED_SHARED_PLACE_IDS = 10
EXPECTED_ZERO_STAR_ROWS = 7

# ISO 3166-1 alpha-2 codes for every country name present in the launch
# dataset (DATABASE_ARCHITECTURE.md section 7: country is geographic, never
# editorial — Hong Kong, Macau, Monaco and the Faroe Islands each get their
# own row). Deliberately explicit and closed: an unmapped country name must
# fail the import rather than silently guess a code.
COUNTRY_ISO_CODES: dict[str, str] = {
    "Andorra": "AD",
    "Argentina": "AR",
    "Aruba": "AW",
    "Austria": "AT",
    "Belgium": "BE",
    "Brazil": "BR",
    "Chile": "CL",
    "China": "CN",
    "Colombia": "CO",
    "Croatia": "HR",
    "Denmark": "DK",
    "Faroe Islands": "FO",
    "Finland": "FI",
    "France": "FR",
    "Germany": "DE",
    "Hong Kong": "HK",
    "Hungary": "HU",
    "Italy": "IT",
    "Japan": "JP",
    "Luxembourg": "LU",
    "Macau": "MO",
    "Malta": "MT",
    "Mexico": "MX",
    "Monaco": "MC",
    "Montenegro": "ME",
    "Netherlands": "NL",
    "Norway": "NO",
    "Peru": "PE",
    "Poland": "PL",
    "Portugal": "PT",
    "Serbia": "RS",
    "Singapore": "SG",
    "Slovenia": "SI",
    "South Korea": "KR",
    "Spain": "ES",
    "Sweden": "SE",
    "Switzerland": "CH",
    "Taiwan": "TW",
    "Thailand": "TH",
    "Turkey": "TR",
    "United Arab Emirates": "AE",
    "United Kingdom": "GB",
    "United States": "US",
}


class ImportValidationError(Exception):
    """Raised when source data or database state fails a required check."""


# ============================================================
# Records
# ============================================================


@dataclass(frozen=True)
class HotelRecord:
    hotel_code: str
    name: str
    michelin_keys: int
    country_name: str
    city_name: str
    address: str
    latitude: float
    longitude: float
    google_place_id: Optional[str]
    michelin_url: Optional[str]
    website_url: Optional[str]
    booking_url: Optional[str]


@dataclass(frozen=True)
class RestaurantRecord:
    restaurant_code: str
    name: str
    michelin_stars: Optional[int]  # None if the source held 0 (see clean_stars)
    cuisine: Optional[str]
    country_name: str
    city_name: str
    address: str
    latitude: float
    longitude: float
    google_place_id: Optional[str]
    michelin_url: Optional[str]
    website_url: Optional[str]
    booking_url: Optional[str]
    property_name: Optional[str]
    worlds_50_best_rank: Optional[int]
    worlds_50_best_year: Optional[int]


@dataclass(frozen=True)
class LinkRecord:
    hotel_code: str
    restaurant_code: str
    link_confidence: str  # already lower-cased
    evidence: Optional[str]


@dataclass(frozen=True)
class HallOfFameCandidate:
    name: str
    restaurant_code: str
    no1_years_raw: str


@dataclass(frozen=True)
class Check:
    name: str
    passed: bool
    detail: str = ""


# ============================================================
# Small parsing helpers
# ============================================================


def clean(value: str) -> Optional[str]:
    """Empty CSV field -> None; everything else stripped."""
    value = value.strip()
    return value if value else None


def parse_float(value: str, *, field: str, code: str) -> float:
    try:
        return float(value)
    except ValueError as exc:
        raise ImportValidationError(
            f"{field} does not parse as a number for {code!r}: {value!r}"
        ) from exc


def parse_optional_int(value: str) -> Optional[int]:
    """Handles clean ints ('3') and float-formatted exports ('2025.0')."""
    value = value.strip()
    if not value:
        return None
    return int(float(value))


def clean_stars(raw: str, *, code: str) -> Optional[int]:
    """0 in the source means 'no current star' and is stored as NULL.

    See DATABASE_IMPORT_GUIDE.md section 7.5 and
    DATABASE_ARCHITECTURE.md section 3.3.
    """
    value = parse_optional_int(raw)
    if value is None:
        raise ImportValidationError(f"restaurant {code!r} has an unparseable star count: {raw!r}")
    return None if value == 0 else value


def iso_code(country_name: str) -> str:
    try:
        return COUNTRY_ISO_CODES[country_name]
    except KeyError as exc:
        raise ImportValidationError(
            f"No ISO 3166-1 alpha-2 mapping for country {country_name!r}. "
            "Add it to COUNTRY_ISO_CODES before importing."
        ) from exc


def resolve_city_name_and_region(country_name: str, city_name: str) -> tuple[str, Optional[str]]:
    """Retire the 'Washington (Virginia)' string workaround.

    DATABASE_IMPORT_GUIDE.md section 6.2: create two rows both named
    'Washington', distinguished by region rather than by a parenthetical
    suffix in the name. Every other city is passed through unchanged, with
    region left NULL (no source file supplies it for anything else).
    """
    if country_name == "United States" and city_name == "Washington (Virginia)":
        return "Washington", "Virginia"
    if country_name == "United States" and city_name == "Washington":
        return "Washington", "District of Columbia"
    return city_name, None


# ============================================================
# CSV loading
# ============================================================


def read_csv_rows(path: Path) -> list[dict[str, str]]:
    if not path.exists():
        raise ImportValidationError(f"Source file not found: {path}")
    with path.open(newline="", encoding="utf-8") as f:
        return list(csv.DictReader(f))


def load_hotels(path: Path) -> list[HotelRecord]:
    records = []
    for row in read_csv_rows(path):
        code = row["hotel_code"].strip()
        records.append(
            HotelRecord(
                hotel_code=code,
                name=row["name"].strip(),
                michelin_keys=int(row["michelin_keys"].strip()),
                country_name=row["country"].strip(),
                city_name=row["city"].strip(),
                address=row["address"].strip(),
                latitude=parse_float(row["latitude"], field="latitude", code=code),
                longitude=parse_float(row["longitude"], field="longitude", code=code),
                google_place_id=clean(row["google_place_id"]),
                michelin_url=clean(row["michelin_url"]),
                website_url=clean(row["website_url"]),
                booking_url=clean(row["booking_url"]),
                # google_maps_url discarded: derived from google_place_id at read time.
                # worlds_50_best_rank/year discarded: empty on every hotel row, and
                # the ranking is a restaurant award (DATABASE_IMPORT_GUIDE.md 9.2).
            )
        )
    return records


def load_restaurants(path: Path) -> list[RestaurantRecord]:
    records = []
    for row in read_csv_rows(path):
        code = row["restaurant_code"].strip()
        records.append(
            RestaurantRecord(
                restaurant_code=code,
                name=row["name"].strip(),
                michelin_stars=clean_stars(row["michelin_stars"], code=code),
                cuisine=clean(row["cuisine"]),
                country_name=row["country"].strip(),
                city_name=row["city"].strip(),
                address=row["address"].strip(),
                latitude=parse_float(row["latitude"], field="latitude", code=code),
                longitude=parse_float(row["longitude"], field="longitude", code=code),
                google_place_id=clean(row["google_place_id"]),
                michelin_url=clean(row["michelin_url"]),
                website_url=clean(row["website_url"]),
                booking_url=clean(row["booking_url"]),
                property_name=clean(row["property_name"]),
                worlds_50_best_rank=parse_optional_int(row["worlds_50_best_rank"]),
                worlds_50_best_year=parse_optional_int(row["worlds_50_best_year"]),
                # google_maps_url discarded (derived). located_in_hotel discarded:
                # is_in_hotel is derived in restaurants_full, never stored.
            )
        )
    return records


def load_links(path: Path) -> list[LinkRecord]:
    records = []
    for row in read_csv_rows(path):
        records.append(
            LinkRecord(
                hotel_code=row["hotel_code"].strip(),
                restaurant_code=row["restaurant_code"].strip(),
                link_confidence=row["link_confidence"].strip().lower(),
                evidence=clean(row["evidence"]),
                # hotel_name, restaurant_name, michelin_stars, both addresses,
                # both cities and country are denormalised review copies and
                # are discarded (DATABASE_IMPORT_GUIDE.md section 8).
            )
        )
    return records


def load_hall_of_fame(path: Path) -> list[HallOfFameCandidate]:
    records = []
    for row in read_csv_rows(path):
        records.append(
            HallOfFameCandidate(
                name=row["name"].strip(),
                restaurant_code=row["restaurant_code"].strip(),
                no1_years_raw=row["no1_years"].strip(),
            )
        )
    return records


# ============================================================
# Pre-import validation
# ============================================================


def validate_source(
    hotels: list[HotelRecord],
    restaurants: list[RestaurantRecord],
    links: list[LinkRecord],
    raw_hotel_rows: list[dict[str, str]],
    raw_restaurant_rows: list[dict[str, str]],
) -> None:
    checks: list[Check] = []

    checks.append(Check("hotels_master.csv row count == 687", len(hotels) == EXPECTED_HOTELS_ROWS, str(len(hotels))))
    checks.append(
        Check(
            "restaurants_master.csv row count == 774",
            len(restaurants) == EXPECTED_RESTAURANTS_ROWS,
            str(len(restaurants)),
        )
    )
    checks.append(Check("hotel_restaurant_links.csv row count == 68", len(links) == EXPECTED_LINKS_ROWS, str(len(links))))

    hotel_codes = [h.hotel_code for h in hotels]
    checks.append(Check("hotel_code non-empty for all rows", all(hotel_codes), ""))
    checks.append(Check("hotel_code unique", len(hotel_codes) == len(set(hotel_codes)), ""))

    restaurant_codes = [r.restaurant_code for r in restaurants]
    checks.append(Check("restaurant_code non-empty for all rows", all(restaurant_codes), ""))
    checks.append(Check("restaurant_code unique", len(restaurant_codes) == len(set(restaurant_codes)), ""))

    checks.append(
        Check(
            "all hotel source id fields empty",
            all(not row["id"].strip() for row in raw_hotel_rows),
            "",
        )
    )
    checks.append(
        Check(
            "all restaurant source id fields empty",
            all(not row["id"].strip() for row in raw_restaurant_rows),
            "",
        )
    )

    hotel_code_set = set(hotel_codes)
    restaurant_code_set = set(restaurant_codes)
    unresolved_hotel_links = [l.hotel_code for l in links if l.hotel_code not in hotel_code_set]
    unresolved_restaurant_links = [l.restaurant_code for l in links if l.restaurant_code not in restaurant_code_set]
    checks.append(Check("every link.hotel_code resolves", not unresolved_hotel_links, str(unresolved_hotel_links)))
    checks.append(
        Check("every link.restaurant_code resolves", not unresolved_restaurant_links, str(unresolved_restaurant_links))
    )

    pairs = [(l.hotel_code, l.restaurant_code) for l in links]
    checks.append(Check("no duplicate (hotel_code, restaurant_code) pair", len(pairs) == len(set(pairs)), ""))

    checks.append(
        Check(
            "michelin_keys in {1,2,3} for every hotel",
            all(h.michelin_keys in (1, 2, 3) for h in hotels),
            "",
        )
    )

    raw_star_values = [int(row["michelin_stars"].strip()) for row in raw_restaurant_rows]
    checks.append(
        Check(
            "michelin_stars in {0,1,2,3} for every restaurant",
            all(v in (0, 1, 2, 3) for v in raw_star_values),
            "",
        )
    )

    hotel_place_ids = [h.google_place_id for h in hotels]
    restaurant_place_ids = [r.google_place_id for r in restaurants]
    checks.append(Check("every hotel has a google_place_id", all(hotel_place_ids), ""))
    checks.append(Check("every restaurant has a google_place_id", all(restaurant_place_ids), ""))
    checks.append(
        Check("google_place_id unique within hotels_master.csv", len(hotel_place_ids) == len(set(hotel_place_ids)), "")
    )
    checks.append(
        Check(
            "google_place_id unique within restaurants_master.csv",
            len(restaurant_place_ids) == len(set(restaurant_place_ids)),
            "",
        )
    )
    shared_place_ids = set(hotel_place_ids) & set(restaurant_place_ids)
    checks.append(
        Check(
            f"exactly {EXPECTED_SHARED_PLACE_IDS} google_place_id values shared between hotels and restaurants",
            len(shared_place_ids) == EXPECTED_SHARED_PLACE_IDS,
            str(len(shared_place_ids)),
        )
    )

    non_exact_links = [row["link_confidence"] for row in read_csv_rows(LINKS_CSV) if row["link_confidence"].strip() != "Exact"]
    checks.append(
        Check(
            "every source link_confidence value is literally 'Exact'",
            not non_exact_links,
            str(set(non_exact_links)),
        )
    )

    zero_star_count = sum(1 for v in raw_star_values if v == 0)
    checks.append(
        Check(
            f"exactly {EXPECTED_ZERO_STAR_ROWS} restaurants with 0 stars in the source",
            zero_star_count == EXPECTED_ZERO_STAR_ROWS,
            str(zero_star_count),
        )
    )

    from collections import Counter

    star_distribution = Counter(raw_star_values)
    checks.append(
        Check(
            "star distribution matches 121/340/306/7 (three/two/one/zero)",
            dict(star_distribution) == EXPECTED_STAR_DISTRIBUTION,
            str(dict(star_distribution)),
        )
    )
    key_distribution = Counter(h.michelin_keys for h in hotels)
    checks.append(
        Check(
            "Key distribution matches 36/161/490 (three/two/one)",
            dict(key_distribution) == EXPECTED_KEY_DISTRIBUTION,
            str(dict(key_distribution)),
        )
    )

    report_checks("Pre-import validation", checks)


# ============================================================
# Derivation
# ============================================================


def derive_countries(
    hotels: list[HotelRecord], raw_hotel_rows: list[dict[str, str]], raw_restaurant_rows: list[dict[str, str]]
) -> list[tuple[str, str, str]]:
    """Distinct (country_code, name, flag_emoji) triples, per section 6.1."""
    pairs = {(row["country"].strip(), row["country_flag"].strip()) for row in raw_hotel_rows}
    pairs |= {(row["country"].strip(), row["country_flag"].strip()) for row in raw_restaurant_rows}
    countries = {}
    for name, flag in pairs:
        code = iso_code(name)
        countries[code] = (code, name, flag)
    return sorted(countries.values())


def derive_cities(
    raw_hotel_rows: list[dict[str, str]], raw_restaurant_rows: list[dict[str, str]]
) -> list[tuple[str, str, Optional[str]]]:
    """Distinct (country_code, name, region) triples, per section 6.2."""
    keys: set[tuple[str, str, Optional[str]]] = set()
    for row in raw_hotel_rows + raw_restaurant_rows:
        country_name = row["country"].strip()
        raw_city = row["city"].strip()
        code = iso_code(country_name)
        name, region = resolve_city_name_and_region(country_name, raw_city)
        keys.add((code, name, region))
    return sorted(keys, key=lambda k: (k[0], k[1], k[2] or ""))


def derive_cuisines(restaurants: list[RestaurantRecord]) -> list[str]:
    """Distinct non-empty cuisine values, per section 6.3."""
    return sorted({r.cuisine for r in restaurants if r.cuisine})


def compute_induction_year(no1_years_raw: str) -> Optional[int]:
    """DATABASE_IMPORT_GUIDE.md section 9.2 / DATA_UPDATE_PROCESS.md section 4.

    Best of the Best was introduced in 2019: every winner whose last No.1
    year predates 2019 was elevated then. A later winner is elevated when
    the *following* year's list publishes. Returns None if no1_years_raw
    cannot be parsed — callers must skip rather than guess.
    """
    if not no1_years_raw:
        return None
    years: list[int] = []
    try:
        for segment in no1_years_raw.split(","):
            segment = segment.strip()
            if "-" in segment:
                _, end = segment.split("-", 1)
                years.append(int(end.strip()))
            else:
                years.append(int(segment))
    except ValueError:
        return None
    if not years:
        return None
    last_win = max(years)
    return 2019 if last_win <= 2018 else last_win + 1


# ============================================================
# Database writers
# ============================================================


def fetch_table_counts(cur: psycopg.Cursor) -> dict[str, int]:
    counts: dict[str, int] = {}
    for table in CATALOGUE_TABLES_IN_ORDER:
        cur.execute(f"select count(*) from public.{table}")  # noqa: S608 — table name from a fixed constant list
        (counts[table],) = cur.fetchone()
    return counts


def assert_tables_empty(cur: psycopg.Cursor, *, allow_nonempty: bool) -> None:
    counts = fetch_table_counts(cur)
    nonempty = {table: n for table, n in counts.items() if n > 0}
    if nonempty and not allow_nonempty:
        detail = ", ".join(f"{t}={n}" for t, n in nonempty.items())
        raise ImportValidationError(
            f"Refusing to import: these catalogue tables already contain rows: {detail}. "
            "Re-run with --allow-nonempty if this is intentional. This importer never "
            "upserts — inserting into a non-empty table risks unique-constraint errors "
            "and a full rollback, by design."
        )
    if nonempty:
        print(f"  --allow-nonempty set; proceeding despite existing rows: {nonempty}")


def insert_countries(cur: psycopg.Cursor, countries: list[tuple[str, str, str]]) -> None:
    cur.executemany(
        "insert into public.countries (country_code, name, flag_emoji) values (%s, %s, %s)",
        countries,
    )


def insert_cities(cur: psycopg.Cursor, cities: list[tuple[str, str, Optional[str]]]) -> None:
    cur.executemany(
        "insert into public.cities (country_code, name, region) values (%s, %s, %s)",
        cities,
    )


def fetch_city_map(cur: psycopg.Cursor) -> dict[tuple[str, str, Optional[str]], str]:
    cur.execute("select id, country_code, name, region from public.cities")
    return {(country_code, name, region): str(city_id) for city_id, country_code, name, region in cur.fetchall()}


def insert_cuisines(cur: psycopg.Cursor, cuisines: list[str]) -> None:
    cur.executemany("insert into public.cuisines (name) values (%s)", [(c,) for c in cuisines])


def fetch_cuisine_map(cur: psycopg.Cursor) -> dict[str, int]:
    cur.execute("select id, name from public.cuisines")
    return {name: cuisine_id for cuisine_id, name in cur.fetchall()}


def insert_hotels(
    cur: psycopg.Cursor,
    hotels: list[HotelRecord],
    city_map: dict[tuple[str, str, Optional[str]], str],
) -> None:
    rows = []
    for h in hotels:
        code = iso_code(h.country_name)
        name, region = resolve_city_name_and_region(h.country_name, h.city_name)
        city_id = city_map[(code, name, region)]
        rows.append(
            (
                h.hotel_code,
                h.name,
                h.michelin_keys,
                city_id,
                code,
                h.address,
                h.longitude,
                h.latitude,
                h.google_place_id,
                h.michelin_url,
                h.website_url,
                h.booking_url,
            )
        )
    cur.executemany(
        """
        insert into public.hotels
            (hotel_code, name, michelin_keys, city_id, country_code, address,
             location, google_place_id, michelin_url, website_url, booking_url)
        values
            (%s, %s, %s, %s, %s, %s,
             ST_SetSRID(ST_MakePoint(%s, %s), 4326)::geography, %s, %s, %s, %s)
        """,
        rows,
    )


def fetch_hotel_map(cur: psycopg.Cursor) -> dict[str, str]:
    cur.execute("select hotel_code, id from public.hotels")
    return {code: str(hotel_id) for code, hotel_id in cur.fetchall()}


def insert_restaurants(
    cur: psycopg.Cursor,
    restaurants: list[RestaurantRecord],
    city_map: dict[tuple[str, str, Optional[str]], str],
    cuisine_map: dict[str, int],
) -> None:
    rows = []
    for r in restaurants:
        code = iso_code(r.country_name)
        name, region = resolve_city_name_and_region(r.country_name, r.city_name)
        city_id = city_map[(code, name, region)]
        cuisine_id = cuisine_map[r.cuisine] if r.cuisine else None
        inclusion_reason = "michelin_star" if r.michelin_stars is not None else "worlds_50_best"
        rows.append(
            (
                r.restaurant_code,
                r.name,
                r.michelin_stars,
                inclusion_reason,
                cuisine_id,
                city_id,
                code,
                r.address,
                r.longitude,
                r.latitude,
                r.google_place_id,
                r.michelin_url,
                r.website_url,
                r.booking_url,
                r.property_name,
            )
        )
    cur.executemany(
        """
        insert into public.restaurants
            (restaurant_code, name, michelin_stars, inclusion_reason, cuisine_id,
             city_id, country_code, address, location, google_place_id,
             michelin_url, website_url, booking_url, property_name)
        values
            (%s, %s, %s, %s, %s,
             %s, %s, %s, ST_SetSRID(ST_MakePoint(%s, %s), 4326)::geography, %s,
             %s, %s, %s, %s)
        """,
        rows,
    )


def fetch_restaurant_map(cur: psycopg.Cursor) -> dict[str, str]:
    cur.execute("select restaurant_code, id from public.restaurants")
    return {code: str(restaurant_id) for code, restaurant_id in cur.fetchall()}


def insert_hotel_restaurants(
    cur: psycopg.Cursor,
    links: list[LinkRecord],
    hotel_map: dict[str, str],
    restaurant_map: dict[str, str],
) -> None:
    rows = [
        (hotel_map[l.hotel_code], restaurant_map[l.restaurant_code], l.link_confidence, l.evidence) for l in links
    ]
    cur.executemany(
        """
        insert into public.hotel_restaurants
            (hotel_id, restaurant_id, link_confidence, evidence, verified_at)
        values
            (%s, %s, %s, %s, now())
        """,
        rows,
    )


def insert_award_history(
    cur: psycopg.Cursor,
    hotels: list[HotelRecord],
    restaurants: list[RestaurantRecord],
    hotel_map: dict[str, str],
    restaurant_map: dict[str, str],
) -> None:
    rows = [
        (
            "hotel",
            hotel_map[h.hotel_code],
            GUIDE_YEAR,
            "michelin_keys",
            h.michelin_keys,
            True,
        )
        for h in hotels
    ]
    rows += [
        (
            "restaurant",
            restaurant_map[r.restaurant_code],
            GUIDE_YEAR,
            "michelin_stars",
            r.michelin_stars,
            True,
        )
        for r in restaurants
        if r.michelin_stars is not None  # never seed history for a null-star row
    ]
    cur.executemany(
        """
        insert into public.award_history
            (entity_type, entity_id, guide_year, award_type, award_value, is_current)
        values
            (%s, %s, %s, %s, %s, %s)
        """,
        rows,
    )


def insert_worlds_50_best_top50(
    cur: psycopg.Cursor,
    restaurants: list[RestaurantRecord],
    restaurant_map: dict[str, str],
) -> int:
    rows = [
        (restaurant_map[r.restaurant_code], r.worlds_50_best_year, r.worlds_50_best_rank, "top_50")
        for r in restaurants
        if r.worlds_50_best_rank is not None
    ]
    cur.executemany(
        """
        insert into public.worlds_50_best (restaurant_id, year, rank, list_type)
        values (%s, %s, %s, %s)
        """,
        rows,
    )
    return len(rows)


def insert_hall_of_fame(
    cur: psycopg.Cursor,
    candidates: list[HallOfFameCandidate],
    restaurant_map: dict[str, str],
) -> tuple[int, list[tuple[str, str]]]:
    """Only seeds a row when the restaurant_code resolves in the catalogue
    AND an induction year can be derived. Never invents a year. Returns
    (rows_inserted, [(name, reason_skipped), ...]).
    """
    rows = []
    skipped: list[tuple[str, str]] = []
    for candidate in candidates:
        if candidate.restaurant_code not in restaurant_map:
            skipped.append((candidate.name, f"restaurant_code {candidate.restaurant_code!r} not in catalogue"))
            continue
        induction_year = compute_induction_year(candidate.no1_years_raw)
        if induction_year is None:
            skipped.append((candidate.name, "induction year could not be derived from no1_years"))
            continue
        rows.append((restaurant_map[candidate.restaurant_code], induction_year, None, "hall_of_fame"))

    cur.executemany(
        """
        insert into public.worlds_50_best (restaurant_id, year, rank, list_type)
        values (%s, %s, %s, %s)
        """,
        rows,
    )
    return len(rows), skipped


# ============================================================
# Post-import validation
# ============================================================


def run_post_import_checks(
    cur: psycopg.Cursor,
    *,
    expected_countries: int,
    expected_cities: int,
    expected_cuisines: int,
    expected_award_history: int,
) -> list[Check]:
    checks: list[Check] = []
    counts = fetch_table_counts(cur)

    checks.append(Check("countries row count", counts["countries"] == expected_countries, str(counts["countries"])))
    checks.append(Check("cities row count", counts["cities"] == expected_cities, str(counts["cities"])))
    checks.append(Check("cuisines row count", counts["cuisines"] == expected_cuisines, str(counts["cuisines"])))
    checks.append(Check("hotels row count == 687", counts["hotels"] == EXPECTED_HOTELS_ROWS, str(counts["hotels"])))
    checks.append(
        Check("restaurants row count == 774", counts["restaurants"] == EXPECTED_RESTAURANTS_ROWS, str(counts["restaurants"]))
    )
    checks.append(
        Check("hotel_restaurants row count == 68", counts["hotel_restaurants"] == EXPECTED_LINKS_ROWS, str(counts["hotel_restaurants"]))
    )
    checks.append(
        Check("award_history row count", counts["award_history"] == expected_award_history, str(counts["award_history"]))
    )

    cur.execute("select count(*) from public.worlds_50_best where list_type = 'top_50'")
    (top50_count,) = cur.fetchone()
    checks.append(Check("worlds_50_best top_50 row count == 50", top50_count == 50, str(top50_count)))

    cur.execute(
        """
        select hr.id from public.hotel_restaurants hr
          left join public.hotels h on h.id = hr.hotel_id
          left join public.restaurants r on r.id = hr.restaurant_id
         where h.id is null or r.id is null
        """
    )
    unresolved = cur.fetchall()
    checks.append(Check("no unresolved hotel_restaurants foreign keys", not unresolved, str(len(unresolved))))

    cur.execute(
        """
        select r.restaurant_code from public.restaurants r
          join public.hotel_restaurants hr on hr.restaurant_id = r.id
         where r.property_name is not null
        """
    )
    conflicts = cur.fetchall()
    checks.append(Check("no restaurant has both property_name and a hotel_restaurants link", not conflicts, str(conflicts)))

    cur.execute("select count(*) from public.restaurants where michelin_stars = 0")
    (zero_star_rows,) = cur.fetchone()
    checks.append(Check("no restaurant has michelin_stars = 0", zero_star_rows == 0, str(zero_star_rows)))

    for table in ("hotels", "restaurants"):
        cur.execute(f"select count(*) from public.{table} where id is null")  # noqa: S608
        (null_ids,) = cur.fetchone()
        checks.append(Check(f"no null id in {table}", null_ids == 0, str(null_ids)))

    cur.execute(
        "select count(*) - count(distinct hotel_code) from public.hotels"
    )
    (dup_hotel_codes,) = cur.fetchone()
    checks.append(Check("no duplicate hotel_code", dup_hotel_codes == 0, str(dup_hotel_codes)))

    cur.execute(
        "select count(*) - count(distinct restaurant_code) from public.restaurants"
    )
    (dup_restaurant_codes,) = cur.fetchone()
    checks.append(Check("no duplicate restaurant_code", dup_restaurant_codes == 0, str(dup_restaurant_codes)))

    cur.execute("select count(*) from public.hotels where location is null")
    (null_hotel_locations,) = cur.fetchone()
    cur.execute("select count(*) from public.restaurants where location is null")
    (null_restaurant_locations,) = cur.fetchone()
    checks.append(
        Check(
            "every imported location is non-null",
            null_hotel_locations == 0 and null_restaurant_locations == 0,
            f"hotels={null_hotel_locations}, restaurants={null_restaurant_locations}",
        )
    )

    cur.execute(
        """
        select tablename from pg_tables
         where schemaname = 'public' and rowsecurity = false
           and tablename = any(%s)
        """,
        (CATALOGUE_TABLES_IN_ORDER,),
    )
    rls_gaps = cur.fetchall()
    checks.append(Check("RLS remains enabled on every catalogue table", not rls_gaps, str(rls_gaps)))

    return checks


# ============================================================
# Reporting
# ============================================================


def report_checks(title: str, checks: list[Check]) -> None:
    print(f"\n{title}:")
    failures = []
    for check in checks:
        status = "PASS" if check.passed else "FAIL"
        suffix = f" ({check.detail})" if check.detail else ""
        print(f"  [{status}] {check.name}{suffix}")
        if not check.passed:
            failures.append(check.name)
    if failures:
        raise ImportValidationError(f"{title} failed: {', '.join(failures)}")


def print_known_discrepancies(actual_cities: int, actual_award_history: int) -> None:
    print(
        "\nKnown documentation discrepancies (verified against the actual CSV files; "
        "see scripts/README_IMPORT.md for the full explanation):"
    )
    print("  - restaurants: importing 774, not the 775 some documents quote. "
          "The 775 figure counts La Paix (rest_0158), which is deliberately excluded here.")
    if actual_cities != 614:
        print(
            f"  - cities: importing {actual_cities}, not the 614 documented in "
            "DATABASE_IMPORT_GUIDE.md/VALIDATION_REPORT.md. Verified as a stale documentation "
            "count, not a transformation issue: hotels_master.csv and restaurants_master.csv "
            "together yield 613 distinct (country, city) pairs, and the documented "
            "Washington/DC-Virginia split does not change that total (both variants already "
            "exist as separate strings in the source)."
        )
    if actual_award_history != 1455:
        print(
            f"  - award_history: importing {actual_award_history}, not the 1455 (687+768) "
            "documented in DATABASE_IMPORT_GUIDE.md. That figure assumes the full 775-restaurant "
            "catalogue including La Paix's 2 stars (768 starred restaurants). For this "
            "774-restaurant import the correct total is 687 hotels + 767 starred restaurants "
            "(121 + 340 + 306) = 1454."
        )
    print(
        "  - hotel_code formatting: DATABASE_ARCHITECTURE.md section 11 documents hotel_%03d "
        "(3-digit, e.g. hotel_001), but the actual source codes use 2-digit padding for 1-99 "
        "(hotel_01) and 3-digit for 100+. Codes are stored verbatim as frozen external "
        "identifiers, so this does not affect the import."
    )


# ============================================================
# Connection handling
# ============================================================


def redact_dsn(dsn: str) -> str:
    """Never print credentials — host and database only."""
    parts = urlsplit(dsn)
    host = parts.hostname or "?"
    port = f":{parts.port}" if parts.port else ""
    db = parts.path or ""
    return f"{parts.scheme}://***@{host}{port}{db}"


def resolve_dsn(target: str) -> str:
    if target == "local":
        return os.environ.get("LOCAL_DATABASE_URL", LOCAL_DEFAULT_DSN)
    if target == "remote":
        dsn = os.environ.get("DATABASE_URL")
        if not dsn:
            raise ImportValidationError(
                "DATABASE_URL is not set. Export it before running against --target remote, e.g.:\n"
                "  export DATABASE_URL='postgresql://...'\n"
                "This script never hardcodes remote credentials."
            )
        return dsn
    raise ImportValidationError(f"Unknown target: {target!r}")


# ============================================================
# Orchestration
# ============================================================


def run_import(*, target: str, dry_run: bool, allow_nonempty: bool, confirm_token: Optional[str]) -> int:
    if target == "remote" and not dry_run:
        if confirm_token != REMOTE_CONFIRM_TOKEN:
            raise ImportValidationError(
                "Remote import requires --confirm-remote-import "
                f"{REMOTE_CONFIRM_TOKEN!r} exactly. Refusing to proceed."
            )

    print("Loading source CSV files...")
    raw_hotel_rows = read_csv_rows(HOTELS_CSV)
    raw_restaurant_rows = read_csv_rows(RESTAURANTS_CSV)
    hotels = load_hotels(HOTELS_CSV)
    restaurants = load_restaurants(RESTAURANTS_CSV)
    links = load_links(LINKS_CSV)
    hall_of_fame_candidates = load_hall_of_fame(HALL_OF_FAME_CSV)
    print(
        f"  hotels_master.csv: {len(hotels)} rows | restaurants_master.csv: {len(restaurants)} rows | "
        f"hotel_restaurant_links.csv: {len(links)} rows | worlds_50_best_hall_of_fame.csv: "
        f"{len(hall_of_fame_candidates)} candidates"
    )

    validate_source(hotels, restaurants, links, raw_hotel_rows, raw_restaurant_rows)

    print("\nDeriving reference data...")
    countries = derive_countries(hotels, raw_hotel_rows, raw_restaurant_rows)
    cities = derive_cities(raw_hotel_rows, raw_restaurant_rows)
    cuisines = derive_cuisines(restaurants)
    starred_restaurant_count = sum(1 for r in restaurants if r.michelin_stars is not None)
    expected_award_history = len(hotels) + starred_restaurant_count
    print(f"  countries: {len(countries)} | cities: {len(cities)} | cuisines: {len(cuisines)}")

    dsn = resolve_dsn(target)
    print(f"\nConnecting to target={target} ({redact_dsn(dsn)})...")

    with psycopg.connect(dsn, autocommit=False) as conn:
        with conn.cursor() as cur:
            try:
                print("\nChecking target catalogue tables are empty...")
                assert_tables_empty(cur, allow_nonempty=allow_nonempty)

                print("\nInserting countries...")
                insert_countries(cur, countries)

                print("Inserting cities...")
                insert_cities(cur, cities)
                city_map = fetch_city_map(cur)

                print("Inserting cuisines...")
                insert_cuisines(cur, cuisines)
                cuisine_map = fetch_cuisine_map(cur)

                print("Inserting hotels...")
                insert_hotels(cur, hotels, city_map)
                hotel_map = fetch_hotel_map(cur)

                print("Inserting restaurants...")
                insert_restaurants(cur, restaurants, city_map, cuisine_map)
                restaurant_map = fetch_restaurant_map(cur)

                print("Inserting hotel_restaurants...")
                insert_hotel_restaurants(cur, links, hotel_map, restaurant_map)

                print("Seeding award_history...")
                insert_award_history(cur, hotels, restaurants, hotel_map, restaurant_map)

                print("Seeding worlds_50_best (Top 50)...")
                top50_inserted = insert_worlds_50_best_top50(cur, restaurants, restaurant_map)
                print(f"  {top50_inserted} Top 50 rows inserted")

                print("Seeding worlds_50_best (Hall of Fame)...")
                hof_inserted, hof_skipped = insert_hall_of_fame(cur, hall_of_fame_candidates, restaurant_map)
                print(f"  {hof_inserted} Hall of Fame rows inserted")
                for name, reason in hof_skipped:
                    print(f"  SKIPPED Hall of Fame member {name!r}: {reason}")

                checks = run_post_import_checks(
                    cur,
                    expected_countries=len(countries),
                    expected_cities=len(cities),
                    expected_cuisines=len(cuisines),
                    expected_award_history=expected_award_history,
                )
                report_checks("Post-import validation", checks)

            except Exception:
                conn.rollback()
                print("\nROLLED BACK — no changes were written.", file=sys.stderr)
                raise

            if dry_run:
                conn.rollback()
                print("\nDRY RUN complete — all checks passed, nothing was written (rolled back).")
            else:
                conn.commit()
                print("\nIMPORT COMPLETE — transaction committed.")

    print_known_discrepancies(len(cities), expected_award_history)
    return 0


# ============================================================
# CLI
# ============================================================


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="Import the Michelin Passport catalogue into PostgreSQL.")
    parser.add_argument("--target", choices=["local", "remote"], required=True)
    parser.add_argument("--dry-run", action="store_true", help="Parse, validate and insert, then roll back.")
    parser.add_argument(
        "--allow-nonempty",
        action="store_true",
        help="Proceed even if a target catalogue table already has rows. Never upserts.",
    )
    parser.add_argument(
        "--confirm-remote-import",
        default=None,
        metavar="TOKEN",
        help=f"Required, exact value {REMOTE_CONFIRM_TOKEN!r}, for a non-dry-run --target remote.",
    )
    return parser


def main() -> None:
    args = build_parser().parse_args()
    try:
        exit_code = run_import(
            target=args.target,
            dry_run=args.dry_run,
            allow_nonempty=args.allow_nonempty,
            confirm_token=args.confirm_remote_import,
        )
    except ImportValidationError as exc:
        print(f"\nERROR: {exc}", file=sys.stderr)
        sys.exit(1)
    except psycopg.Error as exc:
        print(f"\nDATABASE ERROR: {exc}", file=sys.stderr)
        sys.exit(1)
    sys.exit(exit_code)


if __name__ == "__main__":
    main()
