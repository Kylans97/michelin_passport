# Community Rankings Backend V1

Status: **deployed to production, smoke-tested. Empty today — this is
correct, expected behavior, not a bug** (see §7).

## 1. What this is

Implements the `restaurant_rankings` Postgres view that
`RankingsRepository.getCommunityRankings()` has queried since before it
existed. Both Community's "Hottest Places" hero and the Community
Rankings screen depend on it — until this migration, both silently showed
nothing because the query failed with `42P01: relation
"restaurant_rankings" does not exist` (confirmed via a live audit during
an earlier Community pass; documented in
`docs/Architecture/NAVIGATION_INFORMATION_ARCHITECTURE_V2.md` §17).

One backend definition, two UI consumers — no separate ranking logic
exists for Hottest Places vs. Community Rankings.

## 2. Source rating field (audited, not assumed)

`visits.rating` (smallint, `CHECK (rating BETWEEN 1 AND 10)`) — the
overall rating. Confirmed via live `pg_constraint` inspection, distinct
from the independent, nullable sub-ratings (`food_rating`,
`service_rating`, `wine_rating`, `value_rating`, plus hotel-only
`room_rating`/`experience_rating`). `visits` has no formal foreign key to
restaurants — `entity_type`/`entity_id` is a polymorphic, unconstrained
pointer into either `restaurants` or `hotels` — so the view joins
`entity_id = restaurants_full.id` filtered `entity_type = 'restaurant'`.

## 3. Per-user / multiple-visit semantics

**One user contributes one current Restaurant-level rating.** If a user
visits the same restaurant more than once, only their most recent valid
rating (`visited_on DESC, id DESC` as a deterministic tiebreak) counts —
implemented via `DISTINCT ON (user_id, entity_id)`.

**Why**: a single frequent visitor must never be able to submit many
ratings and dominate the community average. Live production data has
zero users with more than one visit to the same restaurant today, but
nothing in the schema prevents it (no unique constraint on
`(user_id, entity_id)`), so this is a defensive design choice made ahead
of the problem existing, not a reaction to an observed one — verified
locally with a synthetic fixture (§6).

## 4. Minimum rating threshold — audited, not assumed

**Chosen: 3 unique raters.**

Full production distribution audit (read-only, live) before any decision:

| Unique raters | Restaurants |
|---|---|
| 1 | 1 |
| 2 | 0 |
| 3 | 0 |
| 4 | 0 |
| 5–9 | 0 |
| 10+ | 0 |

Total: 1,362 open restaurants, exactly **one** with any rating at all
(Parkheuvel, rated 9/10 by a single user). Every threshold from 2 upward
currently yields zero qualifying restaurants — choosing between 2 and 3
was not a material decision (both give the identical, empty result), so
the real decision was between (a) shipping the principled 3-rater
threshold and accepting an empty result today, or (b) using a threshold
of 1 to surface the single existing rating. This was put to the user
explicitly rather than decided silently, given the project's own rule
that a single rating must never be presented with the authority of a
community consensus. **Decision: ship threshold=3, empty today** — the
correct long-term infrastructure, populating naturally as real usage
accumulates, with zero further backend work required when it does.

## 5. Eligible restaurants

Only `restaurants_full.status = 'open'`. Confirmed via live query:
100% of the 1,362 restaurants in production are currently `open` (the
`venue_status` enum also defines `temporarily_closed`/
`permanently_closed`, unused today) — so this filter is currently a
no-op in practice but is load-bearing infrastructure for whenever a
restaurant's status changes. Verified locally: a restaurant with 3
qualifying ratings but `status = 'permanently_closed'` is correctly
excluded from the view (§6, fixture `a004`).

## 6. Local validation — all required edge cases, verified against a
real local Supabase instance with synthetic fixtures (never production
data)

