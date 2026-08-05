# Deployment

Michelin Passport — environments, secrets and operations.

This document covers everything outside the database schema. It does not restate table definitions, policies or import steps.

| Subject | Document |
|---|---|
| Schema, constraints, security model | `DATABASE_ARCHITECTURE.md` |
| Building the catalogue from source files | `DATABASE_IMPORT_GUIDE.md` |
| Guide updates, closures, regression suite | `DATA_UPDATE_PROCESS.md` |
| Dataset statistics | `VALIDATION_REPORT.md` |

---

## 1. Environments

Three, all Supabase projects.

| Environment | Purpose | Catalogue | User data |
|---|---|---|---|
| `local` | development | full import | seeded fixtures |
| `staging` | pre-release verification and migration rehearsal | full import | anonymised or synthetic |
| `production` | live | full import | real |

Staging exists to rehearse migrations and catalogue updates against a full-size catalogue. A guide update applied straight to production has no rehearsal, and `DATA_UPDATE_PROCESS.md` §2 assumes one.

**Never copy production user data into another environment.** The catalogue is public and may be copied freely; `visits`, `photos` and `profiles` may not.

---

## 2. Creating a Supabase project

1. Create the project. Choose a region close to the primary user base — `location` queries are latency-sensitive and PostGIS work happens server-side.
2. Choose a plan that includes **Point-in-Time Recovery**. See §9 for why this is not optional.
3. Record the project reference, database password and API URL. The password is shown once.
4. Enable the extensions in §3.
5. Run the migrations in §5.
6. Import the catalogue — `DATABASE_IMPORT_GUIDE.md`.
7. Apply RLS — `DATABASE_ARCHITECTURE.md` §15.
8. Create the storage bucket — §7.
9. Schedule the cron jobs — §8.
10. Work through the checklist in §11.

---

## 3. Extensions

| Extension | Purpose | Required for |
|---|---|---|
| `postgis` | `geography(Point,4326)` | catalogue |
| `pg_trgm` | trigram search indexes | search |
| `pgcrypto` | `gen_random_uuid()` | every table |
| `pg_cron` | scheduled refresh | statistics |

Enable from Database → Extensions, or with the statements in `DATABASE_IMPORT_GUIDE.md` §1. `pg_cron` installs into the `cron` schema and can only be created in the database named `postgres`.

The build succeeds without `pg_cron`; the statistics views then never refresh, and the symptom is figures that stop moving rather than an error.

---

## 4. Secrets and environment variables

### 4.1 Inventory

| Name | Value | Lives in | Exposure |
|---|---|---|---|
| `SUPABASE_URL` | project API URL | client and server | public |
| `SUPABASE_ANON_KEY` | anonymous API key | Flutter client | **public — ships in the binary** |
| `SUPABASE_SERVICE_ROLE_KEY` | service role key | maintenance process only | **secret** |
| `SUPABASE_DB_URL` | direct Postgres connection string | migration tooling, CI | **secret** |
| `SUPABASE_PROJECT_REF` | project reference | CI | not sensitive |

`SUPABASE_ANON_KEY` is not a secret and does not need protecting. It is extractable from any installed build, which is precisely why every table carries RLS — see `DATABASE_ARCHITECTURE.md` §15.

### 4.2 `service_role`

**`service_role` bypasses every RLS policy in the project.** It can read every private profile, rewrite every award and delete every user row.

- It appears only in the environment of the maintenance process.
- It never appears in the Flutter application, a client `.env`, or a repository — including history. A key committed and then removed is still compromised.
- In CI it is a protected secret, unavailable to workflows triggered by forked pull requests.
- Rotate it whenever someone with access leaves, and after any suspected exposure. Rotation is immediate from the dashboard and invalidates the old key.

The only process that legitimately holds it is the one in `DATA_UPDATE_PROCESS.md`, which is the only writer to the catalogue.

### 4.3 Local configuration

Commit a `.env.example` listing every variable with empty values. Never commit `.env`. Add both `.env` and `.env.local` to `.gitignore` before the first commit, not after.

---

## 5. Migrations

Numbered, forward-only, applied through the Supabase CLI.

