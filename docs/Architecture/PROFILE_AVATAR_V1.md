# Profile UI Redesign V1 + Profile Photo

Status: **Phase A (audit, architecture, Flutter UI) complete. Phase B
(backend migration + Storage bucket/policies + delete-account Edge
Function update) is APPLIED AND LIVE in production as of 2026-08-25,
verified end-to-end with disposable production accounts (§10). Human
physical-device confirmation of the actual upload/replace/remove flow is
the one remaining step — see §10's own note on what has and hasn't been
human-verified yet.**

## 1. What this is

Two related pieces of work:

1. A visual redesign of `ProfileScreen` onto the same mature Chasing
   Stars design system Explore/Passport/Community already use — deep
   green canvas, ivory serif identity hierarchy, restrained metric
   strips, no gold outside Michelin recognition.
2. A real, reusable member profile photo (add/replace/remove), stored in
   Supabase Storage, intended for future reuse across Friends/Community/
   Dining Together — but this pass only wires it into Profile itself.
   Friends/Community are explicitly NOT redesigned or wired to display
   avatars in this pass.

Profile stays conceptually distinct from Passport: Passport answers
"what have I collected/visited/rated/planned"; Profile answers "who am I
and what is the shape of my overall journey." The redesigned "Your
Journey" strip is therefore a **total** cross-app summary
(Places/Events/Trips/Countries), never a restatement of Passport's own
restaurant-centric Stars/Restaurants stats.

## 2. Your Journey — metric definitions (audited against the real data model)

Implemented in `lib/features/profile/journey_metrics.dart`
(`computeJourneyMetrics`), covered by
`test/journey_metrics_test.dart`.

- **Places**: unique venues (restaurants + hotels) with at least one
  logged visit/stay — `VisitedRepository.loadPassportVenues(userId)`,
  the same source Passport's own collection is built from. One venue
  counts once regardless of visit count. Never wishlist, never
  planned-but-unvisited venues.
- **Events**: Events with a genuine CONFIRMED attendance —
  `EventConfirmedAttendanceRepository.loadPassportEventAttendance(userId)`.
  Never Going/Interested intent, which records an intention, not an
  experience that happened — and structurally cannot leak in here, since
  `EventAttendanceEntry` can only be constructed from a confirmed-
  attendance row.
- **Trips**: Trips that have fully ended —
  `compareCalendarDates(trip.endDate, now) < 0`, the exact negation of
  `isUpcomingTrip`'s own established rule (`trip_schedule.dart`). A trip
  currently in progress (today falls within start/end) is NOT yet
  counted; future trips are never counted.
- **Countries**: unique country codes across BOTH visited venues
  (`PassportVenue.countryCode`) AND confirmed-attendance Events
  (`Event.countryCode`) — never Wishlist, never future Trips (a trip's
  own `countryCode` is not a country source at all, regardless of
  timing), never Interested-only Events. Empty country codes are
  excluded.

All four were reliably definable from the existing data model — no STOP
condition was triggered for this section.

## 3. Avatar — data model

