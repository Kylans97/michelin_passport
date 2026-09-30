# Venue claim and submission operations

One-line SQL, run in the Supabase Dashboard's SQL Editor, for every
approve/reject decision a human reviewer makes: a venue claim, a
venue-supplied "about" text submission, or a venue-supplied photo
submission. Each operation is a single `select * from <function>(...)`
call — the function does the row update *and* whatever else approval
requires (granting a permission, nothing else for about text, publishing
a photo) in one transaction, and raises a clear error instead of quietly
doing nothing if the row isn't in a state it can act on.

These six functions (`approve_venue_claim`, `reject_venue_claim`,
`approve_venue_about`, `reject_venue_about`, `approve_venue_photo`,
`reject_venue_photo` — added in
`supabase/migrations/20261005120000_add_venue_approval_rpcs.sql`) replace
the hand-written `insert`/`update` snippets this file used to hold. They
are `SECURITY DEFINER` and revoked from `public`, `anon`, and
`authenticated` — only callable from here (the Dashboard, as
`service_role`/`postgres`), never from the app. There is still no in-app
admin identity and none is planned; review continues to happen entirely
through this file and the Dashboard.

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

**Copy the file to `catalogue-media` before calling `approve_venue_photo`
— this is a required first step, not a suggestion.** A venue photo
submission's `storage_path` points into the *private*
`venue-photo-submissions` bucket; a published photo's `image_url` must be
a public URL into the *public* `catalogue-media` bucket. Moving the file
between them is a Storage operation this SQL function cannot perform —
`storage.objects` is metadata only, the bytes live outside Postgres. So
`approve_venue_photo` takes the destination URL as an explicit argument,
and it does not trust it blindly: it rejects any URL that isn't a real
`catalogue-media` public URL, and it checks that an object actually
exists at that path before publishing anything. Skip the copy and the
call raises — it does not publish a broken image.

Exactly how you get the file from one bucket to the other in the
Dashboard — a direct copy/move action, or download-then-reupload if the
former isn't available for cross-bucket moves — is an open question
neither of us has actually done yet. Confirm on first use and update this
note with whichever it turns out to be.

Once the file is in place, find its public URL (Dashboard → Storage →
`catalogue-media` → the file → copy URL, or construct it as
`https://wcmxugunvwsrulcpeyrc.supabase.co/storage/v1/object/public/catalogue-media/<the path you copied it to>`).

Approve — publishes the photo (new row, or replacing an existing one if
the submission named a `replaces_photo_id`, preserving that photo's own
position) and marks the submission approved, in one transaction. Raises
if the submission isn't `pending`, if the URL doesn't match the real
`catalogue-media` prefix, or if no object exists at that path.

```sql
select * from public.approve_venue_photo('<the submission''s id>', '<your profiles.id>', 'https://wcmxugunvwsrulcpeyrc.supabase.co/storage/v1/object/public/catalogue-media/<the path you copied it to>');
```

Reject — sets `status = 'rejected'` and stores the note. Publishes
nothing.

```sql
select * from public.reject_venue_photo('<the submission''s id>', '<your profiles.id>', '<why>');
```

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
