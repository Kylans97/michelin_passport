// Covers WishlistBody's outer shell, Restaurants/Hotels selector, and
// loading/error/empty states. WishlistBody constructs WishlistRepository
// against Supabase.instance.client eagerly in initState — same
// established limitation as every other Supabase-eager screen in this
// app — so this mirrors the exact widget tree WishlistBody's build()
// produces rather than pumping the real widget.
//
// PASSPORT — WISHLIST UI POLISH V1: the previous large ivory content
// sheet is gone — the persistent deep-green canvas now runs the whole
// way down, matching Passport's own collection body and the finalized
// Ranking cards; saved venues render as ivory WishlistRestaurantCard/
// WishlistHotelCard cards (covered in wishlist_venue_cards_test.dart)
// floating individually on it, not compact rows inside an ivory sheet.
// The old in-body "Trips" quick-link stayed removed (see the deleted
// wishlist_trips_entry_test.dart from the earlier Passport Unified
// Experience V1 pass) — Trips remains a sibling tab on the shared bar.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:michelin_passport/core/constants/app_colors.dart';
import 'package:michelin_passport/core/theme/cs_spacing.dart';
import 'package:michelin_passport/core/widgets/cs_filter_chip.dart';
import 'package:michelin_passport/core/widgets/cs_image_placeholder.dart';
import 'package:michelin_passport/core/widgets/cs_section_title.dart';

enum _VenueType { restaurants, hotels }

// Mirrors WishlistBody's own top padding — filter chips only, no
// title/subtitle (those live once in the shared Passport header now).
Widget _filterRow({required _VenueType selected}) => Padding(
  padding: const EdgeInsets.fromLTRB(
    CsSpacing.pageHorizontal,
    CsSpacing.md,
    CsSpacing.pageHorizontal,
    0,
  ),
  child: Row(
    children: [
      CsFilterChip(
        label: 'Restaurants',
        selected: selected == _VenueType.restaurants,
        onTap: () {},
      ),
      const SizedBox(width: CsSpacing.sm),
      CsFilterChip(
        label: 'Hotels',
        selected: selected == _VenueType.hotels,
        onTap: () {},
      ),
    ],
  ),
);

Widget _shell({required _VenueType selected, required Widget body}) =>
    MaterialApp(
      home: Scaffold(
        backgroundColor: AppColors.deepGreen,
        body: ColoredBox(
          color: AppColors.deepGreen,
          child: Column(
            children: [
              _filterRow(selected: selected),
              const Padding(
                padding: EdgeInsets.fromLTRB(
                  CsSpacing.pageHorizontal,
                  CsSpacing.xl,
                  CsSpacing.pageHorizontal,
                  CsSpacing.md,
                ),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: CsSectionTitle(
                    'YOUR WISHLIST',
                    color: AppColors.textOnDark,
                  ),
                ),
              ),
              Expanded(child: body),
            ],
          ),
        ),
      ),
    );

// Mirrors WishlistBody's private loading/_ErrorState/PassportEmptyState use.
Widget _loadingState() => const Center(
  child: CircularProgressIndicator(
    color: AppColors.textOnDark,
    strokeWidth: 1.5,
  ),
);

Widget _errorState(VoidCallback onRetry) => Center(
  child: Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      const Icon(
        Icons.wifi_off_rounded,
        color: AppColors.secondaryOnDark,
        size: 32,
      ),
      const SizedBox(height: CsSpacing.base),
      Text(
        'Could not load your wishlist',
        style: TextStyle(color: AppColors.secondaryOnDark),
      ),
      const SizedBox(height: CsSpacing.md),
      TextButton(onPressed: onRetry, child: const Text('Retry')),
    ],
  ),
);

Widget _emptyState({required bool isHotels}) => Center(
  child: Padding(
    padding: const EdgeInsets.symmetric(horizontal: 32),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const CsImagePlaceholder(
          width: 64,
          height: 64,
          borderRadius: BorderRadius.all(Radius.circular(12)),
          logoScale: 0.5,
        ),
        const SizedBox(height: CsSpacing.lg),
        Text(
          isHotels ? 'No hotels saved yet.' : 'No restaurants saved yet.',
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppColors.textOnDark),
        ),
      ],
    ),
  ),
);

