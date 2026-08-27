# Profile Privacy & Discoverability V1

Status: **deployed to production, live-validated with disposable test
accounts through the real PostgREST/RPC path** (not just SQL). Migration:
`supabase/migrations/20260825160000_profile_privacy_discoverability_v1.sql`.

## 1. The distinction this feature exists to draw

Mantelier previously had exactly one privacy-adjacent flag,
`profiles.is_public`, which conflated two unrelated questions:

1. Can another member **find** this person at all (search, Find Friends)?
2. Can another member **see this person's content** (visits, ratings,
   photos, wishlist, Trips, event activity)?

Question 2 was already answered correctly and separately, months before
this feature: friendship status plus each table's own `visibility`
column (`visits.visibility`, `event_attendance.visibility`,
`event_confirmed_attendance.visibility`) — never `is_public`. Question 1
had no real answer at all: every profile was unconditionally
discoverable, `is_public` or not, because `search_profiles()` and
`get_profile_identity()` never read it.

**`profiles.is_discoverable`** is the real answer to question 1, and
question 1 only.

```
is_discoverable = true
  → other authenticated Mantelier members may find this user's
    basic identity (username, display name, avatar) through Find
    Friends search.

is_discoverable = true does NOT mean:
  → "my content is public." Visits, ratings, photos, wishlist, Trips,
    event activity and Community Rankings are entirely unaffected and
    remain governed by friendship status and their own existing
    visibility rules, exactly as before this feature existed.
```

## 2. What changed

| Object | Before | After |
|---|---|---|
| `profiles.is_discoverable` | did not exist | new column, `boolean not null default true` — same default for every existing row and every new row |
| `profiles.is_public` | gated `profiles_read` | **deprecated for discovery** (SQL `COMMENT`), column retained unmodified, no longer read by any policy or function |
| `profiles_read` (RLS) | `is_public OR id = auth.uid()`, roles `{anon, authenticated}` | `id = auth.uid()`, role `{authenticated}` only |
| `search_profiles(text)` | ignored discoverability entirely | `is_discoverable OR relationship in ('accepted','pending')`, `blocked` always excluded |
| `get_profile_identity(uuid)` | same gap | same corrected logic |

Nothing else changed. No other table, policy, function, index, grant, or
storage bucket was touched.

## 3. The relationship matrix

Both `search_profiles()` and `get_profile_identity()` share the identical
eligibility rule:

```sql
where auth.uid() is not null
  and (blocked-either-direction excluded, unconditionally)
  and (is_discoverable OR relationship_status in ('accepted', 'pending'))
```

| Relationship state | `is_discoverable = true` | `is_discoverable = false` |
|---|---|---|
| None | visible | **not visible** |
| Accepted friend | visible | **visible** (relationship overrides) |
| Pending (sent or received) | visible | **visible** (relationship overrides) |
| Declined | visible (via discoverability, not the declined row) | **not visible** — a declined row is never itself a bypass |
| Blocked (either direction) | **never visible** | **never visible** |
| Unauthenticated caller | n/a | n/a — both functions reject with a permission error before any row logic runs |

**Declined never bypasses discoverability.** This is the one place a
naive implementation (`f.status is not null`) would have gotten it
wrong — a stale declined row must never resurrect visibility for someone
who has since turned discoverability off. **Blocked always wins**,
regardless of discoverability in either direction.

## 4. Direct profile-read restriction

Before this feature, `profiles_read` allowed any `anon` or
`authenticated` client to read any `is_public = true` row directly via
`GET /rest/v1/profiles`. No app code actually used this path — every
cross-user identity read already went through one of the `SECURITY
DEFINER` RPCs above, which bypass `profiles_read` entirely by design.

