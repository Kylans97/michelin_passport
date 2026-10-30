// Friend Profile verdicts use the app's ivory editorial card: score in
// forest green, no gold text, no rank badge, and an unrated visit shows
// no invented score.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:michelin_passport/core/constants/app_colors.dart';
import 'package:michelin_passport/features/friends/friend_profile_screen.dart';
import 'package:michelin_passport/features/friends/widgets/friend_profile_verdict_row.dart';
import 'package:michelin_passport/features/rankings/widgets/ranking_editorial_card.dart';
import 'package:michelin_passport/models/passport_venue.dart';
import 'package:michelin_passport/models/restaurant.dart';
import 'package:michelin_passport/models/visit.dart';

FriendVenueVisit _fv({int? rating}) => FriendVenueVisit(
  RestaurantVenue(
    Restaurant(
      id: 'r1',
      restaurantCode: 'r1',
      name: 'Flore',
      michelinStars: 2,
      inclusionReason: 'michelin_star',
      cityName: 'Amsterdam',
      countryCode: 'NL',
      countryName: 'Netherlands',
      flagEmoji: '',
      address: '1 Test Street',
    ),
  ),
  Visit(
    id: 'v1',
    userId: 'anna',
    entityType: 'restaurant',
    entityId: 'r1',
    visitedOn: DateTime(DateTime.now().year, 9, 23),
    starsAtVisit: 2,
    rating: rating,
  ),
);

Widget _wrap(FriendVenueVisit fv) => MaterialApp(
  home: Scaffold(
    body: FriendVerdictRow(visit: fv, photoUrl: null, onTap: () {}),
  ),
);

void main() {
  testWidgets('rated visit: forest-green score, no gold text, no rank', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap(_fv(rating: 8)));
    expect(find.byType(RankingEditorialCard), findsOneWidget);
    expect(find.text('Flore'), findsOneWidget);
    expect(
      tester.widget<Text>(find.text('8/10')).style?.color,
      AppColors.forestGreen,
    );
    expect(find.text('· Visited 23 Sep'), findsOneWidget);
    for (final text in tester.widgetList<Text>(find.byType(Text))) {
      expect(text.style?.color, isNot(AppColors.gold));
    }
    expect(find.text('1'), findsNothing); // no rank badge
  });

  testWidgets('unrated visit shows no score', (tester) async {
    await tester.pumpWidget(_wrap(_fv()));
    expect(find.textContaining('/10'), findsNothing);
    expect(find.text('Visited 23 Sep'), findsOneWidget);
  });
}
