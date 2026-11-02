import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/opening_hours.dart';

/// A restaurant's opening hours and closed days (restaurant_opening_hours
/// and restaurant_closures, 20261101180000). Anyone reads them; a manager of the restaurant
/// replaces the whole week through set_restaurant_opening_hours, which
/// goes live at once — no review (decided 2026-11-02).
class OpeningHoursRepository {
  OpeningHoursRepository(this._client);

  final SupabaseClient _client;

  Future<OpeningHours> load(String restaurantId) async {
    final rows = await _client
        .from('restaurant_opening_hours')
        .select('weekday, slot, opens_at, closes_at')
        .eq('restaurant_id', restaurantId);
    return OpeningHours.fromRows((rows as List).cast<Map<String, dynamic>>());
  }

  /// Replaces the week. An empty week takes the hours off the page.
  Future<void> save(String restaurantId, OpeningHours hours) => _client.rpc(
    'set_restaurant_opening_hours',
    params: {'p_restaurant_id': restaurantId, 'p_hours': hours.toRpcJson()},
  );

  /// Closed days that haven't ended yet, soonest first. [today] is the
  /// device's date: a day early or late across timezones only shows a
  /// past closure a little longer.
  Future<List<RestaurantClosure>> loadUpcomingClosures(
    String restaurantId, {
    DateTime? today,
  }) async {
    final now = today ?? DateTime.now();
    final rows = await _client
        .from('restaurant_closures')
        .select('id, starts_on, ends_on')
        .eq('restaurant_id', restaurantId)
        .gte('ends_on', _date(now))
        .order('starts_on', ascending: true);
    return [
      for (final row in rows as List)
        RestaurantClosure.fromJson(row as Map<String, dynamic>),
    ];
  }

  Future<void> addClosure(
    String restaurantId,
    DateTime startsOn,
    DateTime endsOn,
  ) => _client.rpc(
    'add_restaurant_closure',
    params: {
      'p_restaurant_id': restaurantId,
      'p_starts_on': _date(startsOn),
      'p_ends_on': _date(endsOn),
    },
  );

  Future<void> removeClosure(String closureId) => _client.rpc(
    'remove_restaurant_closure',
    params: {'p_closure_id': closureId},
  );

  static String _date(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
