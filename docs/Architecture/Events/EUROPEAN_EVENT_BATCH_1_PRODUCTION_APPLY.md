# EUROPEAN EVENT ENRICHMENT — BATCH 1 PRODUCTION APPLY

Physical-data record of the approved Batch 1 production apply. Human
approval was granted for exactly 4 new Events, per
`EUROPEAN_EVENT_BATCH_1_REVALIDATION_PRE_APPLY.md`. No substitutions,
no additions, no changes to the approved plan were made.

## 1. PRE-WRITE VERIFICATION

Re-read live immediately before writing: `events` count = 5. Bas van
Kranen x Sang Hoon Degeimbre confirmed existing exactly once
(`307d79be-1712-40db-83ac-8758eeb78884`). None of the 4 approved Event
names existed yet (count = 0). Canonical coordinates reconfirmed
unchanged: Grand Resort Bad Ragaz (47.000427, 9.50371), Hiša Franko
(46.247249, 13.537761), Jordnær (55.748299, 12.541208) — all three
still resolve to the same UUIDs used in the approved plan. 39/39
migrations `local == remote`; `db push --dry-run` reported "Remote
database is up to date." No discrepancy found — proceeded exactly as
approved.

## 2. EXACT INSERTED EVENTS

| Field | SHEf's Kitchen Party | Marchal x Seafood Gastro | Douro to Table — Dinner III | Forces of Nature |
|---|---|---|---|---|
| id | `b4cdab07-bdef-4979-bafa-3238182be98a` | `ce123ee9-bd8d-4ca2-9fd0-0c4fbfafb704` | `5ac97246-0ffe-4f7a-a5a6-8d60e2d192a4` | `1e41e3d4-9519-4674-944c-dd4095c186e3` |
| event_type | experience | dinner | dinner | dinner |
| start_date / end_date | 2026-10-25 / 2026-10-25 | 2026-09-29 / 2026-09-29 | 2026-10-20 / 2026-10-20 | 2026-09-13 / 2026-09-13 |
| start_time / end_time | 11:00:00 / 15:00:00 | 18:30:00 / NULL | NULL / NULL | NULL / NULL |
| start_at / end_at | 2026-10-25T10:00:00Z / 2026-10-25T14:00:00Z | 2026-09-29T16:30:00Z / NULL | NULL / NULL | NULL / NULL |
| timezone | Europe/Zurich | Europe/Copenhagen | Europe/Lisbon | Europe/Ljubljana |
| venue_name | Grand Resort Bad Ragaz (Grand Hotel Quellenhof) | Marchal (Hotel d'Angleterre) | Cozinha do Douro (Six Senses Douro Valley) | Hiša Franko |
| city / country | Bad Ragaz / CH | Copenhagen / DK | Lamego / PT | Kobarid / SI |
| latitude / longitude | 47.000427 / 9.50371 | NULL / NULL | NULL / NULL | 46.247249 / 13.537761 |
| admission_type | paid (CHF 290pp) | paid (DKK 2,800pp) | paid (€125pp) | paid (price unpublished) |
| official_url | resortragaz.ch | dangleterre.com | magg.sapo.pt (press) | hisafranko.com |
| ticket_url | shop.e-guma.ch | sevn.ly | NULL | hisafranko.superbexperience.com |
| image_url | NULL | NULL | NULL | NULL |
| external_host_name | NULL | Marchal (Hotel d'Angleterre) | Six Senses Douro Valley | NULL |
| status / moderation_status / availability_status | upcoming / published / available | upcoming / published / available | upcoming / published / unknown | upcoming / published / unknown |

Every field matches the approved pre-apply report exactly — re-read
directly from production after write, not assumed.

## 3. EXACT INSERTED RELATIONSHIPS

| Event | Entity | Type | is_host | is_venue |
|---|---|---|---|---|
| SHEf's Kitchen Party | Grand Resort Bad Ragaz (`48b12739-0b80-48bb-91db-1810593eb4f4`) | Hotel | true | true |
| Forces of Nature | Hiša Franko (`9b7c9adb-82e1-4c25-ac07-708f95840f7e`) | Restaurant | true | true |
| Forces of Nature | Jordnær (`7045174b-d411-4025-b1c2-f05da93af821`) | Restaurant | false | false |

Marchal x Seafood Gastro and Douro to Table — Dinner III have zero
relationship rows, exactly as approved (external host only in both
cases). No `event_chefs` row was created (0, unchanged). No Restaurant,
Hotel, or Private Chef catalogue row was created.

## 4. TIME-PRECISION VERIFICATION

Re-read post-write, checked field by field:

- **SHEf's**: `start_time=11:00:00`, `end_time=15:00:00`,
  `start_at`/`end_at` both set — genuine sourced full-time shape.
- **Marchal**: `start_time=18:30:00` present; `end_time IS NULL`;
  `end_at IS NULL` — confirmed the previously-estimated `22:00` end
  time did **not** return.
- **Douro to Table**: `start_time IS NULL`, `end_time IS NULL`,
  `start_at IS NULL`, `end_at IS NULL` — genuine date-only.
- **Forces of Nature**: `start_time IS NULL`, `end_time IS NULL`,
  `start_at IS NULL`, `end_at IS NULL` — genuine date-only.

Searched all four inserted rows specifically for `00:00`, `23:59`, and
`22:00` — none present anywhere in the four new rows. No fabricated
precision was introduced.

## 5. LOCATION VERIFICATION

SHEf's Kitchen Party and Forces of Nature both carry real, non-null
coordinates pulled directly from their own canonical catalogue rows
(Grand Resort Bad Ragaz, Hiša Franko) — reconfirmed identical to the
pre-write baseline. Marchal and Douro to Table both correctly shipped
with `latitude/longitude = NULL` — no secondary/proxy coordinate was
introduced for either.

## 6. HOST SEMANTIC VERIFICATION

Grand Resort Bad Ragaz: `is_host=true, is_venue=true` for SHEf's
Kitchen Party — genuinely organizes and hosts it. Hiša Franko:
`is_host=true, is_venue=true` for Forces of Nature — Ana Roš's own
restaurant. **Jordnær: `is_host=false, is_venue=false`** — confirmed
by direct read of the inserted row, not merely intended. No participant
was promoted into a host anywhere in this batch.

## 7. EXISTING-DATA INTEGRITY

Re-read all 5 pre-existing Events post-write — every field (name,
start_date, status, moderation_status, venue_name, official_url,
ticket_url) identical to the pre-write baseline: 't Preuvenemint,
Wildfestival, Erloom x Henrique Sá Pessoa, Vergeet Mij Niet Gala, and
the Bas van Kranen pilot. The pilot's own relationship rows (Flore
host+venue, L'air du temps participant) are unchanged. `event_restaurants`
went from 9 pre-existing rows ('t Preuvenemint × 1, Vergeet Mij Niet
Gala × 6, Bas van Kranen pilot × 2) to 11 — the +2 delta is exactly the
two new Forces of Nature rows; every pre-existing row is byte-for-byte
present and unaltered. `event_confirmed_attendance` remains 0 — no
attendance row of any kind was created or altered. No Trip, Visit, or
Photo data was touched.

## 8. STEP 8C PASSPORT SAFETY

`event_confirmed_attendance` count re-confirmed 0 both before and after
this apply — none of the 4 new Events has any confirmed-attendance row,
so none can appear in any user's Passport. No test/manual attendance
was created in production.

## 9. COUNT DELTAS

```
events                    +4  (5 → 9)
event_hotels              +1  (0 → 1)
event_restaurants         +2  (9 → 11)
event_chefs                0  (0 → 0)
event_confirmed_attendance 0  (0 → 0, unchanged)
```

All deltas match the approved pre-apply plan exactly.

## 10. MIGRATION / SCHEMA STATUS

migrations created = 0. migrations deployed = 0. schema changes = 0.
RLS changes = 0. 39/39 migrations remain `local == remote`.
`db push --dry-run` (re-run after the apply): "Remote database is up to
date." — this was a pure data write via direct SQL, not a migration.

## 11. VALIDATION

`dart format --set-exit-if-changed .`: clean, 0 changed.
`flutter analyze`: no issues. `flutter test`: **1506 passed, 0
failed** — baseline unchanged, exactly as expected since no Dart code
was touched. `supabase migration list --linked`: 39/39 synced.
`supabase db push --linked --dry-run`: up to date. `git status
--short`: no new untracked files — only the pre-existing, already-noted
untracked research/doc artifacts, none staged.

## 12. PHYSICAL-DEVICE CHECKLIST

**EVENTS LIST**
- [ ] All 4 new Events appear in the Events feed/Explore
- [ ] Chronological ordering is sensible alongside the 5 existing Events
- [ ] Placeholder image renders correctly for all 4 (no broken image state)

**SHEf's Kitchen Party**
- [ ] Time displays as 11:00–15:00 (CET), not a fabricated range
- [ ] Grand Resort Bad Ragaz shows as host/venue on Event Detail
- [ ] Map pin resolves to the real Bad Ragaz coordinates

**Marchal x Seafood Gastro**
- [ ] Start time (18:30) is visible
- [ ] No end time or duration is displayed — confirm nothing was
      inferred/fabricated on the UI side for the missing end
- [ ] External host name/link ("Marchal (Hotel d'Angleterre)") renders
      correctly

**Douro to Table — Dinner III**
- [ ] Only the date (2026-10-20) is visible, no time of any kind
- [ ] No map pin renders (coordinates are NULL) rather than a wrong one
- [ ] External host name/link renders correctly

**Forces of Nature**
- [ ] Only the date (2026-09-13) is visible, no time of any kind
- [ ] Hiša Franko relationship renders correctly as host/venue
- [ ] Jordnær does **not** appear as a host anywhere in this Event's UI

**Event Detail (all 4)**
- [ ] Tickets / Official website rows link out correctly
- [ ] Admission info renders correctly, including Douro's email-only note
- [ ] Venue/location section matches the table above
- [ ] Back navigation works cleanly from each

**Reverse Discovery (Step 8B)**
- [ ] Grand Resort Bad Ragaz's own Hotel Detail page shows SHEf's
      Kitchen Party under its EVENTS section
- [ ] Hiša Franko's own Restaurant Detail page shows Forces of Nature
      under its EVENTS section
- [ ] Jordnær's own Restaurant Detail page shows nothing new

**Passport (Step 8C)**
- [ ] None of the 4 new Events appears in any test account's Passport
      simply because it now exists in production

## 13. DISCREPANCIES

None. Every step matched the approved plan exactly — no adaptation,
substitution, or scope change occurred at any point in this apply.

## 14. FINAL PRODUCTION STATE

`events` = **9** (5 pre-existing, unchanged + 4 newly approved).
`event_hotels` = **1**. `event_restaurants` = **11** (9 pre-existing,
unchanged + 2 new). `event_chefs` = **0**.
`event_confirmed_attendance` = **0**. The 5 HOLD candidates from the
re-validation (Couverts sur Mer, Toquicimes 2026, San Sebastián
Gastronomika 2026, DolomitiGourmet Festival 2026, Ugly Butterfly x
Simon Hulstone) remain exactly HOLD — none were touched. No migration,
catalogue entity, image upload, staging, commit, or push occurred in
this task.

EUROPEAN EVENT ENRICHMENT — BATCH 1 APPROVED SUBSET APPLIED, FOUR NEW
EVENTS VERIFIED IN PRODUCTION, READY FOR PHYSICAL-DEVICE REVIEW
