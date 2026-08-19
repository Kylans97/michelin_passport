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
// The states themselves (PrivateChefsEmptyState/LoadingState/ErrorState),
// the discovery card (PrivateChefDiscoveryCard), and the country-grouping/
// descriptor/location pure functions are already covered in their own
// dedicated test files — this file only exercises the shell composition
// around them: masthead, and the country-sectioned body they're arranged
// into.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:michelin_passport/core/constants/app_colors.dart';
import 'package:michelin_passport/core/theme/cs_spacing.dart';
import 'package:michelin_passport/core/theme/cs_typography.dart';
import 'package:michelin_passport/core/widgets/cs_image_placeholder.dart';
import 'package:michelin_passport/core/widgets/editorial_back_button.dart';
import 'package:michelin_passport/features/private_chefs/private_chef_grouping.dart';
import 'package:michelin_passport/features/private_chefs/widgets/private_chef_discovery_card.dart';
import 'package:michelin_passport/features/private_chefs/widgets/private_chef_states.dart';
import 'package:michelin_passport/models/private_chef.dart';

const _dutchChefs = [
  PrivateChef(
    id: 'c1',
    slug: 'chef-a',
    displayName: 'Chef A',
    homeCountryCode: 'NL',
  ),
  PrivateChef(
    id: 'c2',
    slug: 'chef-b',
    displayName: 'Chef B',
    homeCountryCode: 'NL',
  ),
];

const _multiCountryGroups = [
  PrivateChefCountryGroup(
    countryCode: 'BE',
    countryName: 'Belgium',
    chefs: [
      PrivateChef(
        id: 'c3',
        slug: 'chef-c',
        displayName: 'Chef C',
        homeCountryCode: 'BE',
      ),
    ],
  ),
  PrivateChefCountryGroup(
    countryCode: 'NL',
    countryName: 'Netherlands',
    chefs: _dutchChefs,
  ),
];

// Mirrors _PrivateChefsScreenState.build's masthead exactly. Step 2C
// physical-device review: back-button top padding and the subtitle's
// bottom padding were both trimmed (xs->0, xl->base) to bring the first
// chef photograph into view sooner, without touching typography, the
// back arrow itself, or SafeArea handling.
Widget _header() => SafeArea(
  bottom: false,
  child: ColoredBox(
    color: AppColors.deepGreen,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(CsSpacing.base, 0, CsSpacing.base, 0),
          child: Align(
            alignment: Alignment.centerLeft,
            child: EditorialBackButton(color: AppColors.ivory),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            CsSpacing.pageHorizontal,
            CsSpacing.xs,
            CsSpacing.pageHorizontal,
            CsSpacing.base,
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

// Mirrors _PrivateChefsScreenState._body/_countrySection/_chefCard exactly.
Widget _populated(List<PrivateChefCountryGroup> groups) => ListView.builder(
  padding: const EdgeInsets.fromLTRB(
    CsSpacing.pageHorizontal,
    CsSpacing.lg,
    CsSpacing.pageHorizontal,
    CsSpacing.section,
  ),
  itemCount: groups.length,
  itemBuilder: (context, index) {
    final group = groups[index];
    return Padding(
      padding: EdgeInsets.only(top: index == 0 ? 0 : CsSpacing.section),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (group.countryName != null) ...[
            Text(
              group.countryName!.toUpperCase(),
              style: CsTypography.eyebrow.copyWith(color: AppColors.taupe),
            ),
            const SizedBox(height: CsSpacing.lg),
          ],
          for (var i = 0; i < group.chefs.length; i++) ...[
            if (i > 0) const SizedBox(height: CsSpacing.section),
            PrivateChefDiscoveryCard(
              chef: group.chefs[i],
              coverImageUrl: null,
              location: null,
              onTap: () {},
            ),
          ],
        ],
      ),
    );
  },
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

    testWidgets(
      'masthead vertical spacing was trimmed (Step 2C device review) — '
      'no top padding above the back arrow, and the gap below the '
      'subtitle no longer uses the old, larger xl token',
      (tester) async {
        await tester.pumpWidget(_shell(body: const PrivateChefsLoadingState()));
        final backButtonPadding = tester.widget<Padding>(
          find
              .ancestor(
                of: find.byType(EditorialBackButton),
                matching: find.byType(Padding),
              )
              .first,
        );
        expect(backButtonPadding.padding, isA<EdgeInsets>());
        expect((backButtonPadding.padding as EdgeInsets).top, 0);

        final subtitlePadding = tester.widget<Padding>(
          find
              .ancestor(
                of: find.text(
                  'Exceptional private dining, personally selected.',
                ),
                matching: find.byType(Padding),
              )
              .first,
        );
        expect((subtitlePadding.padding as EdgeInsets).bottom, CsSpacing.base);
        expect(
          (subtitlePadding.padding as EdgeInsets).bottom,
          lessThan(CsSpacing.xl),
        );
      },
    );

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

    testWidgets(
      'populated state renders a quiet country heading, not "N results"',
      (tester) async {
        await tester.pumpWidget(
          _shell(
            body: _populated([
              const PrivateChefCountryGroup(
                countryCode: 'NL',
                countryName: 'Netherlands',
                chefs: _dutchChefs,
              ),
            ]),
          ),
        );
        expect(find.text('NETHERLANDS'), findsOneWidget);
        expect(find.textContaining('result'), findsNothing);
      },
    );

    testWidgets('populated state renders one large discovery card per chef, no '
        'PrivateChefRow-style circular avatar layout', (tester) async {
      await tester.pumpWidget(
        _shell(
          body: _populated([
            const PrivateChefCountryGroup(
              countryCode: 'NL',
              countryName: 'Netherlands',
              chefs: _dutchChefs,
            ),
          ]),
        ),
      );
      expect(find.text('Chef A'), findsOneWidget);
      expect(find.text('Chef B'), findsOneWidget);
      expect(find.byType(PrivateChefDiscoveryCard), findsNWidgets(2));
      expect(find.byType(ClipOval), findsNothing);
      expect(find.byType(CsImagePlaceholder), findsNWidgets(2));
    });

    testWidgets('multiple country groups render vertically, each under '
        'its own heading', (tester) async {
      await tester.pumpWidget(_shell(body: _populated(_multiCountryGroups)));
      expect(find.text('BELGIUM'), findsOneWidget);
      expect(find.text('Chef C'), findsOneWidget);

      // The full-width portrait cover cards are tall — Netherlands' section
      // sits below the fold in this ListView.builder, so scroll it into
      // view rather than assuming it's already built.
      await tester.scrollUntilVisible(
        find.text('NETHERLANDS'),
        500,
        scrollable: find.byType(Scrollable),
      );
      expect(find.text('NETHERLANDS'), findsOneWidget);
      expect(find.text('Chef A'), findsOneWidget);
      expect(find.text('Chef B'), findsOneWidget);
      // Belgium-before-Netherlands ordering itself is already covered by
      // groupChefsByCountry's own dedicated sort test — this test only
      // needs to confirm both groups actually render into the list.
    });

    testWidgets('320px width — no overflow across all states', (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 844));
      for (final body in [
        const PrivateChefsLoadingState(),
        const PrivateChefsEmptyState(),
        PrivateChefsErrorState(onRetry: () {}),
        _populated([
          const PrivateChefCountryGroup(
            countryCode: 'NL',
            countryName: 'Netherlands',
            chefs: _dutchChefs,
          ),
        ]),
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
                        child: _populated([
                          const PrivateChefCountryGroup(
                            countryCode: 'NL',
                            countryName: 'Netherlands',
                            chefs: _dutchChefs,
                          ),
                        ]),
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
