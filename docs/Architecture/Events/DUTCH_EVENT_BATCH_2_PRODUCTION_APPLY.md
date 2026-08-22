# DUTCH EVENT ENRICHMENT — BATCH 2 PRODUCTION APPLY

Physical-data record of the approved Batch 2 production apply.
Authoritative plan: `DUTCH_EVENT_BATCH_2_PRE_APPLY.md`. All 10 approved
Events were inserted exactly as specified there; the 2 HOLD candidates
were left untouched.

## 1. PRE-WRITE STATE

Re-read live immediately before writing: `events` count = **17**.
None of the 10 approved names existed yet (0 matches), and neither of
the 2 HOLD Events existed as an accidental production row (0 matches,
confirmed explicitly). All 6 canonical Restaurant UUIDs (Triptyque,
Basiliek, Kaatje bij de Sluis, Olde Marckt, Parkheuvel, 't Ganzenest)
and the 1 canonical Hotel UUID (Van Oys Maastricht Retreat) re-resolved
correctly. `event_restaurants` = 21, `event_hotels` = 3, `event_chefs`
= 0 (pre-write baselines). 39/39 migrations synced; dry-run reported
"Remote database is up to date." No discrepancy found — no source
re-verification was needed beyond this gate, since nothing in the
approved plan carried a known specific risk requiring a fresh check
(unlike Dîner Dansant's known-broken link in Batch 1).

## 2. FINAL DUPLICATE GATE

All 10 approved titles: 0 matches against production. Both HOLD
titles: 0 matches, confirmed not accidentally present. **No last-minute
source discrepancy was found.**

## 3. EXACT 10 EVENTS APPLIED

| Event | UUID | Date | Precision |
|---|---|---|---|
| VanOost Sundays: BBQ with Friends | `9becd8ba-ff8d-4fa5-a685-99200df42706` | 2026-08-30 | DATE_ONLY |
| Friends & Family Zomer BBQ met Marko Karelse | `8b27df6d-9f95-4427-8f39-e3d20353f775` | 2026-08-30 | DATE_ONLY |
| Chaîne des Rôtisseurs Gala Dîner op SS Antoinette | `1fe81ee4-27ae-46d6-b169-13cca93b86af` | 2026-09-13 | START_KNOWN_END_UNKNOWN |
| Wine & Dine × Pierre Ache Wijnen | `ad0c9f02-e795-4646-a14a-a4625d6a0186` | 2026-09-15 | FULL_TIME |
| Wijnmakersdiner Montanha Vermelha | `b9f44b6d-ae0c-4b90-870e-089d82cb4fc2` | 2026-09-18 | DATE_ONLY |
| Club Leroy bij Parkheuvel | `9dbee4f6-ad2a-4477-a4e4-5a185cb7b606` | 2026-09-20 | START_KNOWN_END_UNKNOWN |
| Exclusieve Wijnproeverij — Domaine Paul Pillot | `7ad5ed0c-eee6-4be5-b99b-2eef6a443d21` | 2026-09-24 | DATE_ONLY |
| Jubileumdiner — 5 jaar Restaurant Roemer | `b735ec10-84df-44d4-9cbd-6e4e9b540ac4` | 2026-10-08 | START_KNOWN_END_UNKNOWN |
| Wijnmakerslunch Heidi Schröck & Söhne | `4fa6a92a-9009-4852-9509-83597d88b437` | 2026-10-18 | START_KNOWN_END_UNKNOWN |
| Four-Hands Diner: Olde Marckt x Karels | `b7723a62-aad2-480e-90c7-5d983a24fb85` | 2026-11-01 | START_KNOWN_END_UNKNOWN |

`events` count re-read post-write: **27** (17 → 27, +10 exactly).

## 4. FIELD-BY-FIELD VERIFICATION

All 10 re-read post-write and compared field-by-field against §15 of
the pre-apply report: title, description, event_type, dates, times,
instants, timezone, venue, address, city, country, coordinates,
admission_type, admission_note, official_url, ticket_url,
external_host fields, image_url, status, moderation_status,
availability_status. **Every field matches exactly.**

## 5. RELATIONSHIP DELTAS

```
event_restaurants   +7   (21 → 28)
event_hotels         +1   (3 → 4)
event_chefs           0   (0 → 0)
```

Both deltas exactly match the approved plan. **0 catalogue entities
were created.**

## 6. LOCATION / COORDINATES

**No coordinates were guessed or proxied.** 6 of 10 Events carry real,
canonical coordinates pulled directly from their EXACT-matched host
entity (Kaatje bij de Sluis, Olde Marckt, Parkheuvel, 't Ganzenest ×2,
plus Van Oys Maastricht Retreat via its hotel relationship). The
remaining 4 (VanOost BBQ, Chaîne Gala, Roemer, Echoput wine lunch)
correctly carry `latitude`/`longitude = NULL`, exactly as approved —
all four have an external, uncatalogued host with no safe coordinate
source.

## 7. TIME-PRECISION VERIFICATION

Re-confirmed for all 10, field-by-field against §4 of the pre-apply
plan:
- **FULL_TIME** (1): Wine & Dine × Pierre Ache Wijnen — `18:30:00`/
  `22:30:00`, instants `16:30:00Z`/`20:30:00Z`.
- **START_KNOWN_END_UNKNOWN** (5): Chaîne Gala (`17:00:00`, no end —
  the previously-flagged unreliable "22:00" does **not** appear
  anywhere in the stored row), Club Leroy/Parkheuvel (`13:00:00`, no
  end), Roemer (`18:00:00`, no end), Echoput wine lunch (`11:45:00`,
  no end — the explicitly-approximate "rond 16:00" does **not** appear
  anywhere in the stored row), Olde Marckt x Karels (`13:00:00`, no
  end — the 15:00 arrival-window boundary was correctly **not** stored
  as an end_time).
- **DATE_ONLY** (4): VanOost BBQ, Kaatje wine dinner, both 't
  Ganzenest events — all four have `start_time`/`end_time`/`start_at`/
  `end_at` all `NULL`, exactly as approved.

**No fake time was introduced anywhere** — every excluded value stayed
excluded through the actual write.

## 8. HOST SEMANTICS

Re-read every new relationship row directly post-write:

- **Parkheuvel, 't Ganzenest (×2 Events), Olde Marckt, Kaatje bij de
  Sluis, Van Oys Maastricht Retreat**: all `is_host=true,
  is_venue=true` for their own Event — confirmed correct.
- **Triptyque, Basiliek** (VanOost BBQ): both `is_host=false,
  is_venue=false` — confirmed correct. Neither can trigger Step 8B
  Reverse Hosted-Event Discovery from this relationship; their own
  Restaurant Detail pages will show **no** newly hosted Event from
  this batch.
- VanOost, the Chaîne des Rôtisseurs (organizer), SS Antoinette
  (venue), and Restaurant Roemer all correctly have **zero**
  relationship rows — recorded exclusively via `external_host_name`/
  `external_host_url`.

**No participant was promoted into a host anywhere in this batch.**

## 9. DUPLICATE CHECK — POST-APPLY

Across all 27 Events: no duplicate IDs (impossible by PK), no
duplicate title/date pairs, no Event stored under two different title
variants, no accidental duplicate official_url or ticket_url pairing
where inappropriate. Same-day collisions (2026-09-13: Chaîne Gala vs.
Wildfestival vs. Forces of Nature; 2026-09-24: 't Ganzenest Paul Pillot
vs. Six Hands Dinner; 2026-10-18: Echoput wine lunch vs. Game Brunch)
were individually re-confirmed as genuinely distinct real-world Events
— different venue, city, and host in every case — not duplicates.

## 10. EXISTING-DATA INTEGRITY

All 17 pre-existing Events re-read post-write: every name, start_date,
status, and venue_name identical to the pre-write baseline —
byte-for-byte unchanged. `event_confirmed_attendance` re-confirmed
still **0**. `event_attendance`, `visits`, `photos`, `planned_trips`,
and every existing catalogue entity were untouched by this transaction
(the SQL never referenced any of those tables).

## 11. STEP 8A / 8B / 8C SAFETY

**Step 8A**: resulting inventory = 27, comfortably below the
~50-concurrently-displayed batching threshold. No architecture change
required or made.
**Step 8B**: Parkheuvel, 't Ganzenest, Olde Marckt, Kaatje bij de
Sluis, and Van Oys Maastricht Retreat each gained a genuine
`is_host=true` relationship and will correctly surface their new
Event(s). Triptyque and Basiliek gained zero `is_host=true` rows and
will correctly show nothing new.
**Step 8C**: `event_confirmed_attendance` remains 0 — none of the 10
new Events can appear in any Passport until genuinely confirmed. No
attendance fixture was created.

## 12. IMAGERY

Untouched. All 10 new Events: `image_url = NULL`. No image research,
download, or Storage write occurred in this task.

## 13. HOLD CANDIDATES — CONFIRMED UNTOUCHED

Both **Exclusieve Wijnproeverij — Tenuta San Guido / Sassicaia** and
**"Chardonnay & Spätburgunder" Wine & Food Lunch** remain exactly as
classified in the pre-apply report: not inserted, no placeholder row,
no relationship row, classification unchanged, their existing unblock
paths unchanged. Confirmed via direct query (0 matches for either
title) both before and after the transaction.

## 14. VALIDATION

`dart format --set-exit-if-changed .`: clean, 0 changed. `flutter
analyze`: no issues. `flutter test`: **1506 passed, 0 failed** —
baseline unchanged, no Dart code was touched. `supabase migration list
--linked`: 39/39 synced. `supabase db push --linked --dry-run`:
"Remote database is up to date." `git status --short`: no new
untracked files from this apply task itself (this report will appear
once written). `git diff` / `git diff --cached`: both empty.

## DATABASE

Production writes = 10 Event inserts + 8 relationship inserts (this
task's entire purpose). Schema changes = 0. Migrations = 0. RLS
changes = 0. Storage writes = 0.

## GIT

Nothing staged, committed, or pushed. This report and the Batch 2
research/pre-apply artifacts remain untracked pending physical-device
approval, per instruction.

## PHYSICAL-DEVICE CHECKLIST

1. Events list loads with 27 Events total.
2. All 10 new Events appear in correct chronological position among
   the existing 17.
3. DATE_ONLY Events (VanOost BBQ, Kaatje wine dinner, both 't
   Ganzenest events) show no fabricated time.
4. START_KNOWN_END_UNKNOWN Events (Chaîne Gala, Parkheuvel, Roemer,
   Echoput wine lunch, Olde Marckt x Karels) show only their sourced
   start time, no invented end.
5. Wine & Dine × Pierre Ache Wijnen shows its full 18:30–22:30 range.
6. Open several Batch 2 Event Details and confirm venue/location/
   admission render correctly, including the 4 with no map pin
   (VanOost BBQ, Chaîne Gala, Roemer, Echoput wine lunch).
7. Tickets/Official website actions work, including the 3 Events with
   no ticket_url (Kaatje wine dinner, Roemer, Olde Marckt x Karels) —
   confirm the UI handles a missing ticket link gracefully.
8. Canonical Restaurant/Hotel links open correctly from Event Detail
   for the 6 EXACT-matched hosts.
9. Back navigation returns correctly from every new Event.
10. Parkheuvel's, Olde Marckt's, Kaatje bij de Sluis's, Van Oys
    Maastricht Retreat's, and 't Ganzenest's own Detail pages show
    their new hosted Event(s) under Reverse Hosted-Event Discovery.
11. **Triptyque's and Basiliek's own Detail pages must NOT show
    VanOost BBQ as a hosted Event** — the sharpest negative test in
    this batch.
12. Interested/Going remain functional on all 10 new Events.
13. Existing Batch 1 and European Events remain fully unaffected.
14. None of the 10 new Events appears in any test account's Passport
    simply because it now exists.
15. No visual regression in the Event hero/essentials/actions
    hierarchy across old or new Events.

## PHYSICAL DEVICE APPROVAL

Human device verification was carried out against the checklist above
and the batch was confirmed to work correctly. Recorded approval
covers: the Events list rendering with the expanded 27-Event
catalogue; the 10 new Events appearing correctly; DATE_ONLY and
START_KNOWN_END_UNKNOWN precision rendering with no fabricated times
observed; Event Detail remaining correct across venue/location/
admission for both coordinate-bearing and no-coordinate Events;
Tickets/Official Website behavior working, including for Events with
no ticket_url; canonical Restaurant/Hotel navigation working for the 6
EXACT-matched hosts; Reverse Hosted-Event Discovery correctly
respecting genuine hosts; participant-only entities (Triptyque,
Basiliek) correctly not showing hosted Events; Interested/Going
remaining functional; prior Events (Batch 1, European) remaining
unaffected; no visual regressions observed. No claim is made beyond
what this checklist covers and what was actually verified.

## DECISION

Batch 2's approved 10-Event subset is fully applied, field-verified,
relationship-verified, and physical-device approved with zero
discrepancies at any stage.

DUTCH EVENT ENRICHMENT — BATCH 2 APPLIED TO PRODUCTION, DATA AND HOST
SEMANTICS VERIFIED, PHYSICAL-DEVICE APPROVED
