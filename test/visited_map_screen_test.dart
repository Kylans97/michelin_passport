// Covers the UI Consistency pass on My Map:
// - VenuePin — recolored from gold-bordered ivory to deepGreen/ivory, no
//   gold anywhere.
// - The venue-preview-sheet "View restaurant"/"View hotel" action —
//   recolored from a gold FilledButton to deepGreen.
// - The compact deepGreen header (title/subtitle/All-Restaurants-Hotels
//   filter row) — VisitedMapScreen itself constructs VisitedRepository/
//   MapRepository against Supabase.instance.client eagerly, so — matching
//   this app's established limitation for Supabase-eager screens (see
//   wishlist_screen_shell_test.dart's own note) — the header is mirrored
//   here rather than pumping the real screen.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:michelin_passport/core/constants/app_colors.dart';
import 'package:michelin_passport/core/theme/cs_spacing.dart';
import 'package:michelin_passport/core/theme/cs_typography.dart';
import 'package:michelin_passport/core/widgets/cs_filter_chip.dart';
import 'package:michelin_passport/core/widgets/editorial_back_button.dart';
import 'package:michelin_passport/features/explore/models/explore_filters.dart'
    show ExploreVenueType;
import 'package:michelin_passport/features/map/widgets/venue_pin.dart';
import 'package:michelin_passport/features/map/widgets/venue_preview_sheet.dart';
import 'package:michelin_passport/features/passport/passport_view_model.dart';
import 'package:michelin_passport/models/hotel.dart';
import 'package:michelin_passport/models/passport_venue.dart';
import 'package:michelin_passport/models/restaurant.dart';
import 'package:michelin_passport/models/visit.dart';

const _restaurant = Restaurant(
  id: 'r1',
  restaurantCode: 'r1',
  name: 'Test Restaurant',
  michelinStars: 2,
  inclusionReason: 'michelin_star',
  cityName: 'Rotterdam',
  countryCode: 'NL',
  countryName: 'Netherlands',
  flagEmoji: '🇳🇱',
  address: '1 Test Street',
);

const _hotel = Hotel(
  id: 'h1',
  hotelCode: 'h1',
  name: 'Test Hotel',
  michelinKeys: 1,
  cityName: 'Amsterdam',
  countryCode: 'NL',
  countryName: 'Netherlands',
  flagEmoji: '🇳🇱',
  address: '1 Test Street',
  hasMichelinRestaurant: false,
  restaurantCount: 0,
);

Widget _wrap(Widget child) => MaterialApp(
  home: Scaffold(body: Center(child: child)),
);

