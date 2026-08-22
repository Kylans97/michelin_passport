# EVENTS DISCOVERY TAXONOMY — PHASE A — SCHEMA + 27-EVENT BACKFILL PRE-APPLY

Schema-design and backfill-preview task, following
`EVENTS_UI_DISCOVERY_TAXONOMY_AUDIT.md`. **No production write
occurred.** A migration was authored and proven against the **local**
Supabase instance only; the remote/linked project was never pushed to.

## 1. PRODUCTION CATALOGUE RECONSTRUCTION

Re-read fresh, not trusted from the prior audit: `events` count =
**27**, exact same 27 IDs/titles/types as the audit assumed — no
discrepancy. Current `event_type` CHECK constraint read directly from
`pg_constraint`:

```
CHECK ((event_type = ANY (ARRAY['festival','dinner','tasting','market','experience','other'])))
```

Six values allowed today; only four are actually in use in production
(`festival` 1, `dinner` 19, `tasting` 4, `experience` 3; `market`/
`other` unused) — matches the prior audit exactly.

**Schema discovery made during this task, not previously flagged**:
`events.descriptor_tags` (`text[]`, nullable, added in
`20260819140000_events_v2_host_venue_moderation.sql`) already exists
in the schema — but it is **completely dormant**: zero non-null values
across all 27 production rows, and zero references anywhere in the
Dart codebase (`grep` for `descriptorTags`/`descriptor_tags` across
`lib/` returns nothing). This is effectively an orphaned artifact of
an earlier, different design direction — exactly "Option B" (raw
`text[]`) from the audit's own governance comparison, apparently never
adopted. **Left untouched in this task** — Phase A does not repurpose
or drop it; a future cleanup migration could remove it once the new
normalized tables are confirmed as the adopted direction, but that is
explicitly out of this task's scope.

## 2. INDEPENDENT TYPE CLASSIFICATION REVIEW

Every one of the 27 Events was independently re-read (title +
description + actual published times/format), not mechanically copied
from the prior audit. **One classification was deliberately changed
from the prior audit's own lean**, and one tag assignment was refined
— both explained below.

**The four explicitly flagged ambiguous cases, re-examined**:

