import 'package:supabase_flutter/supabase_flutter.dart';

/// A fixed challenge set by Mantelier (20261101870000), in its current
/// period.
class Challenge {
  final String id;
  final String slug;
  final String title;
  final String description;

  /// 'month', 'year' or 'open'.
  final String cadence;
  final DateTime periodStart;
  final DateTime? periodEnd;

  const Challenge({
    required this.id,
    required this.slug,
    required this.title,
    required this.description,
    required this.cadence,
    required this.periodStart,
    this.periodEnd,
  });

  factory Challenge.fromRow(Map<String, dynamic> r) => Challenge(
    id: r['id'] as String,
    slug: r['slug'] as String,
    title: r['title'] as String,
    description: r['description'] as String,
    cadence: r['cadence'] as String,
    periodStart: DateTime.parse(r['period_start'] as String),
    periodEnd: r['period_end'] == null
        ? null
        : DateTime.parse(r['period_end'] as String),
  );

  /// "Until 30 November", "Until 31 December", "Until it's done".
  String get periodLabel {
    final end = periodEnd;
    if (end == null) return "Until it's done";
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June', 'July',
      'August', 'September', 'October', 'November', 'December',
    ];
    return 'Until ${end.day} ${months[end.month - 1]}';
  }
}

/// One person on a ranking: a challenge's or a standing's.
class RankingPlace {
  final String userId;
  final String? username;
  final String? displayName;
  final String? avatarUrl;
  final bool isMe;
  final int rank;

  /// Progress on a challenge, or the total on a standing.
  final int value;

  /// A challenge's target; null on a standing.
  final int? target;
  final DateTime? completedOn;

  const RankingPlace({
    required this.userId,
    required this.isMe,
    required this.rank,
    required this.value,
    this.username,
    this.displayName,
    this.avatarUrl,
    this.target,
    this.completedOn,
  });

  bool get completed => completedOn != null;

  String get label {
    if (isMe) return 'You';
    final name = displayName?.trim();
    if (name != null && name.isNotEmpty) return name;
    final handle = username?.trim();
    if (handle != null && handle.isNotEmpty) return '@$handle';
    return 'Mantelier member';
  }

  factory RankingPlace.fromChallengeRow(Map<String, dynamic> r) => RankingPlace(
    userId: r['user_id'] as String,
    username: r['username'] as String?,
    displayName: r['display_name'] as String?,
    avatarUrl: r['avatar_url'] as String?,
    isMe: r['is_me'] as bool? ?? false,
    rank: (r['rank'] as num).toInt(),
    value: (r['progress'] as num).toInt(),
    target: (r['target'] as num?)?.toInt(),
    completedOn: r['completed_on'] == null
        ? null
        : DateTime.parse(r['completed_on'] as String),
  );

  factory RankingPlace.fromStandingRow(Map<String, dynamic> r) => RankingPlace(
    userId: r['user_id'] as String,
    username: r['username'] as String?,
    displayName: r['display_name'] as String?,
    avatarUrl: r['avatar_url'] as String?,
    isMe: r['is_me'] as bool? ?? false,
    rank: (r['rank'] as num).toInt(),
    value: (r['total'] as num).toInt(),
  );
}

/// The standings among friends.
enum StandingKind {
  stars('stars', 'Stars', 'starred restaurants'),
  w50b('w50b', '50 Best', "World's 50 Best restaurants"),
  selection('selection', 'Selection', 'Selection restaurants');

  const StandingKind(this.wire, this.label, this.unit);
  final String wire;
  final String label;

  /// What the number counts, for a row's meta line.
  final String unit;
}

/// Challenges and standings among the member and their friends. Only
/// visits shared with friends count; the server decides that.
class ChallengeRepository {
  ChallengeRepository(this._client);

  final SupabaseClient _client;

  /// The active challenges; none on a server without 20261101870000.
  Future<List<Challenge>> challenges() async {
    try {
      final rows = await _client.rpc('get_challenges');
      return [
        for (final r in (rows as List).cast<Map<String, dynamic>>())
          Challenge.fromRow(r),
      ];
    } on PostgrestException catch (e) {
      if (e.code == 'PGRST202') return const [];
      rethrow;
    }
  }

  Future<List<RankingPlace>> ranking(String challengeId) async {
    final rows = await _client.rpc(
      'get_challenge_ranking',
      params: {'p_challenge_id': challengeId},
    );
    return [
      for (final r in (rows as List).cast<Map<String, dynamic>>())
        RankingPlace.fromChallengeRow(r),
    ];
  }

  Future<List<RankingPlace>> standings(StandingKind kind) async {
    final rows = await _client.rpc(
      'get_friend_standings',
      params: {'p_kind': kind.wire},
    );
    return [
      for (final r in (rows as List).cast<Map<String, dynamic>>())
        RankingPlace.fromStandingRow(r),
    ];
  }
}

/// "1st", "2nd", "3rd", "4th", "11th", "21st".
String ordinal(int n) {
  final lastTwo = n % 100;
  if (lastTwo >= 11 && lastTwo <= 13) return '${n}th';
  return switch (n % 10) {
    1 => '${n}st',
    2 => '${n}nd',
    3 => '${n}rd',
    _ => '${n}th',
  };
}
