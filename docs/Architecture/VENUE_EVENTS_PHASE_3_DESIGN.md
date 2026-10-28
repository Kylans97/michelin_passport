# Venue events — phase 3 design and migration plan

Written 2026-10-28, for review before any migration is drafted. Builds on
`VENUE_EVENTS_AND_ADMIN_REVIEW_PLAN.md` §3.2–3.3. Nothing here is applied
or committed.

---

## 1. What production has today

Checked read-only against production on 2026-10-28.

- **Events:** 28 rows, all `published`, and **none has `submitted_by` set**.
  No event has ever been written from the app. Every app query on `events`,
  the three link tables and `event_tag_assignments` is a read (checked in
  `lib/`). Changing or dropping the write policies below can't strand a
  row, and doesn't break a shipped build.
- **The time model** is already in the schema:
  - `start_date`/`end_date` are NOT NULL;
  - `start_time`/`end_time` are nullable;
  - `start_at`/`end_at` are nullable and stored only when a time is known;
  - `timezone` is NOT NULL and validated as a real IANA name by a trigger;
  - `end_date >= start_date` always, and `end_at >= start_at` when both
    exist.
- **Write policies, all keyed on `submitted_by = auth.uid()`:**
  - `events_claimant_insert` lets anyone signed in insert a `submitted`
    event with any field values;
  - `event_*_claimant_insert` (×3) add a link to it;
  - `events_owner_update` edits it;
  - `event_*_host_edit_insert` and `event_*_host_delete` (×3) handle
    participant links.
  - `enforce_event_host_edit_columns` locks only `moderation_status` and
    `submitted_by`. Dates, the window and the venue are not checked at
    all.
- **Tags:** `event_tag_assignments` has no client write policy at all.
  The 6 V1 tags exist with the slugs `wine`, `winemaker`, `wild_game`,
  `guest_chef`, `four_hands` and `charity`.
- **Event types:** the check allows 10 types. The V1 form offers 7:
  dinner, lunch, festival, gala, tasting, brunch and party. The other three
  (`market`, `experience`, `other`) stay valid for curated rows.
- **Notifications:** the `type` and `subject_type` checks list every
  allowed value, so `event_approved`, `event_rejected` and the subject
  `event` must be added to them.
- **Admin email:** `notify-venue-submission` is called by a pg_net trigger
  with `{submission_type: TG_TABLE_NAME, row}`. It looks up the venue from
  the row's `venue_type`/`venue_id`, which an `events` row doesn't have.
- **Venue location:**
  - `restaurants_full` and `hotels_full` carry `latitude`/`longitude`,
    `address`, city and country;
  - **private chefs have only `home_city`/`home_country_code`**, with no
    address or coordinates;
  - **no venue, and no country, stores a timezone.**

That last point means the plan's "prefilled from the venue (…, timezone)"
has nothing to read from. Decision 1 below is about that.

---

## 2. Decisions needed before drafting

Each has a recommendation; nothing is drafted until you've chosen.

1. **Where an event's timezone comes from.** Venues store none.
   - **A (recommended):** add `countries.default_timezone`, filled for the
     58 countries that have venues. Each value comes from the IANA zone
     table, not from memory, and gets a Michelin_Database CHANGELOG entry.
     - The form uses it as the default.
     - For a country with more than one zone (Spain with the Canaries,
       Portugal with the Azores and Madeira, France overseas), the form
       asks instead of assuming.
   - **B:** the app keeps a country → timezone map in code. That's
     quicker, but it's data outside the database, the one place this
     project trusts.
   - **C:** derive it from the coordinates. That's exact, but needs a
     timezone-boundary library or service, which is heavy for this.
2. **What "at most a year ahead" covers.**
   - **Recommended:** both the start and the end date fall between today
     and today + 1 year, in the event's own timezone. One rule, and it
     needs no second number.
   - Alternative: only the start date is limited, and the end date is
     limited by a maximum length (a festival may run 10 days, say).
3. **Participants (the guest chef or restaurant on a four-hands).**
   - **Recommended:** not part of phase 3. The venue writes the event and
     its own host link only.
   - Drop the existing participant write policies now, since nothing uses
     them and they still key on `submitted_by`. Add participants later
     through an RPC with the §19 approval.
   - Alternative: move those policies onto host-manager rights now and
     leave them in place.
4. **Who gets the approved/rejected notification.**
   - **Recommended:** the submitter, the same as claims, about texts and
     photos.
   - Alternative: every active manager of the host venue.
5. **Edits to a published event.** As the plan says, they go live at once
   and are recorded. Recommended for the admin side:
   - each edit appears in Review as "changed since approval", showing old
     → new per field;
   - the admin either **marks it seen**, or **takes the event offline**
     with a note. Taking it offline sets it to `rejected`, which hides it
     and notifies the venue.
6. **Coordinates.**
   - **Recommended:** always required. For a restaurant or hotel they
     come prefilled from the venue. A private chef, who has none, sets a
     map pin for every event.
   - Alternative: allow an event with no coordinates. Events without them
     then never appear in nearby or map views.

