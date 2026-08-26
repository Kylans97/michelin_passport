import 'restaurant.dart';

/// The current user's own profile, combining `public.profiles` with
/// Passport-derived Journey Stats computed client-side from their visited
/// restaurants. Deliberately carries no `tier`/gamification field —
/// `profiles` has no such column, and the `user_tiers` view this model
/// used to read no longer exists in the live schema (see the Social
/// Foundation Step 1 audit); tiers are out of this step's scope entirely,
/// not merely hidden.
class UserProfile {
  final String id;
  final String? username;
  final String name;
  final String email;
  final String memberSince;

  // PROFILE UI REDESIGN V1 — the Storage object path (never a URL) for
  // this user's current avatar, or null if none is set. Resolving this
  // into a displayable URL is `ProfileRepository.resolveAvatarUrl`'s job
  // — this model only carries the stable reference, matching `avatar_
  // path`'s own migration-comment rationale for why a path is stored
  // rather than a brittle signed/public URL. `profile_avatar_v1` — the
  // proposed migration adding this column has NOT been applied to
  // production yet (see `docs/Architecture/PROFILE_AVATAR_V1.md`); until
  // then this is always null, which [MemberAvatar] already renders
  // correctly (initials fallback).
  final String? avatarPath;
  final int restaurantsVisited;
  final int countriesVisited;
  final int citiesVisited;
  final int michelinStarsCollected;
  final int oneStarCount;
  final int twoStarCount;
  final int threeStarCount;

  const UserProfile({
    required this.id,
    this.username,
    required this.name,
    required this.email,
    required this.memberSince,
    this.avatarPath,
    required this.restaurantsVisited,
    required this.countriesVisited,
    required this.citiesVisited,
    required this.michelinStarsCollected,
    required this.oneStarCount,
    required this.twoStarCount,
    required this.threeStarCount,
  });

  /// [email] comes from the auth session, not the profile row —
  /// `public.profiles` has never had an email column; it's held only by
  /// `auth.users`, which Flutter reads via `Supabase.instance.client.auth.
  /// currentUser?.email`. [memberSince] is derived from the real
  /// `created_at` column (the row's own signup timestamp) — the previous
  /// version of this model read a `member_since` column that has never
  /// existed on `profiles`.
  factory UserProfile.fromSupabase({
    required Map<String, dynamic> profileRow,
    required List<Restaurant> visited,
    required String email,
  }) {
    final oneStarCount = visited.where((r) => r.michelinStars == 1).length;
    final twoStarCount = visited.where((r) => r.michelinStars == 2).length;
    final threeStarCount = visited.where((r) => r.michelinStars == 3).length;

    return UserProfile(
      id: profileRow['id'] as String,
      username: profileRow['username'] as String?,
      name: (profileRow['display_name'] as String?) ?? 'Member',
      email: email,
      memberSince: _formatDate(profileRow['created_at'] as String?),
      avatarPath: profileRow['avatar_path'] as String?,
      restaurantsVisited: visited.length,
      countriesVisited: visited.map((r) => r.countryName).toSet().length,
      citiesVisited: visited.map((r) => r.cityName).toSet().length,
      michelinStarsCollected:
          oneStarCount + (twoStarCount * 2) + (threeStarCount * 3),
      oneStarCount: oneStarCount,
      twoStarCount: twoStarCount,
      threeStarCount: threeStarCount,
    );
  }

  static String _formatDate(String? iso) {
    if (iso == null) return '';
    final dt = DateTime.tryParse(iso);
    if (dt == null) return '';
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return '${months[dt.month - 1]} ${dt.year}';
  }
}
