import '../../models/user_profile.dart';

class MockUser {
  MockUser._();

  static const UserProfile profile = UserProfile(
    id: 'u1',
    name: 'Kylan Scheepstra',
    email: 'kylan@tablepassport.com',
    memberSince: 'January 2024',
    tier: 'Gold Palate',
    restaurantsVisited: 12,
    countriesVisited: 4,
    citiesVisited: 8,
    michelinStarsCollected: 31,
    oneStarCount: 1,
    twoStarCount: 1,
    threeStarCount: 10,
  );
}
