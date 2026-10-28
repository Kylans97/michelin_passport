# Venue events and in-app review — plan

Written 2026-10-28. Decided by the product owner the same day:

- Venues (restaurants, hotels) and private chefs create their own events from Manage venue.
- A new event is **reviewed before it is visible**, and so are event photos.
- A venue picks the event's date itself, **at most one year ahead**.
- After approval the venue can keep editing the event: text, photos, start and end, location.
- Up to **five event photos**, separate from the venue's profile photos.
- Review moves **out of the Supabase dashboard into the app**, with the real preview of the screen being reviewed (option A of the day's write-up).

Also decided 2026-10-28:

- **Any active manager of the host venue may edit its events**, not only the person who created them (§3.3).
- **An admin may approve their own submissions.** There is one admin today, and Mantelier may organise its own events.
- **The product owner's own account is the first admin.**

Nothing in this plan is built. Each phase below goes the way the photo features did: migration drafted and proven on a local replay, app change in the working tree, tests, a look on the simulator, and only then into the repo and onto production — each step on explicit approval.

---

## 1. What already exists

**Events, database.** The self-management groundwork from `EVENTS_V2_ARCHITECTURE.md` §19–§20 is partly in production:

| Piece | Where | State |
|---|---|---|
| `moderation_status` (draft / submitted / published / archived / rejected), public read gated on `published` | `20260819140000` | Applied; all 28 events are `published` |
| `submitted_by`, insert policy (`submitted_by = auth.uid()`, `moderation_status = 'submitted'`), own-submission read | `20260828120000` | Applied, never used (no submitter on any event) |
| Owner UPDATE policy on `submitted_by`, plus a trigger that keeps hosts off `moderation_status`/`submitted_by` | `20261008120000` | Applied |
| `cancelled_at` (host may cancel without review) | `20261008120000` | Applied |
| `approved_at` on the three join tables; new links on a published event land pending | `20261008120000` | Applied |
| Time model (date-only, start known, fully timed, multi-day), `timezone` NOT NULL and validated | Events V2 time-precision and timezone migrations | Applied; settled in CLAUDE.md |

Not built: the submit / approve / reject RPCs (build order step 4), the edit-notification trigger (step 7), any app screen for creating or editing an event, more than one event image (`events.image_url` is a single column).

**Review today.**
- **Claims and about texts:** `approve_venue_claim`, `reject_venue_claim`, `approve_venue_about`, `reject_venue_about`. All take `p_reviewed_by` and are executable by `service_role` only; run as SQL snippets from the dashboard (`docs/Engineering/VENUE_CLAIM_OPERATIONS.md`).
- **Photos:** `approve_venue_photo` / `reject_venue_photo`, the same way. The `publish-venue-photo` Edge Function already does the copy from the private bucket to `catalogue-media` and the approval in one step. It's called by hand with `curl` and its own webhook secret.
- **Notifications** to the venue on every outcome already exist (`venue_claim_*`, `venue_about_*`, `venue_photo_*`), and so do admin emails on every new submission (`notify-venue-claim`, `notify-venue-submission`).

**Manage venue today.** One long screen: about text, the photo list with framing, the card photo, open submissions, preview, contact line.

---

## 2. Phase 1 — In-app review (first, because events depend on it)

### 2.1 The rule change

CLAUDE.md, *Venue permissions*: "There is no in-app admin identity and none is planned — review happens through the dashboard with `service_role`."

Replace with, dated 2026-10-28 and decided by the product owner:

> Review happens in the app, by a small, explicit set of admins listed in `public.admins`. `is_admin()` is the only source of that permission. Every review action is a `SECURITY DEFINER` RPC that checks `is_admin()` and records `auth.uid()` as the reviewer; there is no client write to any moderation column. The dashboard and `service_role` remain available as the fallback, not the normal path. `service_role` still never appears in client code.

`VENUE_CLAIM_OPERATIONS.md` keeps its snippets as that fallback, marked as such.

### 2.2 Database (one migration)

- `public.admins (user_id uuid primary key references profiles(id), added_at, added_by)`. RLS on, no client policies at all; rows added by hand in the dashboard, which is the one step that stays there on purpose.
- `is_admin()` — `SECURITY DEFINER`, `stable`, `revoke … from public, anon` in the same migration (CLAUDE.md's standing rule), granted to `authenticated`.
- `get_review_queue()` — admin-only. One list across every kind, oldest first: venue claims, about texts, photos, and (from phase 3) events, event photos and pending participant links. Each row carries what the list needs to show (kind, venue, submitter, submitted at).
- Admin wrappers around the existing review functions: `admin_approve_venue_claim`, `admin_reject_venue_claim`, `admin_approve_venue_about`, `admin_reject_venue_about`, `admin_reject_venue_photo`. Each checks `is_admin()` and passes `auth.uid()` as `p_reviewed_by`. The existing functions stay unchanged and dashboard-only, so the fallback path keeps working.

### 2.3 Photo approval

`publish-venue-photo` gains a second way in. Alongside its webhook secret, it accepts the caller's own JWT, checks `is_admin()` for that user, and uses their id as the reviewer. Its copy → verify → approve order, and its refusal to take a URL from the caller, stay exactly as they are.

### 2.4 App

- Profile gets a **Review** row, shown only when `is_admin()` is true, with a count of what is waiting.
- **Review queue:** grouped by kind, oldest first.
- **One review screen per kind**, each with the real preview:
  - **about text:** the real venue page with the new text (the owner-preview override params already do this);
  - **photo:** the photo in its real header and card frames, with its framing applied, plus the venue page with it in place;
  - **claim:** the submitted details;
  - **event:** the real Event detail screen (phase 3).
- **Approve**, or **Reject with a note.** The note reaches the venue through the notifications that already exist.

### 2.5 Proof

Local replay: a non-admin is refused by every RPC, an admin's approval records their id, and photo publish works through both the JWT and the secret path. Tests for the queue and each review screen. Tried on the simulator with the developer's account added to `admins`.

---

## 3. Phase 2 and 3 — Venue landing page, then events

### 3.1 Venue landing page (phase 2, app only)

My Venues → a venue opens a landing page:

- the venue's name and its card photo;
- **Profile** — the about text;
- **Photos** — the photo list, framing and the card photo, as today;
- **Events** — new, see below;
- **Preview my page**, and the contact line.

It's the same content as the current screen, split up and nothing removed. Private chefs get the same page.

### 3.2 Creating an event (phase 3)

**Form:**
- **Required:** title, description, type (the V1 types: Dinner, Lunch, Festival, Gala, Tasting, Brunch, Party).
- **Optional:** tags (Wine, Winemaker, Wild/Game, Guest Chef, Four Hands, Charity), ticket URL, admission note.
- **Date and time:** the settled time model, exactly:
  - a date is required;
  - a start time is optional, and an end time optional only once a start exists;
  - multi-day events are allowed;
  - **an unknown time is never filled in for the venue** (CLAUDE.md).
- **Location:** prefilled from the venue (name, address, coordinates, timezone), and can be changed for an event held elsewhere. A changed location needs coordinates, set with a map pin. The timezone stays the venue's unless the pin lands in another country, in which case it is asked for.

**Rules, enforced in the database as well as in the form:**
- **The date window:** the start date may not be in the past, and may be **at most one year ahead**. "One year" is measured in the event's own timezone, so "today" means today where the event happens.
- **The host is the venue:** the event's host link is the venue itself (`is_host`), created together with the event.

**How it's written:** one `SECURITY DEFINER` RPC, `submit_venue_event`. It checks `is_active_venue_manager()` for the host venue, validates the date window and time model, and inserts the event as `submitted` with its host link in one transaction. It replaces the two loose insert policies for venue use. Then the admin email (`notify-venue-submission` extended) and a place in the review queue.

**Review:** `admin_approve_event` publishes it, and `admin_reject_event` sends it back with a note. Rejected events stay visible to the venue, edited and resubmitted from there. New notification types: `event_approved`, `event_rejected`.

### 3.3 Editing an event

- **What changes:** after approval, edits go live straight away (title, description, dates and times within the same window, location, tags, ticket URL), as §19 and `20261008120000` already intend.
- **Every edit to a published event is recorded** for the admins (build order step 7): it appears in the review screen as "changed since approval", with what changed. Removing an already-approved participant link does too, per §19's note.
- **Edit rights (decided):** `events_owner_update` moves from `submitted_by = auth.uid()` to "an active manager of one of the event's host venues" (`is_active_venue_manager()`, the single source of permission). A manager who leaves can no longer edit, and a new manager can. `submitted_by` stays as the record of who submitted.
- **Cancel:** the venue can cancel without review (`cancelled_at`, already in place).
- **Locked for the venue:** the moderation columns stay locked by the existing trigger, extended to any new review columns (`reviewed_at`, `reviewed_by`, `review_note`).

---

## 4. Phase 4 — Event photos

- **Up to five per event**, separate from the profile photos. A new `event_photos` table: `event_id`, `image_url`, `display_order`, plus header framing and a card choice with a card crop, matching the venue photo tables so the same editor, `FramedImage` and RPCs apply. Public read follows the event's own publication.
- **Submissions are reviewed:** `venue_photo_submissions` gains a nullable `event_id`. A photo with one belongs to that event and counts against its own cap of five, not the venue's. That keeps the upload pipeline (validate, strip EXIF, hash, duplicate check, upload), the queue and the `publish-venue-photo` path the same. The function then publishes into `event_photos` instead of the venue's table.
- **Order, framing and the card photo:** these change through the same kind of RPCs as for venues, live without review.
- **The app:** the event detail hero (`EventDetailHero`, kept separate per CLAUDE.md) becomes a gallery. Event cards use the event's card photo, then `events.image_url`, then the placeholder.

---

## 5. Order and size

| Phase | What | Database | App |
|---|---|---|---|
| 1 | In-app review | 1 migration + Edge Function change | Review row, queue, review screens |
| 2 | Venue landing page | — | Split Manage venue |
| 3 | Venue events | 1–2 migrations | Events list, form, edit, review screen |
| 4 | Event photos | 1 migration + Edge Function change | Upload, framing, gallery |

Phase 2 can be built alongside phase 1, since it touches no database and no review code. Phase 3 needs phase 1's review queue. Phase 4 needs phase 3.

Rollout per phase is the usual: migration first, then the build that reads it. Installed builds are unaffected throughout, because nothing they read is removed or renamed.

## 6. Decided, and still open

- **Edit rights:** any active manager of a host venue (decided).
- **An admin's own submissions:** allowed (decided). The RPCs do not refuse a reviewer who manages the venue in question.
- **Who goes into `admins`:** the product owner's account (decided). Added by hand in the dashboard when phase 1 is applied.
- **Mantelier's own events:** an admin may later want to organise events as Mantelier, not as a venue. That is an event with no canonical host and `external_host_name` = Mantelier. It is not part of phase 3's venue form, but phase 3's RPCs should not rule it out.
