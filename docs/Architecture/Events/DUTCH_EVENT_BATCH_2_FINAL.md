# DUTCH EVENT ENRICHMENT — BATCH 2 FINAL REPORT

Closing summary of Dutch Event Enrichment Batch 2, from deep
verification through production apply and physical-device approval.
Supersedes nothing in `DUTCH_EVENT_BATCH_2_PRE_APPLY.md` or
`DUTCH_EVENT_BATCH_2_PRODUCTION_APPLY.md` — both remain the historical
record of how this batch was verified and applied; this document is
the closing summary once human approval was recorded.

## PHYSICAL DEVICE APPROVAL

Human-approved. The device pass confirmed the batch works correctly:
Events list renders with the expanded 27-Event catalogue; the 10 new
Events appear correctly with truthful date/time precision and no
fabricated times; Event Detail, venue/location/admission, and
Tickets/Official Website behavior all render correctly; canonical
Restaurant/Hotel navigation works; Reverse Hosted-Event Discovery
correctly respects genuine hosts and correctly excludes
participant-only entities; Interested/Going remain functional; prior
Events are unaffected; no visual regressions observed.

## FINAL PRODUCTION STATE

Re-confirmed live at finalization, read-only: `events` = **27**. All
10 Batch 2 Events exist exactly once. All 17 pre-existing Events
(Batch 1 + European) remain present, unchanged. Both HOLD candidates
confirmed absent (0 matches for either title).

## 10 INSERTED EVENTS

| Event | UUID | Date |
|---|---|---|
| VanOost Sundays: BBQ with Friends | `9becd8ba-ff8d-4fa5-a685-99200df42706` | 2026-08-30 |
| Friends & Family Zomer BBQ met Marko Karelse | `8b27df6d-9f95-4427-8f39-e3d20353f775` | 2026-08-30 |
| Chaîne des Rôtisseurs Gala Dîner op SS Antoinette | `1fe81ee4-27ae-46d6-b169-13cca93b86af` | 2026-09-13 |
| Wine & Dine × Pierre Ache Wijnen | `ad0c9f02-e795-4646-a14a-a4625d6a0186` | 2026-09-15 |
| Wijnmakersdiner Montanha Vermelha | `b9f44b6d-ae0c-4b90-870e-089d82cb4fc2` | 2026-09-18 |
| Club Leroy bij Parkheuvel | `9dbee4f6-ad2a-4477-a4e4-5a185cb7b606` | 2026-09-20 |
| Exclusieve Wijnproeverij — Domaine Paul Pillot | `7ad5ed0c-eee6-4be5-b99b-2eef6a443d21` | 2026-09-24 |
| Jubileumdiner — 5 jaar Restaurant Roemer | `b735ec10-84df-44d4-9cbd-6e4e9b540ac4` | 2026-10-08 |
| Wijnmakerslunch Heidi Schröck & Söhne | `4fa6a92a-9009-4852-9509-83597d88b437` | 2026-10-18 |
| Four-Hands Diner: Olde Marckt x Karels | `b7723a62-aad2-480e-90c7-5d983a24fb85` | 2026-11-01 |

## RELATIONSHIP DELTAS

```
events               +10   (17 → 27)
event_restaurants     +7   (21 → 28)
event_hotels           +1   (3 → 4)
event_chefs             0   (0 → 0)
```

Re-confirmed live at finalization — exactly matching the approved
apply.

## HOST SEMANTICS

Re-verified directly, no writes: Parkheuvel, 't Ganzenest (×2 Events),
Olde Marckt, Kaatje bij de Sluis, and Van Oys Maastricht Retreat all
`is_host=true, is_venue=true` for their own Event.

## PARTICIPANT-ONLY SAFETY

Triptyque and Basiliek (VanOost BBQ) both re-confirmed
`is_host=false, is_venue=false`. Neither can trigger Step 8B Reverse
Hosted-Event Discovery — their own Restaurant Detail pages show no
newly hosted Event from this batch.

## TIME PRECISION

No fake time exists anywhere in the 10 new rows, re-confirmed at
finalization:
- **Van Oys Wine & Dine × Pierre Ache**: genuine FULL_TIME, sourced
  18:30–22:30.
- **Chaîne des Rôtisseurs Gala**: the previously-flagged unreliable
  "22:00" end time remains absent — confirmed `end_time IS NULL`.
- **Wijnmakerslunch Heidi Schröck / De Echoput**: the explicitly
  approximate "rond 16:00" remains absent — confirmed `end_time IS
  NULL`.
- **Four-Hands: Olde Marckt x Karels**: the 15:00 arrival-window
  boundary was not misrepresented as an Event end time — confirmed
  `end_time IS NULL`.
- Remaining 6 Events: precision shapes (4 DATE_ONLY, 2 additional
  START_KNOWN_END_UNKNOWN) all match the approved plan exactly.

## LOCATION / COORDINATES

6 of 10 Events (Parkheuvel, 't Ganzenest ×2, Olde Marckt, Kaatje bij de
Sluis, Van Oys Wine & Dine) carry real, verified canonical coordinates.
4 of 10 (VanOost BBQ, Chaîne Gala, Roemer, Echoput wine lunch)
correctly remain `latitude`/`longitude = NULL` — all four legitimate
production Events with an external, uncatalogued host. No city-centre
or proxy coordinate was ever introduced.

