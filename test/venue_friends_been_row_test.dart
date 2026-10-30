// "Friends who've been" on Restaurant/Hotel Detail: label wording, nothing
// rendered without friends, no score anywhere, and a list sheet for more
// than one friend.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:michelin_passport/features/friends/widgets/identity_row.dart';
import 'package:michelin_passport/features/friends/widgets/venue_friends_been_row.dart';
import 'package:michelin_passport/models/friendship.dart';

Friendship _f(String name) =>
    Friendship(friendshipId: 'fs-$name', friendId: name, displayName: name);

Widget _wrap(List<Friendship> friends) => MaterialApp(
  home: Scaffold(
    body: VenueFriendsBeenRow(
      entityType: 'restaurant',
      entityId: 'r1',
      loadFriends: () async => friends,
    ),
  ),
);

void main() {
  test('label wording', () {
    expect(friendsBeenLabel([_f('Anna')]), 'Anna has been here');
    expect(
      friendsBeenLabel([_f('Anna'), _f('Bas')]),
      'Anna & Bas have been here',
    );
    expect(
      friendsBeenLabel([_f('Anna'), _f('Bas'), _f('Cas')]),
      'Anna, Bas & Cas have been here',
    );
    expect(
      friendsBeenLabel([_f('Anna'), _f('Bas'), _f('Cas'), _f('Dirk')]),
      'Anna, Bas & 2 other friends have been here',
    );
  });

  testWidgets('renders nothing when no friend has been', (tester) async {
    await tester.pumpWidget(_wrap(const []));
    await tester.pumpAndSettle();
    expect(find.textContaining('been here'), findsNothing);
  });

  testWidgets('shows faces and names, never a score', (tester) async {
    await tester.pumpWidget(_wrap([_f('Anna'), _f('Bas')]));
    await tester.pumpAndSettle();
    expect(find.text('Anna & Bas have been here'), findsOneWidget);
    expect(find.textContaining('/10'), findsNothing);
  });

  testWidgets('several friends open a list to pick from', (tester) async {
    await tester.pumpWidget(_wrap([_f('Anna'), _f('Bas')]));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Anna & Bas have been here'));
    await tester.pumpAndSettle();
    expect(find.text("FRIENDS WHO'VE BEEN"), findsOneWidget);
    expect(find.byType(IdentityRow), findsNWidgets(2));
  });
}
