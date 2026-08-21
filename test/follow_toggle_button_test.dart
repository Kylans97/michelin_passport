// Events V2 Step 6 — covers FollowToggleButton
// (lib/core/widgets/follow_toggle_button.dart): unselected/selected/busy
// states, semantics, accessibility, and the "no gold, distinct from
// Wishlist's heart" visual requirements.
//
// UX correction (physical-device review): the original bell icon read
// primarily as "notifications" rather than "Follow" — replaced with a
// person-add pair (outline vs. filled, same glyph). This file was updated
// to match; the icon-family assertions below now guard against the bell
// ever coming back, not just against heart/bookmark/star.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:michelin_passport/core/constants/app_colors.dart';
import 'package:michelin_passport/core/widgets/follow_toggle_button.dart';

Widget _wrap(Widget child, {double width = 390, double textScale = 1.0}) =>
    MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(
          size: Size(width, 844),
          textScaler: TextScaler.linear(textScale),
        ),
        child: Scaffold(
          body: Center(child: Material(child: child)),
        ),
      ),
    );

void main() {
  group('FollowToggleButton — states', () {
    testWidgets('not following: outline person-add icon, deepGreen/ivory, '
        'no gold', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const FollowToggleButton(
            isFollowing: false,
            busy: false,
            onTap: null,
            entityName: 'Parkheuvel',
          ),
        ),
      );
      expect(find.byIcon(Icons.person_add_alt_1_outlined), findsOneWidget);
      expect(find.byIcon(Icons.person_add_alt_1_rounded), findsNothing);
      final icon = tester.widget<Icon>(
        find.byIcon(Icons.person_add_alt_1_outlined),
      );
      expect(icon.color, AppColors.textOnDark);
      expect(icon.color, isNot(AppColors.gold));
    });

    testWidgets('following: filled person-add icon — state conveyed by '
        'shape, not just color', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const FollowToggleButton(
            isFollowing: true,
            busy: false,
            onTap: null,
            entityName: 'Parkheuvel',
          ),
        ),
      );
      expect(find.byIcon(Icons.person_add_alt_1_rounded), findsOneWidget);
      expect(find.byIcon(Icons.person_add_alt_1_outlined), findsNothing);
    });

    testWidgets('busy: shows a spinner instead of either icon, never gold', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          const FollowToggleButton(
            isFollowing: false,
            busy: true,
            onTap: null,
            entityName: 'Parkheuvel',
          ),
        ),
      );
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.byIcon(Icons.person_add_alt_1_outlined), findsNothing);
      expect(find.byIcon(Icons.person_add_alt_1_rounded), findsNothing);
      final indicator = tester.widget<CircularProgressIndicator>(
        find.byType(CircularProgressIndicator),
      );
      expect(indicator.color, isNot(AppColors.gold));
    });

    testWidgets('never uses the bell/notification icon family — the '
        'original icon must not come back', (tester) async {
      for (final following in [true, false]) {
        await tester.pumpWidget(
          _wrap(
            FollowToggleButton(
              isFollowing: following,
              busy: false,
              onTap: null,
              entityName: 'Parkheuvel',
            ),
          ),
        );
        expect(find.byIcon(Icons.notifications_rounded), findsNothing);
        expect(find.byIcon(Icons.notifications_none_rounded), findsNothing);
      }
    });

    testWidgets('never uses the heart icon family — must stay visually '
        'distinct from Wishlist', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const FollowToggleButton(
            isFollowing: true,
            busy: false,
            onTap: null,
            entityName: 'Parkheuvel',
          ),
        ),
      );
      expect(find.byIcon(Icons.favorite_rounded), findsNothing);
      expect(find.byIcon(Icons.favorite_border_rounded), findsNothing);
    });

    testWidgets('never uses the bookmark icon family — must stay visually '
        'distinct from Event Interested', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const FollowToggleButton(
            isFollowing: true,
            busy: false,
            onTap: null,
            entityName: 'Parkheuvel',
          ),
        ),
      );
      expect(find.byIcon(Icons.bookmark_rounded), findsNothing);
      expect(find.byIcon(Icons.bookmark_border_rounded), findsNothing);
    });

    testWidgets('never uses a star icon — reserved for Michelin '
        'recognition elsewhere in the product', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const FollowToggleButton(
            isFollowing: true,
            busy: false,
            onTap: null,
            entityName: 'Parkheuvel',
          ),
        ),
      );
      expect(find.byIcon(Icons.star_rounded), findsNothing);
      expect(find.byIcon(Icons.star_border_rounded), findsNothing);
    });
  });

  group('FollowToggleButton — interaction', () {
    testWidgets('tapping while not busy fires onTap', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        _wrap(
          FollowToggleButton(
            isFollowing: false,
            busy: false,
            onTap: () => taps++,
            entityName: 'Parkheuvel',
          ),
        ),
      );
      await tester.tap(find.byType(FollowToggleButton));
      expect(taps, 1);
    });

    testWidgets('tapping while busy is ignored — double-tap protection', (
      tester,
    ) async {
      var taps = 0;
      await tester.pumpWidget(
        _wrap(
          FollowToggleButton(
            isFollowing: false,
            busy: true,
            onTap: () => taps++,
            entityName: 'Parkheuvel',
          ),
        ),
      );
      await tester.tap(find.byType(FollowToggleButton), warnIfMissed: false);
      expect(taps, 0);
    });

    testWidgets('a null onTap renders without throwing and ignores taps', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          const FollowToggleButton(
            isFollowing: false,
            busy: false,
            onTap: null,
            entityName: 'Parkheuvel',
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      await tester.tap(find.byType(FollowToggleButton), warnIfMissed: false);
      expect(tester.takeException(), isNull);
    });
  });

  group('FollowToggleButton — semantics', () {
    testWidgets('not following: semantic label reads "Follow {name}", '
        'never "Notifications on"', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const FollowToggleButton(
            isFollowing: false,
            busy: false,
            onTap: null,
            entityName: 'Parkheuvel',
          ),
        ),
      );
      expect(find.bySemanticsLabel('Follow Parkheuvel'), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp('Notification')), findsNothing);
    });

    testWidgets('following: semantic label reads "Unfollow {name}", never '
        '"Notifications on"', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const FollowToggleButton(
            isFollowing: true,
            busy: false,
            onTap: null,
            entityName: 'Parkheuvel',
          ),
        ),
      );
      expect(find.bySemanticsLabel('Unfollow Parkheuvel'), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp('Notification')), findsNothing);
    });

    testWidgets('the entity name is threaded through correctly for a '
        'different entity (Hotel Okura Amsterdam)', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const FollowToggleButton(
            isFollowing: false,
            busy: false,
            onTap: null,
            entityName: 'Hotel Okura Amsterdam',
          ),
        ),
      );
      expect(
        find.bySemanticsLabel('Follow Hotel Okura Amsterdam'),
        findsOneWidget,
      );
    });

    testWidgets('the outer Semantics config reports button:true and '
        'selected matches isFollowing', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const FollowToggleButton(
            isFollowing: true,
            busy: false,
            onTap: null,
            entityName: 'Parkheuvel',
          ),
        ),
      );
      final semanticsWidgets = tester.widgetList<Semantics>(
        find.descendant(
          of: find.byType(FollowToggleButton),
          matching: find.byType(Semantics),
        ),
      );
      expect(
        semanticsWidgets.any(
          (s) => s.properties.button == true && s.properties.selected == true,
        ),
        isTrue,
      );
    });
  });

  group('FollowToggleButton — responsive', () {
    testWidgets('320px width — no overflow', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const FollowToggleButton(
            isFollowing: false,
            busy: false,
            onTap: null,
            entityName: 'Parkheuvel',
          ),
          width: 320,
        ),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('1.6x text scale — no overflow', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const FollowToggleButton(
            isFollowing: false,
            busy: false,
            onTap: null,
            entityName: 'Parkheuvel',
          ),
          textScale: 1.6,
        ),
      );
      expect(tester.takeException(), isNull);
    });
  });
}
