# Account Deletion

Status: **deployed to production (v2), live-smoke-tested with disposable
accounts (including a live attack test), unit tested, and locally
end-to-end validated. Now purges BOTH `visit-photos` and `profile-photos`
as hard preconditions — see §3/§5 for the Profile Avatar V1 backend apply
that added the second bucket. Physical-device confirmation with a
disposable account pending.**

## 1. Why this exists

Apple App Store review requires apps that support account creation to
also offer in-app account deletion, without requiring the user to email
support. Mantelier's Profile screen already has a real, tested "Delete
account" entry and confirmation flow (see
`docs/Architecture/NAVIGATION_INFORMATION_ARCHITECTURE_V2.md` §13); this
document covers the backend that flow depends on.

## 2. User-data dependency map (audited, not assumed)

Confirmed via a live, read-only query against the linked production
database (`information_schema`/`pg_constraint`), re-verified a second,
independent time (a different query strategy — `pg_constraint` directly,
plus a full `information_schema.columns` grep for `user_id`/`profile_id`/
`owner_id`-shaped columns across every table) before writing any code.

### AUTO_CASCADE — cleaned up automatically by deleting the `auth.users` row

`public.profiles.id` is `ON DELETE CASCADE` from `auth.users(id)`. Every
one of these 16 tables is in turn `ON DELETE CASCADE` from
`profiles.id`:

`event_attendance`, `event_confirmed_attendance`, `follows`
(`follower_id` and `following_id`), `follows_hotels`,
`follows_private_chefs`, `follows_restaurants`, `friendships`
(`requester_id` and `addressee_id` — the row is deleted if EITHER party
is deleted), `photos`, `planned_trips`, `planned_venues`,
`private_chef_enquiries`, `visits`, `wishlist`.

`friendships.blocked_by` is `ON DELETE SET NULL`, not CASCADE — if the
deleted user had blocked someone, that friendship row is not deleted (the
other party keeps their own history), only the `blocked_by` reference is
nulled. This is benign and does not leak the deleted user's identity.

Supabase's own internal `auth.*` tables (`identities`, `sessions`,
`mfa_factors`, `oauth_authorizations`, `oauth_consents`,
`one_time_tokens`, `webauthn_challenges`, `webauthn_credentials`) all
cascade from `auth.users(id)` too — `supabase.auth.admin.deleteUser(id)`
handles all of this with zero manual work.

### EXPLICIT_DELETE_REQUIRED — must be cleaned up manually, and now blocks deletion if it fails (see §3)

**Supabase Storage** is never covered by a Postgres FK cascade. Two
buckets hold user-owned content: `visit-photos` (private, objects keyed
`{user_id}/{visit_id}/{filename}`) and, as of **Profile Avatar V1**
(applied 2026-08-25), `profile-photos` (private, objects keyed
`{user_id}/{uniqueId}.{ext}` — see `docs/Architecture/PROFILE_AVATAR_V1.md`).
The other bucket, `catalogue-media`, is public admin/curated content
(private chef photos etc.), keyed by entity id, not user id — never
touched by deletion.

### ANONYMIZE_REQUIRED

None. No product reason was found to retain any personal content after
deletion — full deletion is used throughout, per "prefer deletion unless
there is a clear product reason otherwise."

### REVIEW_REQUIRED

None — the dependency map above is exhaustive and unambiguous across two
independent audit passes. No `notifications`, `reviews`, `comments`,
`reports`, `blocks`, or trip-sub-item tables exist in this schema at all.

`public.profiles.avatar_url` is a free-text column, not a Storage
reference, and has never been populated by any write path — it needs no
separate handling; the row itself is deleted by cascade.
`public.profiles.avatar_path` (added by Profile Avatar V1) IS a Storage
object reference, but needs no separate handling either: it is a plain
text column on the same cascading `profiles` row, and by the time that
cascade runs, the Storage OBJECT it points to has already been purged in
the precondition step below (§3) — never left dangling.

No `SECURITY DEFINER` function relevant to deletion/admin operations
exists (18 checked — friend/follow RPCs and PostGIS internals only).

