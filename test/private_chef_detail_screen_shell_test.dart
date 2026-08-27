// Covers PrivateChefDetailScreen's outer shell and section composition.
// PrivateChefDetailScreen constructs PrivateChefRepository against
// Supabase.instance.client eagerly in initState — same established
// Supabase-eager-screen limitation as private_chefs_screen_shell_test.dart
// — so this mirrors the exact widget tree its build() produces (hero +
// ABOUT + BACKGROUND + THE EXPERIENCE + CONNECT, each conditional,
// separated by SectionDivider only between sections that are actually
// present) rather than pumping the real screen.
//
// Step 2B: "Restaurant Provenance" was renamed to "Background" and now
// merges two distinct sources — restaurant history
// (PrivateChefRestaurantHistory/PrivateChefProvenanceRow) and education
// (PrivateChefEducation/PrivateChefEducationRow), restaurant items first.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:michelin_passport/core/constants/app_colors.dart';
import 'package:michelin_passport/core/theme/cs_spacing.dart';
import 'package:michelin_passport/core/theme/cs_typography.dart';
import 'package:michelin_passport/core/widgets/follow_toggle_button.dart';
import 'package:michelin_passport/core/widgets/section_divider.dart';
import 'package:michelin_passport/features/private_chefs/private_chef_location.dart';
import 'package:michelin_passport/features/private_chefs/widgets/private_chef_connect_section.dart';
import 'package:michelin_passport/features/private_chefs/widgets/private_chef_education_row.dart';
import 'package:michelin_passport/features/private_chefs/widgets/private_chef_experience_section.dart';
import 'package:michelin_passport/features/private_chefs/widgets/private_chef_hero.dart';
import 'package:michelin_passport/features/private_chefs/widgets/private_chef_provenance_row.dart';
import 'package:michelin_passport/features/private_chefs/widgets/private_chef_states.dart';
import 'package:michelin_passport/models/private_chef.dart';
import 'package:michelin_passport/models/private_chef_education.dart';
import 'package:michelin_passport/models/private_chef_restaurant_history.dart';
import 'package:michelin_passport/models/restaurant.dart';
import 'package:michelin_passport/models/venue_country.dart';

const _countryNames = {
  'NL': VenueCountry(name: 'Netherlands', code: 'NL', flag: '🇳🇱'),
};

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
    'role': 'Service',
    'period_text': '2.5 years',
    'display_order': 0,
  }, restaurant: _restaurant),
];

final _education = [
  const PrivateChefEducation(
    id: 'e1',
    privateChefId: 'c1',
    institution: 'De Rooi Pannen',
    program: 'Horeca Ondernemend Management',
  ),
];

// Mirrors _PrivateChefDetailScreenState._body's section-assembly exactly.
Widget _body(
  PrivateChef chef,
  List<PrivateChefRestaurantHistory> history, [
  List<PrivateChefEducation> education = const [],
]) {
  final biography = (chef.biography ?? '').trim();
  final hasBiography = biography.isNotEmpty;
  final hasBackground = history.isNotEmpty || education.isNotEmpty;
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
    if (hasBackground)
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'BACKGROUND',
            style: CsTypography.eyebrow.copyWith(color: AppColors.taupe),
          ),
          const SizedBox(height: CsSpacing.xs),
          for (final row in history)
            PrivateChefProvenanceRow(
              history: row,
              onTap: row.isCanonical ? () {} : null,
            ),
          for (final item in education)
            PrivateChefEducationRow(education: item),
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

