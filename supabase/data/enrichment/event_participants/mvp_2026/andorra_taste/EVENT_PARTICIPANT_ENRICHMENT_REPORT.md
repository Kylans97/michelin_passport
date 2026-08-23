# Andorra Taste 2026 — Event Participant Enrichment Report

Status: research complete, evidence documented, and the event + all 6 EXACT_MATCH participant links are **APPLIED and VERIFIED in production** — see the Applied Status section at the end for the full application/verification record, including a schema-drift correction discovered and safely handled during apply. §1–§8 below are the original pre-application research and are preserved unmodified. Recommendation: **GREEN**.

---

## 1. Event

| Field | Value |
|---|---|
| Name | Andorra Taste |
| Edition | 5th |
| Dates | 16–20 September 2026 |
| City / Country | Escaldes-Engordany, Andorra (AD) |
| Venue | El Prat del Roure, C/ Veedors |
| Official URL | https://www.andorrataste.com/en |
| Admission | `mixed` — public programme free (limited capacity on some activities), separate professional/trade agenda |

Confirmed via the official site (`andorrataste.com/en`, `/en/programa`, `/en/ponente`, `/en/popular`) and cross-validated by three independent editorial sources (TheGourmetJournal, Alto, Baco&Boca) all describing the same 2026, France-guest-country, 5th-edition event. No duplicate event exists in production (`select ... where name ilike '%andorra%'` returned zero rows).

## 2. Participants

- **Raw participants found:** 19 (16 from the official Speakers page + 3 Andorran restaurateurs named in editorial cross-validation coverage).
- **Restaurant-type candidates:** 16.
- **Not-a-restaurant:** 3 (Audrey Doré — sommelier; Oriol Balaguer — pastry brand; Óscar Caballero — gastronomy journalist).

## 3. Matching

| Status | Count |
|---|---|
| EXACT_MATCH | 6 |
| PROBABLE_MATCH | 0 |
| MANUAL_REVIEW | 0 |
| NO_MATCH | 10 |
| NOT_A_RESTAURANT | 3 |

**Restaurant match rate:** 6 / 16 = **37.5%**
**Michelin-starred EXACT_MATCH count:** **6** (all six matches are currently Michelin-starred)

## 4. Exact matches

| Chef | Restaurant | City | Stars |
|---|---|---|---|
| Sergio y Javier Torres | Cocina Hermanos Torres | Barcelona, ES | ★★★ |
| Julian Stieger | Rote Wand Chef's Table | Lech am Arlberg, AT | ★★ |
| Vivien Durand | Le Prince Noir - Vivien Durand | Lormont, FR | ★ |
| Juanlu Fernández | LÚ Cocina y Alma | Jerez de la Frontera, ES | ★★ |
| Paco Roncero | Paco Roncero | Madrid, ES | ★★ |
| Iván Cerdeño | Iván Cerdeño | Toledo, ES | ★★ |

Full evidence per match: `exact_matches.csv`.

## 5. Expected MICHELIN AT THIS EVENT preview

```
MICHELIN AT THIS EVENT

Cocina Hermanos Torres         ★★★
Barcelona 🇪🇸

Julian Stieger's Rote Wand Chef's Table   ★★
Lech am Arlberg 🇦🇹

Paco Roncero                   ★★
Madrid 🇪🇸

LÚ Cocina y Alma                ★★
Jerez de la Frontera 🇪🇸

Iván Cerdeño                   ★★
Toledo 🇪🇸

Le Prince Noir - Vivien Durand  ★
Lormont 🇫🇷
```
(Sorted most-decorated first, per the existing `michelinStarredParticipants` sort rule — see EVENTS_UI_MICHELIN_PARTICIPATION.md.)

## 6. Review items