## 3. Backend architecture — the `delete-account` Edge Function

`supabase/functions/delete-account/index.ts`. Deno, using the
service-role key **only inside this function's own environment** — never
sent to or reachable from the Flutter client. **Live in production**
(`supabase functions deploy delete-account`, `verify_jwt = true`, the
project default — no override).

### Security model

- Identity comes **only** from the caller's own JWT
  (`admin.auth.getUser(jwt)`, verified against the service-role client).
  There is no field anywhere in this function — request body, query
  string, header — that accepts a client-supplied target user id. A
  malicious authenticated user cannot request deletion of another
  account through this endpoint; there is structurally no parameter for
  one.
- The platform's own JWT-verification gateway rejects requests with
  no/invalid Supabase-issued token before this code runs at all —
  confirmed live in production: an unauthenticated request returns the
  platform's own `{"code":"UNAUTHORIZED_NO_AUTH_HEADER", ...}`, never
  reaching this function's code path. This function's own `getUser()`
  check is a second, independent verification.
- **Live-tested in production, not just reasoned about**: an
  authenticated disposable "attacker" test account was used to call this
  function with `user_id`/`target_id`/`userId` fields in the body
  pointing at a different disposable test account — the body was ignored
  entirely (the function never parses one), only the attacker's own
  account was deleted, the target account was confirmed fully untouched
  (its `auth.users` row, `profiles` row, and a control `planned_trips`
  row all still present). See §5.

### Deletion order — Storage is now a HARD PRECONDITION, both buckets

1. Authenticate the caller from their JWT → derive `userId`.
2. **Purge `visit-photos/{userId}/...`** (recursive — Supabase Storage's
   `list()` represents a "folder" as an entry with `id: null`; there is
   no native recursive delete, so this function recurses manually).
   **Hard precondition, not best-effort**: if listing OR removal fails
   for any reason, the function returns failure immediately and never
   proceeds further — the auth account and the caller's session are left
   fully intact, so the same authenticated user can simply retry.
   - **Why this changed from an earlier best-effort design**: once
     `auth.users` is deleted, the user's own JWT is invalidated, so they
     can no longer retry Storage cleanup under their own identity — any
     leftover personal media would then require manual/admin
     intervention to remove. That is a materially worse privacy outcome
     than asking the user to tap "Delete my account" again after a
     transient Storage failure. A listing failure specifically throws
     (rather than being treated as "no files found") — "I couldn't
     verify whether files exist" must never be treated the same as "no
     files exist" when the whole point is a hard precondition.
3. **Purge `profile-photos/{userId}/...`** — same hard-precondition
   treatment, same reasoning, added by Profile Avatar V1. Both bucket
   purges share one `purgeBucket(admin, bucket, userId)` helper
   (previously `purgeVisitPhotos`, generalized) — parameterized only by
   bucket name, since the recursive-listing/hard-precondition logic is
   identical for either bucket. A user who never set an avatar purges an
   empty listing — a normal, successful no-op, not a failure.
4. `supabase.auth.admin.deleteUser(userId)` — only reached after steps 2
   AND 3 both succeed. `profiles.id` is `ON DELETE CASCADE` from
   `auth.users(id)`, and every one of the 16 user-owned tables (§2)
   cascades from `profiles.id` in turn — this one call is sufficient for
   all Postgres-side data. No manual per-table DELETE is issued anywhere;
   the cascade is trusted because it was independently, twice verified,
   not assumed. `profiles.avatar_path` is a plain column on that same
   cascading row — see §2's note on why it needs no separate handling.

Success is reported ONLY after step 4 itself succeeds — never before, so
the client never hears "deleted" while the auth account still exists. A
Storage failure in EITHER bucket now means the account is NOT deleted at
all — there is no window where auth deletion succeeds but Storage cleanup
didn't, and no residual orphaned-file risk in either bucket.

### Response contract

