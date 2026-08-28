/// Venue photo submission — Layer 1 validation limits, per the product
/// brief. Pure Dart, no Flutter/image import, matching this app's own
/// `core/` convention (see `photo_limits.dart`) so the numbers themselves
/// stay reusable and unit-testable independent of how they're checked.
library;

/// "maximaal 5 MB" — enforced client-side before upload AND mirrored by
/// the `venue-photo-submissions` Storage bucket's own `file_size_limit`
/// (5242880, see 20260828120000's migration) — belt and suspenders: a
/// client that skips this check still cannot exceed it.
const int maxVenuePhotoSubmissionBytes = 5 * 1024 * 1024;

/// "minimaal 1200 pixels op de korte zijde" — checked against
/// `min(width, height)`, independent of orientation.
const int minVenuePhotoShortSidePx = 1200;

/// "een beeldverhouding tussen 3:4 en 16:9" — both bounds expressed as
/// long-side/short-side (orientation-independent): 3:4 -> 4/3 ≈ 1.333,
/// 16:9 ≈ 1.778. A ratio outside this range is rejected in EITHER
/// direction — too square (nearing 1:1) excludes e.g. Instagram-style
/// square posts, too elongated (above 16:9) excludes wide banners.
const double minVenuePhotoAspectRatio = 4 / 3;
const double maxVenuePhotoAspectRatio = 16 / 9;

/// "Accepteer alleen JPEG en PNG" — matches the Storage bucket's own
/// `allowed_mime_types` exactly (`['image/jpeg', 'image/png']`).
const List<String> allowedVenuePhotoMimeTypes = ['image/jpeg', 'image/png'];
