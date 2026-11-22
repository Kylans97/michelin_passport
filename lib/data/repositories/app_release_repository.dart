import 'package:supabase_flutter/supabase_flutter.dart';

/// The one `app_release` row (20261101680000): the version on the App
/// Store and the oldest that still works, both edited by hand after a
/// release. Readable signed out too.
class AppRelease {
  final String latestVersion;
  final String minimumVersion;

  const AppRelease({required this.latestVersion, required this.minimumVersion});
}

/// -1, 0 or 1 for "1.9.0" against "1.10.0", part by part as numbers, so
/// 1.10.0 is newer than 1.9.0. A missing part counts as 0; anything that
/// isn't a number makes the two equal, so a bad value never prompts.
int compareVersions(String a, String b) {
  List<int>? parts(String v) {
    final out = <int>[];
    for (final p in v.trim().split('.')) {
      final n = int.tryParse(p);
      if (n == null) return null;
      out.add(n);
    }
    return out;
  }

  final pa = parts(a);
  final pb = parts(b);
  if (pa == null || pb == null) return 0;
  for (var i = 0; i < 3; i++) {
    final x = i < pa.length ? pa[i] : 0;
    final y = i < pb.length ? pb[i] : 0;
    if (x != y) return x < y ? -1 : 1;
  }
  return 0;
}

class AppReleaseRepository {
  AppReleaseRepository(this._client);

  final SupabaseClient _client;

  /// Null before the migration, or when the row can't be read: then
  /// nobody is asked anything.
  Future<AppRelease?> load() async {
    try {
      final row = await _client
          .from('app_release')
          .select('latest_version, minimum_version')
          .maybeSingle();
      if (row == null) return null;
      return AppRelease(
        latestVersion: row['latest_version'] as String,
        minimumVersion: row['minimum_version'] as String,
      );
    } catch (_) {
      return null;
    }
  }
}