```bash
supabase login
supabase link --project-ref "$SUPABASE_PROJECT_REF"

supabase migration new add_status_note   # creates a timestamped file
supabase db push                          # applies pending migrations
supabase migration list                   # local against remote
```

**Never edit a migration that has been applied to any shared environment.** Correct it with a new one. An edited migration produces environments that report the same version and hold different schemas, and nothing detects it.

Order of application matters and is fixed by `DATABASE_IMPORT_GUIDE.md` §2. A migration that creates a table referencing `cities` must run after the one that creates `cities`; the CLI orders by filename timestamp and does not check dependencies.

**Rehearse every migration on staging first**, against a full-size catalogue. A migration that takes milliseconds on an empty table can take a lock on a populated one.

---

## 6. Local development

```bash
supabase start                            # local Postgres, Auth, Storage
supabase db reset                         # re-applies every migration from scratch
```

`supabase db reset` is the fastest way to verify that the migration set builds a correct database from nothing. Run it before every release; it is the only check that catches a migration set which works incrementally but not from empty.

Seed the catalogue by running `DATABASE_IMPORT_GUIDE.md` against the local instance. Seed user data with fixtures — never with a production extract.

Create at least two test users with different `is_public` values. Most RLS defects are invisible with one user, because a policy that returns everything and a policy that returns your own rows look identical.

---

## 7. Storage

Photographs are stored in Supabase Storage. The database holds only `photos.storage_path`.

### 7.1 Bucket

Create a bucket named `photos`, **private**. A public bucket serves every object to anyone holding the URL, which makes the policies on the `photos` table decorative: the metadata is protected and the image is not.

### 7.2 Path convention

```
photos/{user_id}/{photo_id}.jpg
```

The owner's UUID is the first path segment. The policies below depend on it, so the convention is load-bearing rather than tidiness.

### 7.3 Policies

Storage has its own RLS on `storage.objects` and inherits nothing from the `public` schema. These mirror `DATABASE_ARCHITECTURE.md` §15.6.

```sql
CREATE POLICY photos_owner_read ON storage.objects
  FOR SELECT TO authenticated
  USING (bucket_id = 'photos'
     AND (storage.foldername(name))[1] = auth.uid()::text);

CREATE POLICY photos_owner_write ON storage.objects
  FOR INSERT TO authenticated
  WITH CHECK (bucket_id = 'photos'
          AND (storage.foldername(name))[1] = auth.uid()::text);

CREATE POLICY photos_owner_delete ON storage.objects
  FOR DELETE TO authenticated
  USING (bucket_id = 'photos'
     AND (storage.foldername(name))[1] = auth.uid()::text);
```

### 7.4 Serving images

Third-party visibility is decided by the `photos` table, not by Storage. The application checks visibility through `photos`, then issues a **signed URL** for the object.

Use a short expiry — minutes, not days. A signed URL is a bearer token: anyone holding it has the object until it expires, regardless of any later change to `is_public`.

### 7.5 Orphans

Deleting a `photos` row does not delete the object, and deleting the object does not remove the row. Delete both, in that order, and reconcile periodically — Storage is billed by volume and an orphaned object is invisible to the application forever.

---

## 8. Scheduled jobs

`pg_cron` runs the materialised view refreshes. Job definitions, cadence and the reasoning are in `DATA_UPDATE_PROCESS.md` §13.

Operational requirements:

- Schedule jobs in UTC. `cron.schedule` does not honour a session timezone.
- Stagger jobs by several minutes. Concurrent refreshes compete for the same I/O.
- Keep them outside any window in which a catalogue update runs. A refresh reading mid-update produces a statistic matching neither catalogue state.
- Verify after every deployment: a cron job is not part of the migration set and does not survive a project rebuild unless it is re-created.

```sql
SELECT jobid, jobname, schedule, active FROM cron.job;
```

---

## 9. Backup and recovery

**Backup is an operational responsibility, not a schema feature.** Nothing in the database creates or verifies a backup, and no constraint compensates for its absence.

### 9.1 Why this is not optional here

`visits`, `wishlist` and `photos` reference the catalogue polymorphically through `entity_type` and `entity_id`, so PostgreSQL cannot enforce those references — see `DATABASE_ARCHITECTURE.md` §4. A `DELETE` against `hotels` or `restaurants` succeeds and silently orphans every dependent user row.

