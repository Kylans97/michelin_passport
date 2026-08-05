# Changelog

Michelin Passport — documentation changes.

Two passes are recorded. **Pass 1** implemented `ENGINEERING_REVIEW.md`; **Pass 2** implemented the accepted findings of `MAINTAINABILITY_AUDIT.md`. No schema was redesigned in either. One constraint was widened in Pass 1; Pass 2 changed no schema at all.

---

# Pass 2 — maintainability audit

## P1 — Profile bootstrap documented

| | |
|---|---|
| Files | `DATABASE_ARCHITECTURE.md` §4.1 (new) and §4; `DATABASE_IMPORT_GUIDE.md` §2; `START_HERE.md` |
| Reason | `profiles.id` referenced `auth.users` and nothing said how the row was created. Every user-table read policy calls `profile_is_visible(user_id)`, which returns false with no profile row, so a signed-up user could read none of their own data — presenting as an empty application rather than an error. |

New §4.1 gives the `handle_new_user()` trigger in full, with `SECURITY DEFINER` and `SET search_path` and why each is required. It settles the three open questions:

- **Username unknown at signup.** `username` is nullable and `raw_user_meta_data ->> 'username'` returns NULL for an absent key, so one trigger serves both flows without branching. A profile with a NULL username is fully functional; every policy keys on `id`.
- **UNIQUE handling.** Enforced at update, not at signup. `text UNIQUE` permits multiple NULLs — the one place PostgreSQL treating NULLs as distinct is wanted rather than worked around, in contrast to §2.2.
- **Do not pre-check availability.** The read policy hides other users' private rows, so a lookup reports a taken name as available and the `UPDATE` fails anyway. Attempt the write and catch SQLSTATE `23505`. Never put username selection in the trigger: a `23505` there aborts the `auth.users` insert and no account is created.

Both implementation orders now name the trigger as part of step 10.

## P2 — Backup and recovery defined

| | |
|---|---|
| Files | `DEPLOYMENT.md` §9 (new); `DATABASE_ARCHITECTURE.md` §4; `DATA_UPDATE_PROCESS.md` §8; `START_HERE.md` |
| Reason | Two documents instructed the reader to restore from backup. Neither defined one. |

Placed in `DEPLOYMENT.md` alone, with the others referencing §9.3 — the instruction was to avoid duplicated operational documentation.

§9 states PITR as a **hard requirement** rather than a precaution, with the reason stated plainly: the accepted mitigation for the polymorphic-reference risk is *detect, then restore*, so without PITR the second half does not exist and the documented protection is fictional. Detection also lags — orphans surface on the next regression run — which sets the minimum recovery window at seven days.

The recovery procedure ends where the external codes earn their place: a restored catalogue row carries a new UUID, so `visits.entity_id` is remapped through `restaurant_code`.

## P3 — `DEPLOYMENT.md` created

| | |
|---|---|
| File | `DEPLOYMENT.md` (new, 11 sections) |
| Reason | Environment variables, secrets, migration tooling, storage configuration, monitoring and local seeding were absent from all nine documents, and none belongs in the schema reference or the import guide. |

Covers environments, project creation, extensions, secrets inventory, `service_role` handling, migrations, local development, storage, scheduled jobs, backup, monitoring and a deployment checklist. It restates no schema and points at the existing documents by section.

Three operational hazards are named because each fails silently: a signed URL is a bearer token and survives a later privacy change, so expiry is short; deleting a `photos` row does not delete the object, and Storage is billed by volume; a cron job is not part of the migration set and does not survive a project rebuild.

## C1 — NULL semantics unified

| | |
|---|---|
| Files | `DATABASE_ARCHITECTURE.md` §3.3 and its column table; `START_HERE.md`; `VALIDATION_REPORT.md` |
| Reason | The column comment and `START_HERE.md` said NULL meant MICHELIN had not assessed the venue. Two paragraphs below, the same document said Wing is in a covered guide and unstarred — and Wing carries NULL. The short definition was wrong for one of the seven rows it defined, and it was the version a developer reads. |

One sentence now appears identically in all three documents:

