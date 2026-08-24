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

### Out of scope
No Bib Gourmand or unstarred MICHELIN Guide entries. No Green Star in award
history. World's 50 Best is in scope.

---

## Working standards

**Never guess.** Every data decision must be traceable and verified, not
inferred. When a lookup returns the wrong record, hold it back and log it —
do not import it and do not quietly fix it.

**Log near-misses, not just failures.** The QA log runs to 174 entries
because it records reasoning, not only errors. Corrections go in
`CHANGELOG.md` with the relevant `issue_id`.

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
- The `service_role` key never appears in client code.
- Catalogue tables (`hotels`, `restaurants`, `hotel_restaurants`,
  `countries`, `cities`) are world-readable, write-restricted.
- Supabase region is EU and cannot be changed without migration.
- Photo egress is the primary cost risk, not database size. Compress
  client-side before upload; never serve full-resolution images.

---

## Constraints on agent behaviour

- Never commit or push unless explicitly asked.
- Never create migrations or write to Supabase as a side effect of another
  task. Say what a migration would need to do and stop.
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
