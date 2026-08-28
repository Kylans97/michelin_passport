/// Venue photo display variants, built from Supabase's own Image
/// Transformation render endpoint — no separate stored asset per
/// displayed size. Verified directly against this project's live
/// Storage API before choosing this route (Pro-tier-and-above feature;
/// confirmed enabled here): `GET /storage/v1/render/image/public/
/// {bucket}/{path}?width=&height=` returns a real resized image with no
/// `apikey` header required for a public bucket, so these URLs work
/// directly in `Image.network`/`NetworkImage` with no custom headers.
///
/// See supabase/migrations/20260828130000_add_photo_duplicate_detection_
/// and_focus_point.sql's own header comment for the full route
/// decision, including why the THUMBNAIL variant points at a separate,
/// pre-cropped "thumb source" object rather than the original: the
/// render endpoint's `resize=cover` always crops to center, with no
/// focus-point/gravity parameter at all — a limitation confirmed against
/// Supabase's own docs, not assumed. Medium and hero both read the
/// original object directly; only the thumbnail needs the pre-cropped
/// source this file expects as a separate path.
library;

const _catalogueMediaBucket = 'catalogue-media';

/// A thumbnail for the Community list / small avatar-style slots —
/// small and square. [thumbSourcePath] must point at the pre-cropped,
/// focus-point-centered square object generated at approval time (see
/// the migration comment above) — passing the original, un-cropped
/// photo's path here would silently re-introduce the center-crop
/// problem this variant exists to avoid.
String venuePhotoThumbnailUrl({
  required String supabaseUrl,
  required String thumbSourcePath,
  int size = 128,
}) => _renderUrl(
  supabaseUrl: supabaseUrl,
  bucket: _catalogueMediaBucket,
  path: thumbSourcePath,
  width: size,
  height: size,
);

/// A medium-sized crop for wishlist/passport cards — reads the
/// ORIGINAL approved photo directly (never the thumbnail's pre-cropped
/// source), center-cropped to [width]x[height] via `resize=cover`. Not
/// focus-point-aware — see the migration's header comment for why that
/// scoping call was made only for the much smaller, much more
/// aggressively cropped thumbnail.
String venuePhotoMediumUrl({
  required String supabaseUrl,
  required String originalPath,
  int width = 480,
  int height = 320,
}) => _renderUrl(
  supabaseUrl: supabaseUrl,
  bucket: _catalogueMediaBucket,
  path: originalPath,
  width: width,
  height: height,
);

/// The hero — the original approved photo, full resolution, no crop.
/// Deliberately the PLAIN object endpoint (`/object/public/...`), not
/// the render endpoint: that endpoint serves the stored bytes exactly
/// as uploaded, with no transformation or re-encoding of any kind — the
/// correct behaviour for "the original," not something achieved by
/// passing parameters to the transform endpoint instead.
String venuePhotoHeroUrl({
  required String supabaseUrl,
  required String originalPath,
}) => '$supabaseUrl/storage/v1/object/public/$_catalogueMediaBucket/$originalPath';

String _renderUrl({
  required String supabaseUrl,
  required String bucket,
  required String path,
  required int width,
  required int height,
  String resize = 'cover',
}) {
  return '$supabaseUrl/storage/v1/render/image/public/$bucket/$path'
      '?width=$width&height=$height&resize=$resize';
}
