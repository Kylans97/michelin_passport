# Validation Report

Michelin Passport — data validation for the launch catalogue.

| | |
|---|---|
| **Dataset version** | `2026.07` |
| **Generated** | 28 July 2026 |
| **Source data revision** | `hotels_master.csv`, `restaurants_master.csv`, `hotel_restaurant_links.csv`, `restaurants_pending_manual_review.csv` — MVP final revision, 28 July 2026 |
| **Validation version** | 1.0 |
| **Supersedes** | — |

**This report describes one dataset snapshot.** Every figure in it — row counts, award distributions, coverage percentages, open issue counts — belongs to dataset `2026.07` and is expected to be wrong for any later one.

It is not amended when the catalogue changes. A guide update produces a new validation run, a new dataset version, and a new report that supersedes this one. Treat a report whose dataset version does not match the database as a historical record.

`VALIDATION_REPORT.md` is authoritative for dataset statistics and row counts wherever another document quotes them. `DATABASE_ARCHITECTURE.md` is authoritative for schema.

---

## 1. Executive summary

The catalogue holds **687 hotels**, **775 restaurants** and **68 hotel-restaurant relationships** across 43 countries and 614 cities. It passes 30 of 30 structural checks.

No record is blocked from import. Thirty-seven data issues remain open, tracked in `ACTION_TRIAGE.md`; none affects a table definition and all are correctable by row update after launch.

Two classes of imperfection are known and quantified. **Four venues hold a stored value that disagrees with a MICHELIN card** — one of them an award value, which is the most serious category in a product whose premise is award accuracy. **Three venues are confirmed to exist and are absent from the catalogue** because the place data required to create them has not been obtained, and nothing was fabricated to fill the gap.

Enrichment fields — MICHELIN URLs, websites, booking links, cuisine — are sparse by design and nullable. They are listed in §5.

---

## 2. Validation methodology

Validation is structural, referential and cross-source.

**Structural.** Column presence and order, type conformance, uniqueness of every key, nullability against the declared contract, absence of leading and trailing whitespace, and UTF-8 validity across every text field.

**Referential.** Every foreign key resolves in both directions. Every relationship row resolves to an existing hotel and an existing restaurant. Every venue resolves to a city and a country present in the reference tables.

**Range and domain.** Coordinates within valid latitude and longitude bounds, and inside the bounding box of the country recorded on the row. Award values within their permitted domains. Enumerated columns restricted to their permitted sets.

**Rule conformance.** The three hotel-scope rules in `DATABASE_ARCHITECTURE.md` §6 are mutually exclusive by construction, and conformance is asserted rather than assumed: no restaurant carries both a relationship row and a `property_name`.

**Cross-source.** Every award value, address and relationship traces to a MICHELIN publication, an operator's own site, or an explicit recorded decision. Where two sources disagree the row is flagged rather than resolved by preference, and the disagreement is recorded in `qa_issues.csv`.

**What is deliberately not validated.** Enrichment fields are not checked for presence, because their absence is expected. National totals are not reconciled against secondary sources: four different sources gave four different counts for US two-stars during collection, and only selections MICHELIN publishes itself proved reliable.

---

## 3. Validation results

### 3.1 Structure — pass

| Check | Result |
|---|---|
| Column count and order, all files | Pass |
| `hotel_code`, `restaurant_code`, `link_id` unique and non-null | Pass |
| Primary key column empty in source, assigned by PostgreSQL | Pass |
| No leading or trailing whitespace in any field | Pass |
| Valid UTF-8 throughout | Pass |

### 3.2 Completeness — pass

| Field | Coverage |
|---|---|
| `google_place_id`, hotels | 687 / 687 |
| `google_place_id`, restaurants | 774 / 774 |
| Coordinates, both tables | 100% |
| `city`, `country`, `name`, award value | 100%, both tables |

### 3.3 Referential integrity — pass

All 68 relationships resolve on both sides. No duplicate hotel-and-restaurant pair. Every linked restaurant is marked as being in a hotel.

### 3.4 Geographic — pass

1 462 rows checked against the bounding box of their recorded country. Zero outside.

### 3.5 Domain — pass

`michelin_keys` restricted to 1, 2, 3. `michelin_stars` restricted to 1, 2, 3 or null. Seven nulls, all World's 50 Best entries. `link_confidence` resolves to a single value across all 68 rows.

### 3.6 Uniqueness — pass, with ten intentional exceptions

Place IDs are unique within each table. **Ten are shared between a hotel row and a restaurant row**, listed in `DATABASE_ARCHITECTURE.md` §8, because one building carries one Google record. This is intentional and a cross-table unique index would reject all ten.

No duplicate hotel name within a country. No duplicate restaurant name within a city.

Nine rows share a name with another row across four names — IGNIV by Andreas Caminada, L'Atelier de Joël Robuchon, La Brezza and Noor. Four collide within one country. All are legitimate distinct venues and are the reason deduplication keys on code rather than name.

### 3.7 Rule conformance — pass

Thirty-three restaurants sit in a non-Key hotel: `property_name` populated, no hotel row, no relationship row. Distribution: Hong Kong 11, Macau 7, Japan 6, United States 6, and one each in Italy, Taiwan and Denmark.

No restaurant carries both a relationship row and a `property_name`.

---

## 4. Known issues

Thirty-seven open items. The four below are the ones that affect what a user sees. Full list in `ACTION_TRIAGE.md`.

### 4.1 Value conflicts — 4 venues

A stored value disagrees with a MICHELIN card. None blocks import.