---

## 3. Migration A — `20261018120000_add_venue_event_submission.sql`

Named after the highest migration on `main` and on the open
`feature/editorial-selection` branch (`20261017130000`). It covers the
schema, the RPCs and the policies. If decision 1 is A, Migration B
(`countries.default_timezone`) comes first and is a data change with its
own CHANGELOG entry.

### 3.1 Schema

- `events`: add `reviewed_at timestamptz`, `reviewed_by uuid` (references
  profiles, on delete set null) and `review_note text`. All three are
  nullable, and no existing row changes.
- **New table `event_edits`:**
  - columns: `id`, `event_id` (cascade), `edited_by`, `edited_at`,
    `changes jsonb` (`{field: {old, new}}`), `seen_at` and `seen_by`;
  - RLS is on, with **no client policy or grant**. It is written only by
    the update RPC and read only by the admin queue.
- `enforce_event_host_edit_columns`: extended to the three review columns.
  No client update path is left (see 3.3), but the trigger stays as
  defence in depth.
- Notification checks: add `event_approved`, `event_rejected`, and the
  subject type `event`.

### 3.2 Functions

All of these are `SECURITY DEFINER`, each with its own `revoke execute …
from public, anon` in this migration. The client-facing ones are granted
to `authenticated`.

**Validation.** One private function, `validate_venue_event(...)`, used by
both submit and update, so the rules can't drift apart. It checks:

- the name (1–200 characters) and description (1–5,000) aren't empty;
- the type is one of the 7 V1 types, and every tag slug is one of the 6;
- the date window (per decision 2), using `(now() at time zone
  p_timezone)::date` as "today where the event happens";
- `end_time` only alongside a `start_time`;
- for a single-day event, `end_time > start_time`. An overnight event has
  to end on the next date;
- the coordinates are within range, and the country exists;
- the ticket URL, if given, starts with `https://`.

**Computing instants, never inventing them.** `start_at` is set only when
`start_time` is known: `(start_date + start_time) at time zone timezone`.
`end_at` is set only when `end_time` is known, the same way from
`end_date`. Otherwise both stay null.

**Functions the venue calls:**

| Function | What it does |
|---|---|
| `submit_venue_event(p_venue_type, p_venue_id, …fields, p_tag_slugs text[], p_at_venue boolean)` | Requires `is_active_venue_manager(p_venue_type, p_venue_id)`. Validates the fields, then in one transaction inserts the event as `submitted` (with `submitted_by = auth.uid()` and status `upcoming`), its **host link** (`is_host = true`, and `is_venue = p_at_venue`) and its tags. Queues the admin email. Returns the new id. |
| `update_venue_event(p_event_id, …same fields)` | Requires an active manager of one of the event's host venues (this is the decided edit-rights change). Validates the same way, then rewrites the fields and replaces the tags. What happens next depends on the event's status. **Submitted** stays submitted, and the queue shows the latest version. **Rejected** goes back to `submitted`, which is the resubmit, and the email is sent again. **Published** stays live, and an `event_edits` row records what changed; an unchanged save records nothing. **Archived** is refused. |
| `cancel_venue_event(p_event_id)` | Same rights as update. Sets `cancelled_at`; the existing shim sets `status`. Needs no review. |
| `get_venue_events(p_venue_type, p_venue_id)` | Requires a manager. Returns every event the venue hosts, in any status, including `review_note`. Every other manager of the venue sees them too, which `events_own_submission_read` (submitter only) can't do. |

**Functions the admin calls.** Each checks `is_admin()` and records
`auth.uid()`:

| Function | What it does |
|---|---|
| `admin_approve_event(p_event_id)` | Moves a `submitted` event to `published`, sets the review columns, and sends an `event_approved` notification. |
| `admin_reject_event(p_event_id, p_note)` | Moves a `submitted` or `published` event to `rejected`. Requires a note, sets the review columns, and sends `event_rejected`. Used on a published event, it takes it offline (decision 5). |
| `admin_mark_event_edit_seen(p_edit_id)` | Sets `seen_at`/`seen_by` on the edit. |

**The review queue.** `get_review_queue()` is recreated with two new
kinds:

- `venue_event`, a submitted event, with the event's fields;
- `venue_event_edit`, an unseen edit, with its changes.

Its return columns change, so it needs a drop and a create. Shipped builds
still work: `ReviewItem.fromJson` skips kinds a build doesn't know, and the
Profile badge counts only the parsed items.

**The admin email.** It is queued from inside the submit and update RPCs.
It doesn't use a trigger on `events`, because there the host venue isn't
known yet. The payload is `{submission_type: 'events', row: event +
venue_type + venue_id}`. The call has its own exception block, the same
best-effort rule as today, so a failed email never blocks the submission.

### 3.3 Policies

- **Dropped:**
  - `events_claimant_insert`, `events_owner_update`, `event_*_claimant_insert`
    (×3), so every venue write goes through the RPCs. These were the open
    insert and update paths with no window or field checks.
  - Per decision 3, also `event_*_host_edit_insert` and
    `event_*_host_delete` (×3).
