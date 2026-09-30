# Venue claim and submission operations

One-line SQL, run in the Supabase Dashboard's SQL Editor, for every
approve/reject decision a human reviewer makes: a venue claim, a
venue-supplied "about" text submission, or a venue-supplied photo
submission. Each operation is a single `select * from <function>(...)`
call (photo approval is a single `curl` call instead, for reasons below)
— the function does the row update *and* whatever else approval requires
(granting a permission, nothing else for about text, publishing a photo)
in one transaction or one guaranteed-ordered sequence, and raises/reports
a clear error instead of quietly doing nothing if the row isn't in a
state it can act on.

Six SQL functions (`approve_venue_claim`, `reject_venue_claim`,
`approve_venue_about`, `reject_venue_about`, `approve_venue_photo`,
`reject_venue_photo` — added in
`supabase/migrations/20261005120000_add_venue_approval_rpcs.sql`) replace
the hand-written `insert`/`update` snippets this file used to hold. They
are `SECURITY DEFINER` and revoked from `public`, `anon`, and
`authenticated` — only callable from here (the Dashboard, as
`service_role`/`postgres`), never from the app. One Edge Function
(`publish-venue-photo`, added after and layered on top of
`approve_venue_photo` — see the Photo submissions section below) is now
the normal way to publish a photo, closing a real gap the SQL function
alone couldn't: it derives the destination itself instead of trusting a
human-supplied URL. There is still no in-app admin identity and none is
planned; review continues to happen entirely through this file and the
Dashboard.

## Finding your own `profiles.id`

Every call below needs the reviewer's own `profiles.id` (not their
`auth.users.id` — they're the same value, `profiles.id` is just the
FK-friendly name here) as the `p_reviewed_by` argument, so the review is
attributable to a real person rather than left null or hardcoded. Look it
up once:

```sql
select id, username, display_name from public.profiles where username = '<your username>';
```

Every `<your profiles.id>` below is that value — a placeholder, not a
real id.

## Claims

`p_venue_type` is `'restaurant'`, `'hotel'`, or `'private_chef'` — claims
live in three separate tables, so the function needs to be told which one
to look in.

Approve — sets the claim's `status`/`reviewed_at`/`reviewed_by` *and*
inserts the matching `venue_managers_*` row (`granted_by` set to the same
reviewer) in one transaction. Raises if the claim isn't currently
`pending`, or if that user already holds an active (non-revoked) manager
grant on that venue — it never silently grants a second one.

```sql
select * from public.approve_venue_claim('restaurant', '<the claim''s id>', '<your profiles.id>');
```

Reject — sets `status = 'rejected'`, records the reviewer and a note.
Raises if the claim isn't currently `pending`.

```sql
select * from public.reject_venue_claim('restaurant', '<the claim''s id>', '<your profiles.id>', '<why>');
```

## About-text submissions

No `p_venue_type` argument — `venue_about_submissions` is one table
carrying its own `venue_type`/`venue_id`, resolved from the row itself.

Approve — sets `status`/`reviewed_at`/`reviewed_by`. Nothing else to do:
`venue_about_current` resolves "latest approved" by `reviewed_at`, so this
one row automatically supersedes any earlier approved submission for the
same venue without needing to touch it.

```sql
select * from public.approve_venue_about('<the submission''s id>', '<your profiles.id>');
```

Reject — sets `status = 'rejected'` and stores the note.

```sql
select * from public.reject_venue_about('<the submission''s id>', '<your profiles.id>', '<why>');
```

Note: as of this round, `reject_venue_about`'s note is shown to the
manager in the app the same way a rejected photo's note already is — see
`VenueAboutSubmission.reviewNote` / `VenueManagementScreen`'s About
section.

## Photo submissions

**Normal path: the `publish-venue-photo` Edge Function.** Takes only a
submission id and a reviewer id — it copies the file from the private
`venue-photo-submissions` bucket into the public `catalogue-media`
bucket itself, verifies the object actually landed before doing anything
else, and only then calls `approve_venue_photo` with the URL it derived.
There is no URL for a human to copy, paste, or mistype — that was the
whole point of building it (see `supabase/functions/publish-venue-photo/
index.ts`'s own header for the full reasoning and the empirical proof
that cross-bucket copy works on this project).

