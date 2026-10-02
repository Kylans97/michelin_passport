# CLAUDE.md

Project context for Claude Code sessions. Read this before touching anything.

Working title: **Chasing Stars** (not final — a rename is in progress; do not
propagate the name into new identifiers, bundle IDs or table names).

---

## What this is

A Flutter + Supabase mobile app, plus a planned public content website, for
discovering and recording exceptional gastronomy. Benelux-first, global audience.

The loop is: **discover → follow → see what's happening → plan → attend →
keep it in your Passport.**

It is not a restaurant directory and not a booking marketplace. The
differentiator is the connected graph — Restaurant/Hotel/Chef ↔ Events ↔
Friends ↔ Trips ↔ Passport ↔ editorial — not the number of venues.

**Events are the primary pillar.** Curated high-end gastronomy events across
Europe: four-hands dinners, guest-chef collaborations, winemaker dinners,
galas, festivals. Optimise architecture and UI decisions for that.

Design register: private members' club / luxury editorial, not database UI.
Deep forest green + ivory, editorial serif, generous spacing, restrained
controls. Gold is reserved in-product for MICHELIN stars and Keys.

---

## Where the detail lives

| Topic | Path |
|---|---|
| Database schema and every convention | `docs/Architecture/Michelin_Database/DATABASE_ARCHITECTURE.md` |
| Data-collection orientation and settled decisions | `docs/Architecture/Michelin_Database/START_HERE.md` |
| Product vision | `docs/VISION.md`, `docs/Vision/` |
| Design | `docs/Design/` |
| Engineering notes | `docs/Engineering/` |
| Planning | `docs/Plannnig/` (sic — misspelled in the repo) |

Read the relevant doc before proposing changes in its area. Do not restate
its contents here.

---

## Settled decisions — do not reopen

These were decided deliberately. If a task appears to require breaking one,
stop and say so rather than working around it.

### Relationships
- Relationships live **only** in the `hotel_restaurants` join table.
- `restaurant_names`, `restaurant_codes`, `has_michelin_restaurant` were
  removed from hotels; `hotel_id`, `hotel_code`, `hotel_name` were removed
  from restaurants. **Do not put them back.**
- Anything else that looks like a relationship is a view.

### Hotel scope — three rules, mutually exclusive by construction
1. `hotels` holds **only** MICHELIN Key hotels. No stub rows for unkeyed
   properties, ever.
2. `hotel_restaurants` holds only verified links to Key hotels already in
   `hotels`.
3. A restaurant in a **non-Key** hotel stores the property in
   `restaurants.property_name` — no hotel row, no link row.

`property_name` is free text and **must never be joined on**.

### Identity
- `id` is a Postgres-generated `uuid`. Never written into CSVs.
- `hotel_code` / `restaurant_code` are the stable human keys. Keep both.
- **Never match on name.** Search, dedupe and linking key on code + country.
  Two brand clusters exist inside Switzerland alone (IGNIV, La Brezza).
- Google Place ID uniqueness is **per table, never across tables**. Shared
  IDs between a hotel row and a restaurant row are deliberate.

### Data source of truth (corrected 24 August 2026)
- **The live Supabase database is authoritative. The master CSVs
  (`restaurants_master.csv`, `hotels_master.csv`, `hotel_restaurant_links
  .csv`) are an export of it, never an import into it.** They were the
  original import source; production has since grown beyond them (588
  restaurants and 88 hotels exist only in the database, plus a `phone`
  column on `restaurants` no CSV ever carried) and they were never
  refreshed. Do not treat their row counts or schema as current.
- `START_HERE.md`'s own "Source files" section and its "No phone numbers"
  settled decision predate this correction and describe the pre-build
  planning snapshot, not the present state — both are marked superseded
  in place there, not deleted, per this project's own "log near-misses,
  not just failures" standard.
- Current, dated read-only exports taken directly from production live
  alongside the frozen originals in `supabase/data/` as
  `*_LIVE_20260824.csv`. See `START_HERE.md`'s superseded notice for the
  full file list and what each one covers.

### Awards
- `michelin_stars = 0` is valid — World's 50 Best entries without a star.
  Never render as "no award".
- `michelin_keys` in 1–3, `michelin_stars` in 0–3.
- Historical experiences stay meaningful even when a guide or award changes.

### Events
- **Known calendar date ≠ known clock time.** The model supports date-only,
  known-start/unknown-end, fully timed, and multi-day date-only events.
  **Unknown times are NEVER fabricated.**
- Store `timestamptz` plus the venue's IANA timezone; render in the event's
  own timezone, never the viewer's.