`profiles.avatar_path text` (nullable) — a Storage **object path**,
never a URL. A new column, deliberately not reusing the existing
`avatar_url` column: that column has never been populated by any write
path in this app (confirmed by grepping every call site during this
task's audit), and a stable path fits this feature's own display
strategy (short-lived signed URLs resolved at read time) better than a
URL/token stored at rest ever would.

Object path convention: `{userId}/{uniqueId}.{ext}` — **not** the fixed
`{userId}/avatar.<ext>` shape this feature's own brief first suggested.
Deviated deliberately, matching the codebase's existing `visit-photos`
convention exactly: a unique path per upload means a replace can never
collide with, or need to overwrite in place, the object the `profiles`
row still references until the DB update itself has succeeded, and it
solves display-side cache invalidation for free (a new path is
guaranteed to be a cache miss; a fixed path is not).

Exactly one canonical current avatar per user — never an unbounded list
of orphans:

- `ProfileRepository.uploadAvatar` uploads a new object and returns its
  path; it does not touch `profiles` at all.
- `ProfileRepository.replaceAvatar` orchestrates the full safe sequence:
  upload new → update `profiles.avatar_path` → only after that DB write
  succeeds, best-effort delete the previously-referenced object. If the
  DB write fails, the newly uploaded object is cleaned up and the
  existing avatar is left completely untouched — there is never a
  window where a user has no avatar because a replace partially failed.
- `ProfileRepository.removeAvatar` clears the column first, then
  best-effort deletes the Storage object (DB reference first, matching
  `replaceAvatar`'s own "never point at something that might not exist"
  ordering).

This exactly mirrors `PhotoRepository`'s own established
upload/replace/delete orchestration for visit photos — no new pattern
was invented.

## 4. Storage architecture (live in production — see §10)

`profile-photos`: a new **private** bucket, 5 MiB per-object limit,
`image/jpeg`/`image/png`/`image/webp`/`image/heic`. Private because the
app always displays images via short-lived signed URLs
(`createSignedUrl`), never a public bucket URL — matching `visit-photos`
exactly, and unlike the separate, deliberately-public `catalogue-media`
bucket (admin-curated content with no per-user ownership).

### Storage read visibility — the most consequential decision

This feature's own brief explicitly required: match `profile_path`
Storage read access to the same `is_discoverable`/relationship-based
identity-visibility semantics `search_profiles`/`get_profile_identity`
just established (Profile Privacy & Discoverability V1) — **or STOP and
report rather than implement an insecure shortcut**, and never make the
whole bucket public purely for convenience.

**Decision: owner-only Storage read access for V1**, matching
`visit-photos`' own RLS shape exactly
(`(storage.foldername(name))[1] = auth.uid()::text` for select/insert/
delete, no update policy). This is a deliberate, scoped-down answer, not
a shortcut:

- Nothing in this pass exposes `avatar_path` to any user other than its
  owner through any RPC. `search_profiles`/`get_profile_identity`/
  `get_friends`/`get_incoming_friend_requests`/
  `get_outgoing_friend_requests` are all untouched by the proposed
  migration and still only ever select the pre-existing (never
  populated) `avatar_url` column.
- Friends/Community/Dining Together are explicitly out of scope for this
  pass (see §6) — there is no real feature today that needs a friend or
  a discoverable stranger to read this bucket.
- Postgres RLS on `storage.objects` CAN reference other tables (e.g. a
  policy could join `profiles`/`friendships` the same way
  `search_profiles` does), and a plain SQL RPC CANNOT itself mint a
  Storage signed URL (signed URLs are a Storage-API operation, not a
  Postgres function). Matching the full discoverable-or-related
  eligibility rule for Storage reads would therefore require either (a)
  a more complex RLS policy joining `profiles`/`friendships` directly on
  `storage.objects`, or (b) a dedicated `SECURITY DEFINER` RPC that
  checks eligibility and calls the Storage API to mint a signed URL on
  the caller's behalf. Both are real, non-trivial architecture — exactly
  the "significant secure URL or RPC architecture" this feature's own
  brief said should trigger a STOP rather than a silent implementation.
- Deferring that work is safe specifically because nothing consumes it
  yet: shipping owner-only access now blocks nothing in this pass and
  narrows future work to "extend an existing RLS policy / add one RPC,"
  not "retrofit a security model after avatars are already visible
  cross-account."

**This is the STOP this section names** — reported here, in the
architecture doc, rather than silently building the broader visibility
model. Extending read access to match `is_discoverable`/relationship
visibility is real, separate, deferred work for whichever future pass
actually wires avatar display into Friends/Community-facing surfaces.

### Migration

`supabase/migrations/20260825170000_add_profile_avatar.sql` — **applied
to production 2026-08-25** (`supabase db push --linked`, confirmed via
`supabase migration list`: local/remote timestamps match). Added
`profiles.avatar_path`, created the `profile-photos` bucket, and added
the three owner-only RLS policies described above. Live schema/bucket/
policy state was independently re-confirmed directly against production
after applying (not inferred from the migration file) — see §10. See the
migration file's own inline comments for the full reasoning (mirrors this
document).

## 5. Image handling — deliberately no crop dependency in V1

`lib/features/profile/avatar_picker.dart` — `pickAvatarImage()` uses
`ImagePicker().pickImage` (single image, gallery source only — no
Camera permission requested since nothing in this feature needs one),
`imageQuality: 85`, `maxWidth`/`maxHeight: 1024`, `requestFullMetadata:
false` (no EXIF/GPS read, no extra permission prompt) — the same
compression strategy `staged_photo.dart`'s existing `pickStagedPhotos`
already established for visit photos, with a tighter 1024px cap
appropriate for an avatar.