- **Manual review:** none.
- **Probable matches:** none.
- **Catalogue-expansion candidates surfaced:** Manolo Franco / La Casa de Manolo Franco (Valdemorillo, 1 Michelin star, 2025 Guide) — a genuine current Michelin-starred restaurant absent from the catalogue. Also: Flocons de Sel (Emmanuel Renaut, Megève, 3★), SanBrite (Riccardo Gaspari, Cortina d'Ampezzo), Ansils (Iris/Bruno Jordán, Benasque), La Coopérative (Dennys Teixeira). None created — recorded only.
- **Andorra itself:** zero restaurants in the production catalogue at all — every Andorran participant (Eric Marty, José Antonio Guillermo, Roger Biosca, Marc Mora) is structurally NO_MATCH regardless of research depth. Ironic given the event's own host country, but consistent with this app's Michelin-recognition-curated catalogue scope.

## 7. Recommendation: GREEN

Six EXACT_MATCH participants, all currently Michelin-starred (3+2+1+2+2+2 = 12 combined stars), spanning three countries (ES/AT/FR) — comfortably exceeds the GREEN bar ("multiple reliable restaurant matches... at least 2 Michelin-starred EXACT_MATCH participants"). International mix is genuine, not manufactured — matches a real, current, verifiable event roster.

## 8. Data quality

- No duplicate participant rows (19 unique names).
- No duplicate event/restaurant pairs prepared (6 unique restaurant_codes).
- Every EXACT_MATCH restaurant_code independently re-queried and confirmed to exist in production immediately before writing this report.
- No Michelin star count sourced from the event's own website — every star count in `exact_matches.csv` was read from `restaurants_full.michelin_stars` directly.
- `link_event_restaurants.sql` contains zero literal restaurant UUIDs by design (see that file's own header).

---

## 9. Applied status (added post-approval — original research above is unmodified)

Applied to production 2026-08-23, following the re-resolve → re-verify → duplicate-check → write → post-write-verify sequence in `docs/Architecture/EVENT_PARTICIPANT_ENRICHMENT_STANDARD.md`.

- **Event status:** `APPLIED / VERIFIED`
- **Production event id:** `35dd62ac-2d72-40e1-a231-8518358d169d`
- **Relationship status (all 6):** `APPLIED / VERIFIED`
- **event_restaurants row ids:** see `applied_status.csv`

### Schema-drift correction (discovered and safely handled during this apply)

The `link_event_restaurants.sql` artifact as originally prepared (2026-08-16) inserted `start_at`/`end_at` as literal timestamps and did not set `timezone`/`start_date`/`end_date` at all — correct for the schema at prepare time. Between then and apply time (2026-08-23), the Events V2 Time Precision migrations (2026-08-22) added `timezone`, `start_date`, `end_date` as `NOT NULL` columns. The first apply attempt therefore failed cleanly: Postgres rejected the insert with `null value in column "timezone" violates not-null constraint`, the transaction rolled back automatically, and a follow-up query confirmed zero partial writes (`event_restaurants` count unchanged at 28, zero Andorra Taste rows).

Rather than fabricate a specific clock time to satisfy the old shape, this event was applied using the schema's own current, more accurate date-only representation — the exact same pattern already live for Douro to Table and Forces of Nature (`start_at`/`end_at` NULL, `timezone='Europe/Andorra'`, `start_date='2026-09-16'`, `end_date='2026-09-20'`, `start_time`/`end_time` NULL). This is not new research or a new fact — the event's exact clock time was never actually sourced in the first place (the original `00:00:00`/`23:59:59` were always whole-day placeholders); the correction only changes how that same already-known fact is stored. `link_event_restaurants.sql` has been updated in place to reflect exactly what was executed, with its own header documenting this correction for future reference.

### Verification performed

- **Pre-flight duplicate check (final, immediately before apply):** `select id, name, start_date, end_date from public.events where name = 'Andorra Taste' and start_date = '2026-09-16'` → zero rows, both before the failed attempt and again before the corrected attempt.
- **Post-write event read-back:** exactly one `Andorra Taste` row; every field (name, description, country_code, city, venue_name, address, official_url, ticket_url, event_type, status, admission_type, admission_note, timezone, start_date, end_date) matches the approved payload exactly; `moderation_status = 'published'` (default); `id = 35dd62ac-2d72-40e1-a231-8518358d169d`.
- **Post-write relationship read-back:** exactly 6 `event_restaurants` rows for this event, joined to `public.restaurants`, each resolving to the intended `restaurant_code`/name/city/Michelin-star-count, all `status = 'open'`, all `is_host = false` / `is_venue = false` (plain participants).
- **Duplicate check:** zero rows with `count(*) > 1` grouped by `(event_id, restaurant_id)` for this event.
- **Blast-radius check:** `events` total 27 → 28 (exactly +1); `event_restaurants` total 28 → 34 (exactly +6); no other `events` or `restaurants` row was touched by this apply (no `UPDATE` statement was ever issued against either table).
- **REST/anon-key runtime path:** not independently re-tested this time (unlike the Preuvenemint pilot) — no production anon key was retrieved or used in this session. The direct-query verification above already mirrors `EventsRepository.loadLinkedVenues`'s own two-query join shape (`event_restaurants` → `restaurant_id` list → `restaurants` lookup), which is the meaningful equivalent at the data level; only the PostgREST/RLS-as-anon-role layer specifically was not separately exercised.

No content in §1–§8 above was altered — this section is additive only, preserving the original research as it stood before production application.

---

ANDORRA TASTE 2026 EVENT PARTICIPANT ENRICHMENT — EVENT CREATED, ALL 6 EXACT_MATCH RELATIONSHIPS APPLIED AND VERIFIED
