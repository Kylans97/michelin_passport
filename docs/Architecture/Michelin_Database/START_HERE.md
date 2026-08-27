# Mantelier

Project orientation. Read this first, then the document you need.

---

## SUPERSEDED NOTICE — 24 August 2026: production is now the source of truth

Everything below this notice describes the project as it stood **before
the database and application were built** — a pre-implementation planning
snapshot. It is kept, not deleted, as the historical record of that
freeze. It is no longer current, and should not be read as authoritative
about the present state of the data.

**What changed and why.** The catalogue was originally imported from the
CSVs listed in "Source files" below. Since then, the live Supabase
database has grown beyond that snapshot through direct enrichment work —
588 restaurants and 88 hotels now exist in production that were never in
`restaurants_master.csv`/`hotels_master.csv`, and a `phone` column was
added to `restaurants` (migration `20260819120000_add_restaurant_phone
.sql`) that no CSV ever carried. The CSVs stopped being updated; the
database did not stop growing. Discovered and reconciled 24 August 2026.

**The rule going forward: the live Supabase database is authoritative.
The master CSVs are an export of it, never an import into it.** Nothing
should be re-imported from `restaurants_master.csv`/`hotels_master.csv`
on the assumption they are current — they are not. A fresh, read-only
export was taken directly from production on 24 August 2026:

