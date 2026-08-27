# DUTCH EVENT ENRICHMENT — BATCH 1 FINAL

Closing summary of the Dutch Event Enrichment Batch 1 workstream, from
research through production apply and physical-device approval.
Supersedes nothing in `DUTCH_EVENT_ENRICHMENT_SPRINT_AUDIT.md`,
`DUTCH_EVENT_BATCH_1_PRE_APPLY.md`, or `DUTCH_EVENT_BATCH_1_PRODUCTION_
APPLY.md` — all three remain the historical record of how this batch
was researched, verified, and applied; this document is the closing
summary once human approval was recorded.

## SCOPE

Dutch Event enrichment Batch 1 — a research-through-production
workstream targeting the Netherlands market for Mantelier Events,
building directly on the now-live date-only architecture and the
already-shipped European Batch 1.

## RESEARCH

27 broad candidates researched nationwide (six parallel regional/
thematic passes) → 18 curated shortlist → 8 deeply, independently
re-verified production-ready Events, recommended and approved for this
batch.

## PRODUCTION APPLY

`events`: 9 → **17**.

## INSERTED EVENTS

| Event | UUID | Date |
|---|---|---|
| Chefs & Sommeliers Party | `60271509-2de7-4c28-ae5f-eadd0a30aeec` | 2026-08-31 |
| VanOost Sundays: 4 Hands Lunch — Sören Herzig | `12dea83b-799c-4908-afc8-92de5cd96d5f` | 2026-09-06 |
| Winemakers Lunch — South Africa | `bb917cbc-434f-4545-be81-99164ac7ec1f` | 2026-09-12 |
| Six Hands Dinner: Drie chefs, drie continenten, één avond | `7d9db50e-b7d5-497d-8399-0a9fbacee9b0` | 2026-09-24 |
| Game Brunch | `2a76f968-d2cb-45dd-964f-1176b4b52cbd` | 2026-10-18 |
| 4 Hands Dinner: Bas van Kranen x Sebastian Frank | `b7e5b3f7-f39b-4dfe-823d-d470d93094cd` | 2026-11-09 |
| Four Hands Dinner: Merlet x Restaurant Joann | `226646cf-6d82-4320-bfc8-e93d9298b334` | 2026-11-22 |
| Dîner Dansant | `de0a1aee-c35c-46e6-8179-ebc83399c027` | 2026-12-24 |

Re-confirmed live at finalization time — all 8 exist exactly once, all
9 pre-existing Events remain byte-for-byte unchanged.

## RELATIONSHIPS

Actual production deltas, matching the approved pre-apply plan
exactly:

```
events                +8   (9 → 17)
event_restaurants    +10   (11 → 21)
event_hotels           +2   (1 → 3)
event_chefs             0   (0 → 0)
```

Host semantics (re-confirmed at finalization, no writes):

- **Flore, Inter Scaldes, Merlet (both its Events), Van Oys Maastricht
  Retreat (both its Events), Bij Jef (its own Event)**: `is_host=true,
  is_venue=true`.
- **Zarzo, Parkheuvel, Zilte, Joann, Bij Jef (on Chefs & Sommeliers
  Party only)**: `is_host=false, is_venue=false` — participant-only.

## TIME PRECISION

Re-confirmed: no unknown time was ever fabricated. Flore x Sebastian
Frank, VanOost x Herzig, Winemakers Lunch, and Six Hands Dinner are all
genuine DATE_ONLY (start/end time, start/end instant all NULL). Merlet
x Joann is genuine START_KNOWN_END_UNKNOWN (12:30 start, no end).
Game Brunch, Chefs & Sommeliers Party, and Dîner Dansant are genuine
FULL_TIME with real, sourced instants — including two legitimate
`00:00` end times (Chefs & Sommeliers Party crossing into Sept 1,
Dîner Dansant crossing into Dec 25), which are sourced facts, not
invented placeholders.

## EXTERNAL HOST

VanOost remains correctly external-only: zero relationship rows,
`external_host_name = 'VanOost'`, `external_host_url` set,
`latitude`/`longitude` both NULL. No Restaurant catalogue entity was
created for it, no proxy coordinates were introduced.

## DÎNER DANSANT

Final stored state, re-confirmed at finalization: `official_url` =
`https://www.vanoys.com/event-calendar/diner-dansant/`, `ticket_url` =
the same URL (not the broken SevenRooms deep link the venue's own site
still misroutes to), `availability_status` = `unknown`. This decision
was made once, during the production apply, and is not being revisited
here — it remains a candidate for future content maintenance once
Van Oys fixes their own booking CTA.

## STEP 8A

Total inventory after this batch: 17. Remains well below the
~50-concurrently-displayed threshold identified for batching the
popularity RPC. No batching implemented, none needed.

## STEP 8B