## HOLD EVENTS

Both remain outside production, unchanged, with their unblock paths
intact:
- **Exclusieve Wijnproeverij — Tenuta San Guido / Sassicaia** (Ganzenest)
  — no bookable slot currently exists in the venue's reservation
  system; re-check within 4–6 weeks of 2026-11-19.
- **"Chardonnay & Spätburgunder" Wine & Food Lunch** (Karel 5) — only
  a single non-primary source confirms this event; contact Karel V
  directly (info@karelv.nl) before reconsidering.

## DUPLICATE INTEGRITY

No duplicate IDs, no duplicate title/date pairs, no Event stored under
two title variants across all 27 Events. Same-day coincidences
(2026-09-13, 2026-09-24, 2026-10-18) individually re-confirmed as
genuinely distinct real-world Events at different venues/cities/hosts.

## STEP 8A

27 total Events, comfortably below the ~50-concurrently-displayed
batching threshold. No architecture change required or made.

## STEP 8B

Reverse Hosted-Event Discovery remains semantically correct — 5
genuine hosts correctly surface their new Event(s); 2 participant-only
entities correctly surface nothing new. No code was changed.

## STEP 8C

Passport eligibility remains exclusively `event_confirmed_attendance`,
re-confirmed still 0 for this batch. None of the 10 new Events can
appear in any Passport until a genuine confirmed attendance occurs.

## DATABASE

migrations created = 0. migrations deployed = 0. schema changes = 0.
RLS changes = 0. production writes during finalization = 0 (the 10
Event/8 relationship writes happened in the prior apply step, not in
this finalization task). 39/39 migrations synced; "Remote database is
up to date."

## VALIDATION

`dart format --set-exit-if-changed .`: clean. `flutter analyze`: no
issues. `flutter test`: **1506 passed, 0 failed** — matches the
established baseline exactly, re-confirmed at finalization.

## FILES

New: `docs/Architecture/Events/DUTCH_EVENT_BATCH_2_PRE_APPLY.md`,
`DUTCH_EVENT_BATCH_2_PRODUCTION_APPLY.md`, `DUTCH_EVENT_BATCH_2_FINAL.md`
(this file), `supabase/data/enrichment/events/dutch_event_batch_2_pre_apply.json`.
No Dart/Flutter files were created or modified anywhere in this
workstream.

## UNRELATED EXCLUSIONS

Confirmed left untracked, untouched, unstaged — verified individually:
`docs/Architecture/EVENTS_CONTENT_ENRICHMENT_4_EVENTS_PRE_APPLY.md`,
all European Event enrichment docs (`EUROPEAN_EVENT_BATCH_1_PRE_APPLY.md`,
`EUROPEAN_EVENT_BATCH_1_PRODUCTION_APPLY.md`,
`EUROPEAN_EVENT_BATCH_1_REVALIDATION_PRE_APPLY.md`,
`EUROPEAN_EVENT_ENRICHMENT_SPRINT_AUDIT.md`,
`EUROPEAN_EVENT_FIRST_DATE_ONLY_PILOT_PRE_APPLY.md`),
`EVENT_HERO_IMAGERY_PILOT_RESEARCH.md` (Event Hero Imagery remains a
separate parked workstream — no image research, upload, or provenance
schema work occurred here), `GAULT_MILLAU_UNBLOCK_DEPLOYMENT_REPORT.md`,
the three `MICHELIN_*` reports, `event_participants/mvp_2026/`,
`european_event_batch_1_pre_apply.json`,
`european_event_candidates_2026_2027.csv`,
`gault_millau/PRODUCTION_IMPORT_FINAL_REPORT.md`, and the
`michelin_belgium_expansion/`, `michelin_bulk_location_enrichment/`,
`michelin_catalogue_reconciliation/`, `michelin_france_manual_source/`,
`michelin_history_netherlands/`, and `michelin_location_spike/`
directories.

## GIT

Commit hash, message, and push result recorded in the chat final
report accompanying this document's publication (this file is written
before staging, so the exact hash isn't yet known at write time).

## NEXT

NEXT WORKSTREAM:
EVENTS UI REDESIGN + DISCOVERY FILTERS + EVENT TAXONOMY

Agreed product requirements for that future workstream (documentation
only — not started here):

**Social filters**: All / Friends Going / Friends Interested / From
hosts you follow (Following).

**Event type** (the Event's form): Dinner, Lunch, Festival, Gala,
Tasting, Brunch, Party.

**Event tags/themes** (the Event's content): Wine, Winemaker,
Champagne, Wild/Game, Four Hands, Guest Chef, Charity, Seasonal.

Type and tags are explicitly separate concepts — e.g. Winemakers Lunch
→ type=Lunch, tags=[Wine, Winemaker]; Four Hands Dinner → type=Dinner,
tags=[Four Hands, Guest Chef]. The eventual taxonomy should be derived
from the real 27-Event production catalogue now live, not invented
abstractly. No schema or tags were created in this task.

Event Hero Imagery remains a separate, still-parked future workstream.

DUTCH EVENT ENRICHMENT — BATCH 2 FINALIZED, PHYSICAL DEVICE APPROVED,
PRODUCTION CATALOGUE VERIFIED, COMMITTED AND PUSHED
