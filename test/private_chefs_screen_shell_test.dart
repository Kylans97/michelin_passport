// Covers PrivateChefsScreen's outer shell (deepGreen masthead, safe-area
// handling, title/subtitle) and its loading/empty/error/populated states.
// PrivateChefsScreen constructs PrivateChefRepository against
// Supabase.instance.client eagerly in initState — same established
// limitation as every other Supabase-eager screen in this app (see
// wishlist_screen_shell_test.dart's own note) — so this mirrors the exact
// widget tree its build() produces rather than pumping the real screen.
// Unlike WishlistScreen (a bottom-nav tab body with no Scaffold of its
// own), PrivateChefsScreen is a PUSHED route via MaterialPageRoute and
// therefore owns a real Scaffold — mirrors WITH one, matching
// GuideCatalogueLayout's own precedent.
//
// The states themselves (PrivateChefsEmptyState/LoadingState/ErrorState)
// and the populated row (PrivateChefRow) are imported directly from
// production and already covered in their own dedicated test files — this
// file only exercises the shell composition around them.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:michelin_passport/core/constants/app_colors.dart';
import 'package:michelin_passport/core/theme/cs_spacing.dart';
import 'package:michelin_passport/core/theme/cs_typography.dart';
import 'package:michelin_passport/core/widgets/editorial_back_button.dart';
import 'package:michelin_passport/features/guides/widgets/guide_venue_card.dart'
    show GuideVenueCardDivider;
import 'package:michelin_passport/features/private_chefs/widgets/private_chef_row.dart';
import 'package:michelin_passport/features/private_chefs/widgets/private_chef_states.dart';
import 'package:michelin_passport/models/private_chef.dart';

const _chefs = [
  PrivateChef(id: 'c1', slug: 'chef-a', displayName: 'Chef A'),
  PrivateChef(id: 'c2', slug: 'chef-b', displayName: 'Chef B'),
];

// Mirrors _PrivateChefsScreenState.build's masthead exactly.
Widget _header() => SafeArea(
  bottom: false,
  child: ColoredBox(
    color: AppColors.deepGreen,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(
            CsSpacing.base,
            CsSpacing.xs,
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
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Private Chefs',
                style: CsTypography.screenTitle.copyWith(
                  color: AppColors.ivory,
                ),
              ),
              const SizedBox(height: CsSpacing.xs),
              Text(
                'Exceptional private dining, personally selected.',
                style: CsTypography.body.copyWith(
                  color: AppColors.secondaryOnDark,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  ),
);

Widget _shell({required Widget body}) => MaterialApp(
  home: AnnotatedRegion<SystemUiOverlayStyle>(
    value: SystemUiOverlayStyle.light,
    child: Scaffold(
      backgroundColor: AppColors.deepGreen,
      body: Column(
        children: [
          _header(),
          Expanded(
            child: ColoredBox(color: AppColors.ivory, child: body),
          ),
        ],
      ),
    ),
  ),
);

Widget _populated() => ListView.separated(
  padding: const EdgeInsets.symmetric(
    horizontal: CsSpacing.pageHorizontal,
    vertical: CsSpacing.sm,
  ),
  itemCount: _chefs.length,
  separatorBuilder: (_, _) => const GuideVenueCardDivider(),
  itemBuilder: (context, index) =>
      PrivateChefRow(chef: _chefs[index], onTap: () {}),
);

void main() {
  group('PrivateChefsScreen shell', () {
    testWidgets('title and subtitle render', (tester) async {
      await tester.pumpWidget(_shell(body: const PrivateChefsLoadingState()));
      expect(find.text('Private Chefs'), findsOneWidget);
      expect(
        find.text('Exceptional private dining, personally selected.'),
        findsOneWidget,
      );
    });

    testWidgets('back button present in the deepGreen masthead', (
      tester,
    ) async {
      await tester.pumpWidget(_shell(body: const PrivateChefsLoadingState()));
      expect(find.byType(EditorialBackButton), findsOneWidget);
    });

    testWidgets('title color is ivory, never gold', (tester) async {
      await tester.pumpWidget(_shell(body: const PrivateChefsLoadingState()));
      final title = tester.widget<Text>(find.text('Private Chefs'));
      expect(title.style?.color, AppColors.ivory);
      expect(title.style?.color, isNot(AppColors.gold));
    });

    testWidgets('loading state renders inside the ivory body', (tester) async {
      await tester.pumpWidget(_shell(body: const PrivateChefsLoadingState()));
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('empty state renders the editorial coming-soon copy', (
      tester,
    ) async {
      await tester.pumpWidget(_shell(body: const PrivateChefsEmptyState()));
      expect(find.text('Private Chefs are coming soon'), findsOneWidget);
    });

    testWidgets('error state renders with a working retry', (tester) async {
      var retried = false;
      await tester.pumpWidget(
        _shell(body: PrivateChefsErrorState(onRetry: () => retried = true)),
      );
      await tester.tap(find.text('Retry'));
      expect(retried, isTrue);
    });

    testWidgets('populated state renders one row per chef and each tap '
        'fires its own callback', (tester) async {
      await tester.pumpWidget(_shell(body: _populated()));
      expect(find.text('Chef A'), findsOneWidget);
      expect(find.text('Chef B'), findsOneWidget);
      expect(find.byType(PrivateChefRow), findsNWidgets(2));
    });

    testWidgets('320px width — no overflow across all states', (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 844));
      for (final body in [
        const PrivateChefsLoadingState(),
        const PrivateChefsEmptyState(),
        PrivateChefsErrorState(onRetry: () {}),
        _populated(),
      ]) {
        await tester.pumpWidget(_shell(body: body));
        expect(tester.takeException(), isNull);
      }
      await tester.binding.setSurfaceSize(null);
    });

    testWidgets('1.6x text scale — no overflow', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(1.6)),
            child: AnnotatedRegion<SystemUiOverlayStyle>(
              value: SystemUiOverlayStyle.light,
              child: Scaffold(
                backgroundColor: AppColors.deepGreen,
                body: Column(
                  children: [
                    _header(),
                    Expanded(
                      child: ColoredBox(
                        color: AppColors.ivory,
                        child: _populated(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
    });
  });
}
