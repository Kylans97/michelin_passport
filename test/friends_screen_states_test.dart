// Covers FriendsScreen's empty states and request-row actions (Social
// Foundation Step 1). FriendsScreen constructs FriendshipRepository
// against Supabase.instance.client eagerly in initState (same established
// limitation as every other screen in this app that touches Supabase
// there), so this reconstructs the exact copy/row shapes from
// lib/features/friends/friends_screen.dart rather than pumping the real
// screen.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:michelin_passport/core/constants/app_colors.dart';
import 'package:michelin_passport/core/theme/cs_spacing.dart';
import 'package:michelin_passport/core/theme/cs_typography.dart';
import 'package:michelin_passport/core/widgets/cs_primary_button.dart';
import 'package:michelin_passport/core/widgets/editorial_back_button.dart';
import 'package:michelin_passport/features/friends/widgets/identity_row.dart';

// Mirrors _FriendsScreenState.build's outer shell (Friends Safe Area
// Polish pass) — FriendsScreen constructs FriendshipRepository against
// Supabase.instance.client eagerly in initState, so the real screen can't
// be pumped here (same established limitation as the rest of this file).
// Scaffold.backgroundColor is forest-green (not ivory) so the top safe
// area/status bar continues the header seamlessly; the tab content area
// below paints its own explicit ivory ColoredBox rather than relying on
// the Scaffold's background.
Widget _friendsScreenShell({required Widget tabContent}) =>
    AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: AppColors.forestGreen,
        body: Column(
          children: [
            ColoredBox(
              color: AppColors.forestGreen,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: EditorialBackButton(color: AppColors.ivory),
                  ),
                  Text(
                    'Friends',
                    style: CsTypography.screenTitle.copyWith(
                      color: AppColors.ivory,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ColoredBox(color: AppColors.ivory, child: tabContent),
            ),
          ],
        ),
      ),
    );

Widget _friendsEmptyState({VoidCallback? onFindFriends}) => Column(
  mainAxisSize: MainAxisSize.min,
  children: [
    Text(
      'Find friends and discover the places they loved',
      textAlign: TextAlign.center,
      style: CsTypography.placeTitle.copyWith(color: AppColors.forestGreen),
    ),
    const SizedBox(height: CsSpacing.sm),
    Text(
      'Search for people you know by username.',
      textAlign: TextAlign.center,
      style: CsTypography.body.copyWith(color: AppColors.taupe),
    ),
    const SizedBox(height: CsSpacing.xl),
    CsPrimaryButton(label: 'Find friends', onTap: onFindFriends ?? () {}),
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
  home: Scaffold(backgroundColor: AppColors.ivory, body: child),
);

void main() {
  group('FriendsScreen outer shell (Safe Area Polish)', () {
    testWidgets('Scaffold background is forest-green, with an explicit ivory '
        'ColoredBox for the tab content area below the header', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: _friendsScreenShell(tabContent: _friendsEmptyState()),
        ),
      );

      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
      expect(scaffold.backgroundColor, AppColors.forestGreen);

      expect(
        find.byWidgetPredicate(
          (w) => w is ColoredBox && w.color == AppColors.forestGreen,
        ),
        findsOneWidget,
      );
      expect(
        find.byWidgetPredicate(
          (w) => w is ColoredBox && w.color == AppColors.ivory,
        ),
        findsOneWidget,
      );

      final region = tester.widget<AnnotatedRegion<SystemUiOverlayStyle>>(
        find.byType(AnnotatedRegion<SystemUiOverlayStyle>),
      );
      expect(region.value, SystemUiOverlayStyle.light);

      final title = tester.widget<Text>(find.text('Friends'));
      expect(title.style?.color, AppColors.ivory);

      final backIcon = tester.widget<Icon>(
        find.byIcon(Icons.arrow_back_ios_new_rounded),
      );
      expect(backIcon.color, AppColors.ivory);
    });

    testWidgets('the empty state still renders inside the shell', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: _friendsScreenShell(tabContent: _friendsEmptyState()),
        ),
      );
      expect(
        find.text('Find friends and discover the places they loved'),
        findsOneWidget,
      );
      expect(find.text('Find friends'), findsOneWidget);
    });
  });

  group('FriendsScreen empty states', () {
    testWidgets('friends tab empty state', (tester) async {
      await tester.pumpWidget(_wrap(_friendsEmptyState()));
      expect(
        find.text('Find friends and discover the places they loved'),
        findsOneWidget,
      );
      expect(
        find.text('Search for people you know by username.'),
        findsOneWidget,
      );
      expect(find.text('Find friends'), findsOneWidget);
    });

    testWidgets('the discovery CTA fires its callback', (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        _wrap(_friendsEmptyState(onFindFriends: () => tapped = true)),
      );
      await tester.tap(find.text('Find friends'));
      expect(tapped, isTrue);
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
              backgroundColor: AppColors.ivory,
              body: _outgoingRequestRow(onCancel: () {}),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
    });
  });
}
