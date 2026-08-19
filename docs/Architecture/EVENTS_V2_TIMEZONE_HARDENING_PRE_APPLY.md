# Events V2 — Timezone Hardening Pre-Apply Report

**Status: prepared, implemented locally, validated locally, NOT deployed to production and NOT committed.** This document records the exact root cause, the exact migration files, the exact Dart implementation, and the exact validation performed before requesting human approval to deploy the schema change and backfill production data. See `EVENTS_V2_TIME_LOCATION_AUDIT.md` (the read-only audit this task re-confirmed and built on) and `EVENTS_V2_ARCHITECTURE.md` §36 (the now-formalized canonical model) for supporting detail this document doesn't repeat.

## Root cause

`Event.fromJson` (`lib/models/event.dart`, pre-change lines 146-147) called `.toLocal()` on `start_at`/`end_at` after parsing — silently converting every event's displayed time into the **viewer's device timezone** instead of the **event's own location**. A Tokyo event at 19:00 JST would show 19:00 only to a viewer whose device happened to be set to `Asia/Tokyo`; every other viewer saw a different, wrong hour (and potentially the wrong calendar date). One root cause, not several scattered bugs — every rendering surface inherited it because all six read `Event.startAt`/`endAt` through the same shared formatters. Chronological logic (`canAttendEvent`, sorting) was never affected: `isAfter`/`isBefore`/`compareTo` compare the underlying instant regardless of zone-tagging — only *display* was broken.

Re-confirmed at the start of this task, directly against current code (not from memory) — no drift from the prior audit's findings. Two additional rendering surfaces were found this pass that the prior audit's grep missed: `explore_discovery_cards.dart` and `friend_going_tile.dart` — both use `formatEventDateRange(event)`, which already took the whole `Event` and needed no call-site change once the formatter itself became timezone-aware internally.

## Database

**Migration 1 — `supabase/migrations/20260820120000_events_v2_timezone_hardening.sql`** (nullable column + validation, safe to deploy standalone, zero data risk):

- `events.timezone text` — nullable, IANA identifier only, documented via column comment.
- `validate_event_timezone()` trigger function + `events_validate_timezone` BEFORE INSERT/UPDATE trigger — validates using Postgres's own bundled tzdata (`perform now() at time zone new.timezone`, catching the real `invalid_parameter_value` exception), not a regex or hand-maintained allowlist. Empirically confirmed against local Docker Postgres: an invalid identifier (`Not/AZone`) raises SQLSTATE `22023`, exactly the exception this trigger catches and re-raises with a clear message.

**Migration 2 — `supabase/migrations/20260820130000_events_v2_timezone_not_null.sql`** (tightens to `NOT NULL`, deliberately a separate file):

- A single `alter table public.events alter column timezone set not null;`.
- Kept separate from Migration 1 specifically so the backfill UPDATE (below) is its own independently-reviewed action sitting between the two schema changes — the same "schema first, verified; data write second, independently verified" shape already established in this project (the Parkheuvel phone rollout). **Migration 2 is intentionally not part of this report's own approval ask (A/B below)** — it's requested separately, only after the backfill is confirmed complete with zero remaining NULLs.

**Local validation, full pipeline proven end-to-end** against local Docker Postgres (`supabase migration up --local`):
1. Migration 1 applied cleanly.
2. Migration 2 attempted immediately after (before backfill) — **correctly failed**: `ERROR: column "timezone" of relation "events" contains null values (SQLSTATE 23502)`. This is the intended, designed safety behavior — NOT NULL cannot silently succeed over an incomplete backfill.
3. Trigger reject path tested manually: `Not/AZone` → rejected with the custom error message.
4. Trigger accept path tested manually: `Europe/Amsterdam` → accepted.
5. Local test row backfilled manually; Migration 2 re-run — succeeded. `\d events` confirmed the column now shows `not null`.

No migration has been applied to the linked/production database. Confirmed immediately before writing this report: `select timezone from public.events` against production returns `ERROR: 42703: column "timezone" does not exist` — production schema is exactly as expected, no drift.

