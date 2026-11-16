import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/booking_window.dart';

/// A restaurant's booking window (restaurant_booking_windows and
/// restaurant_booking_releases, 20261101400000). Anyone reads it; a
/// manager of the restaurant replaces it through
/// set_restaurant_booking_window, which goes live at once — no review
/// (decided 2026-11-16, like opening hours).
class BookingWindowRepository {
  BookingWindowRepository(this._client);

  final SupabaseClient _client;

  /// Null when the restaurant has no window on record.
  Future<BookingWindow?> load(String restaurantId) async {
    final row = await _client
        .from('restaurant_booking_windows')
        .select(
          'kind, timezone, rolling_amount, rolling_unit, release_day, '
          'months_ahead, release_time, platform, source_kind, source_url, '
          'verified_on',
        )
        .eq('restaurant_id', restaurantId)
        .maybeSingle();
    if (row == null) return null;
    final releases = await _client
        .from('restaurant_booking_releases')
        .select('release_on, release_time, covers_from, covers_to')
        .eq('restaurant_id', restaurantId)
        .order('release_on', ascending: true);
    return BookingWindow.fromRow(
      row,
      releases: [
        for (final r in (releases as List).cast<Map<String, dynamic>>())
          BookingRelease.fromRow(r),
      ],
    );
  }

  /// The timezones of the restaurant's country (countries.timezones). A
  /// window must use one of them; with exactly one, the server fills it in.
  Future<List<String>> countryTimezones(String countryCode) async {
    final row = await _client
        .from('countries')
        .select('timezones')
        .eq('country_code', countryCode)
        .maybeSingle();
    return [...((row?['timezones'] as List?) ?? const []).cast<String>()];
  }

  /// Replaces the window; null takes it off.
  Future<void> save(String restaurantId, BookingWindow? window) => _client.rpc(
    'set_restaurant_booking_window',
    params: {'p_restaurant_id': restaurantId, 'p_window': window?.toRpcJson()},
  );
}
