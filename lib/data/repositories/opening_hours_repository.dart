import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/opening_hours.dart';

/// A restaurant's opening hours (restaurant_opening_hours,
/// 20261101180000). Anyone reads them; a manager of the restaurant
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
}