- Link semantics are explicit: **host**, **venue**, **participant**.
- V1 types: Dinner, Lunch, Festival, Gala, Tasting, Brunch, Party.
  V1 tags: Wine, Winemaker, Wild/Game, Guest Chef, Four Hands, Charity.
  Types and tags are separate dimensions — do not merge them.
- Discovery ranking (Step 8A), in order: trip relevance → friend Going →
  followed host → friend Interested → popularity → chronology.
  **New filtering runs before this ranking, never replaces or duplicates it.**
- Passport stamps come only from **confirmed attendance**. Interested/Going
  never creates a stamp.

### Venue permissions
- `venue_managers_restaurants` / `_hotels` / `_private_chefs` are the
  **single source of permission** to edit a venue. A claim is a historical
  request; a permission is current state. **Never read the claims tables
  to decide whether someone may edit** — check `is_active_venue_manager()`.
- `has_approved_venue_claim()` **no longer exists.** It conflated request
  and grant; `is_active_venue_manager()` replaced it, and eight policies
  were migrated onto it.
- Active access is the absence of revocation: **`revoked_at is null`**.
  There is deliberately no `status` column.
- Granting a permission from an approved claim is manual SQL run against
  the dashboard (snippets in `docs/Engineering/VENUE_CLAIM_OPERATIONS.md`).
  There is no in-app admin identity and none is planned — review happens
  through the dashboard with `service_role`, the same pattern every other
  manual approval in this schema already uses.

### Venue-supplied content
- **Only factual, verified data originates from us**: MICHELIN stars,
  Keys, World's 50 Best, Gault & Millau, and the verified location
  fields. All descriptive text and all photos come from the venue. Any
  descriptive copy we've filled in ourselves is a **starting value, not
  something we own** — a venue's own submission is never a correction to
  defer to, it's the actual source taking over.
- `venue_about_submissions` holds a venue's own about text, pending
  review; `venue_about_current` is the view resolving the latest
  *approved* one. Verified data is never overwritten by a submission.
- Photo ordering lives on the **published** tables (`restaurant_photos` /
  `hotel_photos` / `private_chef_photos`), never on submissions, and
  changes only through the `reorder_venue_photos` RPC — never a direct
  client-side `display_order` write.
- A manager may change only `display_order` on their venue's published
  photos. A `BEFORE UPDATE` trigger enforces that restriction, since RLS
  itself cannot restrict which columns an update touches.
- A manager's "Preview my page" (`VenueManagementScreen._openPreview`)
  renders the **real** `RestaurantDetailScreen`/`HotelDetailScreen`/
  `PrivateChefDetailScreen`, given their pending content via optional
  override params (`aboutTextOverride`, `photoUrlsOverride`/
  `photosOverride`, `isPreview`) — never a separate replica screen, so it
  cannot drift from what a visitor actually sees. `isPreview` only skips
  *personal* state (visits/stays/wishlisted/following); venue-level
  content (award history, hosted events, linked hotel/restaurants, chef
  history/education) always loads live, and mutating controls stay
  visible but inert rather than hidden.
- `VenueDetailHero` (Restaurant/Hotel), `PrivateChefHero`, and
  `EventDetailHero` stay three separate widgets — **settled, do not
  unify**. Each already diverges in chrome, data shape and interaction
  (AppBar presence, gallery vs. single cover, differing action rows), and
  a forced shared hero would trade that clarity for an abstraction with
  no real reuse behind it.

### Out of scope
No Bib Gourmand or unstarred MICHELIN Guide entries. No Green Star in award
history. World's 50 Best is in scope.

---

## Working standards

**Never guess.** Every data decision must be traceable and verified, not
inferred. When a lookup returns the wrong record, hold it back and log it —
do not import it and do not quietly fix it.

**Log near-misses, not just failures.** The QA log runs to 174 entries
because it records reasoning, not only errors. Two logs, two conventions:
data corrections go in the Michelin_Database changelog
(`docs/Architecture/Michelin_Database/CHANGELOG.md`), with an issue id
from `qa_issues.csv` — that is where an issue id comes from and what it
is for, and traceability there is the whole point of the never-guess rule
above. Engineering changes go in the app's `CHANGELOG.md`
(`docs/Plannnig/CHANGELOG.md`), Keep a Changelog format, with near-misses
under Fixed — an issue id is filing without a function there; what
matters is what broke and why it would recur. Engineering changes
include schema and backend changes even when no build ships alongside
them — a migration applied to production is not nothing just because no
app code changed that day. Each entry belongs to the release it goes out
alongside: applied before a build, it sits in that build's own section;
applied after, it sits under Unreleased until the next one.

**Treat published totals from secondary sources as unverified.** Only
per-guide selections published by MICHELIN itself proved reliable.

**Report honestly.** State what was not testable rather than implying full
coverage. Disclose when a check was skipped and why.

---

## UI principle

