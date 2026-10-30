// Friend Profile header: both overlapping avatars sit wholly inside their
// box (the box once left out the rings' 3pt, clipping both circles), at a
// phone and a narrow width. Also: the friend's globe titles itself after
// the friend.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:michelin_passport/features/friends/widgets/friend_profile_header.dart';
import 'package:michelin_passport/features/friends/widgets/friend_profile_widgets.dart';
import 'package:michelin_passport/features/map/visited_map_screen.dart';

Widget _header() => MaterialApp(
  home: Scaffold(
    body: SingleChildScrollView(
      child: FriendProfileHeaderTop(
        friendPhoto: null,
        friendLabel: 'Anna',
        myPhoto: null,
        myLabel: 'Kylan',
        name: 'Anna de Vries',
        username: 'anna',
        stamps: 12,
        stars: 9,
        onBack: () {},
        onRemoveFriend: () {},
        onBlock: () {},
        onReport: () {},
      ),
    ),
  ),
);

void main() {
  for (final size in const [Size(390, 844), Size(320, 568), Size(1024, 1366)]) {
    testWidgets('avatars are not clipped at ${size.width}x${size.height}', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(_header());

      final avatars = find.byType(FriendProfileAvatar);
      expect(avatars, findsNWidgets(2));
      final stack = find.ancestor(
        of: avatars.first,
        matching: find.byType(Stack),
      );
      final box = tester.getRect(stack.first);
      for (final element in avatars.evaluate()) {
        final rect = tester.getRect(find.byWidget(element.widget));
        expect(rect.width, 54);
        expect(rect.height, 54);
        expect(box.contains(rect.topLeft), isTrue);
        expect(
          rect.bottom <= box.bottom && rect.right <= box.right,
          isTrue,
          reason: 'avatar $rect must sit inside its box $box',
        );
      }
    });
  }

  testWidgets("a friend's globe is titled after the friend", (tester) async {
    // No Supabase in tests: the load fails into the error message, which
    // is exactly the friend-worded copy this checks.
    await tester.pumpWidget(
      const MaterialApp(
        home: VisitedMapScreen(userId: 'anna', ownerName: 'Anna'),
      ),
    );
    await tester.pump();
    expect(find.text("Anna's Map"), findsOneWidget);
    expect(find.text('Every place Anna has shared with you.'), findsOneWidget);
    expect(find.text("Could not load Anna's places."), findsOneWidget);
    expect(find.text('My Map'), findsNothing);
  });
}