Widget _shell(
  PrivateChef chef,
  List<PrivateChefRestaurantHistory> history, [
  List<PrivateChefEducation> education = const [],
  bool isFollowing = false,
  bool followBusy = false,
  VoidCallback? onTapFollow,
]) => MaterialApp(
  home: Scaffold(
    backgroundColor: AppColors.deepGreen,
    body: CustomScrollView(
      slivers: [
        PrivateChefHero(
          displayName: chef.displayName,
          businessName: chef.businessName,
          location: formatChefLocation(
            city: chef.homeCity,
            countryCode: chef.homeCountryCode,
            countryNames: _countryNames,
          ),
          profileImageUrl: chef.profileImageUrl,
          isFollowing: isFollowing,
          followBusy: followBusy,
          onTapFollow: onTapFollow,
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
              child: _body(chef, history, education),
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
      await tester.pumpWidget(_shell(_fullChef, _history, _education));
      expect(find.text('Lucas'), findsWidgets);
      expect(find.text('Test Catering'), findsWidgets);
      // Step 2C §12/§15: hero location resolves to the full country name
      // ("Breda, Netherlands"), never the raw ISO code.
      expect(find.text('Breda, Netherlands'), findsOneWidget);
      expect(find.text('ABOUT'), findsOneWidget);
      expect(find.text('A short editorial biography.'), findsOneWidget);
      expect(find.text('BACKGROUND'), findsOneWidget);
      // Renders inside a Text.rich span alongside StarRow — see
      // private_chef_provenance_row_test.dart's own note on why
      // textContaining, not text, is the correct finder here.
      expect(find.textContaining('Parkheuvel'), findsOneWidget);
      expect(find.text('De Rooi Pannen'), findsOneWidget);
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

    testWidgets(
      'no restaurant history and no education -> no BACKGROUND section',
      (tester) async {
        final chef = PrivateChef(id: 'c1', slug: 'lucas', displayName: 'Lucas');
        await tester.pumpWidget(_shell(chef, const []));
        expect(find.text('BACKGROUND'), findsNothing);
      },
    );

    testWidgets(
      'the old "Restaurant Provenance" heading is never rendered anymore',
      (tester) async {
        await tester.pumpWidget(_shell(_fullChef, _history, _education));
        expect(find.text('RESTAURANT PROVENANCE'), findsNothing);
      },
    );

    testWidgets(
      'restaurant history alone (no education) still renders BACKGROUND',
      (tester) async {
        await tester.pumpWidget(_shell(_fullChef, _history, const []));
        expect(find.text('BACKGROUND'), findsOneWidget);
        expect(find.textContaining('Parkheuvel'), findsOneWidget);
        expect(find.text('De Rooi Pannen'), findsNothing);
      },
    );

    testWidgets(
      'education alone (no restaurant history) still renders BACKGROUND',
      (tester) async {
        await tester.pumpWidget(_shell(_fullChef, const [], _education));
        expect(find.text('BACKGROUND'), findsOneWidget);
        expect(find.text('De Rooi Pannen'), findsOneWidget);
        expect(find.textContaining('Parkheuvel'), findsNothing);
      },
    );

    testWidgets(
      'restaurant items render before education items within BACKGROUND, '
      'matching the approved worked example',
      (tester) async {
        await tester.pumpWidget(_shell(_fullChef, _history, _education));
        final restaurantY = tester
            .getTopLeft(find.textContaining('Parkheuvel'))
            .dy;
        final educationY = tester.getTopLeft(find.text('De Rooi Pannen')).dy;
        expect(restaurantY, lessThan(educationY));
      },
    );

    testWidgets('education row shows institution, program, and no period '
        'when none is known', (tester) async {
      await tester.pumpWidget(_shell(_fullChef, const [], _education));
      expect(find.text('De Rooi Pannen'), findsOneWidget);
      expect(find.text('Horeca Ondernemend Management'), findsOneWidget);
      expect(find.byIcon(Icons.arrow_forward_rounded), findsNothing);
    });

    testWidgets('no instagram/website -> no CONNECT section', (tester) async {
      final chef = PrivateChef(id: 'c1', slug: 'lucas', displayName: 'Lucas');
      await tester.pumpWidget(_shell(chef, const []));
      expect(find.text('CONNECT'), findsNothing);
    });

    testWidgets(
      'a 900-character biography (the hard product maximum) renders in '
      'full — no "Read more", no collapse, no ellipsis truncation',
      (tester) async {
        final longBiography = List.generate(
          900,
          (i) => 'abcdefghijklmnopqrstuvwxyz '[i % 27],
        ).join();
        expect(longBiography.length, 900);
        final chef = PrivateChef(
          id: 'c1',
          slug: 'lucas',
          displayName: 'Lucas',
          biography: longBiography,
        );
        await tester.pumpWidget(_shell(chef, const []));
        final aboutText = tester.widget<Text>(find.text(longBiography));
        expect(aboutText.maxLines, isNull);
        expect(aboutText.overflow, isNot(TextOverflow.ellipsis));
        expect(find.textContaining('Read more'), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('no score/rating/selected badge anywhere', (tester) async {
      await tester.pumpWidget(_shell(_fullChef, _history, _education));
      expect(find.textContaining('Mantelier Selected'), findsNothing);
      expect(find.textContaining('rating'), findsNothing);
    });

    testWidgets('Events V2 Step 6: no Follow control when onTapFollow is '
        'omitted (pre-Step-6 shape)', (tester) async {
      await tester.pumpWidget(_shell(_fullChef, _history, _education));
      expect(find.byType(FollowToggleButton), findsNothing);
    });

    testWidgets('Events V2 Step 6: Follow control renders in the hero and '
        'fires its own callback, independent of the rest of the shell', (
      tester,
    ) async {
      var tapped = false;
      await tester.pumpWidget(
        _shell(
          _fullChef,
          _history,
          _education,
          true,
          false,
          () => tapped = true,
        ),
      );
      expect(find.byType(FollowToggleButton), findsOneWidget);
      expect(find.byIcon(Icons.person_add_alt_1_rounded), findsOneWidget);
      await tester.tap(find.byType(FollowToggleButton));
      expect(tapped, isTrue);
    });

    testWidgets('no dead "Request an Experience" CTA', (tester) async {
      await tester.pumpWidget(_shell(_fullChef, _history, _education));
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
      await tester.pumpWidget(_shell(chef, _history, _education));
      expect(tester.takeException(), isNull);
      await tester.binding.setSurfaceSize(null);
    });

    testWidgets('390px width — no overflow', (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      await tester.pumpWidget(_shell(_fullChef, _history, _education));
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
                        child: _body(_fullChef, _history, _education),
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