1. **Club Leroy bij Parkheuvel** — the prior audit leaned Party. On
   fresh, independent review: it is structurally a single-restaurant,
   single-seating four-course menu with live musical entertainment —
   not a multi-kitchen/multi-station format like the genuine Party
   members (Chefs & Sommeliers Party, SHEf's Kitchen Party). **Revised
   to Dinner.** This is a real, reasoned deviation, not a copy of the
   prior draft.
2. **Erloom x Henrique Sá Pessoa** — confirmed genuinely ambiguous: the
   source prices both a lunch (€99) and dinner (€129) seating across
   the same 3-day guest-chef residency. Per instruction, no new type
   was invented to solve this; kept as Dinner (the higher-value/
   primary framing), flagged explicitly as an unresolved one-Event/
   two-services modeling limitation.
3. **Merlet x Joann** — starts 12:30 (closer to lunchtime), but the
   source's own title is literally "Four Hands **Dinner**." Kept as
   Dinner, source-naming authoritative over clock-time inference.
4. **Dîner Dansant** — live music/dancing could argue Party, but
   "Dîner" is literally Van Oys's own name for it, and structurally
   it's a single-venue seated dinner with entertainment, not a
   multi-kitchen showcase. Kept as Dinner.

**Final independently-verified distribution** (differs from the prior
audit's own estimate by exactly the Club Leroy reclassification):

| Type | Count |
|---|---|
| Dinner | 16 |
| Lunch | 3 |
| Festival | 2 |
| Gala | 2 |
| Tasting | 1 |
| Brunch | 1 |
| Party | 2 |
| **Total** | **27** |

**10 of 27 Events require an actual `event_type` change** from their
currently-stored value (full list, with reasoning per row, in the
backfill artifact — §8): Chefs & Sommeliers Party (→party),
VanOost Herzig Lunch (→lunch), Winemakers Lunch SA (→lunch),
Wildfestival (→festival), Chaîne Gala (→gala), Club Leroy (→dinner,
from `experience`), Vergeet Mij Niet Gala (→gala), Game Brunch
(→brunch), Heidi Schröck Lunch (→lunch), SHEf's Kitchen Party
(→party). The remaining 17 keep their current value.

## 3. INDEPENDENT TAG CLASSIFICATION REVIEW

Applied the stricter definitions given in this task (e.g. "wine merely
being served with dinner is NOT sufficient," "do not tag an Event
simply because the host's own chef is cooking," "do not automatically
apply four_hands to every guest-chef Event") — not the looser prior
draft.

**One tag assignment was deliberately added beyond the prior audit's
own draft**: **Vergeet Mij Niet Gala** now also carries `guest_chef` —
on re-reading, its 6 named participant restaurants (Ciel Bleu, De
Bokkedoorns, De Librije, De Treeswijkhoeve, Inter Scaldes, Restaurant
Smink) are a genuine multi-restaurant collaboration, not one host's
own kitchen, and qualify under the same definition every other
guest-chef Event is held to.

**One tag was deliberately withheld despite a plausible surface
reading**: **Chefs & Sommeliers Party** is NOT tagged `wine`, even
though wine/champagne selection is a named feature — its own central
identity is the 8-kitchen collaboration, and the stricter "materially
revolves around wine" bar (versus "wine was a listed included
feature") is not met the way it is for the five dedicated wine
dinners/lunches/tastings.

**Final independently-verified tag totals**:

| Tag | Count |
|---|---|
| `wine` | 5 |
| `winemaker` | 4 |
| `wild_game` | 3 |
| `guest_chef` | 15 |
| `four_hands` | 6 |
| `charity` | 1 |
| **Total assignments** | **34** |

No Event was forced to carry a tag without direct textual evidence in
its own description/title — the full per-Event reasoning is in the
backfill artifact (§8). Zero-tag Events remain zero-tag (7 Events:
't Preuvenemint, Chaîne Gala, Club Leroy, Roemer Jubileumdiner, Dîner
Dansant, plus 2 more with no qualifying theme) — tags were never
forced onto every row.

## 4. TAG REFERENCE MODEL — SCHEMA DESIGN

Inspected actual existing conventions before designing anything:
`cuisines` (small curated reference table: `id smallint`, `name text
UNIQUE`, RLS enabled, single public-read policy) and `event_restaurants`
/`event_hotels` (join tables: `id uuid` PK, cascade-deleting FKs,
composite `UNIQUE(event_id, entity_id)`, separate B-tree index on each
FK column in addition to the composite unique, single public-read RLS
policy, no write policy). `event_tags`/`event_tag_assignments` mirror
both conventions directly — see the migration in §6.

## 5. RLS

Inspected the actual policy on `events`, `event_restaurants`, and
`cuisines` directly via `pg_policy` (not assumed from the audit's own
phrase): every one of them has **exactly one** policy — `FOR SELECT
USING (true)` (or, for `events` itself, `USING (moderation_status =
'published')`) — and **no** INSERT/UPDATE/DELETE policy at all. Writes
to every one of these tables happen exclusively via the service role,
which bypasses RLS entirely — there is no "service-write policy" to
copy, because the service role doesn't need one. `event_tags` and
`event_tag_assignments` follow this exact, confirmed pattern: one
public-read `USING (true)` policy each, no write policy, no
`SECURITY DEFINER` anywhere (none was needed).

## 6. EVENT_TYPE MIGRATION

Created **`supabase/migrations/20260823120000_events_v2_discovery_taxonomy_phase_a.sql`**
— additive-only:

```sql
alter table public.events drop constraint events_event_type_check;
alter table public.events add constraint events_event_type_check
  check (event_type = any (array[
    'festival', 'dinner', 'tasting', 'market', 'experience', 'other',
    'lunch', 'gala', 'brunch', 'party'
  ]::text[]));

create table public.event_tags (
  id uuid primary key default gen_random_uuid(),
  slug text not null,
  name text not null,
  created_at timestamptz not null default now()
);
alter table public.event_tags add constraint event_tags_slug_key unique (slug);
alter table public.event_tags enable row level security;
create policy event_tags_public_read on public.event_tags for select using (true);

create table public.event_tag_assignments (
  id uuid primary key default gen_random_uuid(),
  event_id uuid not null references public.events(id) on delete cascade,
  tag_id uuid not null references public.event_tags(id) on delete cascade
);
alter table public.event_tag_assignments
  add constraint event_tag_assignments_event_id_tag_id_key unique (event_id, tag_id);
create index event_tag_assignments_event_idx on public.event_tag_assignments (event_id);
create index event_tag_assignments_tag_idx on public.event_tag_assignments (tag_id);
alter table public.event_tag_assignments enable row level security;
create policy event_tag_assignments_public_read on public.event_tag_assignments for select using (true);
```

**A: values allowed by the database after this migration**: 10 —
the original 6 plus `lunch`/`gala`/`brunch`/`party`.
**B: values used by current production rows**: 4 (`festival`,
`dinner`, `tasting`, `experience`) today; will become 7 after backfill
(`market`/`other` remain allowed but stay unused).
**C: values exposed by the new Dart taxonomy**: all 10 remain
parseable (§7) — the Dart enum was extended, not narrowed.

No existing row is invalidated — every currently-stored value remains
valid both before and after this migration; the constraint only grows.

## 7. DART EVENTTYPE COMPATIBILITY AUDIT

Searched the entire codebase for `EventType` usage before changing
anything. Findings:

- **Enum + parsing** (`lib/models/event.dart`): `fromDbValue` already
  does a defensive linear lookup with a **safe fallback to
  `EventType.other`** for any unrecognized string — this was already
  forward-compatible with schema drift by design, before this task
  touched anything.
- **Only one exhaustive `switch`** over `EventType` exists anywhere in
  the codebase: the `label` getter inside the enum itself. This is the
  only place a compile-time change was required.
- **Only one other `EventType` reference outside the model**:
  `event_detail_screen.dart` line 778, a simple equality check
  (`event.eventType == EventType.other`) to decide whether to hide the
  hero eyebrow — unaffected by adding new values, since it doesn't
  enumerate them.
- **No test hardcodes the old 6-value set**: `event_detail_redesign_test.dart`
  line 352 iterates `EventType.values` generically and asserts a
  property that holds for every value — it automatically extends to
  the 4 new values with zero test changes required.
- **Legacy values (`experience`/`market`/`other`) remain fully
  parseable** — none were removed from the Dart enum or the DB
  constraint. This was a deliberate, explicit decision, not an
  oversight: removing them would require a backfill first and gain
  nothing, since they're harmless to keep.

**Minimal change made** (the only Dart change in this entire task):
added `lunch`, `tasting` (unchanged, already existed — reordered
alongside the new values for readability), `gala`, `brunch`, `party`
to the `EventType` enum with their `dbValue` strings, and extended the
`label` switch to cover all 10 cases. `dart format`, `flutter
analyze`, and the full `flutter test` suite were all re-run after this
change and are clean (§13) — proving existing Events continue
rendering safely with zero other code touched.

## 8. 27-EVENT BACKFILL PREVIEW

**Not executed — preview only.** Full artifact, UUID-keyed (never
title-keyed):
`supabase/data/enrichment/events/events_discovery_taxonomy_phase_a_backfill_preview.json`

Contains, for all 27 Events: `event_id`, `title`, `current_event_type`,
`proposed_event_type`, `type_change_required` (boolean),
`proposed_tags`, and a reasoning note for every non-obvious call —
exactly the four flagged ambiguous cases plus the two deliberate
refinements described in §2–3.

**Exact totals** (independently verified, not forced to match the
task's own ~12/~33 approximations): **10 type changes**, **17
unchanged**; **34 total tag assignments** across 6 tags (Wine 5,
Winemaker 4, Wild/Game 3, Guest Chef 15, Four Hands 6, Charity 1).

## 9. PRODUCTION TRANSACTION PREVIEW — NOT EXECUTED

```sql
BEGIN;

-- 1. Final duplicate re-check for tag slugs (must return 0 rows)
SELECT slug FROM public.event_tags
WHERE slug IN ('wine','winemaker','wild_game','guest_chef','four_hands','charity');

-- 2. Seed the six tag definitions
INSERT INTO public.event_tags (slug, name) VALUES
  ('wine', 'Wine'),
  ('winemaker', 'Winemaker'),
  ('wild_game', 'Wild / Game'),
  ('guest_chef', 'Guest Chef'),
  ('four_hands', 'Four Hands'),
  ('charity', 'Charity');

-- 3. Update only the 10 approved Event type rows, by UUID
UPDATE public.events SET event_type = 'party'   WHERE id = '60271509-2de7-4c28-ae5f-eadd0a30aeec'; -- Chefs & Sommeliers Party
UPDATE public.events SET event_type = 'lunch'   WHERE id = '12dea83b-799c-4908-afc8-92de5cd96d5f'; -- VanOost x Herzig
UPDATE public.events SET event_type = 'lunch'   WHERE id = 'bb917cbc-434f-4545-be81-99164ac7ec1f'; -- Winemakers Lunch SA
UPDATE public.events SET event_type = 'festival' WHERE id = 'eaad5729-e88c-47fa-b842-0343f6f794a2'; -- Wildfestival
UPDATE public.events SET event_type = 'gala'    WHERE id = '1fe81ee4-27ae-46d6-b169-13cca93b86af'; -- Chaîne Gala
UPDATE public.events SET event_type = 'dinner'  WHERE id = '9dbee4f6-ad2a-4477-a4e4-5a185cb7b606'; -- Club Leroy
UPDATE public.events SET event_type = 'gala'    WHERE id = 'fd23d7f5-ff7c-4caf-ba9b-a17e6397a607'; -- Vergeet Mij Niet Gala
UPDATE public.events SET event_type = 'brunch'  WHERE id = '2a76f968-d2cb-45dd-964f-1176b4b52cbd'; -- Game Brunch
UPDATE public.events SET event_type = 'lunch'   WHERE id = '4fa6a92a-9009-4852-9509-83597d88b437'; -- Heidi Schröck Lunch
UPDATE public.events SET event_type = 'party'   WHERE id = 'b4cdab07-bdef-4979-bafa-3238182be98a'; -- SHEf's Kitchen Party

-- 4. Insert the 34 approved tag assignments, resolving tag_id by slug
--    (full 27-row source list in the backfill JSON; example shape:)
INSERT INTO public.event_tag_assignments (event_id, tag_id)
SELECT '8b27df6d-9f95-4427-8f39-e3d20353f775'::uuid, id FROM public.event_tags WHERE slug = 'guest_chef'
UNION ALL
SELECT 'bb917cbc-434f-4545-be81-99164ac7ec1f'::uuid, id FROM public.event_tags WHERE slug = 'wine'
UNION ALL
SELECT 'bb917cbc-434f-4545-be81-99164ac7ec1f'::uuid, id FROM public.event_tags WHERE slug = 'winemaker';
-- ... (remaining rows follow the same pattern for every event_id/tag pair in the backfill JSON)

-- 5. Verify resulting counts
SELECT count(*) FROM public.event_tags;                 -- expect 6
SELECT count(*) FROM public.event_tag_assignments;      -- expect 34
SELECT event_type, count(*) FROM public.events GROUP BY event_type ORDER BY event_type;
-- expect: brunch 1, dinner 16, festival 2, gala 2, lunch 3, party 2, tasting 1 (market/experience/other: 0)

-- 6. Detect accidental duplicates
SELECT event_id, tag_id, count(*) FROM public.event_tag_assignments
  GROUP BY event_id, tag_id HAVING count(*) > 1; -- expect 0 rows (also structurally impossible: UNIQUE constraint)
SELECT slug, count(*) FROM public.event_tags GROUP BY slug HAVING count(*) > 1; -- expect 0 rows

COMMIT;
```

This is deterministic and repeatable: every UPDATE targets an exact
UUID (not a title match), every tag assignment resolves through the
unique `slug`, and the whole thing is one atomic transaction — either
all of it applies or none of it does.

## 10. LOCAL DATABASE PROOF

Applied via `supabase migration up --local` — succeeded cleanly.
Verified directly, all against the **local** instance only:

- **All 10 new/existing Event Types accepted**: set a local fixture
  row to `party` — accepted. Reverted to `dinner` — accepted.
- **Invalid arbitrary `event_type` rejected**: attempted
  `not_a_real_type` — rejected with `violates check constraint
  "events_event_type_check"`.
- **Duplicate tag slugs rejected**: seeded the 6 real tags, then
  attempted a second `wine` — rejected with `violates unique
  constraint "event_tags_slug_key"`.
- **Duplicate Event/tag assignments rejected**: inserted one real
  assignment, then repeated it — rejected with `violates unique
  constraint "event_tag_assignments_event_id_tag_id_key"`.
- **FK integrity proven both directions**: a non-existent `event_id`
  was rejected (`event_tag_assignments_event_id_fkey`); a non-existent
  `tag_id` was rejected (`event_tag_assignments_tag_id_fkey`).
- **Public read + write rejection — tested, with an honest limitation
  disclosed**: using the local project's own `anon` key against the
  REST API, **both SELECT and INSERT were rejected** for `event_tags`
  and `event_tag_assignments`. Investigated rather than assumed
  correct: the identical `anon`-key SELECT was then tried against the
  **pre-existing, already-in-production** `cuisines` and `events`
  tables — **both failed identically** (`permission denied for table
  cuisines` / `permission denied for table events`). This proves the
  failure is a **local CLI environment limitation** (this local stack
  lacks the baseline public-schema grants the actual hosted Supabase
  project has configured at the platform level, outside migration
  history) — not a defect introduced by this migration. The new
  tables behave **identically** to every existing table under this
  local stack's own limits, which is the correct, consistent outcome.
  Write-rejection for `anon` is proven either way (whether by RLS or
  by the missing base grant, the practical outcome — no
  unauthorized write — is identical and correct).
- **RLS was not weakened at any point to make a test pass.**

**Unrelated finding surfaced during local testing, not fixed here**:
the local Postgres flagged `public.spatial_ref_sys` (a stock PostGIS
extension system table) as having RLS disabled. This is pre-existing
local-environment state unrelated to anything in this migration — not
auto-remediated, per the tool's own explicit instruction not to change
RLS without the user's own decision; surfaced here for visibility only.

## 11. COMPATIBILITY / REGRESSION AUDIT

Explicitly confirmed unmodified by this task: Step 8A ranking
(`event_discovery_ranking.dart`/`event_discovery_service.dart` —
untouched), Friends Going/Interested (`event_attendance_repository.dart`
— untouched), Following/Followed Host (`event_host_follow_repository.dart`
— untouched), Step 8B hosted discovery (`_loadHostedEvents` — untouched),
Step 8C Passport eligibility (`loadPassportEventAttendance` —
untouched), Event attendance/lifecycle, date-only/time-precision
support, Trip matching, Event imagery, Event search
(`buildIlikeOrFilter` — untouched), `EventCard`, and the finalized
Event Detail hierarchy. The only production-code file touched anywhere
in this task is `lib/models/event.dart`, and only its `EventType` enum
definition — purely additive metadata, exactly as intended.

## 12. FUTURE FILTER QUERY READINESS

Proven directly against the local schema (read-only query shapes, no
repository code written):

```sql
-- Events tagged Wine
SELECT e.* FROM events e
  JOIN event_tag_assignments eta ON eta.event_id = e.id
  JOIN event_tags t ON t.id = eta.tag_id
  WHERE t.slug = 'wine';

-- Events tagged Wine AND Guest Chef (AND-across-tags)
SELECT e.* FROM events e
  JOIN event_tag_assignments eta ON eta.event_id = e.id
  JOIN event_tags t ON t.id = eta.tag_id
  WHERE t.slug IN ('wine','guest_chef')
  GROUP BY e.id
  HAVING count(DISTINCT t.slug) = 2;

-- Events type Lunch
SELECT * FROM events WHERE event_type = 'lunch';

-- Events type Dinner + tag Wild/Game
SELECT e.* FROM events e
  JOIN event_tag_assignments eta ON eta.event_id = e.id
  JOIN event_tags t ON t.id = eta.tag_id
  WHERE e.event_type = 'dinner' AND t.slug = 'wild_game';
```

All four shapes were executed against the local instance and returned
correct results (verified against the one locally-seeded fixture: a
single-tag query correctly returned 1 row; the AND-across-tags query
correctly returned 0 rows when the fixture only carried one of the two
tags — proving the `HAVING count(DISTINCT …) = N` pattern genuinely
requires all N tags, not just any one of them).

**AND-between-tags requires**: a `GROUP BY event_id` + `HAVING
count(DISTINCT tag_id) = N` (N = number of required tags) — a single
extra join per additional required tag, no client-side intersection
needed, no RPC needed. **Recommended server-side strategy for Phase B
at ~100 Events**: exactly this join+GROUP BY pattern, executed as a
normal Postgrest query (Supabase/Postgrest can express this via
`.select()` with an embedded resource filter, or a small Postgres view
if the client-side query builder can't express `HAVING` directly —
that's a Phase B implementation detail, not a schema requirement). No
RPC is justified by Phase A — the two standard B-tree indexes already
created (§6) are sufficient at this scale, matching the audit's own
performance analysis (§30 of the audit doc).

## 13. VALIDATION

`dart format --set-exit-if-changed .`: clean, 0 changed. `flutter
analyze`: no issues. `flutter test`: **1506 passed, 0 failed** —
baseline unchanged despite the `EventType` enum extension, exactly as
predicted by the compatibility audit (§7). `supabase migration list
--linked`: 39/39 pre-existing migrations remain `local == remote`; the
new `20260823120000` migration shows `"remote": ""` — **not yet
applied to the linked project**. `supabase db push --linked
--dry-run`: explicitly reports `"upToDate": false`, listing
`20260823120000_events_v2_discovery_taxonomy_phase_a.sql` as the one
migration that **would** be pushed — confirming it remains local-only
and pending, exactly as required. No push was executed.

## FILES

New: `supabase/migrations/20260823120000_events_v2_discovery_taxonomy_phase_a.sql`,
`supabase/data/enrichment/events/events_discovery_taxonomy_phase_a_backfill_preview.json`,
`docs/Architecture/Events/EVENTS_DISCOVERY_TAXONOMY_PHASE_A_PRE_APPLY.md`
(this file). Modified: `lib/models/event.dart` (the minimal `EventType`
compatibility extension described in §7 — the only production-code
file touched in this entire task).

## GIT

Nothing staged, committed, or pushed.

EVENTS DISCOVERY TAXONOMY — PHASE A SCHEMA AND 27-EVENT BACKFILL
PREPARED LOCALLY, READY FOR HUMAN PRODUCTION-APPLY REVIEW