Success: `{ "success": true }`, HTTP 200.
Failure: `{ "error": "<restrained, generic message>" }`, HTTP 401/405/500.
Never a raw Postgrest/Storage/Auth error, stack trace, or SQL in the
response — every failure path returns one of a small number of fixed
strings ("Missing Authorization header" / "Invalid or expired session" /
"Method not allowed" / "Could not delete account. Please try again.").

### Idempotency / retry semantics

Deleting `auth.users` invalidates the caller's own JWT immediately (the
user no longer exists to authenticate as). A retry with the same,
now-stale token correctly fails with 401 ("Invalid or expired session")
— confirmed live in both the local stack and production — rather than
silently no-op'ing or duplicating any side effect. There is no window
where a retry could re-trigger deletion side effects, because the second
call can never even authenticate. A Storage-failure retry is even
simpler: the account was never touched, so the same authenticated session
just calls the endpoint again.

### Client integration

`lib/data/repositories/account_deletion_repository.dart` —
`AccountDeletionRepository.deleteCurrentAccount()` calls
`client.functions.invoke('delete-account')` with **no body** (identity
travels via the Authorization header `supabase_flutter` attaches
automatically from the current session — never a manually-added id). On
any non-200 response or thrown exception, it throws
`AccountDeletionFailure` with a restrained, fixed message — never a raw
backend error. `lib/features/profile/delete_account_screen.dart` (already
existing, unchanged by this workstream) calls this, then signs out and
pops to the app's root route on success; on failure it shows the error
and leaves the session untouched, letting the user retry.

## 4. Sign in with Apple

**Not currently implemented.** `AuthRepository`
(`lib/data/repositories/auth_repository.dart`) only has `signUp`/`signIn`
(email+password)/`signOut`; no `sign_in_with_apple` package is a
dependency. No token-revocation work is needed. Documented here so it
isn't forgotten if Apple Sign-In is added later — at that point, Apple's
account-deletion guidance requires revoking the associated authorization
token as part of this same function.

## 5. Tests and validation

### Backend unit tests (`supabase/functions/delete-account/index.test.ts`, Deno)

15 tests (9 original + 6 added by Profile Avatar V1), hand-rolled fakes (a
narrow `DeletionAdminClient` structural interface — not the full Supabase
SDK — so fakes are plain object literals, no mocking framework; storage
entries/errors are now keyed per-bucket so a test can prove either bucket
independently blocks deletion), all passing:
- OPTIONS request → CORS response, no auth attempted.
- Non-POST method rejected (405).
- Missing Authorization header rejected (401), no deletion attempted.
- Invalid/expired token rejected (401), no deletion attempted.
- A valid caller deletes exactly their own id.
- Storage folder recursion correctly purges nested `visit-photos` files.
- A `visit-photos` list failure **blocks** account deletion (hard
  precondition) — the account is not deleted, the raw error never
  reaches the client.
- A `visit-photos` remove failure **blocks** account deletion.
- `profile-photos` is purged after `visit-photos`, before deletion.
- A user who never set an avatar (empty `profile-photos` listing)
  deletes normally — an empty listing is a successful no-op.
- A `profile-photos` list failure **blocks** deletion even when
  `visit-photos` succeeded.
- A `profile-photos` remove failure **blocks** deletion even when
  `visit-photos` succeeded.
- Storage cleanup success (both buckets) is required before, and
  precedes, auth deletion.
- An `auth.admin.deleteUser` failure is reported honestly (500, generic
  message) — the raw backend error never reaches the response body.
- Two different callers each delete only their own account.

Run: `cd supabase/functions/delete-account && deno test --allow-net --allow-env index.test.ts`.

### Local disposable-user end-to-end (live, against the local Supabase
stack — `supabase status` confirmed it running; never production) — run
TWICE, once against the original best-effort Storage design, once again
after the hard-precondition rewrite:

1. Created disposable local auth users via the Admin API.
2. Confirmed `handle_new_user`'s trigger auto-created their `profiles` rows.
3. Inserted representative dependent rows (a `friendships` row between
   two users; a `planned_trips` row).
