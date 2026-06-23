import 'restaurant.dart';

class UserProfile {
  final String id;
  final String name;
  final String email;
  final String memberSince;
  final String tier;
  final int restaurantsVisited;
  final int countriesVisited;
  final int citiesVisited;
  final int michelinStarsCollected;
  final int oneStarCount;
  final int twoStarCount;
  final int threeStarCount;

  const UserProfile({
    required this.id,
    required this.name,
    required this.email,
    required this.memberSince,
    required this.tier,
    required this.restaurantsVisited,
    required this.countriesVisited,
    required this.citiesVisited,
    required this.michelinStarsCollected,
    required this.oneStarCount,
    required this.twoStarCount,
    required this.threeStarCount,
  });

  factory UserProfile.fromSupabase({
    required Map<String, dynamic> profileRow,
    required List<Restaurant> visited,
    String? tierFromDb,
  }) {
    final oneStarCount   = visited.where((r) => r.michelinStars == 1).length;
    final twoStarCount   = visited.where((r) => r.michelinStars == 2).length;
    final threeStarCount = visited.where((r) => r.michelinStars == 3).length;

    return UserProfile(
      id: profileRow['id'] as String,
      name: (profileRow['display_name'] as String?) ?? 'Anonymous',
      email: (profileRow['email'] as String?) ?? '',
      memberSince: _formatDate(profileRow['member_since'] as String?),
      tier: tierFromDb ?? (profileRow['tier'] as String?) ?? 'Explorer',
      restaurantsVisited: visited.length,
      countriesVisited: visited.map((r) => r.country).toSet().length,
      citiesVisited: visited.map((r) => r.city).toSet().length,
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
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December',
    ];
    return '${months[dt.month - 1]} ${dt.year}';
  }
}
