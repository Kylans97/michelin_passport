# Database linter exceptions

Supabase's Security Advisor applies generic, project-agnostic rules —
it cannot know that a specific "security definer view" or "RLS
disabled" finding is a deliberate, already-reasoned design decision
rather than an oversight. This document is the record of that
reasoning, so a finding that reappears in a year reads as "already
investigated, here's why" rather than as an unresolved critical bug
that needs re-triaging from scratch. New entries get added here as
they're found — this list is expected to grow, matching
`MODERATION_MANUAL_CHECKPOINTS.md`'s own "log near-misses" precedent.

---

## 1. Security Definer View — `restaurant_rankings` and `venue_community_rankings`

**Status: accepted, by design. Do not change `security_invoker` on
either view.**

**The finding**: both views have `security_invoker = false` (Postgres
default / colloquially "security definer" — confirmed live via
`pg_class.reloptions`, not assumed). The linter flags this as a
generic "bypasses RLS" pattern.

**Verified NOT a data leak** (checked directly against production, not
assumed from the view's own comments): neither view's output columns
include `user_id` or any individual `rating` value —
`restaurant_rankings` exposes `restaurant_id, name, city, country_flag,
michelin_stars, community_rating, total_visits, is_expired`;
`venue_community_rankings` exposes the same shape per venue type plus
`bayesian_score`. The `HAVING count(...) >= <threshold>` clause runs
inside the innermost CTE, before any row exists to expose — a
below-threshold venue never becomes a row in the view's result at all,
so no PostgREST-supplied filter/`count=exact` request from outside the
view can reach in and defeat it (filters compose on the view's already-
computed output, never inside its CTEs).

**Why `security_invoker = false` is the whole point, not an oversight**:
both views aggregate across `visits`/`venue_ratings`, which are
owner-scoped tables (`venue_ratings_own_read`: `user_id = auth.uid()`,
no `anon` access at all; `visits_read`: owner or accepted-friend only).
That RLS shape is correct and load-bearing for the raw tables — a
person's individual ratings/visits must stay private. The views exist
specifically to compute a *cross-user* aggregate from those otherwise-
mutually-invisible rows and disclose only the aggregate. That
privilege escalation is the view's entire reason to exist, not a bug.

**Why `security_invoker = true` would not "fix" this — it would break
it**, the same way `private_chefs_full` safely uses invoker mode for a
structurally different reason: `private_chefs_full`'s own base table
RLS (`publication_status = 'published'`) is identical for every
caller, `anon` included — no cross-user aggregation happens there, so
invoker mode changes nothing about what's returned. `visits`/
`venue_ratings` are the opposite shape. Under invoker mode:
- `anon` would see zero rows in the underlying CTEs (no policy grants
  `anon` anything on either table) — both views would always return
  empty for a logged-out visitor.
- `authenticated` would see only *their own* row(s) — `count(distinct
  user_id)` could never exceed 1 from inside the RLS-filtered query,
  so the `HAVING >=` threshold would almost never be met. On the rare
  occasion it happened to be met, the view would present a single
  user's own rating back to them *as if* it were the community
  average — a more actively misleading failure than simply being
  empty.

Neither of those is "more secure" — there is no leak being closed,
only a feature being disabled. This was already the reasoning recorded
at build time (see `20260824120000_add_restaurant_rankings_view.sql`
and `20260828120000_add_venue_claims_submissions_rankings.sql`'s own
comments); this entry exists so the linter's periodic re-flagging
doesn't require re-deriving that reasoning from scratch.

**`anon` + `authenticated` both hold SELECT on both views** (confirmed
live via `information_schema.role_table_grants`) — intentional: these
are public discovery/rankings surfaces, meant to be visible before
login, same tier as the restaurant/hotel catalogue itself.

**Known, separate limitation — the averaging/differencing risk**: a
small-`n` average discloses an exact unknown value to anyone who
already knows *n-1* of the *n* contributing ratings through some other
channel (e.g. a small group who rated the same obscure venue and
compared notes) — pure arithmetic (`avg = sum/n`), true of any
average-plus-count disclosure regardless of database permissions, and
**not something `security_invoker` affects either way** (the exposed
columns are identical under either mode — only the internal query's
own privilege changes). The one lever that changes this risk is the
row-count threshold itself, already centralized as a named constant
for exactly this reason:
- `venue_community_rankings`: `venue_ranking_min_reviews()` — currently
  **5** (verified live; earlier internal notes said 3, that value has
  since changed — this document reflects the current, checked value,
  not a remembered one).
- `restaurant_rankings` (the older, restaurant-only view): still a
  bare `HAVING count(*) >= 3` inline in the view definition, never
  extracted to a named function the way the newer view's threshold
  was. Raising either threshold directly raises how much side-
  knowledge an attacker needs before the averaging attack becomes
  exploitable. Revisiting `restaurant_rankings`' own inline `3` to
  match the newer, named-constant pattern is a reasonable future
  cleanup, not done here.

---

## 2. RLS Disabled in Public — `spatial_ref_sys`

**Status: cannot be suppressed or fixed from this project. Confirmed,
not assumed — do not re-attempt without reading this entry first.**

`spatial_ref_sys` is a PostGIS system table (SRID/projection reference
metadata — no user data, no personal data of any kind) that PostGIS
creates in the `public` schema as part of the extension itself. It is
owned by `supabase_admin`, not by this project's own `postgres` role —
confirmed directly: `alter table public.spatial_ref_sys enable row
level security` fails with `ERROR: 42501: must be owner of table
spatial_ref_sys`. There is no project-side permission that grants
around this.

This is a known, currently unresolved gap in Supabase's own tooling,
not something specific to this project — see [supabase/supabase#47206
](https://github.com/supabase/supabase/issues/47206) ("Security
Advisor flags spatial_ref_sys with 'RLS Disabled' but users cannot
enable RLS on it," open as of this writing) and the related community
discussions linked from it. No Dashboard "acknowledge/ignore this
finding" affordance and no `supabase/config.toml` linter-exclusion
setting exist for this today (checked — `supabase db lint` is a
schema-typing checker, a different tool from the Security Advisor that
raised this finding, and has no bearing on it).

The one real fix that exists in the wild — moving the `postgis`
extension out of the `public` schema into a dedicated, non-API-exposed
schema (e.g. `extensions`) — is **not applied here**: it is a
materially larger, riskier change than "suppress a linter finding"
against a live, populated database (`restaurants`/`hotels` both use
`geography(Point,4326)` columns, and `restaurants_full`/`hotels_full`
call `ST_Y`/`ST_X` against them), not something to do as a side effect
of a linter cleanup. Flagged here as a possible future option, not
attempted.