4. Uploaded a real object to `visit-photos/{user}/{visit}/private.jpg`.
5. Signed in as the target user (real password grant, real access token).
6. Served the function locally and called it with that real token.
7. **Result both times: `{"success":true}`, HTTP 200.**
8. Verified each time: the deleted user's `auth.users`/`profiles` rows
   gone; dependent rows (friendship, planned trip) gone; Storage objects
   gone. **The control user's rows fully intact and unaffected, both times.**
9. Retried the same (now-stale) token → 401 "Invalid or expired session"
   — confirmed no false success, no duplicate side effect.
10. Unauthenticated request (no Authorization header) → 401.
11. **Attack test** (first run): a third disposable user authenticated
    and sent a body containing `user_id`/`target_id`/`userId` pointing at
    the control user. Result: only the attacker's own account was
    deleted; the control user remained fully untouched.
12. Cleaned up all remaining disposable users via the Admin API after
    each run. Confirmed the local database returned to 0 users both
    times — no test artifacts left behind.

### Production disposable-user smoke test (live, against the linked
production project — real, but 100% disposable, test-only accounts;
**never** the real user's account)

1. Deployed `delete-account` to production (`supabase functions deploy
   delete-account`) — confirmed live, `status: ACTIVE`, `verify_jwt: true`.
2. Created two disposable production auth users, Test User A (to be
   deleted) and Test User B (control), via the Admin API, distinctly
   emailed (`...+prod@example.test`) so they're unmistakably test-only.
3. Confirmed both `profiles` rows auto-created.
4. Created representative fixtures for A: a `friendships` row with B, a
   `planned_trips` row. Created a distinct control `planned_trips` row
   for B ("must remain").
5. Uploaded a real object to `visit-photos/{A}/prod-test-visit/private.jpg`.
6. Signed in as A (real password grant against production Auth).
7. **Attack test, live in production**: called the deployed function as
   A with a body containing `user_id`/`target_id`/`userId` pointing at
   B. **Result: `{"success":true}`, HTTP 200** — meaning A's own account
   was deleted (exactly as it should be — the function always deletes
   the authenticated caller, regardless of body content).
8. Verified immediately after: A's `auth.users` row gone; A's `profiles`
   row gone; the A↔B friendship gone; A's `planned_trips` row gone; A's
   `visit-photos` object gone. **B's `auth.users` row, `profiles` row,
   and control `planned_trips` row (“must remain”) all fully intact.**
   This is the same live proof as the local attack test, now run against
   the real deployed production function.