Reverse hosted-Event discovery remains semantically correct: every
genuine host (Flore, Inter Scaldes, Merlet, Van Oys Maastricht
Retreat, Bij Jef) will surface its new Event(s) on its own Detail
page; every participant-only entity (Zarzo, Parkheuvel, Zilte, Joann,
and Bij Jef specifically on Chefs & Sommeliers Party) will not. No
code was changed.

## STEP 8C

Passport eligibility remains based exclusively on genuine
`event_confirmed_attendance` — confirmed still 0 for this batch. None
of the 8 new Events can appear in any user's Passport until a real
confirmed attendance occurs.

## PHYSICAL DEVICE

Human-approved. See "FINAL PHYSICAL DEVICE APPROVAL" in
`DUTCH_EVENT_BATCH_1_PRODUCTION_APPLY.md` for the full checklist and
the exact confirmation ("Het klopt allemaal!").

## DATABASE

migrations created = 0. migrations deployed = 0. schema changes = 0.
RLS changes = 0. production writes during finalization = 0 (the 8
Event/12 relationship writes happened in the prior apply step, not in
this finalization task). 39/39 migrations synced; "Remote database is
up to date."

## VALIDATION

`dart format --set-exit-if-changed .`: clean. `flutter analyze`: no
issues. `flutter test`: **1506 passed, 0 failed** — matches the
established baseline exactly, re-confirmed at finalization. `supabase
migration list --linked`: 39/39 synced. `supabase db push --linked
--dry-run`: "Remote database is up to date."

## FILES

New: `docs/Architecture/Events/DUTCH_EVENT_ENRICHMENT_SPRINT_AUDIT.md`,
`docs/Architecture/Events/DUTCH_EVENT_BATCH_1_PRE_APPLY.md`,
`docs/Architecture/Events/DUTCH_EVENT_BATCH_1_PRODUCTION_APPLY.md`,
`docs/Architecture/Events/DUTCH_EVENT_BATCH_1_FINAL.md` (this file),
`supabase/data/enrichment/events/dutch_event_candidates_2026_2027.json`.
No Dart/Flutter files were created or modified anywhere in this
workstream.

## UNRELATED EXCLUSIONS

Confirmed left untracked, untouched, unstaged — verified individually,
not by directory-level assumption:
`docs/Architecture/EVENTS_CONTENT_ENRICHMENT_4_EVENTS_PRE_APPLY.md`,
`docs/Architecture/Events/EUROPEAN_EVENT_BATCH_1_PRE_APPLY.md`,
`docs/Architecture/Events/EUROPEAN_EVENT_BATCH_1_PRODUCTION_APPLY.md`,
`docs/Architecture/Events/EUROPEAN_EVENT_BATCH_1_REVALIDATION_PRE_APPLY.md`,
`docs/Architecture/Events/EUROPEAN_EVENT_ENRICHMENT_SPRINT_AUDIT.md`,
`docs/Architecture/Events/EUROPEAN_EVENT_FIRST_DATE_ONLY_PILOT_PRE_APPLY.md`,
`docs/Architecture/Michelin_Database/GAULT_MILLAU_UNBLOCK_DEPLOYMENT_REPORT.md`,
`supabase/data/enrichment/MICHELIN_EXPANSION_REVIEW_CHECKPOINT.md`,
`supabase/data/enrichment/MICHELIN_PARTIAL_EXPANSION_CONTROL_REPORT.md`,
`supabase/data/enrichment/MICHELIN_PARTIAL_EXPANSION_IMPORT_PLAN.md`,
`supabase/data/enrichment/event_participants/mvp_2026/` (Dolomiti
Gourmet Festival, Andorra Taste, San Sebastián Gastronomika — European
work, individually inspected and confirmed unrelated to Dutch Batch
1), `supabase/data/enrichment/events/european_event_batch_1_pre_apply.json`,
`supabase/data/enrichment/events/european_event_candidates_2026_2027.csv`,
`supabase/data/enrichment/gault_millau/PRODUCTION_IMPORT_FINAL_REPORT.md`,
and the `michelin_belgium_expansion/`, `michelin_bulk_location_
enrichment/`, `michelin_catalogue_reconciliation/`,
`michelin_france_manual_source/`, `michelin_history_netherlands/`, and
`michelin_location_spike/` directories under `supabase/data/
enrichment/`.

## GIT

Commit hash, message, and push result recorded in the chat final
report accompanying this document's publication (this file is written
before staging, so the exact hash isn't yet known at write time).

## NEXT

NEXT WORKSTREAM:
EVENT HERO IMAGERY PILOT

Research hero imagery for all 17 live Events, establish provenance/
rights status for each, and select 1–3 responsible candidates for a
controlled photography test. Not started here.

DUTCH EVENT ENRICHMENT — BATCH 1 FINALIZED, PHYSICAL DEVICE APPROVED,
PRODUCTION CATALOGUE VERIFIED, COMMITTED AND PUSHED