> A NULL `michelin_stars` means the venue does not currently hold a MICHELIN star. It covers two situations: venues in countries where MICHELIN awards no stars, and venues inside a covered guide that are currently unstarred. `inclusion_reason` records why the row exists and is what distinguishes the two.

The banned phrasing appears nowhere except `MAINTAINABILITY_AUDIT.md`, which quotes it as the defect it found.

## C2 — Google ratings decision recorded

| | |
|---|---|
| File | `DATABASE_ARCHITECTURE.md` §14 |
| Reason | A pinned decision that appeared in no document. Eight of the nine accepted decisions were written down; this one was not, and storing a Google rating is a natural-looking addition for anyone wiring up the Places API. |

Four reasons recorded: volatile with no refresh trigger, third-party licensed with retention restrictions, already reachable through the Places API via `google_place_id`, and the product reason — `visits.rating` is what every statistic is built from, so a Google rating on the same screen would compete with the user's own.

## C3 — Settled architectural decisions

| | |
|---|---|
| File | `START_HERE.md` (new section) |
| Reason | The immutable decisions existed only inside two review documents, which a newcomer reasonably reads as historical artifacts rather than binding constraints. |

Nine decisions, one line each, pointing at `ARCHITECTURE_REVIEW.md` for the argument. Framed so a change can be recognised as a reversal rather than an improvement.

## C4 — Document ownership clarified

| | |
|---|---|
| Files | `START_HERE.md`; headers of `DATABASE_ARCHITECTURE.md`, `VALIDATION_REPORT.md`, `DATABASE_IMPORT_GUIDE.md` |
| Reason | The tie-breaker deferred to `DATABASE_ARCHITECTURE.md` for every disputed fact, but the facts that actually conflict are dataset counts, which that document barely mentions. |

Three subjects, three owners: schema and security to `DATABASE_ARCHITECTURE.md`, dataset statistics and row counts to `VALIDATION_REPORT.md`, orientation to `START_HERE.md`. `ARCHITECTURE_REVIEW.md` and `ENGINEERING_REVIEW.md` are labelled decision records — read for *why*, never implement from.

## T1 — Dated instructions replaced with a permanent rule

| | |
|---|---|
| Files | `DATA_UPDATE_PROCESS.md` §1 and §4; `DATABASE_IMPORT_GUIDE.md` §9.2; `VALIDATION_REPORT.md`; `ARCHITECTURE_REVIEW.md` §4 |
| Reason | Four documents carried live instructions keyed to a single date, which would read as current guidance indefinitely after passing. |

Replaced with the rule the date was an instance of: *the restaurant ranked No.1 in a given year is elevated into the Hall of Fame when the following year's list publishes, and leaves the ranking permanently at that moment.* Stated once in `DATA_UPDATE_PROCESS.md` §4 and referenced elsewhere. The update calendar no longer names a month.

The date survives in `ARCHITECTURE_REVIEW.md` §4 as a historical problem statement, which the audit permitted; that item is now marked **RESOLVED**, as is item 5.

## T2 — Volatile counts concentrated

| | |
|---|---|
| Files | `DATABASE_ARCHITECTURE.md` §2.1, §3.4, §5, §6, §9, §11, §13; `DATA_UPDATE_PROCESS.md` §11; `START_HERE.md` |
| Reason | Counts that change on the first guide update were repeated across up to five documents. A maintainer updates the ones they remember; the consistency audits compare documents to each other and pass when all are equally stale. |

Incidental counts replaced with timeless wording — "every catalogue row" rather than a total, "a small table" rather than 68, "the QA log" rather than an entry count.

**Retained deliberately:** every expected value in `DATABASE_IMPORT_GUIDE.md` §10, because assertions require numbers; everything in `VALIDATION_REPORT.md`, which owns them; the orientation table in `START_HERE.md`, now carrying a line stating the figures describe the launch dataset and naming the authoritative source; and structural counts that change only when a documented decision changes — ten shared Place IDs, seven null-star rows, eleven Hall of Fame members.

## T3 — Validation report versioned

| | |
|---|---|
| File | `VALIDATION_REPORT.md` |
| Reason | An inherently point-in-time artifact, listed as current documentation with no indication of what it described or when. |