| File | Rows | Status |
|---|---|---|
| `restaurants_master_LIVE_20260824.csv` | 1362 | **Current** — read-only export of `restaurants_full` |
| `hotels_master_LIVE_20260824.csv` | 775 | **Current** — read-only export of `hotels_full` |
| `hotel_restaurants_LIVE_20260824.csv` | 74 | **Current** — the join table (called `hotel_restaurant_links.csv` in the frozen export below; the live table's real name is `hotel_restaurants`) |
| `events_LIVE_20260824.csv` + 7 related `event_*_LIVE_20260824.csv` files | 28 events, see each file | **Current** — did not exist at all in the original freeze; the events feature was built after this document was last accurate |
| `cuisines_LIVE_20260824.csv`, `worlds_50_best_LIVE_20260824.csv`, `worlds_50_best_hotels_LIVE_20260824.csv` | 153 / 782 / 189 | **Current** — reference tables used to resolve `cuisine`/World's 50 Best fields in the two exports above |
| `restaurants_master.csv`, `hotels_master.csv`, `hotel_restaurant_links.csv` (below) | 774 / 687 / 68 | **Historical freeze only** — the original import snapshot this whole document describes. Preserved untouched as the historical record; do not treat as current, do not re-import. |

The 588 restaurants and 88 hotels that exist only in production are
unevenly enriched — most importantly, essentially none of the 588 new
restaurants have a `google_place_id` or resolved `cuisine`, and only
~2% have a `website_url`, despite being fully geocoded (address/lat/lng
100% populated). The 88 new hotels are in much better shape (address/lat
/lng 100%, `website_url` 95.5%, but `google_place_id` still only 5.7%).
See the enrichment-state report this notice's own investigation produced
for the full per-field, per-country breakdown — this is exactly the input
the next enrichment pass needs and did not have before.

---

## What this is

A mobile application that lets people record the MICHELIN Key hotels and MICHELIN-starred restaurants they have visited, and see their progress across countries and cities.

Backend is PostgreSQL on Supabase with PostGIS. Client is Flutter.

The data set is complete and the architecture is settled. The work is implementation.

---

## Status

| | |
|---|---|
| Data collection | Complete |
| Architecture | Complete |
| Database implementation | Not started |
| Application | Not started |
| Open data issues | 37, none blocking |

---

## The catalogue

| | |
|---|---|
| Hotels | **687** across 21 countries — 36 Three-Key, 161 Two-Key, 490 One-Key |
| Restaurants | **775** across 38 countries — 121 Three-Star, 341 Two-Star, 306 One-Star, 7 unstarred |
| Hotel–restaurant relationships | **68** |
| Countries | 43 |
| Cities | 614 |
| Cuisines | 146 |

Figures describe the launch dataset and change with every guide update. `VALIDATION_REPORT.md` is authoritative and states the snapshot they belong to.

Largest markets — hotels: Italy 144, Germany 126, Japan 115, Spain 109. Restaurants: Japan 254, Netherlands 105, Germany 59, Italy 58, Spain 56, United States 51.

The seven unstarred restaurants are World's 50 Best entries, including Maido, the best restaurant in the world in 2025. Six of them are in Peru, Chile and Colombia, where MICHELIN awards no stars at all.

---

## Documentation

| Document | Responsibility |
|---|---|
| **`DATABASE_ARCHITECTURE.md`** | The schema. Tables, columns, constraints, indexes, conventions, security model. |
| **`DEPLOYMENT.md`** | Environments, secrets, storage, migrations, backup, monitoring. |
| **`DATABASE_IMPORT_GUIDE.md`** | Building the database from the source files. Order, transformations, verification, rollback. |
| **`DATA_UPDATE_PROCESS.md`** | Maintaining the catalogue. Guide updates, closures, renames, new countries, regression tests. |
| **`VALIDATION_REPORT.md`** | What has been validated, how, and what is known to be imperfect. |
| **`ACTION_TRIAGE.md`** | Open data work, ordered. |
| **`ARCHITECTURE_REVIEW.md`** | Seven items raised against the schema. Two applied, five awaiting a decision. |

**Where each kind of fact is authoritative.** If two documents disagree, these three settle it:

| Subject | Authoritative document |
|---|---|
| Schema, constraints, conventions, security | `DATABASE_ARCHITECTURE.md` |
| Dataset statistics and row counts | `VALIDATION_REPORT.md` |
| Project orientation and where to look | `START_HERE.md` |

Counts quoted anywhere else — including on this page — are illustrative and go stale with the first guide update. `VALIDATION_REPORT.md` states which dataset snapshot they describe.

`ARCHITECTURE_REVIEW.md` and `ENGINEERING_REVIEW.md` are decision records, not specifications. Read them for *why* something is the way it is, and for which alternatives were rejected. Never implement from them.

---

## Settled architectural decisions

These are fixed. Each has a full argument in `ARCHITECTURE_REVIEW.md`; the one-line reason is here so a change can be recognised as a reversal rather than an improvement.

| Decision | Why |
|---|---|
| **UUID primary key plus external code** | The UUID is internal and regenerated on any rebuild; the code is what every QA entry, source file and remap references. |
| **Polymorphic user entities** | `visits`, `wishlist` and `photos` address a venue by `entity_type` and `entity_id`, so one table serves both venue types and a visit list orders by date across them. |
| **`award_history` exists from day one** | Adding the table later is trivial; reconstructing an award timeline that was overwritten is impossible. |
| **`worlds_50_best` is its own table** | A star is an ordinal tier where higher is better and a rank is a position where lower is better; one column cannot order both correctly. |
| **`is_in_hotel` is derived, never stored** | It drifted twice as a stored value, and a generated column cannot depend on the existence of a row in another table. |
| **`michelin_stars` is nullable, never zero** | Zero asserts an assessment that did not happen for venues in countries where MICHELIN awards no stars. |
| **No phone numbers** *(SUPERSEDED 24 Aug 2026 — see notice at top of this document)* | Not stored on either catalogue table; `google_place_id` resolves to one when needed. **No longer true**: `restaurants.phone` was added by migration `20260819120000_add_restaurant_phone.sql` and is live in production (1 of 1362 restaurants populated: Parkheuvel). Hotels still have no `phone` column — that half of the original claim still holds. |
| **No stored Google ratings** | Volatile, third-party licensed, and reachable through the Places API; inside Mantelier the user's own rating is the source of truth. |
| **Hotel and property relationship model** | `hotels` holds only Key hotels, the join table holds only verified links to them, and a restaurant in a non-Key hotel records `property_name` instead — three mutually exclusive states. |

---

## Source files *(SUPERSEDED 24 Aug 2026 — historical freeze, not current row counts. See the notice at the top of this document for the live `_LIVE_20260824` exports and which files are now authoritative.)*

| File | Rows |
|---|---|
| `hotels_master.csv` | 687 |
| `restaurants_master.csv` | 774 |
| `restaurants_pending_manual_review.csv` | 1 — La Paix, imported with a corrected address |
| `hotel_restaurant_links.csv` | 68 |
| `qa_issues.csv` | the QA log |
| `manual_actions_required.csv` | open and closed actions |

---

## Implementation order

1. Extensions — PostGIS, pg_trgm, pgcrypto, pg_cron
2. Types, functions and triggers
3. Staging schema
4. Reference tables — `countries`, `cities`, `cuisines`
5. Catalogue tables — `hotels`, `restaurants`
6. `hotel_restaurants`
7. `award_history`, `worlds_50_best`
8. Views
9. Indexes and constraint validation
10. User tables, including the profile bootstrap trigger
11. Row Level Security
12. Materialised views and their refresh schedule

Full procedure in `DATABASE_IMPORT_GUIDE.md`. The order is not negotiable; each step depends on identifiers created by the previous one.

---

## What every developer must know

**Two identifiers per venue.** `id` is an internal UUID generated by PostgreSQL. `hotel_code` and `restaurant_code` are the external keys that every QA entry, manual action and source file references. Both are permanent.

**Codes decide, names may only propose.** Four venue names collide inside a single country. La Brezza appears twice in Switzerland at different star counts because one chef cooks in each seasonally. Deduplication and joins key on the code; a name may generate a candidate for a human to confirm and nothing more. Search matches on name, and every result must show its city and country.

**Three ways a restaurant qualifies.** At least one MICHELIN star, a place on the current World's 50 Best list, or membership of the Best of the Best hall of fame. The third is bounded at eleven restaurants and admits former No.1s only — not every restaurant that has ever ranked. Unstarred Guide entries, including Bib Gourmand, are out of scope.

**`michelin_stars` is NULL, never zero.** **A NULL `michelin_stars` means the venue does not currently hold a MICHELIN star.** It covers two situations: venues in countries where MICHELIN awards no stars, and venues inside a covered guide that are currently unstarred. `inclusion_reason` records why the row exists and is what distinguishes the two.

It must never render as "no award" or as an empty star row — render the World's 50 Best rank instead.

**Three hotel-scope rules, mutually exclusive.** `hotels` holds only Key hotels. `hotel_restaurants` holds only links to Key hotels already present. A restaurant in a non-Key hotel records the property in `property_name`, with no hotel row and no link. 33 restaurants are in the third case.

**`property_name` is free text and is never joined on.** Five properties host more than one starred restaurant.

**A starred restaurant inside a hotel is not evidence the hotel holds a Key.** Grand Hotel a Villa Feltrinelli hosts a starred restaurant and holds none.

**Google Place IDs are unique within a table, never across tables.** Ten are deliberately shared between a hotel row and a restaurant row where one building has one Google record. A cross-table unique index rejects all ten.

**Never delete a catalogue row.** `visits`, `wishlist` and `photos` reference venues polymorphically, so no foreign key protects them. A `DELETE` succeeds silently and orphans every visit that pointed at the row, and a lost visit cannot be reconstructed. Closed venues get a `status`, not a `DELETE`. The regression suite scans for orphans because the database cannot.

**Row Level Security is part of the build, not a hardening pass.** Until policies exist, every table is writable by the `anon` key that ships inside the app. Specification in `DATABASE_ARCHITECTURE.md` §15.

**The `service_role` key belongs only to the maintenance process.** It bypasses every policy. It must never appear in the Flutter application or a repository. Inventory in `DEPLOYMENT.md` §4.

**Point-in-Time Recovery is a hard requirement.** The polymorphic user tables cannot be protected by a foreign key, so recovery from an accidental catalogue delete is a restore. `DEPLOYMENT.md` §9.

**Never overwrite an award without writing history first.** MICHELIN publishes about fifteen guide jurisdictions on independent dates, so award changes are a continuous stream. A value overwritten before it was recorded is unrecoverable.

**Country is geographic.** Monaco, Hong Kong, Macau and the Faroe Islands each hold their own row, although MICHELIN files them under other guides. Guide edition is a property of a city, so per-country counts will not reconcile with MICHELIN's published per-guide figures. That is intended.

**Coordinates: longitude first.** `ST_MakePoint(lng, lat)`. Reversing it produces rows that are silently valid and geographically wrong.

**MICHELIN blocks automated fetching.** Most rosters were captured manually, and the next update will be too. A MICHELIN hotel card's list of restaurants is neither exhaustive nor limited to the building — use it to propose a link, never to reject one.

**Where a national total is unverified, render Unknown.** Never a computed percentage. Nine countries are currently in that state.