| Venue | Stored | MICHELIN card |
|---|---|---|
| Villa Feltrinelli, Gargnano | two stars | appears to show three |
| Sofitel Frankfurt Opera | Hochstraße 44 | Opernplatz 16 |
| Château Neercanne, Maastricht | Von Dopfflaan 10 | 10 Von Dopffplein |
| Flores Raras, València | Carrer de Correus 8 | Correos 43-1º |

Villa Feltrinelli is the most consequential: a wrong star count is the one error this product cannot afford, and correcting it would also change Italy's published three-star and two-star totals.

The Sofitel conflict illustrates why structural validation is not sufficient. The two addresses are about 400 metres apart, so the row passes every automated check while being wrong. Address, coordinates and Place ID on that row are treated as one suspect group, because all three were likely resolved from the same string.

Château Neercanne is a single error affecting two rows, because the hotel and the restaurant share one Place ID.

### 4.2 Confirmed but absent — 3 venues

Each is a real venue with a confirmed award and no obtainable place data.

| Venue | Award | Missing |
|---|---|---|
| Widder Hotel, Zurich | Two Keys | coordinates, Place ID |
| The Dolder Grand, Zurich | Two Keys | coordinates, Place ID |
| Verve by Sven, Bad Ragaz | One star | address, coordinates, Place ID |

The two Zurich hotels are the pair that completes the Swiss Two-Key tier at the 32 MICHELIN publishes. Adding Widder Hotel also creates a relationship to Widder Restaurant, which currently has no relationship row and no `property_name`.

Nothing was invented to fill these gaps. A fabricated coordinate satisfies every validation check in §3 and is undetectable afterwards.

### 4.3 Place identity — 12 venues

Nine hotel Place IDs may resolve to the hotel's restaurant or spa rather than the accommodation. Google frequently ranks the restaurant above the hotel, and this is the largest single defect remaining. Two Hong Kong restaurant Place IDs may cover a sibling concept, and one Kyoto lookup resolves to the ryokan rather than the dining room holding the star.

Six Beijing restaurants have no usable record at all. Google has almost no commercial coverage in mainland China — six of eight lookups returned an unrelated business, in one case a cake shop for a two-star restaurant.

### 4.4 Unverified national totals — 9 countries

Andorra, Brazil, Croatia, Hungary, Malta, Montenegro, Poland, Serbia and Slovenia. Country progress renders **Unknown** for these rather than a false percentage, so the interface degrades honestly — but nine of twenty-one hotel countries showing Unknown is a visible gap at launch.

---

## 5. Sparse fields

Nullable by design. Their absence is not a validation failure.

| Field | Hotels missing | Restaurants missing |
|---|---|---|
| `michelin_url` | 656 | 612 |
| `website_url` | 669 | 763 |
| `booking_url` | 679 | 775 |
| `cuisine_id` | n/a | 170 |
| `property_name` | n/a | 1 of the 33 that require one |

The MICHELIN URL is sparse because the numeric identifier inside it cannot be derived from a name; each one requires an individual lookup, and MICHELIN blocks automated fetching.

No table holds a phone number. This is a decision rather than a gap — see `ARCHITECTURE_REVIEW.md` §7 — so the absence is not counted among the open items below.

---

## 6. Release notes

**Catalogue.** 687 hotels, 775 restaurants, 68 relationships, 43 countries, 614 cities, 146 cuisines. Seeded award history of 1 455 rows at `guide_year = 2026`. Fifty World's 50 Best rankings for 2025.

**One restaurant enters with a non-default status.** La Paix, Anderlecht, imports as `temporarily_closed` while relocating to the Corinthia Grand Hotel Astoria Brussels. It retains two stars. Its stored address is internally contradictory and must be corrected before import — see `DATABASE_IMPORT_GUIDE.md` §6.4.

**Seven restaurants enter with a null star count.** A NULL means the venue does not currently hold a MICHELIN star, which covers both venues in countries where MICHELIN awards no stars and venues inside a covered guide that are unstarred. All seven are World's 50 Best entries. The interface contract in `DATABASE_ARCHITECTURE.md` §3.3 is binding: a null star count must never render as "no award".

**One award seeding step is deliberately deferred.** The reigning World's 50 Best No.1 is elevated into the Hall of Fame only when the following year's list publishes, so no induction row is seeded for it. See `DATA_UPDATE_PROCESS.md` §4.

**Hall of Fame coverage is incomplete at launch.** Eleven restaurants are Best of the Best members. Six are in the catalogue and are seeded; five — El Bulli, The Fat Duck, Noma, Mirazur and Central — have no row because no place data was obtainable for them. Membership is recorded in full in `worlds_50_best_hall_of_fame.csv`. Only Central is absent for scope reasons; The Fat Duck and Mirazur hold three MICHELIN stars and are country-coverage gaps.

**Two schema corrections were applied during review**, both to constraints that did not enforce what they were documented to enforce. Recorded in `ARCHITECTURE_REVIEW.md` §1 and §2.

**One further constraint was widened before implementation.** `inclusion_reason` gained the value `hall_of_fame`, because the scope rule has three qualifying conditions and the constraint offered values for two. Without it a hall-of-fame restaurant would be stored as `worlds_50_best` while being, by definition, absent from that list.

**Five recommendations are open**, three of which are free to act on before the first import and carry a migration cost afterwards. Listed in `ARCHITECTURE_REVIEW.md`.

**Verified during preparation:** MICHELIN awards no stars in Peru, Chile or Colombia. In South America the guide operates in Brazil and, since 2023, Argentina. MICHELIN's hotel selection does cover Peru, so hotel and restaurant coverage are not the same footprint — which is why guide edition is recorded per city rather than per country.
s