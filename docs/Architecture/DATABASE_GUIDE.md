# Mantelier

## Database Guide

**Version:** 1.0  
**Status:** Active  
**Owner:** Engineering  
**Last Updated:** 27 July 2026

---

# Purpose

This document defines how the Mantelier database is designed, maintained and expanded.

It establishes the standards for data quality, migrations, imports and long-term maintainability.

Every database change should follow the principles described in this guide.

---

# Database Philosophy

The database is the foundation of Mantelier.

Application code can be rewritten.

The user interface can evolve.

The database must preserve memories for decades.

Data integrity always takes priority over development speed.

---

# Database Principles

## One Source Of Truth

Every piece of information should exist in exactly one place.

Avoid duplicated data whenever possible.

Reference entities should always be reused.

---

## History Is Permanent

Historical information is never deleted.

Historical information is never overwritten.

Instead:

Create a new historical record.

Examples include:

- Michelin Stars
- Michelin Keys
- Rankings
- Awards

---

## Personal Data And Reference Data

Reference tables describe the world.

Personal tables describe the user.

These should always remain separated.

Reference examples:

Restaurant

Hotel

Award

Ranking

Location

Personal examples:

Restaurant Visit

Hotel Visit

Wishlist

Photos

Ratings

Notes

---

## UUID Policy

Every entity receives a UUID.

UUIDs:

- never change
- survive imports
- survive migrations
- survive application updates

UUIDs should never be regenerated.

---

## Soft Deletes

Whenever possible, records should remain recoverable.

If deletion is required:

Prefer:

deleted_at

instead of permanently removing records.

Historical data should remain available.

---

# Table Categories

The database consists of four categories.

## Reference Tables

Contain objective information.

Examples:

Restaurant

Hotel

RestaurantAward

HotelAward

RestaurantRanking

---

## User Tables

Contain personal information.

Examples:

RestaurantVisit

HotelVisit

Wishlist

Friendship

---

## Media Tables

Contain references to stored media.

Examples:

VisitPhoto

Only references are stored.

Never image files themselves.

---

## System Tables

Contain internal application data.

Examples:

Profiles

Authentication

Settings

Migration metadata

---

# Naming Conventions

Tables

restaurants

hotels

restaurant_visits

hotel_visits

restaurant_awards

restaurant_rankings

visit_photos

Columns

id

restaurant_id

hotel_id

profile_id

created_at

updated_at

deleted_at

latitude

longitude

google_place_id

michelin_url

official_website

Boolean fields

is_active

is_current

is_public

has_photo

---

# Data Types

UUID

Primary keys

TEXT

Descriptions

URLs

Notes

DATE

Visit dates

Award years

TIMESTAMP

created_at

updated_at

deleted_at

DOUBLE PRECISION

Latitude

Longitude

INTEGER

Rankings

Stars

Keys

Ratings

BOOLEAN

Flags

---

# Relationships

Reference tables should never depend on user data.

User tables reference objective tables.

Example:

Profile

↓

RestaurantVisit

↓

Restaurant

↓

RestaurantAward

Restaurant remains independent.

Visits connect users to restaurants.

---

# Migrations

Every schema change requires a migration.

Never manually edit production tables.

Migration files should:

- be small
- be reversible whenever possible
- contain one logical change

Examples:

Add column

Rename column

Create table

Create index

Avoid combining multiple unrelated changes.

---

# Row Level Security

RLS is the authoritative client-access boundary in this project — not table
grants.

This project's Supabase bootstrap grants `anon`/`authenticated` broad
table-level privileges (`SELECT`/`INSERT`/`UPDATE`/`DELETE`/...) by default
on every table in `public`, via project-level `ALTER DEFAULT PRIVILEGES`.
This is standard Supabase behavior, not something any migration here
controls, and it is **not** an independent least-privilege layer — a
migration's own explicit `GRANT` statement does not narrow it. RLS policies
are what actually restrict client access.

Every new table must:

