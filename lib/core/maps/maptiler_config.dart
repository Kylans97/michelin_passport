import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Street-map tiles for the event location picker, from MapTiler.
///
/// The key is a MapTiler **client** key: like the Supabase anon key it ships
/// inside the app and is public by design. A copied key can only use up the
/// account's monthly tile allowance — on the free plan MapTiler then stops
/// serving tiles rather than billing — so nothing secret is at stake.
///
/// Replaces direct `tile.openstreetmap.org` requests, which OpenStreetMap's
/// tile usage policy doesn't allow a published app to make at volume.
class MapTilerConfig {
  MapTilerConfig._();

  /// MapTiler's Streets map, as 256 px raster tiles; `{r}` becomes `@2x` on
  /// high-density screens (flutter_map's retina mode).
  static const style = 'streets-v2';

  /// Null when `MAPTILER_KEY` is missing or empty in `.env` (or `.env` was
  /// never loaded, as in widget tests) — callers show no map rather than
  /// falling back to OpenStreetMap's own tile servers.
  static String? get key {
    try {
      final value = dotenv.env['MAPTILER_KEY']?.trim();
      return value == null || value.isEmpty ? null : value;
    } catch (_) {
      return null;
    }
  }

  static String urlTemplate(String key) =>
      'https://api.maptiler.com/maps/$style/256/{z}/{x}/{y}{r}.png?key=$key';

  /// The attribution MapTiler's terms require to stay visible on the map.
  static const attribution = '© MapTiler © OpenStreetMap contributors';
  static final maptilerCopyright = Uri.parse(
    'https://www.maptiler.com/copyright/',
  );
  static final openStreetMapCopyright = Uri.parse(
    'https://www.openstreetmap.org/copyright',
  );
}