`pubspec.yaml` was audited before writing this file: only `image_picker`
exists among photo-related dependencies; no `image_cropper` or
equivalent. Adding one would be exactly the "large image-processing
dependency" / "substantial native complexity" this feature's own brief
said to avoid rather than silently add. **No interactive 1:1 crop step
exists in V1** — this is a deliberate, documented limitation, not an
oversight. `MemberAvatar` instead renders any picked aspect ratio as a
clean circle via consistent `BoxFit.cover` + `ClipOval` circular
clipping at DISPLAY time, everywhere it's used.

## 6. `MemberAvatar` — canonical, reusable component

`lib/core/widgets/member_avatar.dart`. Takes an already-resolved,
already-signed `avatarUrl` (never a raw Storage path — resolving that is
the caller's job, via `ProfileRepository.resolveAvatarUrl`) and a
`displayName` for the initials fallback. Renders a photo when present;
falls back to initials on `null`/empty `avatarUrl` AND on any
`Image.network` load error — never a broken-image icon. An optional
`onEdit` callback adds a small pencil badge; omitted by every read-only
consumer.

This pass wires `MemberAvatar` into Profile only (the identity hero and
the Edit Profile sheet, both via `ChangeAvatarSheet`). **Friends,
Community, and Dining Together are explicitly NOT redesigned or wired to
display avatars in this pass** — adopting `MemberAvatar` there is
documented future work, not built now. When that work happens, it also
needs the Storage-visibility extension described in §4.

## 7. Account deletion — profile-photo cleanup is a second hard precondition

`supabase/functions/delete-account/index.ts` — **deployed to production,
version 2** (`supabase functions deploy delete-account`, confirmed via
`supabase functions list`). The existing `visit-photos` purge (§"EXPLICIT_DELETE_REQUIRED" in
`docs/Architecture/ACCOUNT_DELETION.md`) is joined by an identical
`profile-photos` purge, both now sharing one `purgeBucket(admin, bucket,
userId)` helper (previously `purgeVisitPhotos`, generalized —
parameterized only by bucket name, since the recursive-listing/
hard-precondition logic is identical for either bucket).

Order: authenticate → purge `visit-photos` (hard precondition) → purge
`profile-photos` (hard precondition) → `auth.admin.deleteUser`. Either
bucket failing blocks deletion entirely and leaves the caller's session
valid so they can retry — the same reasoning as the original
`visit-photos`-only design: once `auth.users` is deleted, the user's own
JWT is invalidated and they can no longer retry Storage cleanup under
their own identity.

A user who never set an avatar purges an empty `profile-photos` listing
— a normal, successful no-op, not a failure. `profiles.avatar_path`
itself needs no separate handling: it is a plain column on the same
`profiles` row that already cascades from `auth.users` deletion, and by
the time that cascade runs, the Storage OBJECT it pointed to has already
been purged in the precondition step above.

`supabase/functions/delete-account/index.test.ts` — updated with 6 new/
reshaped Deno tests covering: profile-photos purged after visit-photos
and before deletion; an empty profile-photos listing (no avatar ever
set) still deletes normally; a profile-photos list failure blocks
deletion even when visit-photos succeeded; a profile-photos remove
failure blocks deletion even when visit-photos succeeded; the fake
admin's storage entries/errors are now keyed per-bucket so a test can
prove either bucket independently blocks deletion. All 15 tests
(9 original + 6 new/reshaped) pass.

`docs/Architecture/ACCOUNT_DELETION.md` has been updated to reflect this
live, deployed behavior (deletion order, test count, production
verification record) — see that doc's own §3/§5/§7.

## 8. Tests

- `test/journey_metrics_test.dart` (13 tests) — pure-function coverage
  of `computeJourneyMetrics`, per §2's fixtures (restaurant + hotel in
  the same country counting once; multiple visits to one place still
  counting once; a trip in progress vs. completed vs. future; confirmed
  vs. structurally-excluded intent-only event attendance; empty country
  codes excluded).
- `test/member_avatar_test.dart` (8 tests) — the real `MemberAvatar`
  widget directly (no Supabase dependency): initials fallback (two-word
  name, `@username`, empty name), empty-string `avatarUrl` treated as
  null, no gold anywhere, edit affordance presence/absence and tap
  behavior, default vs. overridden size.
- `test/change_avatar_sheet_test.dart` (8 tests) — the real
  `ChangeAvatarSheet` widget via its `pickImage`/`replaceAvatar`/
  `removeAvatar` DI seams: no-avatar vs. has-avatar row set, picker
  cancellation, replace success/failure (failure leaves the prior avatar
  referenced — never an optimistic pop), remove success/failure, Cancel
  calling neither mutation.