The accepted mitigation for that risk is **detect, then restore**: the regression suite in `DATA_UPDATE_PROCESS.md` §8 scans for orphans, and recovery is a restore. If PITR is not enabled, the second half of that mitigation does not exist and the documented protection is fictional.

Detection also lags. Orphans are found on the next regression run, which may be hours or days after the deletion, so a backup window measured in days is not sufficient.

### 9.2 Requirements

| | |
|---|---|
| Point-in-Time Recovery | **Enabled.** Requires a paid plan. |
| Recovery window | 7 days minimum, so a deletion found on the next weekly run is still recoverable |
| Daily backups | Retained per plan, in addition to PITR |
| Restore granularity | Whole project to a timestamp — Supabase PITR is not table-level |
| Verification | Restore to a scratch project at least once, before launch and after any plan change |

An unverified backup is an assumption. The only evidence that a restore works is a restore that worked.

### 9.3 Recovering from an accidental catalogue delete

1. Stop the maintenance process. A second run may compound the damage.
2. Note the timestamp of the deletion from `cron.job_run_details` or the deployment log.
3. Restore to a **scratch project** at a timestamp immediately before it. Never restore over production first — a restore is destructive and discards everything written since.
4. Extract the deleted catalogue rows and the affected user rows from the scratch project.
5. Reinsert into production. Catalogue rows keep their `hotel_code` or `restaurant_code`; UUIDs will differ, so remap `visits.entity_id` through the code.
6. Re-run the regression suite.

Step 5 is the reason external codes exist. Without them a restored catalogue row is a new UUID and every reference to the old one is unrecoverable.

---

## 10. Monitoring

The failure modes worth alerting on are the silent ones. Each of these fails without producing an application error.

| Signal | Source | Why |
|---|---|---|
| Failed cron job | `cron.job_run_details` where `status <> 'succeeded'` | A failed refresh serves stale data indefinitely |
| Regression suite failure | CI | Check 10 detects orphaned user rows |
| Table without RLS | the query in `DATABASE_ARCHITECTURE.md` §15.9 | A new table defaults to no policy and is world-writable |
| Auth error rate | Supabase dashboard | A broken profile trigger presents as an empty app, not an error |
| Storage volume growth | Supabase dashboard | Orphaned objects accumulate silently and are billed |
| Database size and connection count | Supabase dashboard | Standard capacity signals |

Run the RLS check in CI, not only at deployment. It is the one check whose failure is a data breach rather than a defect.

---

## 11. Deployment checklist

Every environment, in order.

**Project**
- [ ] Project created in the correct region
- [ ] Plan includes PITR
- [ ] Credentials recorded in the secret store

**Database**
- [ ] `postgis`, `pg_trgm`, `pgcrypto`, `pg_cron` enabled
- [ ] Migrations applied; `supabase migration list` shows no drift
- [ ] Catalogue imported per `DATABASE_IMPORT_GUIDE.md`
- [ ] Validation queries in §10 of that guide return the expected values
- [ ] Staging schema dropped

**Security**
- [ ] RLS enabled on every table — §15.9 first query returns nothing
- [ ] No catalogue table has a write policy — §15.9 second query returns nothing
- [ ] Every `SECURITY DEFINER` function pins `search_path` — §15.9 third query returns nothing
- [ ] Policies tested as `authenticated`, not as the table owner
- [ ] Profile trigger present; a test signup produces a `profiles` row
- [ ] `service_role` key absent from the client build and from the repository

**Storage**
- [ ] `photos` bucket created and **private**
- [ ] `storage.objects` policies applied
- [ ] Signed URL expiry configured

**Operations**
- [ ] Cron jobs scheduled, staggered, and visible in `cron.job`
- [ ] Materialised views populated once before the first `CONCURRENTLY` refresh
- [ ] PITR verified by an actual restore to a scratch project
- [ ] Alerts configured per §10
- [ ] `.env` and `.env.local` in `.gitignore`

**Regression**
- [ ] Suite in `DATA_UPDATE_PROCESS.md` §8 passes
- [ ] `supabase db reset` builds a correct database from empty