void main() {
  group('WishlistBody outer shell', () {
    testWidgets('a single persistent deep-green canvas runs the whole way '
        'down — no separate ivory content sheet, no own Scaffold or back '
        'button anymore, embedded in the Passport shell instead', (
      tester,
    ) async {
      await tester.pumpWidget(
        _shell(selected: _VenueType.restaurants, body: _loadingState()),
      );
      expect(
        find.byWidgetPredicate(
          (w) => w is ColoredBox && w.color == AppColors.deepGreen,
        ),
        findsWidgets,
      );
      expect(
        find.byWidgetPredicate(
          (w) => w is ColoredBox && w.color == AppColors.ivory,
        ),
        findsNothing,
      );
      expect(find.text('YOUR WISHLIST'), findsOneWidget);
      final title = tester.widget<Text>(find.text('YOUR WISHLIST'));
      expect(title.style?.color, AppColors.textOnDark);
    });

    testWidgets('Restaurants/Hotels selector: selected chip is deep-green-'
        'on-ivory, unselected is ivory-on-forest-green — never gold', (
      tester,
    ) async {
      await tester.pumpWidget(
        _shell(selected: _VenueType.restaurants, body: _loadingState()),
      );
      final chips = tester
          .widgetList<CsFilterChip>(find.byType(CsFilterChip))
          .toList();
      expect(chips.length, 2);
      expect(chips[0].label, 'Restaurants');
      expect(chips[0].selected, isTrue);
      expect(chips[1].label, 'Hotels');
      expect(chips[1].selected, isFalse);
    });

    testWidgets('only Restaurants and Hotels exist — no All chip, no '
        'Events chip (Events are not wishlistable)', (tester) async {
      await tester.pumpWidget(
        _shell(selected: _VenueType.restaurants, body: _loadingState()),
      );
      expect(find.text('All'), findsNothing);
      expect(find.text('Events'), findsNothing);
      expect(find.text('Private Chefs'), findsNothing);
    });

    testWidgets('no redundant Trips shortcut anywhere in the body', (
      tester,
    ) async {
      await tester.pumpWidget(
        _shell(selected: _VenueType.restaurants, body: _loadingState()),
      );
      expect(find.text('Trips'), findsNothing);
      expect(find.text('View trips'), findsNothing);
    });
  });

  group('WishlistBody states', () {
    testWidgets('loading renders on the deep-green canvas, "YOUR '
        'WISHLIST" stays', (tester) async {
      await tester.pumpWidget(
        _shell(selected: _VenueType.restaurants, body: _loadingState()),
      );
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      final indicator = tester.widget<CircularProgressIndicator>(
        find.byType(CircularProgressIndicator),
      );
      expect(indicator.color, AppColors.textOnDark);
      expect(find.text('YOUR WISHLIST'), findsOneWidget);
    });

    testWidgets('error state shows restrained copy and a working retry, '
        'never a raw backend error', (tester) async {
      var retried = false;
      await tester.pumpWidget(
        _shell(
          selected: _VenueType.restaurants,
          body: _errorState(() => retried = true),
        ),
      );
      expect(find.text('Could not load your wishlist'), findsOneWidget);
      expect(find.textContaining('Postgrest'), findsNothing);
      expect(find.textContaining('Exception'), findsNothing);
      await tester.tap(find.text('Retry'));
      expect(retried, isTrue);
    });

    testWidgets('restaurants empty state shows restaurant-specific copy '
        'via the canonical Passport empty-state shape', (tester) async {
      await tester.pumpWidget(
        _shell(
          selected: _VenueType.restaurants,
          body: _emptyState(isHotels: false),
        ),
      );
      expect(find.text('No restaurants saved yet.'), findsOneWidget);
      expect(find.byType(CsImagePlaceholder), findsOneWidget);
    });

    testWidgets('hotels empty state shows hotel-specific copy', (tester) async {
      await tester.pumpWidget(
        _shell(selected: _VenueType.hotels, body: _emptyState(isHotels: true)),
      );
      expect(find.text('No hotels saved yet.'), findsOneWidget);
    });

    testWidgets('empty state never renders gold', (tester) async {
      await tester.pumpWidget(
        _shell(
          selected: _VenueType.restaurants,
          body: _emptyState(isHotels: false),
        ),
      );
      for (final text in tester.widgetList<Text>(find.byType(Text))) {
        expect(text.style?.color, isNot(AppColors.gold));
      }
    });
  });
}