| Case | Fixture | Result |
|---|---|---|
| 3 ratings for one restaurant | `a001`, ratings 8/9/10 | appears, `community_rating=9.00`, `total_visits=3` ✅ |
| Multiple visits, same user | `a003`, one user rates twice (5 then 9) | only the latest (9) counts once — deduped correctly ✅ |
| Below-threshold restaurant | `a002`, 2 raters | correctly excluded ✅ |
| Equal averages, different counts | `a005` (4 raters) vs `a006` (3 raters), both avg 8.00 | `a005` sorts first (more evidence wins ties) ✅ |
| Closed restaurant | `a004`, 3 raters, `status='permanently_closed'` | correctly excluded despite qualifying rating count ✅ |
| Null rating | `a007`, 3 visits, all `rating IS NULL` | correctly excluded (zero valid ratings) ✅ |
| Deleted user cascade | `a008`, 3 raters, one user then deleted via the Auth Admin API | rating count dropped from 3 to 2 post-cascade, restaurant correctly disappeared from the view ✅ |

All fixture users, restaurants, cities, and countries were created and
fully cleaned up afterward — local database confirmed back to zero rows
in every affected table.

## 7. Empty state is correct, not an error

With zero restaurants meeting the threshold, the existing UI already
handles this gracefully and was not changed for this reason:
- **Hottest Places** (`community_screen.dart`): the whole section —
  heading included — is omitted, never a heading over nothing.
- **Community Rankings** (`community_rankings_tab.dart`): shows
  `"No community data yet"`, visually and semantically distinct from the
  error state (`"Could not load community rankings"`) — both now have
  direct test coverage (`test/community_rankings_tab_test.dart`), which
  did not exist before this pass.

Neither state fabricates data. This will start showing real content the
moment three community members rate the same restaurant, with no further
backend change.

## 8. Aggregation formula

```
community_rating = round(avg(latest_valid_rating_per_user), 2)
total_visits      = count(distinct qualifying user)   -- historically named
                                                          "total_visits" in
                                                          the Dart model;
                                                          semantically this
                                                          is unique raters,
                                                          not a raw visit
                                                          count (see §10)
```
`HAVING count(*) >= 3` before a restaurant is included at all.

## 9. Sort order

`community_rating DESC, total_visits DESC, name ASC` — better average
first; ties reward more community evidence; alphabetical deterministic
fallback. Never Michelin stars, World's 50 Best, or Gault&Millau — this
ranking reflects the community's own opinion, never external guide
prestige (the `michelin_stars` column is exposed for the UI's own
recognition display and the repository's optional `stars` filter, never
used to influence order).

## 10. View schema

`public.restaurant_rankings` — `security_invoker = false` (deliberately
NOT `security_invoker = true` like `restaurants_full`, which can safely
use invoker semantics because its own base tables are fully public). This
view needs definer semantics to legitimately aggregate across every
user's private `visits` rows — which `visits_read` RLS restricts to the
owning user or accepted friends, never anonymous, never public, never in
aggregate to strangers — while exposing only the resulting restaurant-
level average and count. Explicit grants only (`GRANT SELECT` to `anon`
and `authenticated`; no reliance on ambient default privileges) — matches
the same public-discovery access `restaurants_full` already has.

Columns (intentionally matching the pre-existing Dart contract exactly —
see §16 of the pre-approval report for why no Flutter model change was
needed): `restaurant_id`, `name`, `city`, `country_flag`,
`michelin_stars`, `community_rating`, `total_visits`.

**Privacy**: no user id, profile id, visit id, or individual rating is
ever selected by this view — the output is restaurant-level aggregate
data only, structurally incapable of exposing which specific user(s)
rated a restaurant or what any individual rating was. The 3-rater
threshold additionally means the average itself can never be reverse-
engineered to a single person's exact rating (with 2+ other raters
contributing, the exact individual values are not recoverable from the
average and count alone).

No year filtering, no historical snapshots — a plain (not materialized)
view, representing the current aggregated community opinion and
naturally reflecting rating edits/deletions as they happen.

## 11. Hottest Places

