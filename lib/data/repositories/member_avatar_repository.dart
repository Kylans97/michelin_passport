import 'package:supabase_flutter/supabase_flutter.dart';
import 'profile_repository.dart';

/// Signed photo URLs for other members — friends, people in a pending
/// request, and discoverable members found in search.
///
/// `get_member_avatar_paths` (20261031120000) returns the current photo
/// path of each listed member the caller may see under the same identity
/// rule search_profiles applies (no block, and discoverable or friends or
/// a pending request); the storage policy from the same migration lets the
/// caller sign exactly those objects. URLs are signed through
/// [ProfileRepository.resolveAvatarUrl], so they get the same size
/// transform as the viewer's own photo.
///
/// Best effort, never throws: before that migration is applied the RPC
/// doesn't exist and every member simply keeps their initials. Signed URLs
/// are cached for the life of the app, a little short of their one-hour
/// expiry, so scrolling the same faces doesn't sign them again.
class MemberAvatarRepository {
  MemberAvatarRepository._(this._client, this._profiles);

  static MemberAvatarRepository? _instance;

  /// One per client, so the cache is shared across screens.
  factory MemberAvatarRepository(SupabaseClient client) {
    final existing = _instance;
    if (existing != null && identical(existing._client, client)) {
      return existing;
    }
    return _instance = MemberAvatarRepository._(
      client,
      ProfileRepository(client),
    );
  }

  final SupabaseClient _client;
  final ProfileRepository _profiles;

  static const _ttl = Duration(minutes: 50);
  final _cache = <String, ({String? url, DateTime at})>{};

  /// userId → signed URL, for the members in [userIds] who have a photo
  /// the caller may see. Everyone else is simply absent.
  Future<Map<String, String>> urlsFor(Iterable<String> userIds) async {
    final now = DateTime.now();
    final ids = userIds.toSet();
    final result = <String, String>{};
    final missing = <String>[];
    for (final id in ids) {
      final hit = _cache[id];
      if (hit != null && now.difference(hit.at) < _ttl) {
        if (hit.url != null) result[id] = hit.url!;
      } else {
        missing.add(id);
      }
    }
    if (missing.isEmpty) return result;

    try {
      final rows = await _client.rpc(
        'get_member_avatar_paths',
        params: {'p_user_ids': missing},
      );
      final paths = {
        for (final row in (rows as List).cast<Map<String, dynamic>>())
          row['user_id'] as String: row['avatar_path'] as String?,
      };
      final signed = await Future.wait([
        for (final id in missing) _profiles.resolveAvatarUrl(paths[id]),
      ]);
      for (var i = 0; i < missing.length; i++) {
        final url = signed[i];
        _cache[missing[i]] = (url: url, at: now);
        if (url != null) result[missing[i]] = url;
      }
    } catch (_) {
      // Initials stay; nothing is cached, so the next screen tries again.
    }
    return result;
  }
}