- `test/profile_screen_states_test.dart` / `profile_delete_account_entry_test.dart`
  — updated to mirror the redesigned IA (YOUR JOURNEY with Places/
  Events/Trips/Countries; SOCIAL section for Friends; ACCOUNT holding
  only Edit profile/Notifications/Privacy; a new ACCOUNT ACTIONS section
  for Sign out/Delete account).
- `supabase/functions/delete-account/index.test.ts` — see §7.

Live Storage-security and lifecycle testing was run at apply time, using
disposable production users — never the real account — through the
actual PostgREST/Storage API path, not a local SQL simulation, per this
project's own established precedent (Profile Privacy & Discoverability
V1's production validation). See §10 for the full record.

## 9. What this explicitly does NOT do

- Does not touch Friends/Community/Dining Together screens or wire
  `MemberAvatar` into them.
- Does not extend `search_profiles`/`get_profile_identity`/any RPC to
  expose `avatar_path` or a resolved avatar URL to another user.
- Does not add interactive image cropping.
- Does not expand avatar Storage read access beyond owner-only (§4's
  documented STOP — extending to friends/discoverable users is real,
  separate, deferred work, not done here or in the backend apply).

## 10. Production apply & verification (live, disposable accounts — 2026-08-25)

The architecture in §3/§4/§7 above was approved as-is (no redesign, no
scope expansion) and applied against production. All of the following
was run against the real linked project, not simulated:

**Schema/bucket/policy state, confirmed directly (not inferred from the
migration file):**
- `supabase migration list` — `20260825170000` local/remote timestamps
  match (previously empty `remote`).
- `information_schema.columns` — `profiles.avatar_path` is `text`,
  nullable, no default. `avatar_url` unchanged.
- `storage.buckets` — `profile-photos` exists: `public = false`,
  `file_size_limit = 5242880`, `allowed_mime_types = {image/jpeg,
  image/png, image/webp, image/heic}`.
- `pg_policy` on `storage.objects` — exactly three `profile_photos_*`
  policies (`read`/`insert`/`delete`), each scoped to
  `bucket_id = 'profile-photos' AND (storage.foldername(name))[1] =
  auth.uid()::text`. No update policy. No broader grant of any kind.
- Existing production `profiles` row count unaffected by the migration
  (1 row before and after).

**Live disposable-user Storage security test** (Users A, B):
- A uploaded, read, and updated `profiles.avatar_path` for A's own
  object — all succeeded.
- A's attempts to INSERT into, SELECT/read, and DELETE B's object all
  **failed** (403/404 from the real Storage API — RLS-enforced, not
  client-side).
- B's own object was confirmed still present in `storage.objects` after
  A's attack attempts (ground-truth DB check, not just a repeated API
  call — the Storage GET endpoint is CDN-fronted and can return a
  cached response immediately after a real delete, which is a read-path
  caching artifact, not a security finding; the authoritative check is
  the `storage.objects` row itself).
- B confirmed able to read/delete B's own object (control, proving the
  A/B failures above are ownership enforcement, not a generally broken
  bucket).

**Live avatar lifecycle test** (User A): first avatar (upload → set
`avatar_path` → resolve signed URL) → replace (upload new → update
`avatar_path` → delete superseded, mirroring
`ProfileRepository.replaceAvatar`'s exact ordering) → remove (clear
`avatar_path` → delete object). All steps succeeded; `storage.objects`
for `profile-photos` confirmed empty at the end (no orphans left behind
by the test itself).

**Live account-deletion integration test** (User C) — see
`docs/Architecture/ACCOUNT_DELETION.md`'s own "Profile Avatar V1
production verification" record for the full sequence: seeded both
`visit-photos` and `profile-photos` objects plus a dependent
`planned_trips` row, called the live `delete-account` function, verified
complete removal of all five (auth user, profile, dependent row, both
Storage objects), verified stale-token retry still returns 401, verified
control accounts A/B were untouched.

**Cleanup**: all three disposable users (A, B, C) deleted via the Admin
API; confirmed zero `storage.objects` rows remain in `profile-photos`
and zero matching test `auth.users` rows remain. All local files
containing production credentials/tokens were `chmod 600`, never printed
in full, and deleted immediately after the test run.

**What is still NOT verified**: the actual Flutter app on a physical
device performing a real photo-library selection and upload through the
real UI — this requires a human, since this environment has no on-device
UI-interaction capability. The backend this UI depends on is now fully
live and independently proven correct; only the human tap-through
remains.
