# Events V2 Step 4 — Photo Limit Pre-Final Report

**Status: implemented locally, not staged, not committed, not pushed. No migration created or deployed. The 12 existing test-fixture photos were not touched — no read, write, or delete was issued against `event_confirmed_attendance`/`photos` in this task.**

## AUDIT

- **`AttendancePhotosSection`** (`lib/features/events/widgets/attendance_photos_section.dart`) — the "Photos" block inside `AttendanceDetailsSheet`. Owns load/upload/delete state (`_photos`, `_urls`, `_uploading`), calls `PhotoRepository`'s attendance-keyed methods, renders `VisitPhotoGrid` + `AddPhotosButton`. Before this task: no capacity awareness anywhere — `_addPhotos` uploaded every picked image in a sequential loop with no count check at any layer.
- **`PhotoRepository.uploadAttendancePhoto`** — inserted a `photos` row unconditionally (Storage upload, then insert, with orphan-cleanup on insert failure). No count check before this task.
- **Attendance photo loading** — `loadPhotosForAttendance` selects every row for an `attendance_id`, newest-first, no `LIMIT`. Unchanged by this task — the limit is enforced on the write path, never by truncating what's read back.
- **Staged photo picker** — `pickStagedPhotos()` (`lib/features/photos/staged_photo.dart`) wraps `image_picker`'s `pickMultiImage()` with no selection cap; shared verbatim by `VisitPhotosSection` (Restaurant/Hotel), `StagedPhotoPicker` (Add Visit/Add Stay pre-save), and `AttendancePhotosSection`.
- **`AttendanceDetailsSheet`** — embeds `AttendancePhotosSection` unchanged in shape; not touched by this task beyond what `AttendancePhotosSection` itself needed.
- **Relevant tests** — none existed for `AttendancePhotosSection`, `PhotoRepository`, `AddPhotosButton`, or `staged_photo.dart` before this task (confirmed by grep) — all Supabase-eager or platform-channel-eager, the same pre-existing sandbox limitation this feature has had since Step 4.
- **Photos schema/RLS** — re-read both photo migrations (`20260820140000` widens `entity_type` CHECK to permit `'event'`; `20260820150000` adds INSERT ownership enforcement + a storage friends-read bridge). Neither has, needs, or was given any row-count constraint — a maximum-rows-per-parent rule is not expressible as a plain CHECK constraint (it requires either a trigger or a denormalized counter column), and the task explicitly says not to invent a trigger without review.
- **Storage implementation** — `visit-photos` bucket, private, `{userId}/{attendanceId}/{uniqueFilename}` path convention, signed URLs only. Unrelated to the count limit; not touched.

**Conclusion: the limit belongs in application/repository code, not the database.** See DATABASE below.

## LIMIT ARCHITECTURE

One canonical constant, `lib/core/constants/photo_limits.dart` (new file, pure Dart, no Flutter import):

```dart
const int maxEventAttendancePhotos = 6;
```

Three pure functions live alongside it, each with exactly one call site, each independently unit-tested:

- `remainingAttendancePhotoCapacity(int currentPhotoCount) -> int` — used by the UI layer to decide enabled/disabled and to size the picker's advisory limit.
- `canAddAttendancePhoto(int currentPhotoCount) -> bool` — the exact predicate `PhotoRepository.uploadAttendancePhoto` enforces.
- `clampToRemainingCapacity<T>(List<T> picked, int remainingCapacity) -> List<T>` — the defensive multi-pick truncation.

No literal `6` appears anywhere else in the diff — grepped to confirm every reference goes through `maxEventAttendancePhotos` or one of the three functions above. Placed under `lib/core/constants/` (not `lib/features/events/`) specifically per the task's own instruction — this is a plain product-rule constant with zero Flutter/Supabase dependency, reusable verbatim by a future web client or shared business-logic package without dragging in anything mobile-specific.

## UX

`AttendancePhotosSection.build()`: `remaining = remainingAttendancePhotoCapacity(photos.length)` is recomputed from the currently-loaded list on every build (never a stored flag), so:

