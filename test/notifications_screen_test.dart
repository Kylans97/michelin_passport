// Covers NotificationsScreen's per-type row rendering and the unread-dot
// distinction. NotificationsScreen constructs NotificationsRepository/
// FriendshipRepository against Supabase.instance.client eagerly in
// initState (same established limitation as every other Supabase-eager
// screen in this app), so this reconstructs the exact row shapes from
// lib/features/notifications/notifications_screen.dart rather than
// pumping the real screen — same approach friends_screen_states_test.dart
// already uses for FriendsScreen.
//
// The friendRequestReceived row's Accept/Decline is the exact interaction
// that used to be tested under "FriendsScreen incoming request row" in
// friends_screen_states_test.dart before Notifications V1 moved it here —
// see that file's own note.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:michelin_passport/core/constants/app_colors.dart';
import 'package:michelin_passport/core/theme/cs_typography.dart';
import 'package:michelin_passport/features/friends/widgets/identity_row.dart';

Widget _unreadDot({required bool visible}) => SizedBox(
  width: 8,
  height: 8,
  child: visible
      ? const DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.error,
          ),
        )
      : null,
);

Widget _friendRequestReceivedRow({
  required VoidCallback onAccept,
  required VoidCallback onDecline,
  bool isRead = false,
}) => Row(
  crossAxisAlignment: CrossAxisAlignment.start,
  children: [
    Padding(
      padding: const EdgeInsets.only(top: 12, right: 4),
      child: _unreadDot(visible: !isRead),
    ),
    Expanded(
      child: IdentityRow(
        label: 'Kylan',
        username: 'kylan',
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextButton(onPressed: onDecline, child: const Text('Decline')),
            TextButton(onPressed: onAccept, child: const Text('Accept')),
          ],
        ),
      ),
    ),
  ],
);

Widget _friendRequestAcceptedRow({VoidCallback? onTap}) => IdentityRow(
  label: 'Kylan',
  username: null,
  onTap: onTap,
  trailing: Text(
    'Accepted',
    style: CsTypography.metadata.copyWith(color: AppColors.taupe),
  ),
);

Widget _missingListingAddedRow({
  required String name,
  required String city,
}) => Padding(
  padding: const EdgeInsets.symmetric(vertical: 8),
  child: Row(
    children: [
      const Icon(
        Icons.storefront_outlined,
        color: AppColors.forestGreen,
        size: 20,
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Text(
          '$name in $city has been added.',
          style: CsTypography.body.copyWith(color: AppColors.forestGreen),
        ),
      ),
    ],
  ),
);

Widget _wrap(Widget child) => MaterialApp(
  home: Scaffold(backgroundColor: AppColors.warmWhite, body: child),
);

void main() {
  group('NotificationsScreen — friend_request_received row', () {
    testWidgets('accept fires its own callback, not decline\'s', (
      tester,
    ) async {
      var accepted = false;
      var declined = false;
      await tester.pumpWidget(
        _wrap(
          _friendRequestReceivedRow(
            onAccept: () => accepted = true,
            onDecline: () => declined = true,
          ),
        ),
      );
      await tester.tap(find.text('Accept'));
      expect(accepted, isTrue);
      expect(declined, isFalse);
    });

    testWidgets('decline fires its own callback, not accept\'s', (
      tester,
    ) async {
      var accepted = false;
      var declined = false;
      await tester.pumpWidget(
        _wrap(
          _friendRequestReceivedRow(
            onAccept: () => accepted = true,
            onDecline: () => declined = true,
          ),
        ),
      );
      await tester.tap(find.text('Decline'));
      expect(declined, isTrue);
      expect(accepted, isFalse);
    });

    testWidgets('shows the unread dot when unread, hides it when read', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          _friendRequestReceivedRow(
            onAccept: () {},
            onDecline: () {},
            isRead: false,
          ),
        ),
      );
      expect(
        find.byWidgetPredicate(
          (w) => w is DecoratedBox && (w.decoration as BoxDecoration).color == AppColors.error,
        ),
        findsOneWidget,
      );

      await tester.pumpWidget(
        _wrap(
          _friendRequestReceivedRow(
            onAccept: () {},
            onDecline: () {},
            isRead: true,
          ),
        ),
      );
      expect(
        find.byWidgetPredicate(
          (w) => w is DecoratedBox && (w.decoration as BoxDecoration).color == AppColors.error,
        ),
        findsNothing,
      );
    });
  });

  group('NotificationsScreen — friend_request_accepted row', () {
    testWidgets('shows "Accepted", no Accept/Decline actions', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap(_friendRequestAcceptedRow()));
      expect(find.text('Accepted'), findsOneWidget);
      expect(find.text('Accept'), findsNothing);
      expect(find.text('Decline'), findsNothing);
    });

    testWidgets('tapping the row opens the other person\'s profile', (
      tester,
    ) async {
      var tapped = false;
      await tester.pumpWidget(
        _wrap(_friendRequestAcceptedRow(onTap: () => tapped = true)),
      );
      await tester.tap(find.text('Kylan'));
      expect(tapped, isTrue);
    });
  });

  group('NotificationsScreen — missing_listing_added row', () {
    testWidgets('renders the listing name and city, no actions', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(_missingListingAddedRow(name: 'Flore', city: 'Amsterdam')),
      );
      expect(
        find.textContaining('Flore in Amsterdam has been added.'),
        findsOneWidget,
      );
      expect(find.text('Accept'), findsNothing);
      expect(find.byIcon(Icons.storefront_outlined), findsOneWidget);
    });
  });
}
