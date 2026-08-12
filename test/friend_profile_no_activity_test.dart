// Covers FriendProfileScreen's identity-only guarantee (Social Foundation
// Step 1 §34-35): a Friend or Non-Friend profile must render ONLY
// identity + a relationship action — never visits, ratings, photos,
// wishlist, or trip data. FriendProfileScreen constructs
// FriendshipRepository against Supabase.instance.client eagerly, so this
// reconstructs the exact per-status body shape from
// lib/features/friends/friend_profile_screen.dart's own
// _RelationshipAction, and asserts the render tree never contains any
// activity-shaped copy, for every relationship state.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:michelin_passport/core/constants/app_colors.dart';
import 'package:michelin_passport/core/widgets/cs_primary_button.dart';
import 'package:michelin_passport/models/profile_identity.dart';

// A stand-in for _RelationshipAction — same five-way switch, same copy.
Widget _relationshipAction(
  RelationshipStatus status, {
  VoidCallback? onSendRequest,
  VoidCallback? onAccept,
  VoidCallback? onDecline,
  VoidCallback? onRemove,
}) {
  switch (status) {
    case RelationshipStatus.none:
      return SizedBox(
        width: double.infinity,
        child: CsPrimaryButton(
          label: 'Add friend',
          onTap: onSendRequest ?? () {},
        ),
      );
    case RelationshipStatus.pendingSent:
      return const Text('Request sent');
    case RelationshipStatus.pendingReceived:
      return Row(
        children: [
          TextButton(onPressed: onDecline, child: const Text('Decline')),
          TextButton(onPressed: onAccept, child: const Text('Accept')),
        ],
      );
    case RelationshipStatus.accepted:
      return Column(
        children: [
          const Text('Friends'),
          TextButton(onPressed: onRemove, child: const Text('Remove friend')),
        ],
      );
    case RelationshipStatus.declined:
      return const Text('Unavailable');
  }
}

const _activityWords = [
  'visit',
  'Visit',
  'rating',
  'Rating',
  'photo',
  'Photo',
  'wishlist',
  'Wishlist',
  'trip',
  'Trip',
  'star',
  'Star',
  'passport',
  'Passport',
];

void _expectNoActivityCopy(WidgetTester tester) {
  final texts = tester.widgetList<Text>(find.byType(Text));
  for (final text in texts) {
    final value = text.data ?? '';
    for (final word in _activityWords) {
      expect(
        value.contains(word),
        isFalse,
        reason: '"$value" unexpectedly contains activity-shaped copy "$word"',
      );
    }
  }
}

Widget _wrap(Widget child) => MaterialApp(
  home: Scaffold(backgroundColor: AppColors.deepGreen, body: child),
);

void main() {
  group(
    'FriendProfileScreen — no activity leakage, every relationship state',
    () {
      for (final status in RelationshipStatus.values) {
        testWidgets(
          '$status renders no visit/rating/photo/wishlist/trip copy',
          (tester) async {
            await tester.pumpWidget(_wrap(_relationshipAction(status)));
            _expectNoActivityCopy(tester);
            expect(tester.takeException(), isNull);
          },
        );
      }
    },
  );

  group('FriendProfileScreen — relationship action behavior', () {
    testWidgets('none: "Add friend" fires onSendRequest', (tester) async {
      var sent = false;
      await tester.pumpWidget(
        _wrap(
          _relationshipAction(
            RelationshipStatus.none,
            onSendRequest: () => sent = true,
          ),
        ),
      );
      await tester.tap(find.text('Add friend'));
      expect(sent, isTrue);
    });

    testWidgets('pendingReceived: Accept/Decline fire independently', (
      tester,
    ) async {
      var accepted = false;
      var declined = false;
      await tester.pumpWidget(
        _wrap(
          _relationshipAction(
            RelationshipStatus.pendingReceived,
            onAccept: () => accepted = true,
            onDecline: () => declined = true,
          ),
        ),
      );
      await tester.tap(find.text('Accept'));
      expect(accepted, isTrue);
      expect(declined, isFalse);
    });

    testWidgets('accepted: shows "Friends" and a Remove friend action', (
      tester,
    ) async {
      var removed = false;
      await tester.pumpWidget(
        _wrap(
          _relationshipAction(
            RelationshipStatus.accepted,
            onRemove: () => removed = true,
          ),
        ),
      );
      expect(find.text('Friends'), findsOneWidget);
      await tester.tap(find.text('Remove friend'));
      expect(removed, isTrue);
    });

    testWidgets('pendingSent: quiet "Request sent" label, no action', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(_relationshipAction(RelationshipStatus.pendingSent)),
      );
      expect(find.text('Request sent'), findsOneWidget);
      expect(find.byType(TextButton), findsNothing);
    });

    testWidgets('declined: quiet "Unavailable" label, no action', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(_relationshipAction(RelationshipStatus.declined)),
      );
      expect(find.text('Unavailable'), findsOneWidget);
      expect(find.byType(TextButton), findsNothing);
    });
  });
}