- 0 photos → `remaining = 6`, Add action enabled, no extra copy.
- 4 photos → `remaining = 2`, Add action enabled.
- 6 photos → `remaining = 0`, Add action **disabled** (not hidden — `AddPhotosButton`'s existing `busy` disabled-affordance pattern was the closer fit than removing the whole button and leaving a layout jump), and a subtle **"Maximum 6 photos"** line appears directly below it — `AppColors.textSecondary`, 12px, no icon, no red — deliberately not styled as an error, since reaching the limit is an expected, normal state.
- Deleting a photo already updates `_photos` locally via `setState` with no re-fetch (pre-existing `_confirmDelete` behavior, unchanged) — so the very next `build()` recomputes `remaining` from the shorter list and the Add action re-enables **immediately**, with no extra wiring needed.

## MULTI-PICK

`_addPhotos` now:

1. Computes `remaining` before ever opening the picker; returns early (no-op) if `remaining <= 0` — a defensive backstop, since the Add action is already disabled in that state.
2. Calls `pickStagedPhotos(limit: remaining)` — `image_picker`'s own `pickMultiImage(limit: ...)` parameter, which asks the OS-level picker (PHPickerViewController's `selectionLimit` on iOS, the Android Photo Picker's `maxItems`) to cap selection at the source. **Preventing over-selection at the picker itself**, per the task's stated preference, wherever the platform honors it.
3. Regardless of what the picker returns, `clampToRemainingCapacity(picked, remaining)` truncates defensively — `image_picker`'s own doc comment states the `limit` parameter "may be ignored by platforms that cannot support it," so this is not optional belt-and-suspenders, it's the actual guarantee.
4. Only the clamped (`accepted`) subset is ever passed to `uploadAttendancePhoto` — **the excess is never attempted, never uploaded, and therefore never needs deleting afterward.**
5. If `accepted.length < picked.length`, a brief, non-error-styled (`forestGreen`, matching `VisitPhotosSection`'s own existing `isError: false` convention) snackbar explains: *"Only N of M photos were added — maximum 6 photos per event."*

The task's exact example (4 existing, 5 selected → 2 accepted) is directly asserted in `photo_limits_test.dart`.

## ENFORCEMENT

Not presentation-only. `PhotoRepository.uploadAttendancePhoto` now:

```dart
final currentCount = await _attendancePhotoCount(attendanceId);
if (!canAddAttendancePhoto(currentCount)) {
  throw const AttendancePhotoLimitExceededException();
}
```

— run **before** any Storage upload or `photos` insert is attempted, using a new `_attendancePhotoCount` helper (`select id ... eq('attendance_id', ...)`, row-count via list length — this codebase has no established `count: CountOption.exact` head-request pattern anywhere yet, and a plain fetch is trivially cheap at a maximum of 6 rows). A caller that bypasses the UI entirely and calls this method directly still cannot exceed the limit through this code path.

**This is check-then-act, not a database-level atomic guarantee.** Documented explicitly in the method's own doc comment and here, per the task's own instruction to surface this rather than either building disproportionate schema complexity or silently shipping a weaker guarantee than it looks like: a genuinely race-safe version would need either a `SELECT ... FOR UPDATE` row lock scoped to the attendance, or a trigger-maintained denormalized count column with its own CHECK constraint. Neither was built — the realistic threat model is a single user on a single device uploading through one sequential (`await`-in-a-loop) picker flow, for which this check is already the correct, sufficient guard; the only theoretical gap is two different devices racing an upload to the *same* attendance in the same instant, which is not a scenario this app's UI can even construct today (one user, one active upload flow at a time). **No trigger was added.**

## EXISTING >6 PHOTOS

Not touched, not truncated, not hidden — verified by construction, not merely by intent:

- `loadPhotosForAttendance` has no `LIMIT` clause, unchanged.
- `VisitPhotoGrid` renders `photos.length` items unconditionally (`itemCount: photos.length` — grepped, no `.take()`/`.sublist()` anywhere in that file, and this task added none).
- `AttendancePhotosSection.build()` passes the **full** `photos` list to `VisitPhotoGrid` regardless of length; only the *separate* `AddPhotosButton`/"Maximum" text react to the count.
- `_confirmDelete` is completely unchanged — every existing tile, including photos 7–12, keeps its working delete action.

`attendance_photos_section_shell_test.dart` directly asserts a 7-photo and a 12-photo fixture both render every tile (`grid.photos, hasLength(12)`) while the Add action is correctly disabled alongside them — proving these are independent, not coupled.

## ANALYTICS

Unchanged. `event_photo_added` still fires exactly once per photo whose `uploadAttendancePhoto` call actually succeeds (`for (var i = 0; i < successes; i++) widget.onPhotoUploaded();`, in `AttendancePhotosSection`, untouched by this task). Photos clamped away by `clampToRemainingCapacity` are never attempted, so they were never counted toward `successes` — no event fires for them. Photos rejected by the repository's new capacity check throw and land in the existing `failures` counter — same "no event on failure" path every other upload failure already used. **No new photo-limit analytics event or property was added**, per explicit instruction.

## REGRESSION

- **`VisitPhotosSection`** (Restaurant/Hotel) — not modified, does not import `photo_limits.dart`, calls `pickStagedPhotos()` and `AddPhotosButton(...)` with no new parameters — both default to their pre-existing unlimited/enabled behavior. Confirmed by grep (only `attendance_photos_section.dart` and `photo_repository.dart` import the new constants file) and by the full test suite passing unchanged.
- **`PhotoRepository.uploadPhoto`** (the Restaurant/Hotel upload method) — completely untouched; only a doc-comment note was added explaining why it deliberately has no limit.
- **`AddPhotosButton`/`pickStagedPhotos`** — both shared, both received a purely additive optional parameter (`enabled = true`, `limit = null`) that every pre-existing caller omits, so their default behavior is byte-for-byte unchanged. Proven by `add_photos_button_test.dart`'s first group (explicitly asserts the omitted-`enabled` shape) and by the pre-existing `add_visit_sheet_shell_test.dart` continuing to pass.

No Event-only limit leaked into any Restaurant/Hotel code path.

## DATABASE

**Zero migrations, zero schema changes, zero production writes.** No new file was created under `supabase/migrations/`. Confirmed via `git status --short supabase/migrations/` — only the three pre-existing untracked files from before this task (two already deployed, one deployed in the prior turn) appear; nothing new. This was a deliberate, audited conclusion (see AUDIT/ENFORCEMENT above), not an oversight — reported here rather than silently assumed, per the task's own "if you conclude a database change is necessary, STOP and report it" instruction (inverted: this reports the conclusion that **none** is necessary, and why).

## VALIDATION

- `dart format --set-exit-if-changed .` — **0 files changed**.
- `flutter analyze` — **No issues found!**
- `flutter test` — **1266 passed, 0 failed** (baseline 1235 + 31 new tests — no existing test was weakened).
- **Not independently tested, disclosed rather than hidden**: `pickStagedPhotos`'s new `limit` parameter cannot be exercised directly — `image_picker`'s `ImagePicker()` requires a real platform channel, and no test anywhere in this codebase (before or after this task) mocks that plugin; this was already true of `pickStagedPhotos()` before this task and remains an untested integration point, matching this feature's own established, already-accepted sandbox limitation. `PhotoRepository.uploadAttendancePhoto`'s actual throw path (Storage + Supabase-eager) is likewise not live-tested — but the predicate it wraps, `canAddAttendancePhoto`, is fully and directly tested, which is the actual enforcement decision.

### New/updated tests

- `photo_limits_test.dart` (new) — the constant's value; `remainingAttendancePhotoCapacity` at 0/4/5/6/12 existing photos; `canAddAttendancePhoto` below/at/over the limit (including the 12-photo fixture case); `clampToRemainingCapacity`'s full matrix including the task's exact 4-existing/5-selected/2-accepted example, the 0-remaining case, and a defensive negative-remaining case.
- `add_photos_button_test.dart` (new) — default (`enabled` omitted) shape unchanged; `enabled: false` disables `onPressed`, never uses `AppColors.error`, uses the muted `textSecondary` tint, still renders its label (disabled, not hidden).
- `attendance_photos_section_shell_test.dart` (new) — 0/5/6-photo capacity states; delete-from-6-enables-again; 7-photo and 12-photo fixtures both render every tile while correctly disabled; busy+at-capacity composes correctly; 320px and 1.6x text scale at capacity and at 12 photos, no overflow.
- `photo_repository.dart`'s doc comments updated; no direct new test (Supabase-eager, see VALIDATION above) — its logic is proven via `canAddAttendancePhoto` above.

## FILES

**New**: `lib/core/constants/photo_limits.dart`, `test/photo_limits_test.dart`, `test/add_photos_button_test.dart`, `test/attendance_photos_section_shell_test.dart`, this report.

**Modified**: `lib/data/repositories/photo_repository.dart`, `lib/features/events/widgets/attendance_photos_section.dart`, `lib/features/photos/staged_photo.dart`, `lib/features/photos/widgets/add_photos_button.dart`.

## GIT

**Nothing staged, committed, or pushed.** `git diff --cached --stat` is empty. `HEAD` is still `56bc57b2672fcb00c3fa34aef20a4a6b7699742d`, identical to `origin/main`. No file under `supabase/migrations/` was created. No read, write, or delete was issued against `event_confirmed_attendance` or `photos` in this task — the 12 existing physical-device test photos are untouched, still exactly 12, still fully renderable/removable once this code ships. Working tree also still contains the same pre-existing unrelated in-progress artifacts (Events V2 Step 4/4.1 feature set awaiting its own commit, Michelin/Gault&Millau enrichment reports) left untouched.

---

## MAX EVENT ATTENDANCE PHOTOS = 6

**STOP.**