## Existing event backfill

All 4 production events re-queried directly against the linked production database immediately before writing this report (read-only), confirming zero drift from the prior audit's data:

| id | name | start_at (UTC) | end_at (UTC) | country_code | city |
|---|---|---|---|---|---|
| `75d341a4-41d9-4e76-b47c-936048ae54a4` | 't Preuvenemint | 2026-08-27T16:00:00Z | 2026-08-30T22:00:00Z | NL | Maastricht |
| `eaad5729-e88c-47fa-b842-0343f6f794a2` | Wildfestival | 2026-09-13T11:00:00Z | 2026-09-13T15:00:00Z | NL | Apeldoorn |
| `d09498ce-df42-4885-98d9-ec26fae5945c` | Erloom x Henrique Sá Pessoa | 2026-09-25T10:00:00Z | 2026-09-27T21:00:00Z | NL | Hilvarenbeek |
| `fd23d7f5-ff7c-4caf-ba9b-a17e6397a607` | Vergeet Mij Niet Gala | 2026-10-06T16:00:00Z | 2026-10-06T21:59:00Z | NL | Amsterdam |

All 4 classified **`SAFE_LOCATION_DERIVATION` → `Europe/Amsterdam`** (per the prior audit, re-confirmed here, not re-derived from scratch): the Netherlands has exactly one IANA zone nationwide (no internal variation), so `country_code='NL'` alone gives high-confidence derivation, independently corroborated by back-calculating that every stored UTC value is internally consistent with correct CEST (`+02`) conversion for its actual date (all 4 fall within Aug–Oct 2026, entirely inside DST season). None reach `VERIFIED_TIMEZONE` since that tier requires re-confirming against each event's original source, which this task did not re-fetch. **No event required `MANUAL_REVIEW` or was left `UNKNOWN`** — all 4 are safe to backfill.

**Proposed backfill SQL (drafted, NOT executed)**:

```sql
begin;

update public.events set timezone = 'Europe/Amsterdam'
  where id = '75d341a4-41d9-4e76-b47c-936048ae54a4'; -- 't Preuvenemint
update public.events set timezone = 'Europe/Amsterdam'
  where id = 'eaad5729-e88c-47fa-b842-0343f6f794a2'; -- Wildfestival
update public.events set timezone = 'Europe/Amsterdam'
  where id = 'd09498ce-df42-4885-98d9-ec26fae5945c'; -- Erloom x Henrique Sá Pessoa
update public.events set timezone = 'Europe/Amsterdam'
  where id = 'fd23d7f5-ff7c-4caf-ba9b-a17e6397a607'; -- Vergeet Mij Niet Gala

commit;
```

Scoped to the 4 explicit IDs above, not a broad `WHERE timezone IS NULL`, so the statement's blast radius is exact and auditable regardless of what else might be inserted between now and execution.

## Dart

- **`lib/models/event.dart`**: added `timezone` (nullable `String?`, since pre-migration/pre-backfill rows have none). `Event.fromJson` no longer calls `.toLocal()` on `start_at`/`end_at` — both stay UTC-tagged absolute instants, exactly as Postgres sent them. `createdAt` still calls `.toLocal()`, deliberately unchanged — confirmed via grep it is never displayed anywhere in the UI; it's record metadata, not an Event-time concept.
- **`lib/core/utils/event_time.dart`** (new): `eventLocalDateTime(DateTime instant, String? timezone)` — the one place in the app that performs Event-local timezone conversion, built on `package:timezone`'s `TZDateTime.from`. Falls back to UTC (never the device's own zone) when `timezone` is null, empty, or unrecognized. Lives in `core/utils`, not `features/events`, specifically so the dependency-free models-layer file `event_trip_match.dart` can use it without inverting the models → features layering.
- **`lib/features/events/event_date_format.dart`**: `formatEventDateRange(Event)` and `formatEventDateTime(DateTime instant, String? timezone)` (signature changed — now takes the timezone explicitly) both route through `eventLocalDateTime`. Every existing call site already passed the whole `Event` to `formatEventDateRange`, so only `EventMetaSection`'s two `formatEventDateTime` calls needed updating.

