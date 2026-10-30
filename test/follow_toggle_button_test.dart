// Events V2 Step 6 — covers FollowToggleButton. Revised 2026-10-30: a
// labelled pill ("Follow" / "Following") replaced the person-add glyph,
// whose outline-vs-filled change did not read on device.
//
// Originally: covers FollowToggleButton
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
    testWidgets('not following: a translucent pill reading "Follow" with '
        'a plus, ivory on green, no gold', (tester) async {
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
      expect(find.text('Follow'), findsOneWidget);
      expect(find.text('Following'), findsNothing);
      final icon = tester.widget<Icon>(find.byIcon(Icons.add_rounded));
      expect(icon.color, AppColors.textOnDark);
      expect(icon.color, isNot(AppColors.gold));
    });

    testWidgets('following: a solid ivory pill reading "Following" with a '
        'check — state spelled out, not just a filled glyph', (tester) async {
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
      expect(find.text('Following'), findsOneWidget);
      expect(find.byIcon(Icons.check_rounded), findsOneWidget);
      expect(find.byIcon(Icons.add_rounded), findsNothing);
      final icon = tester.widget<Icon>(find.byIcon(Icons.check_rounded));
      expect(icon.color, AppColors.forestGreen);
      final box = tester.widget<AnimatedContainer>(find.byType(AnimatedContainer));
      expect((box.decoration as ShapeDecoration).color, AppColors.ivory);
    });

    testWidgets('busy: keeps showing the state (no spinner) — the screens '
        'update optimistically', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const FollowToggleButton(
            isFollowing: true,
            busy: true,
            onTap: null,
            entityName: 'Parkheuvel',
          ),
        ),
      );
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text('Following'), findsOneWidget);
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

    testWidgets('following: semantic label says it follows and how to '
        'unfollow, never "Notifications on"', (tester) async {
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
      expect(
        find.bySemanticsLabel('Following Parkheuvel. Tap to unfollow'),
        findsOneWidget,
      );
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
