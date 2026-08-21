/// Events V2 Step 4 — final photo limit correction. Pure Dart, no Flutter
/// import: the one canonical home for this product rule so a future web
/// client/shared business-logic layer can reuse it verbatim, matching this
/// app's own `core/` convention (cross-cutting concerns that aren't
/// widgets live here, not under `features/`).
///
/// Scoped to confirmed Event Attendance only — Restaurant/Hotel visit
/// photos have no maximum today and this constant must never be applied
/// to that flow (see [VisitPhotosSection], which does not import this
/// file).
const int maxEventAttendancePhotos = 6;

/// How many more photos may be added to an attendance currently holding
/// [currentPhotoCount] — never negative, never exceeds
/// [maxEventAttendancePhotos]. `0` means the Add action must be
/// unavailable.
int remainingAttendancePhotoCapacity(int currentPhotoCount) =>
    (maxEventAttendancePhotos - currentPhotoCount).clamp(
      0,
      maxEventAttendancePhotos,
    );

/// The repository-layer predicate `PhotoRepository.uploadAttendancePhoto`
/// enforces before ever touching Storage or `public.photos` — kept as a
/// pure, standalone function (no Supabase client, no `this`) specifically
/// so this capacity check is unit-testable without a live client, matching
/// this codebase's existing pattern for repository decision logic (see
/// `buildAttendanceDetailsUpdate` in `event_confirmed_attendance_repository
/// .dart`). Equivalent to `remainingAttendancePhotoCapacity(currentPhotoCount)
/// > 0`, spelled out separately because "may I add one more" reads more
/// directly as a yes/no gate at its one call site than a capacity number
/// would.
bool canAddAttendancePhoto(int currentPhotoCount) =>
    currentPhotoCount < maxEventAttendancePhotos;

/// Truncates a freshly-picked batch to at most [remainingCapacity] items —
/// the defensive clamp applied even after the OS-level picker was already
/// asked to cap selection at that same number (`image_picker`'s own docs:
/// "This value may be ignored by platforms that cannot support it").
/// Deliberately never uploads the excess and deletes it afterward — excess
/// items are simply never attempted. `remainingCapacity <= 0` yields an
/// empty list rather than throwing; the caller is expected to have already
/// prevented reaching this point via [canAddAttendancePhoto]/the disabled
/// Add action, so this is a defensive floor, not the primary guard.
List<T> clampToRemainingCapacity<T>(List<T> picked, int remainingCapacity) =>
    remainingCapacity <= 0 ? const [] : picked.take(remainingCapacity).toList();
