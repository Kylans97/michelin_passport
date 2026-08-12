// Covers FriendsScreen's empty states and request-row actions (Social
// Foundation Step 1). FriendsScreen constructs FriendshipRepository
// against Supabase.instance.client eagerly in initState (same established
// limitation as every other screen in this app that touches Supabase
// there), so this reconstructs the exact copy/row shapes from
// lib/features/friends/friends_screen.dart rather than pumping the real
// screen.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:michelin_passport/core/constants/app_colors.dart';
import 'package:michelin_passport/core/theme/cs_spacing.dart';
import 'package:michelin_passport/core/theme/cs_typography.dart';
import 'package:michelin_passport/features/friends/widgets/identity_row.dart';

Widget _friendsEmptyState() => Column(
  mainAxisSize: MainAxisSize.min,
  children: [
    Text(
      'No friends yet',
      style: CsTypography.placeTitle.copyWith(color: AppColors.textOnDark),
    ),
    const SizedBox(height: CsSpacing.sm),
    Text(
      'Find people you know by username.',
      style: CsTypography.body.copyWith(color: AppColors.secondaryOnDark),
    ),
  ],
);

Widget _incomingRequestRow({
  required VoidCallback onAccept,
  required VoidCallback onDecline,
}) => IdentityRow(
  label: 'User A',
  username: 'usera',
  trailing: Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      TextButton(onPressed: onDecline, child: const Text('Decline')),
      TextButton(onPressed: onAccept, child: const Text('Accept')),
    ],
  ),
);

Widget _outgoingRequestRow({required VoidCallback onCancel}) => IdentityRow(
  label: 'User C',
  username: 'userc',
  trailing: TextButton(onPressed: onCancel, child: const Text('Cancel')),
);

Widget _wrap(Widget child) => MaterialApp(
  home: Scaffold(backgroundColor: AppColors.deepGreen, body: child),
);

void main() {
  group('FriendsScreen empty states', () {
    testWidgets('friends tab empty state', (tester) async {
      await tester.pumpWidget(_wrap(_friendsEmptyState()));
      expect(find.text('No friends yet'), findsOneWidget);
      expect(find.text('Find people you know by username.'), findsOneWidget);
    });

    testWidgets('320px width — no overflow', (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 844));
      await tester.pumpWidget(_wrap(_friendsEmptyState()));
      expect(tester.takeException(), isNull);
      await tester.binding.setSurfaceSize(null);
    });
  });

  group('FriendsScreen incoming request row', () {
    testWidgets('accept fires its own callback, not decline\'s', (
      tester,
    ) async {
      var accepted = false;
      var declined = false;
      await tester.pumpWidget(
        _wrap(
          _incomingRequestRow(
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
          _incomingRequestRow(
            onAccept: () => accepted = true,
            onDecline: () => declined = true,
          ),
        ),
      );
      await tester.tap(find.text('Decline'));
      expect(declined, isTrue);
      expect(accepted, isFalse);
    });
  });

  group('FriendsScreen outgoing request row', () {
    testWidgets('shows Cancel and fires the cancel callback', (tester) async {
      var cancelled = false;
      await tester.pumpWidget(
        _wrap(_outgoingRequestRow(onCancel: () => cancelled = true)),
      );
      expect(find.text('Cancel'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      expect(cancelled, isTrue);
    });

    testWidgets('1.6x text scale — no overflow', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(1.6)),
            child: Scaffold(
              backgroundColor: AppColors.deepGreen,
              body: _outgoingRequestRow(onCancel: () {}),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
    });
  });
}