- `enable row level security`
- have a `select` policy (`to anon, authenticated` for public catalogue
  data; `to authenticated` scoped to the owner for personal data)
- have no `insert`/`update`/`delete` policy unless a client is genuinely
  meant to write directly — omit the policy entirely rather than writing
  one that's never exercised

A table with RLS enabled and no policy for a given command is fully closed
for that command, regardless of what the underlying grant allows. This
project relies on that guarantee throughout (`friendships`, `private_chefs`,
`private_chef_restaurant_history`, `private_chef_enquiries` all have zero
write policies for at least one command and are correctly closed for it).

A project-wide database privilege audit (2026-08-17) confirmed this pattern
holds correctly across every application table except one:
`public.worlds_50_best_hotels` was created without RLS at all (fixed in
`20260817130000_fix_worlds_50_best_hotels_rls.sql`). Normalizing the
underlying default privileges themselves (so a migration's own `GRANT`
statements become the true, sole boundary) remains a deferred, separate,
project-wide decision — not required while RLS coverage is complete and
correctly scoped.

---

# Data Imports

Every import should follow the same process.

Import

↓

Validation

↓

Review

↓

Backup

↓

Production

Never import data directly into production without validation.

---

# Validation Rules

Before every import verify:

✓ UUID integrity

✓ Duplicate detection

✓ Required fields

✓ Latitude

✓ Longitude

✓ URLs

✓ Google Place IDs

✓ Michelin URLs

✓ Encoding

✓ Row count

✓ Foreign keys

Unknown values remain NULL.

Never guess.

---

# Data Quality Standards

Every record should be:

Accurate

Consistent

Traceable

Complete whenever possible

Verifiable

External sources should always be preferred.

Michelin Guide remains the primary source.

---

# Indexing

Indexes should exist for:

UUID

Foreign keys

Google Place IDs

Coordinates

Restaurant names

Hotel names

Current awards

Search should remain performant as the database grows.

---

# Images

Images are stored in Supabase Storage.

The database stores only:

storage_path

caption

display_order

created_at

Never binary image data.

Two Storage buckets exist, for two different content shapes — see each
bucket's own migration for full detail:

- `visit-photos` — private, per-user visit/stay photography, owner-only
  RLS, read via signed URLs. The table-level `storage_path` pattern
  above.
- `catalogue-media` — public-read, admin/service-role-write-only,
  reusable across Restaurants/Hotels/Private Chefs catalogue photography
  (see `supabase/migrations/20260818150000_add_catalogue_media_storage.sql`
  and `PRIVATE_CHEFS.md`'s Step 2C section). Objects are served directly
  over a public URL, so the owning table stores a plain `image_url` text
  column pointing at that URL rather than a `storage_path` + signed-URL
  pair — the right shape when content is admin-curated and meant to be
  publicly visible, not user-owned and private.

---

# External Data

Supported sources include:

Michelin Guide

Official hotel websites

Official restaurant websites

Google Maps

Additional sources should only supplement official information.

---

# Backup Strategy

Before every major migration:

Create backup.

Before every bulk import:

Create backup.

Before structural changes:

Create backup.

Data should always be recoverable.

---

# Claude Data Pipeline

AI-generated data should never enter production automatically.

The workflow is:

Claude

↓

Validation

↓

Manual Review

↓

CSV

↓

Supabase Import

↓

Verification

↓

Git Commit

Human approval is always required.

---

# Future Expansion

The database is designed to support future entities including:

Bib Gourmand

Michelin Selected

Chef Profiles

Signature Dishes

Wine Lists

Travel Collections

Trips

Badges

Achievements

Timeline

Globe

AI Recommendations

No redesign should be required.

Only extensions.

---

# Database Standard

Every database modification should answer:

Does this preserve history?

Does this avoid duplication?

Does this improve maintainability?

Will this still make sense in ten years?

If not,

reconsider the design.

---

# North Star

> The database is not a collection of restaurants.

> It is the permanent archive of a lifetime of culinary experiences.
