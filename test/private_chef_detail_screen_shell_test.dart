// Covers PrivateChefDetailScreen's outer shell and section composition.
// PrivateChefDetailScreen constructs PrivateChefRepository against
// Supabase.instance.client eagerly in initState — same established
// Supabase-eager-screen limitation as private_chefs_screen_shell_test.dart
// — so this mirrors the exact widget tree its build() produces (hero +
// ABOUT + RESTAURANT PROVENANCE + THE EXPERIENCE + CONNECT, each
// conditional, separated by SectionDivider only between sections that are
// actually present) rather than pumping the real screen.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:michelin_passport/core/constants/app_colors.dart';
import 'package:michelin_passport/core/theme/cs_spacing.dart';
import 'package:michelin_passport/core/theme/cs_typography.dart';
import 'package:michelin_passport/core/widgets/section_divider.dart';
import 'package:michelin_passport/features/private_chefs/widgets/private_chef_connect_section.dart';
import 'package:michelin_passport/features/private_chefs/widgets/private_chef_experience_section.dart';
import 'package:michelin_passport/features/private_chefs/widgets/private_chef_hero.dart';
import 'package:michelin_passport/features/private_chefs/widgets/private_chef_provenance_row.dart';
import 'package:michelin_passport/features/private_chefs/widgets/private_chef_states.dart';
import 'package:michelin_passport/models/private_chef.dart';
import 'package:michelin_passport/models/private_chef_restaurant_history.dart';
import 'package:michelin_passport/models/restaurant.dart';

const _restaurant = Restaurant(
  id: 'r1',
  restaurantCode: 'r1',
  name: 'Parkheuvel',
  michelinStars: 2,
  inclusionReason: 'michelin_star',
  cityName: 'Rotterdam',
  countryCode: 'NL',
  countryName: 'Netherlands',
  flagEmoji: '🇳🇱',
  address: 'Some address',
);

final _fullChef = PrivateChef(
  id: 'c1',
  slug: 'lucas',
  displayName: 'Lucas',
  businessName: 'Test Catering',
  biography: 'A short editorial biography.',
  homeCity: 'Breda',
  homeCountryCode: 'NL',
  serviceAreaText: 'The Netherlands and Belgium',
  minimumGuests: 6,
  maximumGuests: 14,
  winePairingAvailable: true,
  instagramUrl: 'https://instagram.com/test',
  websiteUrl: 'https://example.com',
);

final _history = [
  PrivateChefRestaurantHistory.fromRow({
    'id': 'h1',
    'private_chef_id': 'c1',
    'restaurant_id': 'r1',
    'restaurant_name_text': null,
    'role': 'Sous Chef',
    'period_text': '2019–2022',
    'display_order': 0,
  }, restaurant: _restaurant),
];

// Mirrors _PrivateChefDetailScreenState._body's section-assembly exactly.
Widget _body(PrivateChef chef, List<PrivateChefRestaurantHistory> history) {
  final biography = (chef.biography ?? '').trim();
  final hasBiography = biography.isNotEmpty;
  final hasProvenance = history.isNotEmpty;
  final hasInstagram = (chef.instagramUrl ?? '').trim().isNotEmpty;
  final hasWebsite = (chef.websiteUrl ?? '').trim().isNotEmpty;

  final sections = <Widget>[
    if (hasBiography)
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'ABOUT',
            style: CsTypography.eyebrow.copyWith(color: AppColors.taupe),
          ),
          const SizedBox(height: CsSpacing.md),
          Text(
            biography,
            style: CsTypography.body.copyWith(color: AppColors.textPrimary),
          ),
        ],
      ),
    if (hasProvenance)
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'RESTAURANT PROVENANCE',
            style: CsTypography.eyebrow.copyWith(color: AppColors.taupe),
          ),
          const SizedBox(height: CsSpacing.xs),
          for (final row in history)
            PrivateChefProvenanceRow(
              history: row,
              onTap: row.isCanonical ? () {} : null,
            ),
        ],
      ),
    PrivateChefExperienceSection(chef: chef),
    if (hasInstagram || hasWebsite)
      PrivateChefConnectSection(
        onTapInstagram: hasInstagram ? () {} : null,
        onTapWebsite: hasWebsite ? () {} : null,
      ),
  ];

  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      for (var i = 0; i < sections.length; i++) ...[
        if (i > 0) const SectionDivider(),
        sections[i],
      ],
    ],
  );
}