Unchanged code, now backed by real infrastructure: shows the single
top-ranked eligible restaurant, captioned "Highest rated by the
community" (never "trending" — no temporal signal exists). Tapping
resolves the full `Restaurant` via `RestaurantRepository.getById` and
pushes the canonical `RestaurantDetailScreen`. Hotel and Event cards are
explicitly out of scope for V1 (§13).

## 12. Community Rankings screen

`CommunityRankingsTab` gained two changes in this pass:
- **Testability**: `loadCommunityRankings`/`getRestaurantById` are now
  injectable (same constructor-injection pattern used throughout this
  app's other Supabase-eager widgets), closing a real gap — this widget
  previously had zero test coverage of its loading/error/empty/populated
  states.
- **Navigation**: rows are now tappable — previously `_CommunityRankCard`
  had no `onTap` at all. Tapping resolves the full `Restaurant` (same
  `RestaurantRepository.getById` pattern as Hottest Places) and pushes
  `RestaurantDetailScreen`. This was the one piece of "make the existing
  screen truly functional" that required a code change beyond the
  backend — the screen could not previously navigate anywhere even with
  real data.

The star filter chips (`_starFilter`) are unchanged, already worked, and
are now covered by a direct test proving the correct `stars` parameter is
requested on each tap.

## 13. Hotel / Event — deferred, by design

Not built in this pass. Documented requirements for later:

- **Hotels**: need a genuine cross-user aggregate signal — no equivalent
  of `visits.rating` currently rolls up into any hotel-level view, and no
  hotel-rankings view/table exists anywhere in this schema.
- **Events**: need a batched aggregate (e.g. interested/going popularity
  across all events in one query) — only a per-event RPC
  (`get_event_going_member_count`) exists today; looping it per event
  client-side is an N+1 pattern, not a trivial reuse (documented
  previously in `EVENTS_V2_STEP_8A_PERSONALIZED_RANKING_PRE_FINAL.md`).

Hottest Places' architecture (a single `FutureBuilder` resolving "the
current top item," independent of how many categories exist) does not
need to change to add Hotel/Event later — it would be additive, not a
replacement of the Restaurant V1 path.

## 14. Tests

- `test/ranking_entry_test.dart` (new) — `CommunityRankingEntry.fromJson`
  parsing: every field, numeric precision, null-default handling, and
  that list-mapping preserves backend order.
- `test/community_rankings_tab_test.dart` (new) — the real widget with
  injected fakes: loading, populated (order/rank/rating/visit-count
  display), empty vs. error (distinct messages), star filter reload, tap
  navigation (lookup-only, consistent with this suite's established
  "never pump past a Supabase-eager pushed screen" convention).
- `test/community_screen_shell_test.dart` (existing, unchanged) — already
  covered Hottest Places' empty/error/populated states with the real
  `CommunityScreen` and injected fakes from an earlier pass; still valid,
  still passing.
- `test/community_rankings_screen_test.dart` (existing, unchanged) — the
  outer pushed-screen shell (Scaffold, back button, bounded slot);
  `CommunityRankingsTab`'s own states now have direct coverage above,
  so this file's existing mirror-style shell test remains appropriately
  scoped to just the shell.

## 15. Production migration

`supabase/migrations/20260824120000_add_restaurant_rankings_view.sql`.
Applied via `supabase db push --linked` (the established workflow — no
manual ad-hoc production view). Verified: `restaurant_rankings` exists in
production; `supabase migration list` shows all 41 migrations local↔remote
synced with zero mismatches; a direct, unauthenticated REST call with the
project's `anon` key (`GET .../rest/v1/restaurant_rankings`) returns
`200` with `[]` — confirming the grants work end-to-end through the exact
access path the Flutter app itself uses, not just elevated database
access.

(Note: `supabase db diff`/`supabase db reset` currently fail locally on
an unrelated, pre-existing seed-data bug — an early Events-related insert
violates `events_country_code_fkey` on a fresh shadow-database bootstrap.
This is not caused by, or related to, this migration; it affects any
attempt at a fully-fresh local reset and is worth its own separate fix,
not undertaken here.)