Header carries dataset version `2026.07`, generation date, source data revision, validation version and a supersedes field. It states the report is not amended when the catalogue changes: a guide update produces a new run, a new dataset version and a new report, and a report whose version does not match the database is a historical record.

## Not implemented

**T4** (§14 completeness) and **T5** (review-document shelf-life headers) were excluded by instruction. T4 would have documented MICHELIN Selected, media and social features, which the project's YAGNI position excludes. The substance of T5 was absorbed into C4, which labels both reviews as decision records.

---

# Pass 1 — engineering review

## Blocking findings

### B1 — Row Level Security specified

| | |
|---|---|
| File | `DATABASE_ARCHITECTURE.md` |
| Section | **§15 Security and access control** (new, ~200 lines) |
| Reason | RLS was named in two implementation orders and defined nowhere. On Supabase, PostgREST exposes every `public` table over HTTP and the `anon` key ships inside the Flutter binary, so following the documentation exactly produced a database in which any user could read, edit and delete any other user's data. |

Covers all thirteen tables. Roles and what each may do; the eight catalogue tables as public-read with no write policy; a single `profile_is_visible()` function implementing the visibility rule once; per-table read, insert, update and delete policies for `profiles`, `visits`, `wishlist`, `photos` and `follows`; `service_role` behaviour and where its key may live; storage bucket policies; and verification queries.

Three implementation details are called out because each produces a working-looking but wrong result: `SECURITY DEFINER` is required to avoid `infinite recursion detected in policy`; `SET search_path = public` is required or a caller can substitute their own `profiles` table; and `WITH CHECK` is required alongside `USING` on `UPDATE` or a user can reassign their own row to another user.

Two interactions were decided rather than left open:

- **`photos.is_public` is subordinate to `profiles.is_public`.** A public photo on a private profile stays private. The reverse composition would leak the existence, timing and location of a private user's visit through a single image.
- **`follows` grants no read access.** `follows` has no approval column and a row is created unilaterally by the follower, so granting access would make `is_public = false` meaningless. Recorded as an open product decision in `ACTION_TRIAGE.md` §5a rather than solved by inventing a column.

**Supporting changes:** `DATABASE_IMPORT_GUIDE.md` §2 makes RLS step 11 of twelve and states it is not optional; §12 adds it to common mistakes. `DATA_UPDATE_PROCESS.md` §1a specifies maintenance-process authentication. `START_HERE.md` adds both to the must-know list.

### B2 — Polymorphic references: mitigation, not foreign keys

| | |
|---|---|
| Files | `DATABASE_ARCHITECTURE.md` §4, `DATA_UPDATE_PROCESS.md` §8, `START_HERE.md` |
| Reason | The architecture relied on a process promise — "the maintenance process never deletes a catalogue row" — to protect four tables PostgreSQL cannot protect. |

**The review recommended real foreign keys on `visits`, `wishlist` and `photos`. That recommendation was declined**, because polymorphic user tables are a pinned architectural decision and the instruction is to prefer documentation over schema change.

What replaced it:

1. §4 now states plainly what the database does *not* enforce and what happens when the promise fails: a `DELETE` succeeds, orphans every dependent row, raises no error, and the data cannot be reconstructed.
2. Three named mitigations, all mandatory: the catalogue is append-and-amend only; only `service_role` can write to it, so an accidental delete cannot originate from the application; the regression suite scans for orphans.
3. `DATA_UPDATE_PROCESS.md` §8 adds check 10 — four orphan queries across `visits`, `wishlist`, `photos` and `award_history` — with a note that this check is the enforcement, and that a row returned means the loss has already occurred and the response is a restore, not a cleanup.

**Residual risk, stated for the record.** These mitigations detect the failure; they do not prevent it. A developer with `service_role` access who deletes a catalogue row still destroys user data, and the regression suite reports it only on the next run. The foreign key would have made the `DELETE` fail. That trade is now documented rather than implicit, which was the actual defect.

### B3 — Import guide made executable

| | |
|---|---|
| File | `DATABASE_IMPORT_GUIDE.md` |
| Section | **§5 Staging schema** (new); §7.1, §7.2, §7.3, §8, §9.2, §10.2 rewritten; §6–§12 renumbered |
| Reason | Four objects appeared in SQL and were defined nowhere, so the guide could not be followed end to end despite claiming to allow a build from scratch. |

