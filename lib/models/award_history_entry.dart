// Maps rows from `public.award_history` and `public.worlds_50_best` (see
// supabase/migrations/20260805141519_production_schema_v1.sql). These are
// raw historical rows, deliberately separate from Restaurant/Hotel — a
// restaurant's *current* michelinStars/worlds50BestRank must never be
// confused with, or reconstructed from, its history, and vice versa.

/// One raw `award_history` row for a single guide year. `award_history` is
/// polymorphic (entity_type/entity_id, award_type 'michelin_stars' vs
/// 'michelin_keys') and shared by restaurants and hotels — this model only
/// carries the fields needed to detect transitions and display them, not
/// the entity/award-type columns themselves, since the repository method
/// that loads a list of these has already scoped the query to one
/// entity + one award type.
class MichelinAwardHistoryEntry {
  final int guideYear;

  // NULL is a real possibility per schema (award_value has no NOT NULL
  // constraint) and is treated as "unknown for this year" — never coerced
  // to 0. A recorded 0 (no award that year) is a distinct, real state; see
  // AwardTransition's "lost"/"regained" handling.
  final int? awardValue;

  final bool isCurrent;
  final DateTime? announcedOn;

  const MichelinAwardHistoryEntry({
    required this.guideYear,
    required this.awardValue,
    required this.isCurrent,
    this.announcedOn,
  });

  factory MichelinAwardHistoryEntry.fromJson(Map<String, dynamic> json) =>
      MichelinAwardHistoryEntry(
        guideYear: (json['guide_year'] as num).toInt(),
        awardValue: (json['award_value'] as num?)?.toInt(),
        isCurrent: (json['is_current'] as bool?) ?? false,
        announcedOn: json['announced_on'] != null
            ? DateTime.tryParse(json['announced_on'] as String)
            : null,
      );
}

/// The three permitted values of `worlds_50_best.list_type`. Stores the
/// exact database strings via [dbValue] — do not rename these without a
/// migration.
enum Worlds50BestListType {
  topFifty('top_50'),
  extended('extended_51_100'),
  hallOfFame('hall_of_fame');

  final String dbValue;
  const Worlds50BestListType(this.dbValue);

  static Worlds50BestListType? fromDbValue(String? value) {
    if (value == null) return null;
    for (final type in Worlds50BestListType.values) {
      if (type.dbValue == value) return type;
    }
    return null;
  }
}

/// One raw `worlds_50_best` row for a single year. Unlike Michelin history,
/// every row here is meaningful on its own and shown as-is — see
/// Worlds50BestHistorySummary for the derived appearances/best-rank/Hall of
/// Fame reading of a full list of these.
class Worlds50BestHistoryEntry {
  final int year;

  // NULL for Hall of Fame rows (rank is not a Hall of Fame concept) — never
  // coerced to a number.
  final int? rank;

  final Worlds50BestListType listType;

  const Worlds50BestHistoryEntry({
    required this.year,
    required this.rank,
    required this.listType,
  });

  // [listType] is pre-resolved by the caller (see
  // AwardHistoryRepository.loadWorlds50BestHistory), which drops any row
  // whose list_type doesn't parse rather than guessing — the DB CHECK
  // constraint means that should never actually happen, but silently
  // defaulting an unparseable Hall of Fame/extended row to topFifty would
  // misrepresent it, so this factory requires the resolved type up front
  // instead of resolving (and potentially mis-defaulting) it itself.
  factory Worlds50BestHistoryEntry.fromJson(
    Map<String, dynamic> json, {
    required Worlds50BestListType listType,
  }) => Worlds50BestHistoryEntry(
    year: (json['year'] as num).toInt(),
    rank: (json['rank'] as num?)?.toInt(),
    listType: listType,
  );
}
