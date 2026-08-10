import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/award_history_entry.dart';

// award_history is polymorphic (see production schema migration): the same
// table carries both restaurants' Michelin star history and hotels'
// Michelin Key history, distinguished by entity_type + award_type. Only
// the restaurant/michelin_stars slice is used anywhere yet — see
// loadMichelinHistory's entityType/awardType params for how a future hotel
// Keys history would reuse this unchanged.
const _michelinStarsAwardType = 'michelin_stars';
const _michelinKeysAwardType = 'michelin_keys';

/// Historical (not current) award data for restaurants — and, structurally,
/// hotels later. Deliberately separate from RestaurantRepository/
/// HotelRepository, which only ever resolve *current* catalogue state.
class AwardHistoryRepository {
  AwardHistoryRepository(this._client);

  final SupabaseClient _client;

  /// Every recorded `award_history` row for one entity's Michelin award,
  /// oldest guide year first (the order [detectAwardTransitions] expects,
  /// though it re-sorts defensively regardless). [entityType] is
  /// 'restaurant' today; a future hotel Award History screen would call
  /// this with 'hotel', which resolves to the michelin_keys award_type
  /// automatically.
  Future<List<MichelinAwardHistoryEntry>> loadMichelinHistory({
    required String entityType,
    required String entityId,
  }) async {
    final awardType = entityType == 'hotel'
        ? _michelinKeysAwardType
        : _michelinStarsAwardType;
    final rows = await _client
        .from('award_history')
        .select('guide_year, award_value, is_current, announced_on')
        .eq('entity_type', entityType)
        .eq('entity_id', entityId)
        .eq('award_type', awardType)
        .order('guide_year', ascending: true);
    return (rows as List)
        .map(
          (row) =>
              MichelinAwardHistoryEntry.fromJson(row as Map<String, dynamic>),
        )
        .toList();
  }

  /// Every recorded `worlds_50_best` row for one restaurant (any list_type:
  /// top_50, extended_51_100, hall_of_fame), newest year first for display
  /// — see Worlds50BestHistorySummary for the appearances/best-rank/Hall of
  /// Fame reading of this list.
  Future<List<Worlds50BestHistoryEntry>> loadWorlds50BestHistory(
    String restaurantId,
  ) async {
    final rows = await _client
        .from('worlds_50_best')
        .select('year, rank, list_type')
        .eq('restaurant_id', restaurantId)
        .order('year', ascending: false);
    final result = <Worlds50BestHistoryEntry>[];
    for (final row in (rows as List).cast<Map<String, dynamic>>()) {
      // The DB CHECK constraint guarantees a known list_type, so this only
      // drops a row if the schema itself has changed underneath us —
      // safer than guessing which of the three very different meanings
      // (rank / extended rank / Hall of Fame) an unrecognised value was
      // meant to be.
      final listType = Worlds50BestListType.fromDbValue(
        row['list_type'] as String?,
      );
      if (listType == null) continue;
      result.add(Worlds50BestHistoryEntry.fromJson(row, listType: listType));
    }
    return result;
  }

  /// A cheap existence check — two indexed `limit(1)` lookups run in
  /// parallel, not a full history fetch — used only to decide whether
  /// Restaurant Detail shows the "Award history" action at all. A
  /// restaurant can have real historical rows (e.g. a past World's 50 Best
  /// Hall of Fame induction) without any *current* award_history/
  /// worlds_50_best_rank value, so this can't be derived from the
  /// Restaurant model's own fields alone — see restaurant_detail_screen.dart.
  Future<bool> hasAnyHistory(String restaurantId) async {
    final michelinFuture = _client
        .from('award_history')
        .select('id')
        .eq('entity_type', 'restaurant')
        .eq('entity_id', restaurantId)
        .limit(1);
    final worlds50BestFuture = _client
        .from('worlds_50_best')
        .select('id')
        .eq('restaurant_id', restaurantId)
        .limit(1);
    final results = await Future.wait([michelinFuture, worlds50BestFuture]);
    return (results[0] as List).isNotEmpty || (results[1] as List).isNotEmpty;
  }
}
