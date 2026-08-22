# EVENTS DISCOVERY TAXONOMY — PHASE A FINAL REPORT

Closing summary of Phase A, from architecture audit through production
apply and physical-device approval. Supersedes nothing in
`EVENTS_UI_DISCOVERY_TAXONOMY_AUDIT.md`,
`EVENTS_DISCOVERY_TAXONOMY_PHASE_A_PRE_APPLY.md`, or
`EVENTS_DISCOVERY_TAXONOMY_PHASE_A_PRODUCTION_APPLY.md` — all three
remain the historical record; this document is the closing summary
once human approval was recorded.

## PHYSICAL DEVICE APPROVAL

Human-approved. Recorded regression, matching exactly what was
reported as tested: Events list loads correctly; existing Event
ordering remains correct; Dinner, Lunch, Gala, Brunch, and Party
Events all render correctly; Tasting/Festival Events remain correct;
date-only/full-time formatting remains correct; Interested/Going
remains functional; Event navigation works; reverse hosted discovery
still works; Passport unchanged; no visual regression observed. No
claim beyond this recorded scope is made.

## FINAL PRODUCTION STATE

Re-confirmed live at finalization, read-only: `events` = **27**,
`event_tags` = **6**, `event_tag_assignments` = **34**. Zero duplicate
`(event_id, tag_id)` pairs, zero duplicate tag `slug`s. 40/40
migrations synced; "Remote database is up to date."

## EVENT TYPE TAXONOMY

10 values allowed by `events_event_type_check`, re-confirmed directly
from `pg_constraint`: `festival, dinner, tasting, market, experience,
other, lunch, gala, brunch, party`. All 7 V1 types (dinner, lunch,
festival, gala, tasting, brunch, party) and all 3 legacy compatibility
values (experience, market, other) remain supported — no destructive
removal occurred.

## TAG TAXONOMY

6 tags live in `event_tags`: `wine`, `winemaker`, `wild_game`,
`guest_chef`, `four_hands`, `charity` — each with a unique `slug`.

## TYPE DISTRIBUTION

Re-confirmed live: Dinner 16, Lunch 3, Festival 2, Gala 2, Tasting 1,
Brunch 1, Party 2 = 27. Matches the approved distribution exactly.

## TAG DISTRIBUTION

Re-confirmed live: Wine 5, Winemaker 4, Wild/Game 3, Guest Chef 15,
Four Hands 6, Charity 1 = 34. Matches the approved distribution
exactly.

## AMBIGUOUS CASE DECISIONS

Re-confirmed live, all four remain **Dinner**: Club Leroy bij
Parkheuvel, Erloom x Henrique Sá Pessoa, Four Hands Dinner: Merlet x
Restaurant Joann, Dîner Dansant — matching the reasoning recorded in
the pre-apply document exactly.

## SCHEMA

`event_tags`: `id uuid PK`, `slug text UNIQUE NOT NULL`, `name text
NOT NULL`, `created_at timestamptz NOT NULL`. `event_tag_assignments`:
`id uuid PK`, `event_id uuid` (FK → `events`, `ON DELETE CASCADE`),
`tag_id uuid` (FK → `event_tags`, `ON DELETE CASCADE`), composite
`UNIQUE(event_id, tag_id)`. Indexes: PK on each table, the composite
unique index, plus separate B-tree indexes on `event_id` and `tag_id`
individually — all re-confirmed directly via `pg_indexes`.

## RLS

Both new tables: exactly one policy each, `FOR SELECT USING (true)` —
`event_tags_public_read`, `event_tag_assignments_public_read` — no
write policy on either (writes are service-role-only, matching every
comparable reference/join table in this schema). Re-confirmed directly
via `pg_policy`, unchanged from the approved design.

## DART COMPATIBILITY

Re-inspected the actual diff in `lib/models/event.dart`: exactly the
`EventType` enum's 4 new values (`lunch`, `gala`, `brunch`, `party`)
and the corresponding 4 new `label` switch arms. No filter state, no
query plumbing, no search changes, no Step 8A changes, no Event Detail
or EventCard tag rendering — confirmed compatibility-only, exactly as
scoped.

