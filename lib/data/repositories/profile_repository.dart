import 'dart:math';
import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/restaurant.dart';
import '../../models/user_profile.dart';

// PROFILE UI REDESIGN V1 — the private Storage bucket profile photos are
// uploaded to. NOT YET CREATED in production — see the proposed
// migration `20260825170000_add_profile_avatar.sql` and
// `docs/Architecture/PROFILE_AVATAR_V1.md` for the full pre-apply
// architecture. Every method below that touches this bucket will fail
// against production until that migration is reviewed and applied;
// that's expected, not a bug in this code.
const avatarBucket = 'profile-photos';

final _avatarRandom = Random();

class ProfileRepository {
  ProfileRepository(this._client);

  final SupabaseClient _client;

  Future<UserProfile> getProfile({
    required String userId,
    required List<Restaurant> visited,
  }) async {
    final profileRows = await _client
        .from('profiles')
        .select()
        .eq('id', userId)
        .limit(1);

    if ((profileRows as List).isEmpty) {
      throw Exception('Profile not found for user $userId');
    }

    return UserProfile.fromSupabase(
      profileRow: profileRows.first,
      visited: visited,
      email: _client.auth.currentUser?.email ?? '',
    );
  }

  // Sets display name and/or username (whichever is passed). The
  // database's profiles_username_format CHECK and profiles_username_key
  // unique index remain the real authority — a caller should validate
  // with UsernameRules first for UX, then be ready to catch a
  // PostgrestException with code 23505 (taken) or 23514 (invalid format)
  // from this call regardless.
  Future<void> updateProfile({
    required String userId,
    String? displayName,
    String? username,
  }) async {
    final payload = <String, dynamic>{};
    if (displayName != null) payload['display_name'] = displayName;
    if (username != null) payload['username'] = username;
    if (payload.isEmpty) return;
    await _client.from('profiles').update(payload).eq('id', userId);
  }

  // Best-effort availability hint (debounced typing feedback) — not
  // authoritative; a race between the check and the actual update is
  // still possible and is still safely caught by the real DB constraint.
  Future<bool> isUsernameAvailable(String candidate) async {
    final result = await _client.rpc(
      'username_available',
      params: {'candidate': candidate},
    );
    return result as bool;
  }

  // PROFILE PRIVACY & DISCOVERABILITY V1 — [userId] is always the
  // caller's own id at every real call site (Privacy Settings only ever
  // reads/writes the signed-in user's own row), which is also the only
  // row `profiles_read`/`profiles_update` RLS permits either of these to
  // touch — a user cannot read or write another user's is_discoverable
  // through this repository, enforced server-side, not just by this
  // method's own calling convention. Governs Find Friends discovery
  // ONLY — see the column's own migration comment
  // (`20260825160000_profile_privacy_discoverability_v1.sql`) for why
  // this never affects visits/wishlist/photos/Trips/event visibility.
  Future<bool> getDiscoverable(String userId) async {
    final row = await _client
        .from('profiles')
        .select('is_discoverable')
        .eq('id', userId)
        .limit(1)
        .single();
    return row['is_discoverable'] as bool? ?? true;
  }

  Future<void> setDiscoverable({
    required String userId,
    required bool value,
  }) async {
    await _client
        .from('profiles')
        .update({'is_discoverable': value})
        .eq('id', userId);
  }

  // ── Avatar (PROFILE UI REDESIGN V1 — proposed, not yet applied) ────────
  //
  // Mirrors PhotoRepository's own upload/resolve/remove shape exactly —
  // same {userId}/{uniqueId}.{ext} path convention (never a fixed
  // "avatar.<ext>" path, so a replace can never collide with, or need to
  // overwrite, the object still referenced by the row until the DB
  // update itself succeeds), same signed-URL display strategy, same
  // "storage object first, DB reference second, best-effort cleanup of
  // whatever's superseded" ordering.

