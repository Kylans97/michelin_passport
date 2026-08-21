# Events V2 Step 4.1 — Would Recommend Production Apply Report

**Status: `20260820160000_events_v2_would_recommend.sql` deployed to production. Nothing else deployed. Nothing staged, committed, or pushed to git.**

## Migration result

Pre-deploy checks (both run before any write):

- `supabase migration list --linked` — every migration through `20260820150000` showed matching `local`/`remote` timestamps; **`20260820160000` was the only row with an empty `remote` value** (unapplied).
- `supabase db push --linked --dry-run` — `{"upToDate":false,"dryRun":true,"migrations":["20260820160000_events_v2_would_recommend.sql"]}`. Confirmed: exactly one pending migration, exactly the approved one.

Deployed: `supabase db push --linked` → `Applying migration 20260820160000_events_v2_would_recommend.sql...` → `{"upToDate":false,"dryRun":false,"migrations":["20260820160000_events_v2_would_recommend.sql"]}`. No other file was pushed; no backfill statement exists anywhere in this migration to run.

## Schema verification

Queried live via `supabase db query --linked` against `information_schema.columns`:

| column | data_type | is_nullable | column_default |
|---|---|---|---|
| `would_recommend` | `boolean` | `YES` | `null` (none) |

Exactly as required: boolean, nullable, no default. Every sibling column on the table was re-selected in the same query and is byte-for-byte unchanged from its pre-migration definition:

| column | data_type | is_nullable | column_default |
|---|---|---|---|
| `rating` | `smallint` | `YES` | `null` |
| `comment` | `text` | `YES` | `null` |
| `source` | `text` | `NO` | `'manual'::text` |
| `visibility` | `text` | `NO` | `'private'::text` |

Check constraints re-queried via `pg_constraint`: `event_confirmed_attendance_rating_check`, `_source_check`, `_visibility_check` — all three present, definitions unchanged, and (as designed — the migration deliberately adds no CHECK on `would_recommend`) no fourth constraint was added.

## Existing-row verification

`select count(*), count(*) filter (where would_recommend is true), count(*) filter (where would_recommend is false), count(*) filter (where would_recommend is null) from event_confirmed_attendance` → **`total_rows: 0`** (production currently has zero confirmed-attendance rows). "Existing rows remain NULL" is satisfied vacuously and exactly — there was nothing to backfill, nothing was written, and the row count before and after this migration is identical (0 → 0), confirming no row was created, deleted, or touched by the deploy itself.

## RLS verification

Queried live via `pg_policy`: all 4 pre-existing policies present, unchanged —

- `event_confirmed_attendance_select` (`user_id = auth.uid() OR (visibility = 'friends' AND is_friend(user_id))`)
- `event_confirmed_attendance_insert` (`WITH CHECK user_id = auth.uid()`)
- `event_confirmed_attendance_update` (`USING/WITH CHECK user_id = auth.uid()`)
- `event_confirmed_attendance_delete` (`USING user_id = auth.uid()`)

No new policy was added; no existing policy's expression changed. None reference `would_recommend`, matching the migration's own pre-authoring audit that no policy enumerates specific columns.

Post-deploy migration state: `supabase migration list --linked` now shows `local == remote` for every row including `20260820160000`. `supabase db push --linked --dry-run` (re-run after the real push) returned `{"upToDate":true,"migrations":[]}` — **"Remote database is up to date."**

## Validation

- `dart format --set-exit-if-changed .` — **0 files changed**.
- `flutter analyze` — **No issues found!**
- `flutter test` — **1235 passed, 0 failed** — matches the expected baseline exactly.

## Git state

`git status --short` (excluding untracked): only the same pre-existing unstaged modifications from before this deploy (`docs/Architecture/EVENTS_V2_ANALYTICS_CONTRACT.md`, `analytics_event.dart`, `analytics_properties.dart`, `event_detail_screen.dart`, `events_screen.dart`, plus unrelated in-progress files predating this task). `git diff --cached --stat` is empty — **nothing staged**. `HEAD` is still `56bc57b2672fcb00c3fa34aef20a4a6b7699742d`, identical to `origin/main` — no commit was made. The migration file itself remains untracked (`??`) in git, exactly as before — deploying it to the database does not touch git.

---

## Next gate

Physical-device testing of the full recommend flow (unanswered / Yes / No / Yes→No / No→Yes / clear back to unanswered / "Edit your experience" prepopulation / persistence after reload) — not performed as part of this apply. No other production data was created or modified.

**STOP.**
