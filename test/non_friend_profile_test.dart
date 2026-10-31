// The non-friend profile (redesign 2026-10-31): centred identity, a warm
// line per relationship, one action, and nothing private.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:michelin_passport/features/friends/widgets/non_friend_profile.dart';
import 'package:michelin_passport/models/profile_identity.dart';

Widget _wrap(
  RelationshipStatus status, {
  bool isSelf = false,
  VoidCallback? onSend,
  VoidCallback? onAccept,
}) => MaterialApp(
  home: Scaffold(
    body: NonFriendProfile(
      identity: ProfileIdentity(
        id: 'u1',
        username: 'anna',
        displayName: 'Anna de Vries',
        relationshipStatus: status,
      ),
      isSelf: isSelf,
      onSendRequest: onSend ?? () {},
      onAccept: onAccept ?? () {},
      onDecline: () {},
      onBlock: () {},
      onReport: () {},
    ),
  ),
);

void main() {
  testWidgets('a stranger: identity, invitation and Add friend', (
    tester,
  ) async {
    var sent = 0;
    await tester.pumpWidget(
      _wrap(RelationshipStatus.none, onSend: () => sent++),
    );
    expect(find.text('Anna de Vries'), findsOneWidget);
    expect(find.text('@ANNA'), findsOneWidget);
    expect(
      find.text('Start enjoying the Mantelier journey together.'),
      findsOneWidget,
    );
    await tester.tap(find.text('Add friend'));
    expect(sent, 1);
    // Nothing a non-friend may not see.
    expect(find.textContaining('STAMPS'), findsNothing);
    expect(find.textContaining('STARS'), findsNothing);
  });

  testWidgets('request sent: quiet state, first name in the copy', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap(RelationshipStatus.pendingSent));
    expect(find.text('Request sent'), findsOneWidget);
    expect(find.text('Add friend'), findsNothing);
    expect(find.textContaining('Once Anna accepts'), findsOneWidget);
  });

  testWidgets('request received: Accept with a quieter Decline', (
    tester,
  ) async {
    var accepted = 0;
    await tester.pumpWidget(
      _wrap(RelationshipStatus.pendingReceived, onAccept: () => accepted++),
    );
    expect(
      find.text('Anna would like to share the journey with you.'),
      findsOneWidget,
    );
    expect(find.text('Decline'), findsOneWidget);
    await tester.tap(find.text('Accept'));
    expect(accepted, 1);
  });

  testWidgets('your own profile: no action, no invitation', (tester) async {
    await tester.pumpWidget(_wrap(RelationshipStatus.none, isSelf: true));
    expect(find.text('Add friend'), findsNothing);
    expect(
      find.text('Start enjoying the Mantelier journey together.'),
      findsNothing,
    );
  });

  testWidgets('fits at 320px', (tester) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.binding.setSurfaceSize(const Size(320, 568));
    await tester.pumpWidget(_wrap(RelationshipStatus.pendingReceived));
    expect(tester.takeException(), isNull);
  });
}
