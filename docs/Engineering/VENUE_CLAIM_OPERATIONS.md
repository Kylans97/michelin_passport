# Venue claim operations

Manual SQL run in the Supabase Dashboard's SQL Editor as part of
reviewing venue claims. There was no existing home for this kind of
operational snippet in this repo — `scripts/` holds only the Python
catalogue-import tooling, and nothing under `docs/` collects one-off
admin SQL — so this file is that home, filed under Engineering per
`CLAUDE.md`'s own docs table. If a better location emerges, move it; the
grant SQL itself is the part that matters.

Review itself — approving/rejecting/blocking a claim by editing its
`status` — happens directly in the Table Editor, unchanged. This file is
only for the step that comes *after* approval: turning that approval into
an actual permission row. That step is **not automated** — approving a
claim only ever sets `status = 'approved'`; nothing reads that as
"therefore grant access." See
`supabase/migrations/20260930120000_add_venue_managers_permission_tables.sql`
for why.

## Finding your own `profiles.id`

Every grant/revoke below needs the reviewer's own `profiles.id` (not
their `auth.users.id` — they're the same value, `profiles.id` is just the
FK-friendly name here) for `granted_by`/`revoked_by`. Look it up once:

```sql
select id, username, display_name from public.profiles where username = '<your username>';
```

## Granting access from an approved claim

Run after setting a `claims_restaurants` row's `status` to `'approved'`
in the Table Editor. The `where c.status = 'approved'` clause is a
safety check, not decoration — it means this can never grant access from
a claim that's still pending, was rejected, or was blocked, even if the
wrong `claim_id` is pasted in. If it inserts 0 rows, the claim wasn't
actually `'approved'` — check its status before re-running.

```sql
insert into public.venue_managers_restaurants (user_id, restaurant_id, claim_id, granted_by)
select c.user_id, c.restaurant_id, c.id, '<your profiles.id>'
from public.claims_restaurants c
where c.id = '<the approved claim''s id>'
  and c.status = 'approved';
```

The `claims_hotels`/`claims_private_chefs` shape is identical, against
`venue_managers_hotels`/`venue_managers_private_chefs`:

```sql
insert into public.venue_managers_hotels (user_id, hotel_id, claim_id, granted_by)
select c.user_id, c.hotel_id, c.id, '<your profiles.id>'
from public.claims_hotels c
where c.id = '<the approved claim''s id>'
  and c.status = 'approved';

insert into public.venue_managers_private_chefs (user_id, private_chef_id, claim_id, granted_by)
select c.user_id, c.private_chef_id, c.id, '<your profiles.id>'
from public.claims_private_chefs c
where c.id = '<the approved claim''s id>'
  and c.status = 'approved';
```

If someone already holds an active grant on that same venue, this fails
with a `unique_violation` on the table's own `_active_uidx` index —
correct, not a bug: revoke the existing one first (below) if the new
grant should replace it.

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