`staging_hotels`, `staging_restaurants`, `staging_links` and `country_bounds` now have full `CREATE TABLE` definitions in a dedicated `staging` schema, with load statements and a note on which columns are discarded. `city_text` and `country_text` are defined as staging columns and the §7.3 resolution query is rewritten to join through staging, which it previously could not do — the earlier version referenced `r.city_text` on the production table, where no such column exists.

`country_bounds` gets two population routes — Natural Earth shapefile, or `ST_MakeEnvelope` rows — plus a coverage assertion, because an unpopulated country is silently unchecked. This matters more than its size: §10.2 is the only test that catches a reversed `ST_MakePoint`, the most damaging silent error in the build.

Three problems were found while making the examples executable, and fixed:

- **`COPY` reads an empty CSV field as `''`, not `NULL`.** On a `UNIQUE` column the second empty `google_place_id` raises a duplicate key error that reads like a real collision. Every nullable text column is now wrapped in `nullif(col,'')`.
- The old §6.2 added temporary `lat`/`lng` columns to the production tables. Coordinates now come from staging and the production tables are never altered.
- §9.2 read `staging_restaurants` after §6 implied it was gone. The lifecycle is now explicit: staging is dropped in §11, after validation.

---

## Cheap fixes

### D1 — Filenames and cross-references

| | |
|---|---|
| Files | all |
| Reason | Every document referenced `DATABASE_ARCHITECTURE.md` while the file was named `DATABASE_ARCHITECTURE_v2_0.md`. No cross-reference resolved. |

Four files renamed to drop the `_v2_0` suffix. All superseded `_v1_1` copies deleted. Version now lives in git history, not in filenames — which also removes the contradiction of a document set that had scrubbed every internal version reference while announcing its version seven times in the file listing.

### D2 — Denormalised `country_code`

| | |
|---|---|
| Files | `DATABASE_IMPORT_GUIDE.md` §10.6 (new), `DATA_UPDATE_PROCESS.md` §8 check 9 |
| Reason | `country_code` on both catalogue tables is derivable through `city_id`, and nothing enforced agreement. |

No constraint added, as instructed. Two regression queries assert `hotels.country_code = cities.country_code` and the same for `restaurants`. The denormalisation stays because it buys the `(country_code, michelin_keys)` index that a join could not.

### D3 — `guide_year` given one meaning

| | |
|---|---|
| Files | `DATABASE_ARCHITECTURE.md` §3.5, `DATA_UPDATE_PROCESS.md` §3 |
| Reason | The architecture implied a guide edition; the update process said rows are written on change. Both could not hold. |

Four paragraphs now appear **verbatim in both documents**: the definition, the consequence that an unchanged venue carries one row indefinitely, and the statement that seeded 2026 rows are a launch limitation rather than historical truth, so a "held since" feature is only meaningful for post-launch changes.

### D4 — `venue_status` enum retained

| | |
|---|---|
| File | `DATABASE_ARCHITECTURE.md` §3.1 |
| Reason | The review flagged it as the schema's only enum among seven constrained vocabularies and recommended conversion to `text` with a `CHECK`. |

**Not converted, and the review's own argument was overstated.** It claimed `ALTER TYPE … ADD VALUE` has transactional restrictions; that was true before PostgreSQL 12 and the target is 15 or later. With the migration objection removed, the enum's advantages stand: `status` is read on nearly every catalogue query and is the one such column that benefits from a fixed-width representation.

§3.1 now documents why it is the exception and gives the statement for adding a value, with the caveat that a value cannot be removed once added.

---

## Maintenance risks

### M1 — `inclusion_reason` gained `hall_of_fame`

| | |
|---|---|
| File | `DATABASE_ARCHITECTURE.md` §3.3 |
| Reason | The scope rule has three qualifying conditions; the constraint offered values for two. |

**This is the one schema change in this pass.** It is one value in a `CHECK` on a table that does not yet exist, and it fixes a correctness defect rather than a preference: without it, a hall-of-fame restaurant is stored as `worlds_50_best` while being — by definition, since members are ineligible — absent from that list. Central would be recorded as something it demonstrably is not.

