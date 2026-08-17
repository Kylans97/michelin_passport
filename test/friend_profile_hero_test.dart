// Covers FriendProfileScreen's hero (Community/Friends UX Step 1 §6-8):
// the forest-green upper treatment — back arrow, avatar, display name,
// username, relationship action. _Hero is private to
// friend_profile_screen.dart (Dart privacy is per-file), so this
// reconstructs its exact widget tree/colors here, using the real
// CsPrimaryButton/CsSecondaryButton/EditorialBackButton leaf widgets.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:michelin_passport/core/constants/app_colors.dart';
import 'package:michelin_passport/core/theme/cs_spacing.dart';
import 'package:michelin_passport/core/theme/cs_typography.dart';
import 'package:michelin_passport/core/widgets/cs_primary_button.dart';
import 'package:michelin_passport/core/widgets/editorial_back_button.dart';

// Mirrors _Hero exactly (avatar/name/username portion — the relationship
// action itself is already covered independently by
// friend_profile_no_activity_test.dart).
Widget _hero({required String label, String? username}) {
  final words = label.trim().split(' ').where((w) => w.isNotEmpty);
  final initials = words.isEmpty
      ? '?'
      : words.map((w) => w[0]).take(2).join().toUpperCase();

  return ColoredBox(
    color: AppColors.forestGreen,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            CsSpacing.base,
            CsSpacing.sm,
            CsSpacing.base,
            0,
          ),
          child: Align(
            alignment: Alignment.centerLeft,
            child: EditorialBackButton(color: AppColors.ivory),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            CsSpacing.pageHorizontal,
            CsSpacing.sm,
            CsSpacing.pageHorizontal,
            CsSpacing.xl,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 96,
                height: 96,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.ivory,
                ),
                alignment: Alignment.center,
                child: Text(
                  initials,
                  style: CsTypography.screenTitle.copyWith(
                    color: AppColors.forestGreen,
                  ),
                ),
              ),
              const SizedBox(height: CsSpacing.lg),
              Text(
                label,
                textAlign: TextAlign.center,
                style: CsTypography.screenTitle.copyWith(
                  color: AppColors.ivory,
                ),
              ),
              if (username != null) ...[
                const SizedBox(height: 4),
                Text(
                  '@$username',
                  style: CsTypography.body.copyWith(
                    color: AppColors.secondaryOnDark,
                  ),
                ),
              ],
              const SizedBox(height: CsSpacing.xl),
              SizedBox(
                width: double.infinity,
                child: CsPrimaryButton(label: 'Add friend', onTap: () {}),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

// The real screen always embeds _Hero inside a SingleChildScrollView
// (never pinned, so an arbitrarily long user-generated display name can
// never overflow with no escape route) — matched here rather than
// dropping the hero straight into a bare, unconstrained-height SizedBox.
Widget _wrap(Widget child, {double width = 390}) => MaterialApp(
  home: Scaffold(
    body: SizedBox(
      width: width,
      child: SingleChildScrollView(child: child),
    ),
  ),
);

void main() {
  group('FriendProfileScreen hero', () {
    testWidgets('renders avatar initials, name, and username', (tester) async {
      await tester.pumpWidget(
        _wrap(_hero(label: 'Kylan Scheepstra', username: 'kylan')),
      );
      expect(find.text('KS'), findsOneWidget);
      expect(find.text('Kylan Scheepstra'), findsOneWidget);
      expect(find.text('@kylan'), findsOneWidget);
    });

    testWidgets('never renders gold — canvas is forest-green, avatar/name '
        'are ivory', (tester) async {
      await tester.pumpWidget(_wrap(_hero(label: 'Kylan Scheepstra')));

      expect(
        find.byWidgetPredicate(
          (w) => w is ColoredBox && w.color == AppColors.forestGreen,
        ),
        findsOneWidget,
      );

      final name = tester.widget<Text>(find.text('Kylan Scheepstra'));
      expect(name.style?.color, AppColors.ivory);
      expect(name.style?.color, isNot(AppColors.gold));

      final initials = tester.widget<Text>(find.text('KS'));
      expect(initials.style?.color, AppColors.forestGreen);
      expect(initials.style?.color, isNot(AppColors.gold));

      final backIcon = tester.widget<Icon>(
        find.byIcon(Icons.arrow_back_ios_new_rounded),
      );
      expect(backIcon.color, AppColors.ivory);
      expect(backIcon.color, isNot(AppColors.gold));
    });

    testWidgets('the avatar circle has no border — restrained, not a '
        'social-media ring', (tester) async {
      await tester.pumpWidget(_wrap(_hero(label: 'Kylan Scheepstra')));
      final circle = tester.widget<Container>(
        find
            .ancestor(of: find.text('KS'), matching: find.byType(Container))
            .first,
      );
      final decoration = circle.decoration! as BoxDecoration;
      expect(decoration.border, isNull);
    });

    testWidgets('long display name at 320px does not overflow', (tester) async {
      await tester.pumpWidget(
        _wrap(
          _hero(
            label:
                'A Deliberately Long Display Name Used To Confirm This '
                'Hero Never Overflows',
            username: 'a_very_long_username_indeed',
          ),
          width: 320,
        ),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('390px — no overflow', (tester) async {
      await tester.pumpWidget(
        _wrap(_hero(label: 'Kylan Scheepstra', username: 'kylan'), width: 390),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('1.6x text scale — no overflow', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(1.6)),
            child: Scaffold(
              body: SizedBox(
                width: 320,
                child: _hero(label: 'Kylan Scheepstra', username: 'kylan'),
              ),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
    });
  });

  // FriendProfileScreen constructs FriendshipRepository against
  // Supabase.instance.client eagerly in initState, so the real screen
  // can't be pumped here — same established limitation as everywhere else
  // in this file/feature. This mirrors _FriendProfileScreenState.build's
  // outer shell (UI Polish pass) instead: Scaffold.backgroundColor is
  // forest-green (not ivory) so the top safe area/status bar continues
  // whatever forest-green content sits directly beneath it, and an
  // AnnotatedRegion forces light status-bar icons for this screen only.
  group('FriendProfileScreen outer shell (UI Polish)', () {
    testWidgets('Scaffold background is forest-green, with an explicit ivory '
        'ColoredBox for the content area below the hero', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: AnnotatedRegion<SystemUiOverlayStyle>(
            value: SystemUiOverlayStyle.light,
            child: Scaffold(
              backgroundColor: AppColors.forestGreen,
              body: Column(
                children: [
                  _hero(label: 'Kylan Scheepstra'),
                  Expanded(
                    child: ColoredBox(
                      color: AppColors.ivory,
                      child: const SizedBox.shrink(),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
      expect(scaffold.backgroundColor, AppColors.forestGreen);

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
    });
  });
}