- **Kept:** the public reads, `events_own_submission_read` and
  `event_*_own_submission_read`. They are harmless, and they still let the
  submitter see their row.
- **Grants:** `anon` keeps its table-level grants on `events`, as today.
  RLS is what protects the table, and with no anon policy left for
  insert, update or delete, there is no anon write path.

### 3.4 Edge Function

`notify-venue-submission` learns `submission_type: 'events'`. It uses the
same venue lookup, with a subject like "New event from Flore: 4 Hands
Dinner …" and the date, the time only if known, and the location. It is
deployed after the migration. Until then an event's email fails softly, and
the submission itself still goes through.

---

## 4. App changes (the phase 3 build)

- **The Events screen**, opened from the landing page, switches from the
  public hosted-events list to `get_venue_events`. It groups events by
  status (awaiting review, not approved with the note, live, cancelled)
  and adds **Create an event**.
- **The event form:**
  - title, description and type (the 7 V1 types);
  - tags, a ticket URL, admission type and an admission note;
  - a date, then an optional start time, an end time only once a start is
    set, and an optional end date for multi-day events;
  - a location prefilled from the venue, with "Held somewhere else" to
    change it with a map pin;
  - the timezone per decision 1.
  - The same window and time rules are checked in the form, so the RPC's
    error is a last line of defence rather than the normal path.
- **Editing** uses the same form, prefilled. A published event shows
  "Changes go live straight away". Rejected events show the note and
  "Resubmit". **Cancel** asks for confirmation.
- **Review:** two new item kinds.
  - A submitted event shows a preview through the real
    `EventDetailScreen`, given the event directly. The settled hero stays
    as it is.
  - A changed event shows old → new with "Mark as seen" and "Take
    offline".
- **Notifications:** `event_approved` and `event_rejected` open the
  venue's Events screen.

---

## 5. Proof before applying, then rollout

The same method as phase 1:

1. Replay the full stack locally (`supabase start` on a scratch copy).
2. Run a scenario script covering:
   - a non-manager is refused;
   - dates in the past and more than a year ahead (in the event's own
     timezone, including just around midnight) are refused;
   - an end time without a start time, and single-day end before start,
     are refused;
   - an unknown time stays null in `start_at`/`end_at`;
   - the host link and tags are written in the same transaction as the
     event;
   - a second manager can edit, and a revoked manager can't;
   - rejected → edit → submitted works;
   - an edit to a published event writes one `event_edits` row, and an
     unchanged save writes none;
   - cancel works;
   - admin approve and reject send their notifications, and a non-admin
     is refused;
   - the queue includes both new kinds;
   - direct table writes from `authenticated` are refused.
3. Check `has_function_privilege('anon', …)` on every new function.
4. Compare definition hashes between the stepwise run and a fresh replay.
5. **Rollout order:** the migration, then deploying the Edge Function,
   then the build. Installed builds are unaffected, because they never
   wrote events.

---

## 6. Changes while drafting (2026-10-28)

All six recommendations were accepted. Drafting and the local replay
changed these points:

- **Timezones are a list, not one default.** The column is
  `countries.timezones text[]`, holding every zone IANA's `zone.tab`
  (tzdata 2025b) lists for the country. With one zone, the form uses it as
  the default. With several, the form asks. The RPCs refuse a timezone
  outside the event country's list.
  - The count is 44 countries with one zone and 14 with several.
  - France has only `Europe/Paris`, because its overseas regions have
    their own country codes, so the France example in §2 was wrong.
  - All 149 zones exist in production's Postgres.
- **The event tags were never in migration history.** All six exist only
  in production (inserted 2026-08-22), so a fresh replay had none.
  Migration A seeds them with production's exact rows, ids included,
  using `on conflict do nothing`, which is a no-op on production. Tag
  validation now checks the `event_tags` table rather than a hardcoded
  list.
- **Installed builds throw on an unknown notification type**
  (`AppNotificationType.fromWire`), which would empty their whole
  Notifications screen. So `get_notifications()` and
  `get_unread_notification_count()` keep returning only the types they
  already knew, and the phase 3 build reads the new `_v2` functions.
  - `_v2` is built from production's live definition, which has one more
    column than the migration that created it:
    `20261012120000`'s `friendship_status`.
  - The phase 3 build should also make the parser skip unknown types, so
    this can't recur.
- **"At the venue" uses the venue's verified location.** The RPC copies
  the name, address, city, country and coordinates from
  `restaurants_full`/`hotels_full`, and ignores whatever the client sent.
- **Also added:**
  - `events.submitted_at`, the queue's date; it resets on resubmit;
  - an admin read policy on events and the link tables, for the review
    preview;
  - an event already under way may keep its past start date when edited,
    but can't be moved into the past.

## 7. Not in phase 3

- event photos (phase 4);
- participants and guest-chef links (decision 3);
- Mantelier's own events with no venue host. The RPCs don't rule them out:
  they're a later admin-only path that creates an event with
  `external_host_name`.