## Timezone package decision

**`package:timezone` v0.11.1**, verified via pub.dev before adding: published by `labs.dart.dev` (verified publisher), actively maintained, full iOS/Android/Web/desktop support, ~2.94M downloads, depends only on `http`+`path`. Provides real IANA tzdata + `TZDateTime`. Added to `pubspec.yaml` with a justifying comment; `flutter pub get` run successfully.

**A genuine finding from this pass, not assumed**: the package ships three database-size variants (default, `_all`, `_10y`). The default variant was the initial choice (smaller, "covers every currently-inhabited zone" per the package's own pitch) — but direct empirical testing found **`Europe/Amsterdam` does not resolve under the default variant** (`Location with the name "Europe/Amsterdam" doesn't exist`). It's a backward-compatibility *link* in IANA's own tzdata (aliased to `Europe/Brussels`, identical civil-time rules since WWII), which the default variant's "no deprecated/historical zones" trim excludes. That is the exact zone every one of this app's 4 real events needs. Had this shipped with the default variant, every event would have silently rendered in UTC instead of Amsterdam time — no crash (the fallback exists precisely to avoid crashing on an unrecognized identifier), just silently wrong, which is worse. **Switched to the `_all` variant** (`lib/main.dart`'s `initializeTimeZones()` now imports `package:timezone/data/latest_all.dart`) — confirmed by a follow-up empirical test that `Europe/Amsterdam` resolves correctly under `_all`. The ~80kb size difference is a trivial cost next to that failure mode.

## UI

All Event rendering surfaces route through the two updated formatters, so no per-widget timezone logic was needed — the fix is centralized:

- `event_meta_section.dart` (Event Detail's date/time row) — both `formatEventDateTime` calls updated to pass `event.timezone`.
- `event_card.dart`, `explore_event_result_tile.dart`, `explore_discovery_cards.dart`, `friend_going_tile.dart` — all already call `formatEventDateRange(event)`, unaffected at the call site since the formatter's internal behavior changed, not its signature.

## Trips

`eventMatchesTrip` (`lib/models/event_trip_match.dart`) previously truncated `event.startAt`/`endAt` to calendar date directly — correct only when those fields happened to be tagged in a zone that matched the intended comparison, which `.toLocal()` never reliably was. Now truncates `eventLocalDateTime(event.startAt, event.timezone)`/`eventLocalDateTime(event.endAt, event.timezone)` instead — comparing against the **event's own local calendar date**, never the device's. Doc comment updated to explain why. Two new regression tests prove the fix in both directions (a zone ahead of UTC shifting the local date forward; a zone behind UTC shifting it backward) — see Validation below.

## Sorting / completion

`canAttendEvent` (`event_detail_screen.dart`) and every event-sorting comparator (`event_trip_match.dart`, `discovery_selectors.dart`) are unchanged — confirmed and documented (doc comment added to `canAttendEvent`) that `.isAfter`/`.isBefore`/`.compareTo` compare the underlying instant regardless of zone-tagging, so removing `.toLocal()` from parsing required zero change to any of them. The same reasoning is recorded as the rule the future "Did you make it?" Attendance trigger must follow: key off `event.endAt`'s absolute instant, never a rendered local date/time.

## Location

No schema change (none was needed — re-confirmed). `EVENTS_V2_ARCHITECTURE.md` §36 formalizes the existing, already-correct behavior as an explicit rule: every Event snapshots its own `venue_name`/`address`/`city`/`country_code`/`latitude`/`longitude` at authoring/import time; a linked host/venue's own canonical record is relational and contextual only, never the resolved source of an Event's location at read time. Remaining location data gaps (missing addresses/coordinates for 3 of the 4 events, no canonical venue link for Hotel Okura) are pre-existing, out of this task's scope per its own instruction, and are the same gaps the prior audit already flagged as future work.

## Web readiness

Unchanged from the prior audit's recommendation, now implemented: the canonical representation is `start_at` (absolute ISO instant) + `timezone` (IANA identifier); every consumer — Flutter today, a future Flutter Web build, a future public website, a future API partner — derives event-local display identically from that pair, never from an ambient/device zone. No web build was implemented in this task.

## Database safety

- Every `MODIFY`/`ADD` above is additive — no existing column, row, or value is altered by Migration 1. `start_at`/`end_at` are untouched.
- Migration 2 (`NOT NULL`) cannot succeed while any row is unbackfilled — proven, not assumed (see Database section above).
- The proposed backfill UPDATE only ever sets `timezone`, scoped to 4 explicit IDs — no other column, no other row.
- RLS: unaffected — `events_public_read` gates on `moderation_status`, unrelated to `timezone`; no new policy needed.
- No attendance, intent, follow, or relationship row is touched by anything in this report.

## Validation

- `dart format --set-exit-if-changed .` — clean (2 files reformatted during development, then re-verified clean).
- `flutter analyze` — **No issues found!**
- `flutter test` — **1128 passed, 0 failed** (baseline 1102 + 26 new tests in `test/event_time_test.dart`, exact match, no test weakened).
- New test coverage: timezone conversion across Europe/Amsterdam (summer/winter/both DST transition instants), Asia/Tokyo and Asia/Dubai (fixed offset, no DST, cross-date-boundary), America/New_York (DST, behind UTC); fallback behavior (null/empty/invalid identifier, never device-tagging-dependent); date range formatting (same-day, Preuvenemint-style multi-day, an overnight event that's same-UTC-day but crosses event-local midnight — the exact regression this hardening fixes, month/year boundary crossings); `Event.fromJson` timezone parsing (valid/missing/explicit-null, and confirming `start_at`/`end_at` stay UTC-tagged); `eventMatchesTrip` event-local-date regression tests in both directions; `eventsMatchingTrip` sorting proven still instant-based across mixed timezones.
- **6 existing test files' helper fixtures fixed** for a latent, newly-surfaced determinism issue: constructing `Event`/`DateTime` literals via the implicit-local `DateTime(...)` constructor (as several existing test helpers did) means the resulting instant depends on the *test machine's own* UTC offset — harmless before this change (no cross-zone conversion was ever applied to those values), but exactly the kind of value `eventLocalDateTime`'s UTC fallback now converts. Fixed by re-tagging those helpers' `DateTime`s as UTC (same digits, deterministic regardless of machine zone) and pairing them with an explicit `timezone: 'UTC'` — no test's asserted behavior changed, only its determinism.

## Files

**New**: `lib/core/utils/event_time.dart`, `supabase/migrations/20260820120000_events_v2_timezone_hardening.sql`, `supabase/migrations/20260820130000_events_v2_timezone_not_null.sql`, `test/event_time_test.dart`, this report, `EVENTS_V2_TIME_LOCATION_AUDIT.md` (prior task, still untracked).

**Modified**: `pubspec.yaml`, `pubspec.lock`, `lib/main.dart`, `lib/models/event.dart`, `lib/models/event_trip_match.dart`, `lib/features/events/event_date_format.dart`, `lib/features/events/event_detail_screen.dart`, `lib/features/events/widgets/event_meta_section.dart`, `docs/Architecture/EVENTS_V2_ARCHITECTURE.md` (§36 added), `test/events_test.dart`, `test/event_detail_redesign_test.dart`, `test/explore_discovery_widgets_test.dart`, `test/explore_search_results_test.dart`, `test/friend_going_tile_test.dart`, `test/friend_profile_going_section_test.dart`.

## Git

**Nothing staged, committed, or pushed.** `git status --short` confirms all of the above as unstaged modifications (`M`) or untracked (`??`) files only. Working tree also contains pre-existing, unrelated untracked artifacts from other in-progress work (Michelin/Gault Millau enrichment reports and data under `supabase/data/enrichment/`, `docs/Architecture/Michelin_Database/GAULT_MILLAU_UNBLOCK_DEPLOYMENT_REPORT.md`) — these predate this task, are outside its scope, and were left untouched.