  /// Uploads [bytes] to a fresh, uniquely-named object under [userId]'s
  /// own folder and returns the new Storage PATH (never a URL) — the
  /// caller still has to persist it via [updateAvatarPath] afterward;
  /// this method alone does not touch `profiles` at all, so a caller can
  /// safely upload-then-verify before ever changing what the user's
  /// profile currently references (see [replaceAvatar] for the full,
  /// safe orchestration).
  Future<String> uploadAvatar({
    required String userId,
    required Uint8List bytes,
    required String fileExtension,
  }) async {
    final uniqueId =
        '${DateTime.now().microsecondsSinceEpoch}_${_avatarRandom.nextInt(1 << 32)}';
    final storagePath = '$userId/$uniqueId.$fileExtension';
    final contentType = fileExtension == 'jpg' ? 'jpeg' : fileExtension;
    await _client.storage
        .from(avatarBucket)
        .uploadBinary(
          storagePath,
          bytes,
          fileOptions: FileOptions(contentType: 'image/$contentType'),
        );
    return storagePath;
  }

  /// Persists [avatarPath] (or `null` to clear it) as the user's own
  /// canonical avatar reference. Scoped by `id` alone — `profiles_update`
  /// RLS (`id = auth.uid()`, unchanged by Profile Privacy &
  /// Discoverability V1) is the real boundary preventing a user from
  /// setting anyone else's.
  Future<void> updateAvatarPath({
    required String userId,
    required String? avatarPath,
  }) async {
    await _client
        .from('profiles')
        .update({'avatar_path': avatarPath})
        .eq('id', userId);
  }

  /// The full "pick a new photo" flow's safe ordering (§29 of this
  /// feature's own spec): upload the new object first, only then update
  /// `profiles.avatar_path` to point at it, and only AFTER that DB write
  /// has actually succeeded, best-effort remove whatever the previous
  /// [currentAvatarPath] was. If the DB update itself fails, the newly
  /// uploaded object is cleaned up (mirrors [PhotoRepository.uploadPhoto]
  /// 's own orphan-cleanup-on-failure) and the user's existing avatar is
  /// left completely untouched — never a window where a user has no
  /// avatar because a replace partially failed.
  Future<String> replaceAvatar({
    required String userId,
    required Uint8List bytes,
    required String fileExtension,
    required String? currentAvatarPath,
  }) async {
    final newPath = await uploadAvatar(
      userId: userId,
      bytes: bytes,
      fileExtension: fileExtension,
    );
    try {
      await updateAvatarPath(userId: userId, avatarPath: newPath);
    } catch (_) {
      try {
        await _client.storage.from(avatarBucket).remove([newPath]);
      } catch (_) {
        // Best-effort — the original failure is what the caller sees.
      }
      rethrow;
    }
    if (currentAvatarPath != null && currentAvatarPath.isNotEmpty) {
      try {
        await _client.storage.from(avatarBucket).remove([currentAvatarPath]);
      } catch (_) {
        // Best-effort, matching PhotoRepository.deletePhoto's own
        // reasoning: the user-visible outcome (their new avatar is live)
        // already succeeded — a leftover superseded object is invisible
        // and logged, never surfaced as a user-facing failure.
      }
    }
    return newPath;
  }

  /// Clears the user's avatar reference, then best-effort removes the
  /// Storage object — DB reference first, matching [replaceAvatar]'s own
  /// "never point at something that might not exist" ordering.
  Future<void> removeAvatar({
    required String userId,
    required String currentAvatarPath,
  }) async {
    await updateAvatarPath(userId: userId, avatarPath: null);
    try {
      await _client.storage.from(avatarBucket).remove([currentAvatarPath]);
    } catch (_) {
      // Best-effort — the row no longer references it either way.
    }
  }

  /// A signed, time-limited display URL for one avatar path — the only
  /// way to actually display an avatar, since the bucket is private.
  /// Returns null (never throws) when [avatarPath] is null/empty, so
  /// every call site can write `resolveAvatarUrl(profile.avatarPath)`
  /// unconditionally.
  Future<String?> resolveAvatarUrl(
    String? avatarPath, {
    int expiresInSeconds = 3600,
  }) async {
    if (avatarPath == null || avatarPath.isEmpty) return null;
    try {
      return await _client.storage
          .from(avatarBucket)
          .createSignedUrl(avatarPath, expiresInSeconds);
    } catch (_) {
      return null;
    }
  }
}