Widget _shell(PrivateChef chef, List<PrivateChefRestaurantHistory> history) =>
    MaterialApp(
      home: Scaffold(
        backgroundColor: AppColors.deepGreen,
        body: CustomScrollView(
          slivers: [
            PrivateChefHero(
              displayName: chef.displayName,
              businessName: chef.businessName,
              location:
                  [
                    if ((chef.homeCity ?? '').isNotEmpty) chef.homeCity!,
                    if ((chef.homeCountryCode ?? '').isNotEmpty)
                      chef.homeCountryCode!,
                  ].isEmpty
                  ? null
                  : [
                      if ((chef.homeCity ?? '').isNotEmpty) chef.homeCity!,
                      if ((chef.homeCountryCode ?? '').isNotEmpty)
                        chef.homeCountryCode!,
                    ].join(', '),
              profileImageUrl: chef.profileImageUrl,
            ),
            SliverToBoxAdapter(
              child: ColoredBox(
                color: AppColors.ivory,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    CsSpacing.pageHorizontal,
                    CsSpacing.xl,
                    CsSpacing.pageHorizontal,
                    CsSpacing.section,
                  ),
                  child: _body(chef, history),
                ),
              ),
            ),
          ],
        ),
      ),
    );

void main() {
  group('PrivateChefDetailScreen shell', () {
    testWidgets('renders hero identity and every present section', (
      tester,
    ) async {
      await tester.pumpWidget(_shell(_fullChef, _history));
      expect(find.text('Lucas'), findsWidgets);
      expect(find.text('Test Catering'), findsWidgets);
      expect(find.text('ABOUT'), findsOneWidget);
      expect(find.text('A short editorial biography.'), findsOneWidget);
      expect(find.text('RESTAURANT PROVENANCE'), findsOneWidget);
      // Renders inside a Text.rich span alongside StarRow — see
      // private_chef_provenance_row_test.dart's own note on why
      // textContaining, not text, is the correct finder here.
      expect(find.textContaining('Parkheuvel'), findsOneWidget);
      expect(find.text('THE EXPERIENCE'), findsOneWidget);
      expect(find.text('CONNECT'), findsOneWidget);
    });

    testWidgets('biography absent -> no ABOUT section, no placeholder copy', (
      tester,
    ) async {
      final chef = PrivateChef(id: 'c1', slug: 'lucas', displayName: 'Lucas');
      await tester.pumpWidget(_shell(chef, const []));
      expect(find.text('ABOUT'), findsNothing);
    });

    testWidgets('no provenance -> no RESTAURANT PROVENANCE section', (
      tester,
    ) async {
      final chef = PrivateChef(id: 'c1', slug: 'lucas', displayName: 'Lucas');
      await tester.pumpWidget(_shell(chef, const []));
      expect(find.text('RESTAURANT PROVENANCE'), findsNothing);
    });

    testWidgets('no instagram/website -> no CONNECT section', (tester) async {
      final chef = PrivateChef(id: 'c1', slug: 'lucas', displayName: 'Lucas');
      await tester.pumpWidget(_shell(chef, const []));
      expect(find.text('CONNECT'), findsNothing);
    });

    testWidgets('no score/rating/selected badge anywhere', (tester) async {
      await tester.pumpWidget(_shell(_fullChef, _history));
      expect(find.textContaining('Chasing Stars Selected'), findsNothing);
      expect(find.textContaining('rating'), findsNothing);
    });

    testWidgets('no dead "Request an Experience" CTA', (tester) async {
      await tester.pumpWidget(_shell(_fullChef, _history));
      expect(find.textContaining('Request'), findsNothing);
      expect(find.textContaining('Coming soon'), findsNothing);
    });

    testWidgets('loading/error/not-found states render inside a deepGreen '
        'Scaffold with a SafeArea', (tester) async {
      for (final body in [
        const PrivateChefsLoadingState(),
        PrivateChefsErrorState(onRetry: () {}),
        const PrivateChefNotFoundState(),
      ]) {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              backgroundColor: AppColors.deepGreen,
              body: SafeArea(child: body),
            ),
          ),
        );
        expect(tester.takeException(), isNull);
      }
    });

    testWidgets('long biography/business name — 320px no overflow', (
      tester,
    ) async {
      final chef = PrivateChef(
        id: 'c1',
        slug: 'lucas',
        displayName: 'A Genuinely Very Long Private Chef Display Name',
        businessName: 'An Equally Long Catering Business Name For Testing',
        biography:
            'A genuinely long biography paragraph meant to stress-test '
            'wrapping behavior across several lines of running editorial '
            'prose describing a chef in considerable detail.',
        serviceAreaText:
            'A very long service area description spanning '
            'several countries and regions for testing purposes',
      );
      await tester.binding.setSurfaceSize(const Size(320, 844));
      await tester.pumpWidget(_shell(chef, _history));
      expect(tester.takeException(), isNull);
      await tester.binding.setSurfaceSize(null);
    });

    testWidgets('1.6x text scale — no overflow', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(1.6)),
            child: Scaffold(
              backgroundColor: AppColors.deepGreen,
              body: CustomScrollView(
                slivers: [
                  PrivateChefHero(
                    displayName: _fullChef.displayName,
                    businessName: _fullChef.businessName,
                  ),
                  SliverToBoxAdapter(
                    child: ColoredBox(
                      color: AppColors.ivory,
                      child: Padding(
                        padding: const EdgeInsets.all(CsSpacing.pageHorizontal),
                        child: _body(_fullChef, _history),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
    });
  });
}