The column is also now documented as recording the **primary** reason a row exists, with the explicit warning that filtering it does not enumerate World's 50 Best restaurants; query the `worlds_50_best` table for that.

### M2 — `hotels_full` specified

| | |
|---|---|
| File | `DATABASE_ARCHITECTURE.md` §5 |
| Reason | The application reads the views rather than the tables, and one of the two views was a single sentence naming two columns without defining them. |

`has_michelin_restaurant`, `restaurant_count` and the four resolved reference fields now have definitions, to the same standard as `restaurants_full`.

### M3 — Scheduled refresh documented

| | |
|---|---|
| Files | `DATA_UPDATE_PROCESS.md` §13 (new), `DATABASE_ARCHITECTURE.md` §5, `DATABASE_IMPORT_GUIDE.md` §1 |
| Reason | "Refreshed nightly" named no mechanism, and `pg_cron` was absent from the extensions list. |

New §13 covers the required unique index, `REFRESH MATERIALIZED VIEW CONCURRENTLY` and what happens without it, the `cron.schedule` call with a concrete cadence, the instruction to stagger views and to avoid catalogue update windows, and verification against `cron.job_run_details`.

The failure mode is called out because it is invisible from the application: a failed refresh leaves the view serving stale contents, so the symptom is statistics that stop moving rather than an error.

### M4 — Code formats reconciled with the naming convention

| | |
|---|---|
| File | `DATABASE_ARCHITECTURE.md` §11 |
| Reason | `hotel_001` and `rest_0001` disagree in prefix style and digit width, in a section stating "never abbreviate". |

The codes are frozen — 193 QA entries and 38 manual actions reference them. §11 now states that they predate the convention, that the convention governs schema identifiers only, and gives the exact widths (`hotel_%03d`, `rest_%04d`) so a formatting script cannot generate a code that matches nothing.

---

## Correction made during this pass

While writing §7.3 of the import guide I justified joining `cities` on `country_code` by asserting that fourteen city names occur in more than one country. **That figure was fabricated.** Checked against the data: **zero** city names occur in more than one country.

The advice is still correct and the justification is now the accurate one — `cities` is unique on `(country_code, name, region)`, not on `name`, so a name-only join happens to succeed today and would break silently on the first city added to a second country. Corrected in both places it appeared.

---

## Files changed

| File | Change |
|---|---|
| `DATABASE_ARCHITECTURE.md` | §15 added; §3.1, §3.3, §3.5, §4, §5, §11 revised. Renamed. |
| `DATABASE_IMPORT_GUIDE.md` | §5 added; §1, §2, §7, §8, §9.2, §10, §11, §12 revised; §6–§12 renumbered |
| `DATA_UPDATE_PROCESS.md` | §1a and §13 added; §3 and §8 revised |
| `START_HERE.md` | Implementation order; three must-know entries. Renamed. |
| `ACTION_TRIAGE.md` | §5a added. Renamed. |
| `VALIDATION_REPORT.md` | Release note on the widened constraint. Renamed. |
| `ARCHITECTURE_REVIEW.md` | Unchanged in substance |
| `ENGINEERING_REVIEW.md` | Status banner |
| `CHANGELOG.md` | New |


---

## Current document set

| File | Role |
|---|---|
| `START_HERE.md` | Orientation, settled decisions, document ownership |
| `DATABASE_ARCHITECTURE.md` | Schema, conventions, security model |
| `DATABASE_IMPORT_GUIDE.md` | Building the catalogue |
| `DATA_UPDATE_PROCESS.md` | Guide updates, closures, regression suite |
| `DEPLOYMENT.md` | Environments, secrets, storage, backup, monitoring |
| `VALIDATION_REPORT.md` | Dataset `2026.07` validation |
| `ACTION_TRIAGE.md` | Open data work |
| `ARCHITECTURE_REVIEW.md` | Decision record — schema |
| `ENGINEERING_REVIEW.md` | Decision record — implementation readiness |
| `MAINTAINABILITY_AUDIT.md` | Decision record — maintainability |
| `CHANGELOG.md` | This file |
