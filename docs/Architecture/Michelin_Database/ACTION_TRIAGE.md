# Action Triage

Mantelier — open data work.

Thirty-eight items. None blocks the import. All are corrected by row update, none by schema change.

Ordered by consequence: what a user would see first, and what gets more expensive the longer it waits.

| Group | Items |
|---|---|
| 1. Critical data corrections | 4 |
| 2. Missing records | 5 |
| 3. Address and identity conflicts | 3 |
| 4. Place identity | 10 |
| 5. Coverage and enrichment | 10 |
| 6. Post-MVP | 6 |

---

## 1. Critical data corrections

An award value is the product. A hotel with the wrong Key count is an annoyance; a restaurant with the wrong star count contradicts the reason the application exists.

| ID | Item | Why it matters |
|---|---|---|
| **MA-067** | **Villa Feltrinelli, Gargnano — stored at two stars, the MICHELIN card appears to show three** | A three-star restaurant would render as two. It also blocks MA-051: if the card is right, Italy holds 16 three-star and 36 two-star restaurants, and the single missing Italian two-star becomes two. Resolve this before touching MA-051. |
| MA-017 | Three Osaka hotel restaurants, star counts never verified | Place data is complete; the Osaka starred selection was never obtained. Three rows currently assert an award nobody has checked. |
| MA-051 | One Italian two-star never identified | MICHELIN publishes 38 for Italy; 37 are held. The source list arrived with an alphabetical gap. Blocked behind MA-067. |
| MA-047 | Kanamean Nishitomiya — the star belongs to one of two dining rooms | The Place ID resolves to the ryokan. The property runs both Kaname and Nishitomiya, and the row does not say which holds the star. |

---

## 2. Missing records

Each is a confirmed venue with no obtainable place data. **Nothing may be invented to close these.** A fabricated coordinate passes every validation check and is undetectable afterwards.

| ID | Record | Missing | Why it matters |
|---|---|---|---|
| **MA-071** | Widder Hotel and The Dolder Grand, Zurich — Two Keys each | coordinates, Place IDs | These are the two hotels that complete the Swiss Two-Key tier at the 32 MICHELIN publishes. Adding Widder Hotel also creates the missing relationship to Widder Restaurant, which currently reads as being in no hotel at all. |
| **MA-066** | Verve by Sven, one star, Grand Resort Bad Ragaz | address, coordinates, Place ID | A starred restaurant absent from the catalogue. Bad Ragaz holds three starred restaurants and the database shows two. |
| **MA-074** | Five Best of the Best members — El Bulli, The Fat Duck, Noma, Mirazur, Central | address, coordinates, Place ID | Six of the eleven hall-of-fame restaurants are in the catalogue; these five are not. The Fat Duck and Mirazur hold three MICHELIN stars and are country-coverage gaps rather than scope gaps. |
| MA-075 | Best of the Best induction years | the induction year for each of the eleven | `worlds_50_best.year` needs the year a restaurant was elevated, which the publisher does not list beside the No.1 years. Blocks hall-of-fame seeding for the six that are present. |
| MA-014 | Six Swiss hotels held back for want of a verified Key count | Key counts | Four of the six are now identified. Switzerland is the most incomplete European market. |

---

## 3. Address and identity conflicts

Each is a stored value disagreeing with a MICHELIN card. None is caught by any automated check, which is precisely why they are listed.

| ID | Venue | Conflict | Why it matters |
|---|---|---|---|
| MA-068 | Sofitel Frankfurt Opera | Hochstraße 44 against Opernplatz 16 | About 400 metres apart, so the row passes its bounding-box check while being wrong. Address, coordinates and Place ID were likely resolved from the same string and must be re-verified as one group. |
| MA-069 | Château Neercanne, Maastricht | Von Dopfflaan 10 against 10 Von Dopffplein | A *laan* and a *plein* are different streets. The hotel and restaurant share one Place ID, so one error affects two rows. |
| MA-070 | Flores Raras, València | Carrer de Correus 8 against Correos 43-1º | House number and street-name language both differ. The venue was renamed from El Poblet on MICHELIN's authority; the address was not changed, because a rename is safe on that evidence and a re-addressing is not. |

