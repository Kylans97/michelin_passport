// Maps rows from `public.worlds_50_best_hotels` (see
// supabase/migrations/20260807160000_create_worlds_50_best_hotels.sql,
// prepared but not yet applied remotely). Deliberately a separate model
// from Worlds50BestHistoryEntry (award_history_entry.dart), not a reuse of
// it — that type's list_type enum carries a 'hallOfFame' value with no
// hotel equivalent (The World's 50 Best Hotels publishes no Hall of Fame /
// Best-of-the-Best mechanism, confirmed during research), and giving hotels
// a type that can even represent Hall of Fame would leave a reachable
// nonsense state. This type's list_type enum has exactly the two values
// hotels' real data has, structurally, not just by convention.

/// The two permitted values of `worlds_50_best_hotels.list_type`. Stores the
/// exact database strings via [dbValue] — do not rename these without a
/// migration. Only two members, deliberately: there is no Hall of Fame
/// concept for hotels.
enum HotelWorlds50BestListType {
  topFifty('top_50'),
  extended('extended_51_100');

  final String dbValue;
  const HotelWorlds50BestListType(this.dbValue);

  static HotelWorlds50BestListType? fromDbValue(String? value) {
    if (value == null) return null;
    for (final type in HotelWorlds50BestListType.values) {
      if (type.dbValue == value) return type;
    }
    return null;
  }
}

/// One raw `worlds_50_best_hotels` row for a single year. Every row is
/// meaningful on its own and shown as-is — not collapsed into transitions
/// the way Michelin Key history is, since each yearly ranking matters
/// independently (mirrors Worlds50BestHistoryEntry's treatment for
/// restaurants).
class HotelWorlds50BestEntry {
  final int year;

  // NULL is possible per schema (rank has no NOT NULL constraint) — never
  // coerced to a number.
  final int? rank;

  final HotelWorlds50BestListType listType;

  const HotelWorlds50BestEntry({
    required this.year,
    required this.rank,
    required this.listType,
  });

  // [listType] is pre-resolved by the caller (see
  // AwardHistoryRepository.loadWorlds50BestHotelsHistory), which drops any
  // row whose list_type doesn't parse rather than guessing — the DB CHECK
  // constraint means that should never actually happen, but silently
  // defaulting an unparseable row to topFifty would misrepresent it.
  factory HotelWorlds50BestEntry.fromJson(
    Map<String, dynamic> json, {
    required HotelWorlds50BestListType listType,
  }) => HotelWorlds50BestEntry(
    year: (json['year'] as num).toInt(),
    rank: (json['rank'] as num?)?.toInt(),
    listType: listType,
  );
}
