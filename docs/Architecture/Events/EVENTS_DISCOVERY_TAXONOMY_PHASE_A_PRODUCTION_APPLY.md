# EVENTS DISCOVERY TAXONOMY — PHASE A — PRODUCTION APPLY

Physical-data record of the approved Phase A production apply.
Authoritative plan: `EVENTS_DISCOVERY_TAXONOMY_PHASE_A_PRE_APPLY.md`.

## SCOPE CLARIFICATION

The apply request arrived truncated — it listed only 4 of the 6
approved tags (`wine`, `winemaker`, `wild_game`, `guest_chef`,
omitting `four_hands` and `charity`). This was flagged before any
write, and the human confirmed: apply all 6 tags exactly as specified
in the already-approved pre-apply document. The apply below reflects
that confirmation.

## 1. PRE-WRITE STATE

Re-read live immediately before writing: `events` count = **27**.
39/39 pre-existing migrations synced; exactly 1 pending migration
(`20260823120000_events_v2_discovery_taxonomy_phase_a.sql`).
`event_tags`/`event_tag_assignments` confirmed not yet existing
(`to_regclass` returned `NULL` for both). No discrepancy found.

## 2. MIGRATION DEPLOYED

`supabase db push --linked` applied
`20260823120000_events_v2_discovery_taxonomy_phase_a.sql`. Re-verified
post-deploy: `events_event_type_check` widened to the 10 approved
values; `event_tags`/`event_tag_assignments` exist and were confirmed
empty (0 rows each) immediately after — a pure schema change, no data
yet, exactly as designed.

## 3. BACKFILL TRANSACTION APPLIED

One atomic statement (tag seed → type updates → tag assignments, all
UUID/slug-keyed, matching the pre-apply's own transaction preview
exactly) returned:

```
tags_seeded: 6
events_type_updated: 10
assignments_inserted: 34
```

Exactly matching the approved plan — no partial application, no
deviation.

## 4. POST-WRITE VERIFICATION

**Event type distribution** (re-read live): brunch 1, dinner 16,
festival 2, gala 2, lunch 3, party 2, tasting 1 = **27** — matches the
approved distribution exactly.

**Tag assignment distribution** (re-read live): charity 1, four_hands
6, guest_chef 15, wild_game 3, wine 5, winemaker 4 = **34** — matches
exactly.

**Duplicate check**: zero duplicate `(event_id, tag_id)` pairs, zero
duplicate tag `slug`s — confirmed via direct query (also structurally
guaranteed by the UNIQUE constraints).

**`events` count unchanged**: still 27 — this apply only ever updated
the `event_type` column on 10 existing rows and inserted rows into the
two new tables; no `events` row was added, removed, or had any other
column touched.

## 5. VALIDATION

`dart format --set-exit-if-changed .`: clean. `flutter analyze`: no
issues. `flutter test`: **1506 passed, 0 failed** — unchanged, no Dart
code was touched in this apply (the `EventType` enum extension was
already made and validated in the pre-apply phase). `supabase
migration list --linked`: **40/40** synced (39 pre-existing + the new
Phase A migration). `supabase db push --linked --dry-run`: "Remote
database is up to date."

## DATABASE

Production writes = 1 migration deployed (additive schema only) + 1
backfill transaction (6 tag rows, 10 Event `event_type` updates, 34
tag-assignment rows). Schema changes = 1 (this migration). RLS changes
= 2 new public-read policies (`event_tags_public_read`,
`event_tag_assignments_public_read`), matching existing convention
exactly. No existing table's RLS was modified. No catalogue entity was
created. No image was touched.

## GIT

Nothing staged, committed, or pushed in this apply task.

EVENTS DISCOVERY TAXONOMY — PHASE A APPLIED TO PRODUCTION, SCHEMA AND
27-EVENT BACKFILL VERIFIED
