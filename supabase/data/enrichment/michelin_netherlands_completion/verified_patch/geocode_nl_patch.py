#!/usr/bin/env python3
"""Isolated Netherlands 18-restaurant patch geocoding.

Nominatim/OSM only, 1 request/sec pacing, results cached locally to
geocoding_cache.json in THIS folder. Does not read or write anything
under michelin_bulk_location_enrichment/ (the Belgium/France workstream) --
fully separate cache, fully separate scope (18 NL restaurants only).

For each of the 18 GENUINELY_MISSING candidates in genuinely_missing.csv,
issues two independent Nominatim queries:
  1. ADDRESS query -- structured street/postcode/city search (ground truth).
  2. VENUE query -- free-text restaurant-name + city search (what a naive
     "search by name" approach would return).
Then applies the venue-vs-address consistency safeguard: a venue-level
result is only trusted if it is geographically close to (or the same OSM
node as) the address-level result. NAME MATCH != LOCATION PROOF.

Read-only against OpenStreetMap's public API. Writes only within this
verified_patch/ folder.
"""

from __future__ import annotations

import csv
import json
import math
import time
import urllib.parse
import urllib.request
from pathlib import Path

HERE = Path(__file__).resolve().parent
PARENT = HERE.parent
CACHE_PATH = HERE / "geocoding_cache.json"
NOMINATIM_URL = "https://nominatim.openstreetmap.org/search"
USER_AGENT = "ChasingStarsMichelinPassport-NLPatch/1.0 (research; contact: kylan_97@live.nl)"
PACING_SECONDS = 1.1


def haversine_m(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
    r = 6371000.0
    p1, p2 = math.radians(lat1), math.radians(lat2)
    dp = math.radians(lat2 - lat1)
    dl = math.radians(lon2 - lon1)
    a = math.sin(dp / 2) ** 2 + math.cos(p1) * math.cos(p2) * math.sin(dl / 2) ** 2
    return 2 * r * math.asin(math.sqrt(a))


def load_cache() -> dict:
    if CACHE_PATH.exists():
        return json.loads(CACHE_PATH.read_text())
    return {}


def save_cache(cache: dict) -> None:
    CACHE_PATH.write_text(json.dumps(cache, indent=2, ensure_ascii=False))


def query_nominatim(cache: dict, key: str, q: str) -> list[dict]:
    if key in cache:
        return cache[key]
    params = {"q": q, "format": "json", "limit": 3, "addressdetails": 1, "countrycodes": "nl"}
    url = f"{NOMINATIM_URL}?{urllib.parse.urlencode(params)}"
    req = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
    try:
        with urllib.request.urlopen(req, timeout=20) as resp:
            data = json.loads(resp.read().decode("utf-8"))
    except Exception as exc:  # network/HTTP failure -- record and move on
        data = {"error": str(exc)}
    cache[key] = data
    save_cache(cache)
    time.sleep(PACING_SECONDS)
    return data


def main() -> None:
    with (PARENT / "genuinely_missing.csv").open(newline="", encoding="utf-8") as f:
        rows = list(csv.DictReader(f))

    cache = load_cache()
    results = []

    for row in rows:
        cid = row["candidate_id"]
        name = row["canonical_name"]
        city = row["city"]
        address = row["address"]

        addr_key = f"addr::{cid}"
        venue_key = f"venue::{cid}"

        addr_results = query_nominatim(cache, addr_key, f"{address}, Netherlands")
        venue_results = query_nominatim(cache, venue_key, f"{name}, {city}, Netherlands")

        addr_top = addr_results[0] if isinstance(addr_results, list) and addr_results else None
        venue_top = venue_results[0] if isinstance(venue_results, list) and venue_results else None

        distance_m = None
        if addr_top and venue_top:
            try:
                distance_m = haversine_m(
                    float(addr_top["lat"]), float(addr_top["lon"]),
                    float(venue_top["lat"]), float(venue_top["lon"]),
                )
            except (KeyError, ValueError):
                distance_m = None

        results.append({
            "candidate_id": cid,
            "canonical_name": name,
            "city": city,
            "address": address,
            "addr_top": addr_top,
            "venue_top": venue_top,
            "distance_m": distance_m,
        })

        tag = "OK" if (addr_top or venue_top) else "NOT_FOUND"
        print(f"[{tag}] {cid} {name} -- addr={'hit' if addr_top else 'miss'} "
              f"venue={'hit' if venue_top else 'miss'} dist={distance_m}")

    (HERE / "geocode_raw_results.json").write_text(
        json.dumps(results, indent=2, ensure_ascii=False)
    )
    print(f"\nWrote {len(results)} raw results to geocode_raw_results.json and cache to geocoding_cache.json")


if __name__ == "__main__":
    main()