## 27-EVENT BACKFILL

All 10 approved `event_type` updates and all 34 approved tag
assignments applied in one atomic transaction, confirmed matching the
pre-apply plan exactly — no partial application, no deviation, no
row left unaccounted for.

## DATA INTEGRITY

`events` row count unchanged at 27 throughout (only the `event_type`
column was updated on 10 existing rows — no row was added, removed, or
had any other column touched). Zero duplicate tag assignments, zero
duplicate tag slugs.

## STEP 8A REGRESSION

No regression — `event_discovery_ranking.dart`/
`event_discovery_service.dart` were not touched anywhere in Phase A;
physical-device approval confirmed ranking/ordering remains correct.

## STEP 8B REGRESSION

No regression — `_loadHostedEvents`/`HostedEventsSection` were not
touched; physical-device approval confirmed reverse hosted discovery
still works.

## STEP 8C REGRESSION

No regression — `loadPassportEventAttendance` was not touched;
physical-device approval confirmed Passport unchanged.

## DATABASE

migrations created = 0 (during finalization; 1 was created and
deployed in the prior apply phase). migrations deployed = 0 (during
finalization). schema changes = 0 (during finalization). RLS changes =
0 (during finalization). production writes = 0 (during finalization —
all writes happened in the prior, already-approved apply step). 40/40
migrations synced; remote up to date.

## VALIDATION

`dart format --set-exit-if-changed .`: clean. `flutter analyze`: no
issues. `flutter test`: **1506 passed, 0 failed** — matches the
established baseline exactly, re-confirmed at finalization.

## FILES

New: `supabase/migrations/20260823120000_events_v2_discovery_taxonomy_phase_a.sql`,
`supabase/data/enrichment/events/events_discovery_taxonomy_phase_a_backfill_preview.json`,
`docs/Architecture/Events/EVENTS_UI_DISCOVERY_TAXONOMY_AUDIT.md`,
`docs/Architecture/Events/EVENTS_DISCOVERY_TAXONOMY_PHASE_A_PRE_APPLY.md`,
`docs/Architecture/Events/EVENTS_DISCOVERY_TAXONOMY_PHASE_A_PRODUCTION_APPLY.md`,
`docs/Architecture/Events/EVENTS_DISCOVERY_TAXONOMY_PHASE_A_FINAL.md` (this
file). Modified: `lib/models/event.dart` (compatibility-only, per
above).

## UNRELATED EXCLUSIONS

Confirmed left untracked, untouched, unstaged — verified individually:
`docs/Architecture/EVENTS_CONTENT_ENRICHMENT_4_EVENTS_PRE_APPLY.md`,
all European Event enrichment docs/data, `EVENT_HERO_IMAGERY_PILOT_RESEARCH.md`
and its data artifact (Event Hero Imagery remains a separate parked
workstream), Michelin/Gault&Millau enrichment artifacts,
`event_participants/mvp_2026/`, and the `michelin_*` enrichment
directories.

## GIT

Commit hash, message, and push result recorded in the chat final
report accompanying this document's publication (this file is written
before staging, so the exact hash isn't yet known at write time).

## NEXT

**Phase A is complete. Phase B has NOT started.**

NEXT WORKSTREAM:
EVENTS DISCOVERY TAXONOMY — PHASE B, DISCOVERY / FILTER PLUMBING

Build the non-visual discovery/filter domain and repository layer
before any UI redesign. Phase B should support combinations such as
Friends Going + Wine, Friends Interested + Dinner, Following + Four
Hands, Netherlands + Wine, Lunch + date window, and Following + Guest
Chef + Netherlands. Core principle, carried forward from the original
audit: **filter first, then existing Step 8A ranking** — no ranking
logic duplicated. Not started here.

Kept explicitly separate, not touched or advanced in Phase A: Event
Hero Imagery Pilot, Passport Historical Integrity, Dutch Event Batch
3, further European Event enrichment.

EVENTS DISCOVERY TAXONOMY — PHASE A FINALIZED, PHYSICAL DEVICE
APPROVED, PRODUCTION TAXONOMY VERIFIED, COMMITTED AND PUSHED