---

## 4. Place identity

Records that resolve to the wrong establishment. Ten items.

**MA-048 — nine hotel Place IDs may resolve to a restaurant or spa rather than the accommodation.** The largest single defect remaining. Google frequently ranks a hotel's restaurant above the hotel itself, so a Place ID that looks correct opens the wrong card. Every hotel Place ID must be confirmed to resolve to accommodation.

**MA-046** — two Hong Kong restaurant Place IDs may cover a sibling concept at the same address.

**MA-045, MA-054, MA-055, MA-056, MA-057, MA-060** — nine restaurants and three hotels for which no correct record was ever obtained. Each returned a different establishment. They are held with name, city and award only.

**MA-062** — one restaurant, Jean-Georges New York, is marked as being in a hotel with no property name. 1 Central Park West is a hotel tower but no source names the property. It is the last row in a group of three; the other two were resolved when their address proved to be an office and retail complex rather than a hotel.

**MA-064** — La Paix imports with a corrected address. Its stored address, coordinates and Place ID point to a different property four kilometres away.

---

## 5. Coverage and enrichment

**MA-026 to MA-034 — nine countries with unverified totals.** Andorra, Brazil, Croatia, Hungary, Malta, Montenegro, Poland, Serbia, Slovenia. Country Progress renders Unknown rather than a false percentage, which is honest but visible: nine of twenty-one hotel countries show no figure. Verify only against selections MICHELIN publishes itself; secondary sources gave four different answers for one US tier during collection.

**MA-072 — 7132 House of Architects.** A second hotel on the same site as 7132 Hotel, named on its MICHELIN card. Key status unknown. It shares a street and postcode with an existing row, so the address matcher could merge the two. Record it either way.

---

## 5a. Open product decision

**Follower-only visibility.** `profiles.is_public` is binary today: a profile is visible to everyone or to its owner alone. A follow grants no read access, because `follows` has no approval step and a row is created unilaterally — if following granted access, any user could read any private profile by inserting one row.

Follower-only visibility is a reasonable feature and needs a `status` column on `follows` plus a third branch in `profile_is_visible`. It is not implemented, and the security model is documented as it stands rather than as it might become. See `DATABASE_ARCHITECTURE.md` §15.4.

Not counted among the 38 data actions: this is a product decision, not a data defect.

---

## 6. Post-MVP

None affects a user opening the application on day one.

| ID | Item | Note |
|---|---|---|
| MA-036 | 656 hotel and 612 restaurant MICHELIN URLs missing | The numeric identifier cannot be derived from a name, so each needs an individual lookup and MICHELIN blocks automated fetching. |
| MA-037 | Website and booking URLs, sparse on both tables | Consider linking out through `google_place_id` instead of storing them. |
| MA-038 | Cuisine blank on 170 restaurants | Cosmetic on a detail page; removes a filter dimension for those rows. |
| MA-039 | Address matcher assumes street-then-number | Pipeline tooling, not application code. Fix before running the linker over any British-form market: Malta, Ireland, the UK, the US. |
| MA-044 | Six Beijing restaurants hold the wrong record | Google has almost no commercial coverage in mainland China. Needs Amap or Baidu. |
| MA-061 | Texas, American South and Southwest two-star tiers | Expansion, not repair. |

---

## Recommended sequence

**Before the first import.** MA-062, the last row in its group, and the two decisions in `ARCHITECTURE_REVIEW.md` §3 and §6 that cost nothing now and a migration later.

**First week after import.** MA-067. One card re-read at full resolution settles an award value, unblocks MA-051 and corrects two published totals. Then MA-017.

**First month.** The three missing records in §2 and MA-048. All are mechanical place-data work, and together they close the largest remaining defect and complete the Swiss market.

**Before the next guide cycle.** MA-039, so the address matcher is correct before it runs over a new market rather than after.
