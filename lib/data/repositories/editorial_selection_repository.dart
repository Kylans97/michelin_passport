import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/restaurant.dart';
import 'restaurant_repository.dart' show restaurantFullColumns;

/// One restaurant currently in the Selection, with the day it was chosen.
typedef SelectionEntry = ({Restaurant restaurant, DateTime selectedOn});

/// Reads our own editorial Selection ("Mantelier Selection" in the app) —
/// `public.editorial_selections` (20261023120000). Current membership is
/// `removed_on is null`; never `restaurants.inclusion_reason`, which is
/// creation provenance only (see that column's comment).
///
/// Works before the migration too: a server without the table answers
/// PostgREST's "not found" (PGRST205), which reads as an empty Selection,
/// so Explore and Guides simply leave the Selection out.
class EditorialSelectionRepository {
  EditorialSelectionRepository(this._client);

  final SupabaseClient _client;

  /// Every current Selection restaurant, most recently chosen first.
  /// Two queries total: the Selection rows, then one batched
  /// restaurants_full lookup.
  Future<List<SelectionEntry>> loadCurrent() async {
    final List<dynamic> rows;
    try {
      rows = await _client
          .from('editorial_selections')
          .select('restaurant_id, selected_on')
          .isFilter('removed_on', null)
          .order('selected_on', ascending: false)
          .order('created_at', ascending: false);
    } on PostgrestException catch (e) {
      if (e.code == 'PGRST205' || e.code == '42P01') return const [];
      rethrow;
    }
    if (rows.isEmpty) return const [];

    final selectedOn = <String, DateTime>{
      for (final row in rows)
        (row['restaurant_id'] as String): DateTime.parse(
          row['selected_on'] as String,
        ),
    };
    final restaurantRows = await _client
        .from('restaurants_full')
        .select(restaurantFullColumns)
        .inFilter('id', selectedOn.keys.toList());
    final byId = {
      for (final row in restaurantRows as List)
        (row['id'] as String): Restaurant.fromJson(row as Map<String, dynamic>),
    };
    return [
      // Keep the Selection's own order (newest first).
      for (final id in selectedOn.keys)
        if (byId[id] case final restaurant?)
          (restaurant: restaurant, selectedOn: selectedOn[id]!),
    ];
  }
}