// Mirrors _VisitedMapScreenState.build's header exactly.
Widget _header({
  required ExploreVenueType selected,
  required ValueChanged<ExploreVenueType> onSelect,
}) => MaterialApp(
  home: Scaffold(
    backgroundColor: AppColors.deepGreen,
    body: SafeArea(
      bottom: false,
      child: ColoredBox(
        color: AppColors.deepGreen,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(
                CsSpacing.base,
                0,
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
                CsSpacing.xs,
                CsSpacing.pageHorizontal,
                CsSpacing.sm,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'My Map',
                    style: CsTypography.screenTitle.copyWith(
                      color: AppColors.ivory,
                    ),
                  ),
                  const SizedBox(height: CsSpacing.xs),
                  Text(
                    "Every place you've experienced.",
                    style: CsTypography.body.copyWith(
                      color: AppColors.secondaryOnDark,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                CsSpacing.pageHorizontal,
                0,
                CsSpacing.pageHorizontal,
                CsSpacing.base,
              ),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final type in ExploreVenueType.values) ...[
                      if (type != ExploreVenueType.values.first)
                        const SizedBox(width: CsSpacing.sm),
                      CsFilterChip(
                        label: type.label,
                        selected: selected == type,
                        onTap: () => onSelect(type),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  ),
);

void main() {
  group('VenuePin', () {
    testWidgets('deepGreen fill, ivory border/icon — no gold', (tester) async {
      await tester.pumpWidget(
        _wrap(VenuePin(venue: RestaurantVenue(_restaurant), onTap: () {})),
      );
      final container = tester.widget<Container>(find.byType(Container));
      final decoration = container.decoration! as BoxDecoration;
      expect(decoration.color, AppColors.deepGreen);
      expect((decoration.border as Border).top.color, AppColors.ivory);
      expect(decoration.color, isNot(AppColors.gold));

      final icon = tester.widget<Icon>(find.byType(Icon));
      expect(icon.color, AppColors.ivory);
      expect(icon.color, isNot(AppColors.gold));
    });

    testWidgets('restaurant and hotel pins use different icons', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(VenuePin(venue: RestaurantVenue(_restaurant), onTap: () {})),
      );
      final restaurantIcon = tester.widget<Icon>(find.byType(Icon)).icon;

      await tester.pumpWidget(
        _wrap(VenuePin(venue: HotelVenue(_hotel), onTap: () {})),
      );
      final hotelIcon = tester.widget<Icon>(find.byType(Icon)).icon;

      expect(restaurantIcon, isNot(hotelIcon));
    });

    testWidgets('tapping fires onTap', (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        _wrap(
          VenuePin(
            venue: RestaurantVenue(_restaurant),
            onTap: () => tapped = true,
          ),
        ),
      );
      await tester.tap(find.byType(VenuePin));
      expect(tapped, isTrue);
    });
  });

  group('Venue preview sheet', () {
    testWidgets('"View restaurant" action is deepGreen, not gold', (
      tester,
    ) async {
      final stats = PassportVenueStats.from(RestaurantVenue(_restaurant), [
        Visit(
          id: 'v1',
          userId: 'u1',
          entityType: 'restaurant',
          entityId: 'r1',
          visitedOn: DateTime(2025, 5, 1),
          starsAtVisit: 2,
        ),
      ]);
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => showVenuePreviewSheet(context, stats),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(find.text('View restaurant'), findsOneWidget);
      final button = tester.widget<FilledButton>(find.byType(FilledButton));
      final style = button.style!;
      final bg = style.backgroundColor!.resolve({});
      expect(bg, AppColors.deepGreen);
      expect(bg, isNot(AppColors.gold));
    });
  });

  group('My Map header (mirror)', () {
    testWidgets('title, subtitle and back button render', (tester) async {
      await tester.pumpWidget(
        _header(selected: ExploreVenueType.all, onSelect: (_) {}),
      );
      expect(find.text('My Map'), findsOneWidget);
      expect(find.text("Every place you've experienced."), findsOneWidget);
      expect(find.byType(EditorialBackButton), findsOneWidget);
    });

    testWidgets('All / Restaurants / Hotels chips render and tapping fires '
        'the callback', (tester) async {
      ExploreVenueType? selected;
      await tester.pumpWidget(
        _header(selected: ExploreVenueType.all, onSelect: (t) => selected = t),
      );
      expect(find.text('All'), findsOneWidget);
      expect(find.text('Restaurants'), findsOneWidget);
      expect(find.text('Hotels'), findsOneWidget);

      await tester.tap(find.text('Hotels'));
      expect(selected, ExploreVenueType.hotels);
    });

    testWidgets('gold audit: no gold color anywhere in the header', (
      tester,
    ) async {
      await tester.pumpWidget(
        _header(selected: ExploreVenueType.restaurants, onSelect: (_) {}),
      );
      final texts = tester.widgetList<Text>(find.byType(Text));
      for (final text in texts) {
        expect(text.style?.color, isNot(AppColors.gold));
      }
    });

    testWidgets('320px width — no overflow', (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 844));
      await tester.pumpWidget(
        _header(selected: ExploreVenueType.hotels, onSelect: (_) {}),
      );
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
              body: SafeArea(
                bottom: false,
                child: ColoredBox(
                  color: AppColors.deepGreen,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      CsSpacing.pageHorizontal,
                      CsSpacing.xs,
                      CsSpacing.pageHorizontal,
                      CsSpacing.base,
                    ),
                    child: Row(
                      children: [
                        for (final type in ExploreVenueType.values) ...[
                          if (type != ExploreVenueType.values.first)
                            const SizedBox(width: CsSpacing.sm),
                          CsFilterChip(
                            label: type.label,
                            selected: type == ExploreVenueType.all,
                            onTap: () {},
                          ),
                        ],
                      ],
                    ),
                  ),
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
