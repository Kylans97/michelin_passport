import 'package:supabase_flutter/supabase_flutter.dart';

/// One friend tagged on a visit (`visit_companions`, 20261101850000).
///
/// Only the visit's owner sees [status] `pending` or `declined`; everyone
/// else who may read the visit sees accepted companions only. The server
/// decides that (get_visit_companions), never this class.
class VisitCompanion {
  final String tagId;
  final String visitId;
  final String userId;
  final String? username;
  final String? displayName;
  final String? avatarUrl;
  final String status;

  /// The companion's own copy of the visit, when they added it to their
  /// Passport.
  final String? copyVisitId;

  const VisitCompanion({
    required this.tagId,
    required this.visitId,
    required this.userId,
    required this.status,
    this.username,
    this.displayName,
    this.avatarUrl,
    this.copyVisitId,
  });

  bool get isAccepted => status == 'accepted';
  bool get isPending => status == 'pending';

  /// A real name, then "@username", then a neutral default.
  String get label {
    final name = displayName?.trim();
    if (name != null && name.isNotEmpty) return name;
    final handle = username?.trim();
    if (handle != null && handle.isNotEmpty) return '@$handle';
    return 'Mantelier member';
  }

  /// The first name, for "with Pieter" lines.
  String get firstName => label.startsWith('@') ? label : label.split(' ').first;

  factory VisitCompanion.fromRow(Map<String, dynamic> row) => VisitCompanion(
    tagId: (row['tag_id'] ?? row['id']) as String,
    visitId: row['visit_id'] as String,
    userId: row['user_id'] as String,
    username: row['username'] as String?,
    displayName: row['display_name'] as String?,
    avatarUrl: row['avatar_url'] as String?,
    status: row['status'] as String,
    copyVisitId: row['copy_visit_id'] as String?,
  );
}

/// "Pieter", "Pieter and Anouk", "Pieter, Anouk and Joris",
/// "Pieter and 3 others".
String companionsLine(List<String> names) {
  if (names.isEmpty) return '';
  if (names.length == 1) return names.first;
  if (names.length == 2) return '${names[0]} and ${names[1]}';
  if (names.length == 3) return '${names[0]}, ${names[1]} and ${names[2]}';
  return '${names.first} and ${names.length - 1} others';
}

/// Tags the friends a member was with on a visit. Every write is a
/// server function: the table has no client write grant.
class VisitCompanionRepository {
  VisitCompanionRepository(this._client);

  final SupabaseClient _client;

  /// Companions for these visits, keyed by visit id. On a server without
  /// 20261101850000 every visit simply has none.
  Future<Map<String, List<VisitCompanion>>> forVisits(
    Iterable<String> visitIds,
  ) async {
    final ids = visitIds.toSet().toList();
    if (ids.isEmpty) return const {};
    try {
      final rows = await _client.rpc(
        'get_visit_companions',
        params: {'p_visit_ids': ids},
      );
      final map = <String, List<VisitCompanion>>{};
      for (final r in (rows as List).cast<Map<String, dynamic>>()) {
        final c = VisitCompanion.fromRow(r);
        (map[c.visitId] ??= []).add(c);
      }
      return map;
    } on PostgrestException catch (e) {
      if (e.code == 'PGRST202') return const {};
      rethrow;
    }
  }

  /// Sets the full list of friends on the member's own visit. New names
  /// are notified; names left out are removed.
  Future<List<VisitCompanion>> setCompanions(
    String visitId,
    List<String> userIds,
  ) async {
    await _client.rpc(
      'set_visit_companions',
      params: {'p_visit_id': visitId, 'p_user_ids': userIds},
    );
    return (await forVisits([visitId]))[visitId] ?? const [];
  }

  /// The tagged friend answers. Returns their own copy's id when one was
  /// made or found.
  Future<String?> respond(
    String tagId, {
    required bool accept,
    bool addToPassport = true,
  }) async {
    final result = await _client.rpc(
      'respond_to_visit_tag',
      params: {
        'p_tag_id': tagId,
        'p_accept': accept,
        'p_add_to_passport': addToPassport,
      },
    );
    if (result is Map) return result['copy_visit_id'] as String?;
    return null;
  }

  /// Either person removes a tag. A copy in the friend's Passport stays.
  Future<void> remove(String tagId) =>
      _client.rpc('remove_visit_tag', params: {'p_tag_id': tagId});
}