9. Retried A's now-stale token → 401 "Invalid or expired session."
10. Unauthenticated request → 401, rejected by the platform's own
    gateway before reaching this function's code (`{"code":
    "UNAUTHORIZED_NO_AUTH_HEADER", ...}`).
11. **Cleanup**: deleted Test User B via the Admin API (cascading its
    profile and control trip). Confirmed zero `auth.users` rows matching
    the test email patterns remain, and zero `visit-photos` objects
    remain under either test user's id. All local files containing the
    production service-role/anon keys used for this test were deleted
    immediately after (never committed, never logged in full to any
    file).

### Profile Avatar V1 production verification (live, disposable accounts, real client path — 2026-08-25)

Run after applying the `profile-photos` migration and redeploying this
function (v1 → v2, confirmed via `supabase functions list`):

1. Created a disposable production user (Test User C), distinctly
   emailed, via the Admin API.
2. Uploaded a real object to `visit-photos/{C}/test-visit/private.jpg`
   and a real object to `profile-photos/{C}/avatar.jpg`, both via the
   real Storage REST API using C's own signed-in access token.
3. Set `profiles.avatar_path` for C to the uploaded `profile-photos`
   path via the real PostgREST path (owner-only `profiles_update` RLS).
4. Inserted a representative dependent row (`planned_trips`) for C.
5. Called the **live, deployed** `delete-account` function as C.
   **Result: `{"success":true}`, HTTP 200.**
6. Verified directly against production (`information_schema`/table
   queries, not inference): C's `auth.users` row gone, `profiles` row
   gone, the `planned_trips` row gone, the `visit-photos` object gone
   (`storage.objects` count = 0 for C's prefix), the `profile-photos`
   object gone (`storage.objects` count = 0 for C's prefix).
7. Retried C's now-stale token → 401 "Invalid or expired session" —
   consistent with the pre-existing retry semantics.
8. Two other disposable users (A, B) used earlier in the same session for
   Storage RLS cross-user attack testing (see
   `docs/Architecture/PROFILE_AVATAR_V1.md`) were confirmed still present
   in `auth.users` throughout — proving C's deletion was scoped to C
   alone.
9. **Cleanup**: deleted Test Users A, B, and C via the Admin API.
   Confirmed zero `storage.objects` rows remain in `profile-photos`.
   Confirmed zero `auth.users` rows matching the test email pattern
   remain. All local files containing the production service-role/anon
   keys and disposable-user tokens used for this test were deleted
   immediately after (chmod 600 throughout, never printed in full, never
   committed).

### Flutter (existing, unchanged, already covers the client contract)

`test/delete_account_screen_test.dart` (9 tests) and
`test/profile_delete_account_entry_test.dart` (3 tests) — both written in
a prior pass, both still valid and passing, exercising the REAL
`DeleteAccountScreen` widget via its injectable
`deleteAccount`/`signOut` callbacks (no Supabase needed in the test
process). These prove: first tap never deletes; a confirmation dialog is
required; Cancel (both screen-level and dialog-level) leaves the account
untouched; the final confirmation invokes the deletion abstraction
exactly once; success signs out and returns to the unauthenticated root;
failure leaves the session intact, shows a restrained error, and allows
retry.

**Not added**: a Flutter unit test that fakes `SupabaseClient` directly
to assert `AccountDeletionRepository` calls `functions.invoke('delete-
account')` with no body. This codebase has no established convention for
faking the Supabase client directly (confirmed: no repository anywhere in
this app has a direct unit test against a fake `SupabaseClient` — every
Supabase-eager class in this app is instead tested indirectly, via
constructor-injected callbacks at the UI layer or via mirrored widget
trees). The Edge Function's own Deno tests plus the live local AND
production E2E attack tests already prove the actual runtime behavior of
this exact call — real evidence, not a mocked assertion.

### Physical device

Pending — requires a human to sign up a fresh disposable account in the
app and tap through Profile → Delete account → confirm, since this
repository has no automated on-device UI interaction capability. See the
final report for the exact checklist.

## 6. Privacy / logging audit

Grepped the Edge Function source for logging of: user email, user id,
JWT/access token, service-role key, deleted-content bodies. Findings:
- `console.error` calls log the resolved `userId` (a UUID) alongside a
  generic operation-failure message — standard, necessary for operational
  debugging of a failed deletion, and not independently identifying
  without separate database access.
- **Never logged, anywhere**: email address, JWT/access token contents,
  service-role key, request/response bodies, file contents, or any other
  personal content.
- Production test credentials (service-role/anon keys fetched for the
  smoke test) were written only to a restricted-permission (`chmod 600`)
  directory outside the git repository, never printed in full to any
  visible output, and deleted immediately after the smoke test completed.

## 7. Production deployment status

**Deployed and live, version 2.** `supabase functions deploy
delete-account` — confirmed via `supabase functions list`: `status:
ACTIVE`, `verify_jwt: true`, `version: 2` (redeployed 2026-08-25 to add
the `profile-photos` purge; `version: 1` was the original visit-photos-
only deployment). Smoke-tested end-to-end with disposable production
accounts (§5), including a live attack test and, for v2, a full
two-bucket deletion integration test, all proving the security model in
the real production environment, not just locally.

## 8. Known limitations

- Sign in with Apple token revocation is not applicable today (§4) — will
  need adding if/when Apple Sign-In is built.
- Physical-device confirmation with a disposable account has not
  happened yet — the backend, client wiring, and UI logic are all
  independently verified (production API calls + existing widget tests),
  but nobody has physically tapped through the real app against the real
  production function yet.
- The previously-documented "orphaned Storage files on failure" residual
  risk no longer applies — Storage cleanup is now a hard precondition,
  so a Storage failure blocks deletion entirely rather than leaving
  orphaned files.