```sh
curl -X POST 'https://wcmxugunvwsrulcpeyrc.supabase.co/functions/v1/publish-venue-photo' \
  -H 'Content-Type: application/json' \
  -H 'x-webhook-secret: <the function''s webhook secret>' \
  -d '{"submission_id": "<the submission''s id>", "reviewed_by": "<your profiles.id>"}'
```

The webhook secret is a `supabase secrets set` value, not written down
here — ask whoever last deployed the function, or generate and set a new
one if it's been lost (`openssl rand -hex 32`, then `supabase secrets set
PUBLISH_VENUE_PHOTO_WEBHOOK_SECRET=... --project-ref
wcmxugunvwsrulcpeyrc`).

A response of `{"success": true, ...}` means the photo is live. Anything
else means nothing was published — the error explains why, and says
explicitly whether the file already made it to `catalogue-media` (safe to
just call again) or nothing happened at all (same — safe to just call
again). Calling it twice on an already-published submission fails
cleanly: the submission is no longer `pending`, so the function refuses
before attempting anything.

Reject — sets `status = 'rejected'` and stores the note. Publishes
nothing. `publish-venue-photo` deliberately has no reject path; rejection
never touches Storage, so this is the whole of it:

```sql
select * from public.reject_venue_photo('<the submission''s id>', '<your profiles.id>', '<why>');
```

### Fallback: if the function is unavailable

`approve_venue_photo` itself is unchanged and still callable directly —
`publish-venue-photo` is a layer on top of it, not a replacement. This is
the manual path from before the function existed, kept here because it's
the thing that still works when nothing else does.

**Copy the file to `catalogue-media` yourself first — this is a required
step, not a suggestion.** A venue photo submission's `storage_path`
points into the *private* `venue-photo-submissions` bucket; a published
photo's `image_url` must be a public URL into the *public*
`catalogue-media` bucket. `approve_venue_photo` takes the destination URL
as an explicit argument, and does not trust it blindly: it rejects any
URL that isn't a real `catalogue-media` public URL, and checks that an
object actually exists at that path before publishing anything. Skip the
copy and the call raises — it does not publish a broken image. Unlike a
hand-typed URL, though, nothing stops you from pasting the *wrong*
submission's file here — that is exactly the failure mode
`publish-venue-photo` exists to close, so prefer it whenever it's up.

Exactly how you get the file from one bucket to the other in the
Dashboard — a direct copy/move action, or download-then-reupload if the
former isn't available for cross-bucket moves — is an open question for
*manual* use; `publish-venue-photo` itself uses the Storage API's
`copy()` directly and has confirmed that works on this project. Confirm
on first manual use and update this note with whichever it turns out to
be for the Dashboard UI specifically.

Once the file is in place, find its public URL (Dashboard → Storage →
`catalogue-media` → the file → copy URL, or construct it as
`https://wcmxugunvwsrulcpeyrc.supabase.co/storage/v1/object/public/catalogue-media/<the path you copied it to>`).

```sql
select * from public.approve_venue_photo('<the submission''s id>', '<your profiles.id>', 'https://wcmxugunvwsrulcpeyrc.supabase.co/storage/v1/object/public/catalogue-media/<the path you copied it to>');
```

Same behavior either way: publishes the photo (new row, or replacing an
existing one if the submission named a `replaces_photo_id`, preserving
that photo's own position) and marks the submission approved, in one
transaction. Raises if the submission isn't `pending`, if the URL doesn't
match the real `catalogue-media` prefix, or if no object exists at that
path.

## Revoking access

Not asked for as part of the task that created the grant SQL above, but
follows directly from the same table shape — included for symmetry, since
`revoked_at`/`revoked_by`/`revoked_reason` all exist specifically to make
this recordable rather than a silent `delete`.

```sql
update public.venue_managers_restaurants
set revoked_at = now(), revoked_by = '<your profiles.id>', revoked_reason = '<why>'
where id = '<the venue_managers_restaurants row''s id>'
  and revoked_at is null;
```

Same shape for `venue_managers_hotels`/`venue_managers_private_chefs`.
`revoked_reason` is required by the table's own CHECK constraint the
moment `revoked_at` is set — there is no way to revoke without recording
why.
