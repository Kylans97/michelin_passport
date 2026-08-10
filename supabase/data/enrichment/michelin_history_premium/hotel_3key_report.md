# Three-Key Hotels — Award History & Field Enrichment Report

**Scope:** the 36 hotels in `_source/three_key_hotels.csv` currently holding 3 MICHELIN Keys.
**Status:** research only. Nothing here has been imported into any database. Retrieved 2026-08-07.

## Context verified before starting

MICHELIN Keys is a genuinely new classification — there is no decades-long history to recover, unlike the star-restaurant workstream. The system launched country-by-country through 2024 and early 2025 (France, US, Spain — April 2024; Italy — May 2024; Japan — July 2024; Thailand — September 2024; Great Britain & Ireland — October 2024; Germany/Austria/Switzerland — 9 October 2024), then converged into a single first-ever **global** selection on 8 October 2025 (Paris ceremony), which also gave several countries — the Netherlands, Croatia, Singapore — their first-ever Keys list. A second global ceremony is scheduled for 18 September 2026, which is **after** today's date (2026-08-07), so no 2026-specific announcement exists yet to research; the "2026" guide_year already seeded as `is_current` in the production table is effectively still carrying the October 2025 result forward, and this workspace does not touch that row.

Because of this compressed timeline, realistic historical coverage is exactly 2024 and/or 2025, not a long back-series — and full coverage across all 36 hotels turned out to be achievable.

## Part 1 — Historical Key-award data

**36 of 36 hotels received a historical `award_history`-shaped row** (`hotel_award_history.csv`), each carrying `is_current = false` and never restating the seeded current row.

- **32 hotels**: `guide_year = 2024` — held 3 Keys since their country's 2024 debut list (17 in Germany/Austria/Switzerland, 4 in Spain, 5 in Italy, 5 in Japan, 1 in Monaco/France).
- **4 hotels**: `guide_year = 2025` — first appear at 3 Keys in the October 2025 global selection:
  - **De L'Europe** (Amsterdam) — the Netherlands' first-ever Keys list; sole Dutch Three-Key hotel.
  - **Villa Nai 3.3** (Dugi Otok) — Croatia's first-ever Keys list; sole Croatian Three-Key hotel.
  - **Raffles Hotel, Singapore** — Singapore's first-ever Keys list; first and only Singapore hotel ever to receive Three Keys.
  - **Borgo Santo Pietro** (Chiusdino, Italy) — see below; a genuine *change*, not a debut.

### The one confirmed Key-count change

**Borgo Santo Pietro** is the one hotel in the set that visibly gained Three Keys rather than holding them since 2024. Italy's inaugural 2024 selection named exactly 8 Three-Key hotels (confirmed via Forbes and italiabsolutely.com, both listing all 8 by name) — Borgo Santo Pietro is **not** among them. A MICHELIN Guide article titled "The Dozens of Newly-Added Key Hotels in Italy — Including Five New Three Keys" (2025) names it as one of five hotels newly promoted to Three Keys that year. Its exact 2024 tier (1 Key / 2 Keys / unrated) could not be established from available sources and is recorded in `hotel_history_unresolved.csv` rather than guessed.

Every other hotel's evidence points to unbroken 3-Key status since its country's debut list, with no other decreases, increases, or gaps found.

### Confidence profile

30 rows `medium` confidence (country/press-level confirmation via WebSearch/WebFetch snippets, since `guide.michelin.com` blocks direct fetch — confirmed HTTP 403 on every attempt), 6 rows `high` confidence (hotel's own primary press release, an official tourism-board republish of MICHELIN's own text, or a dedicated wire release naming that specific hotel). No `low`-confidence rows and no `rejected` rows.

### Unresolved (1 entry)

`hotel_history_unresolved.csv` — Borgo Santo Pietro's Key tier (if any) prior to its 2025 upgrade, as above.

## Part 2 — Field enrichment (existing columns only)

Of the 36 source rows, only `hotel_17` (De L'Europe) already had `website_url`, `michelin_url`, and `booking_url` populated. The remaining 35 hotels were missing at least one of the three; **101 of 101 missing fields were resolved** (`hotels_3key_fields.csv`), one row per field, all `status = proposed`.

| Field | Before (populated) | Missing | After proposal |
|---|---|---|---|
| `website_url` | 1 / 36 | 35 | 36 / 36 |
| `michelin_url` | 5 / 36 | 31 | 36 / 36 |
| `booking_url` | 1 / 36 | 35 | 36 / 36 |

No Instagram, description, or Google rating/review data was fetched or stored anywhere in this pass, per scope.

### Confidence profile (101 rows)

- **41 high** — direct WebFetch confirmation of the hotel's own official domain and/or a specifically-named deep booking link (e.g. a Synxis/chain reservation URL with the hotel's own ID).
- **47 medium** — confirmed via search-engine snippets (mostly `guide.michelin.com` hotel pages, which block direct fetch with HTTP 403 on every single attempt made) or a hotel/brand domain confirmed only indirectly.
- **13 low** — a plausible entry point (usually the hotel's homepage, which carries an embedded booking widget) proposed in place of a dedicated booking-engine subpage that could not be independently isolated. These are concentrated in `booking_url` (roughly a third of that column) and are the rows most worth a human's first look.

### What was hardest to verify

- **`guide.michelin.com` blocks all automated fetching** (HTTP 403 confirmed on every direct-fetch attempt against a hotel page or the "Every Three-Key Hotel" travel articles) — every `michelin_url` and every Part-1 fact anchored to a MICHELIN-authored article had to be corroborated via search-engine snippets instead of a primary-source fetch, capping most of those rows at `medium` rather than `high` confidence.
- **Dedicated booking-engine URLs** were frequently not discoverable for independent boutique hotels that book via an on-page modal/widget rather than a separate URL (Sacher Wien, Grand Resort Bad Ragaz, Badrutt's Palace, Baur au Lac, The Woodward, HOTEL THE MITSUI KYOTO, Bvlgari Tokyo, Four Seasons Tokyo Otemachi, Villa Nai 3.3, Hôtel de Paris Monte-Carlo) — these were proposed at `low` confidence using the hotel's homepage.
- **Borgo Santo Pietro's pre-2025 Key tier** — genuinely unrecoverable from the sources available; parked in the unresolved file rather than guessed.
- **Name variants**: MICHELIN and hotel-brand sites use fuller names than the source file in a few cases (e.g. "Fairmont Hotel Vier Jahreszeiten" vs. the source's "Hotel Vier Jahreszeiten"; "Castello di Reschio" vs. "Reschio Hotel") — every one of these was verified against city, country, and address before acceptance, never on name alone, per `DATABASE_ARCHITECTURE.md` §7.

## Review checkpoint

Per `PROVENANCE_SCHEMA.md`, every `confidence: low` row (13 field-enrichment rows, all `booking_url` homepage fallbacks) and the single `unresolved` entry warrant a human look before any import is considered. All `medium`-confidence rows rest on independently corroborating secondary sources but not a direct MICHELIN Guide fetch, and would benefit from a manual guide.michelin.com check where feasible.