`profiles_read` is now `id = auth.uid()`, `authenticated` only. A user
can read their own row and no one else's, full stop, regardless of
`is_discoverable`. All legitimate cross-user identity access continues
through `get_friends()` / `get_incoming_friend_requests()` /
`get_outgoing_friend_requests()` / `get_profile_identity()` /
`search_profiles()` — none of which changed their own access pattern,
only `search_profiles`/`get_profile_identity`'s row-eligibility logic
changed.

## 5. RPC security boundary

- `search_profiles`/`get_profile_identity`: `SECURITY DEFINER`, `EXECUTE`
  revoked from `public`, granted to `authenticated` only. An anonymous
  caller receives a Postgres permission-denied error before any query
  logic runs (live-verified: `42501 permission denied for function
  search_profiles`).
- `get_friends`/`get_incoming_friend_requests`/
  `get_outgoing_friend_requests`: unchanged, still scoped to real
  existing relationships, never read `is_public` and correctly never
  read `is_discoverable` either — an existing friend or a pending
  request must never lose the ability to see who's on the other end of
  it just because that person later opts out of *new* discovery.
- The toggle itself (`profiles.is_discoverable`) is writable only via
  `profiles_update` (`id = auth.uid()`, unchanged by this migration) —
  a user can set their own value and no one else's, enforced
  server-side, not merely by the client's own calling convention.

## 6. UI behavior

`Profile → Settings → Privacy` (`lib/features/profile/
privacy_settings_screen.dart`): a single row, **"Allow members to find
me"**, with copy that is deliberately specific about what it does and
does not affect:

> Let other Mantelier members find your name and username in Find
> Friends.
> Your visits, wishlist and trips keep their existing privacy settings.

The toggle is non-optimistic — its visible state only moves after the
write has actually succeeded (`ProfileRepository.setDiscoverable`), so a
failure never leaves an incorrect persisted state on screen and never
needs a rollback step.

## 7. Production validation (live, disposable accounts, real client path)

Because a local Postgres-planner artifact was found in an earlier
same-statement `set_config` simulation of `auth.uid()` (a testing-method
quirk, not a logic bug — see the implementation pre-apply report), the
final relationship matrix was validated against **production**, through
the real PostgREST REST endpoints with real access tokens from real
password sign-ins — exactly the path the Flutter app itself uses, not
raw SQL.

Eight disposable accounts (`zzzprivtest######-{s,a,b,c,d,e,f,g}
@example.test`) were created via the Admin API, real relationships were
established via the real `send_friend_request`/`accept_friend_request`/
`decline_friend_request`/`block_user` RPCs (not direct table writes),
and every cell of the matrix above was confirmed via a real
`POST /rest/v1/rpc/search_profiles` and
`POST /rest/v1/rpc/get_profile_identity` call, including the toggle
E2E (real `PATCH /rest/v1/profiles`, not a direct SQL `UPDATE`) and the
direct-read security checks (User A cannot read User B's row; anon
cannot read any row). All eight accounts and every fixture were deleted
immediately after via the Admin API; production returned to exactly one
profile row afterward.

## 8. What this explicitly does NOT control

- Visit history, ratings, or notes (`visits` + friendship + `visibility`)
- Photos (`photos`, inherits the parent visit/attendance's visibility)
- Wishlist (`wishlist`, unconditional friends-only rule, no change)
- Trips / planned visits (`planned_trips`/`planned_venues`, owner-only,
  no change)
- Event Going/Interested (`event_attendance`)
- Confirmed event attendance (`event_confirmed_attendance`)
- Community Rankings (aggregate-only view, never carried per-user data
  to begin with)

Turning "Allow members to find me" off does not delete friends, cancel
pending requests, remove an existing friend from Friends, hide the user
from an already-established friend, change any content visibility, or
modify blocked relationships. It only controls whether an unrelated
member can find this person going forward.

## 9. Future consideration (not built)

`is_public` remains in the table, deprecated for discovery, undocumented
for any other purpose. It is a safe candidate for an eventual `DROP
COLUMN` once nothing anywhere references it — not part of this pass, and
not implied by it.