The discovery engine can be sophisticated while the interface stays calm.

Do not build a screen full of permanent filter chips, badges, ratings and
database controls. Preferred shape:

> search → one elegant Filters affordance → subtle active-filter summary →
> personalised ranked feed → editorial cards → rich detail

---

## Security and infrastructure

- **RLS is mandatory on every user table.** The `anon` key ships inside the
  published Flutter app and is public. `profiles`, `visits`, `photos`,
  `wishlist`, `follows`, event attendance — all of them.
- **Every new `SECURITY DEFINER` function needs its own explicit
  `revoke execute on function ... from public, anon;`, written in the same
  migration that creates it.** This project's Supabase instance auto-grants
  `anon` (via PUBLIC) execute on every new function in `public`, and —
  confirmed by direct testing (20260925170000, PG 17) — `alter default
  privileges ... revoke execute on functions from public, anon` does **not**
  suppress this for functions the way the equivalent fix works for tables
  (`20260918130000_revoke_anon_defaults_on_private_tables.sql` — tables have
  no such built-in default, so that one genuinely closed the source). This
  exact gap has already been independently rediscovered and patched four
  times on four different functions
  (`20260813130000_social_foundation_step1_revoke_anon_execute.sql`,
  `20260815130000_social_foundation_step2b_revoke_anon_execute.sql`,
  `20260925140000_add_venue_invites.sql`/`20260925160000_...`, and
  `20260925170000_close_anon_execute_default_privilege.sql`'s own backlog
  cleanup) — do not let it become a fifth. `from public` is required, not
  optional: revoking only `from anon` is a no-op if PUBLIC still holds the
  grant. Verify with `has_function_privilege('anon', '<fn>(<args>)',
  'EXECUTE')`, not by inspection alone.
- The `service_role` key never appears in client code.
- Catalogue tables (`hotels`, `restaurants`, `hotel_restaurants`,
  `countries`, `cities`) are world-readable, write-restricted.
- Supabase region is EU and cannot be changed without migration.
- Photo egress is the primary cost risk, not database size. Compress
  client-side before upload; never serve full-resolution images.
- Venue photos are picked with `photo_manager`, not `image_picker` —
  `image_picker`'s iOS picker can silently return a locally-cached iCloud
  proxy under this feature's resolution minimum; `photo_manager` can
  request the true original.
- Two Edge Functions (`notify-venue-claim`, `notify-venue-submission`)
  email `claimedvenues@mantelier.app` on a new claim and on a new
  about/photo submission. Both are best-effort — a pg_net trigger with
  its own exception handler — and can never block the insert that
  triggered them.

---

## Constraints on agent behaviour

- Never commit or push unless explicitly asked.
- Never create migrations or write to Supabase as a side effect of another
  task. Say what a migration would need to do and stop.
- A session that applies a migration ends by confirming the migration is
  committed and that `supabase migration list --linked` shows local and
  remote in agreement. Not optional, not conditional on being asked.
- A schema diff — production against what the local migrations actually
  produce, not just the migration ledger — runs at each version bump,
  before the push. `supabase db diff --linked` currently cannot do this:
  its shadow-database bootstrap replays every migration from empty, and
  nothing in migration history seeds `public.countries`, so any migration
  with a real `country_code` fails its foreign key and the bootstrap
  never completes. Until that gap is closed, do the diff by hand instead —
  `supabase db dump --linked` for production's schema, a disposable local
  Postgres with migrations replayed directly via `psql`, then `diff` the
  two dumps.
- `supabase db push --linked` can hang after printing "Applying
  migration..." even though the migration already committed successfully —
  observed directly (20261007120000, CLI 2.111.0). The failure mode this
  invites is retrying the apply on the strength of the CLI not returning,
  which is the one thing not to do. When a push looks stuck, verify the
  real state against production directly (query for the object the
  migration creates) before concluding anything, and never retry on
  output alone.
- A column, table or RPC that a shipped build reads cannot be removed
  while that build is in the wild. Destructive changes go in three
  steps — add the new shape, migrate readers and ship, then remove the
  old shape once the old build is gone. During the middle step both
  shapes must stay correct, not merely present, because a stale value an
  old build trusts is worse than a missing one it crashes on.
- Never modify files under `docs/Architecture/Michelin_Database/` without
  being asked — those are the record.
- Do not run destructive commands against production data.
- If a task conflicts with a settled decision above, stop and report the
  conflict rather than choosing an interpretation.

---

## Related workspace

Claude Cowork operates from a separate ops folder outside this repo
(event sourcing, research, content drafts). It has read access to this file
via symlink. Its output lands in a staging inbox and **never enters Supabase
or the master CSVs without human review** — the "never guess" rule applied
between agents. Do not build tooling that bypasses that review step.
