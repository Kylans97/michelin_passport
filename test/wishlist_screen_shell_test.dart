// Covers WishlistBody's outer shell, Restaurants/Hotels selector, and
// loading/error/empty states. WishlistBody constructs WishlistRepository
// against Supabase.instance.client eagerly in initState — same
// established limitation as every other Supabase-eager screen in this
// app — so this mirrors the exact widget tree WishlistBody's build()
// produces rather than pumping the real widget.
//
// Passport Unified Experience V1: WishlistBody is no longer a pushed
// screen with its own Scaffold/back button/title — it's one of
// PassportScreen's four local subsections, embedded directly beneath the
// shared Passport header + local tab bar (see passport_unified_shell_test
// .dart for that persistent-shell behavior). This mirror now reflects
// just WishlistBody's own content: a dark top zone (the Restaurants/
// Hotels selector, no title/subtitle of its own) over an ivory body
// headed "YOUR WISHLIST". The old in-body "Trips" quick-link is gone —
// Trips is a sibling tab one tap away on the shared bar now, so the
// shortcut was redundant (see the deleted wishlist_trips_entry_test.dart).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:michelin_passport/core/constants/app_colors.dart';
import 'package:michelin_passport/core/theme/cs_spacing.dart';
import 'package:michelin_passport/core/theme/cs_typography.dart';
import 'package:michelin_passport/core/widgets/cs_filter_chip.dart';
import 'package:michelin_passport/core/widgets/cs_image_placeholder.dart';
import 'package:michelin_passport/core/widgets/cs_section_title.dart';
import 'package:michelin_passport/features/wishlist/widgets/wishlist_venue_row.dart';

enum _VenueType { restaurants, hotels }

// Mirrors WishlistBody's own top padding — filter chips only, no
// title/subtitle (those live once in the shared Passport header now).
Widget _filterRow({required _VenueType selected}) => Padding(
  padding: const EdgeInsets.fromLTRB(
    CsSpacing.pageHorizontal,
    CsSpacing.md,
    CsSpacing.pageHorizontal,
    CsSpacing.lg,
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
              Expanded(
                child: ColoredBox(
                  color: AppColors.ivory,
                  child: Column(
                    children: [
                      const Padding(
                        padding: EdgeInsets.fromLTRB(
                          CsSpacing.pageHorizontal,
                          CsSpacing.lg,
                          CsSpacing.pageHorizontal,
                          CsSpacing.md,
                        ),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: CsSectionTitle(
                            'YOUR WISHLIST',
                            color: AppColors.forestGreen,
                          ),
                        ),
                      ),
                      Expanded(child: body),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

// Mirrors WishlistBody's private _LoadingState/_ErrorState/_EmptyState.
Widget _loadingState() => const Center(
  child: CircularProgressIndicator(
    color: AppColors.forestGreen,
    strokeWidth: 1.5,
  ),
);

Widget _errorState(VoidCallback onRetry) => Center(
  child: Padding(
    padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 56),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.wifi_off_rounded, color: AppColors.taupe, size: 32),
        const SizedBox(height: CsSpacing.base),
        Text(
          'Could not load your wishlist',
          textAlign: TextAlign.center,
          style: CsTypography.body.copyWith(color: AppColors.taupe),
        ),
        const SizedBox(height: CsSpacing.md),
        TextButton(
          onPressed: onRetry,
          child: Text(
            'Retry',
            style: CsTypography.bodyMedium.copyWith(
              color: AppColors.forestGreen,
            ),
          ),
        ),
      ],
    ),
  ),
);

Widget _emptyState({required bool isHotels}) => Center(
  child: Padding(
    padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 56),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const CsImagePlaceholder(
          width: 56,
          height: 56,
          borderRadius: BorderRadius.all(Radius.circular(14)),
          logoScale: 0.5,
        ),
        const SizedBox(height: CsSpacing.lg),
        Text(
          isHotels ? 'No hotels saved yet' : 'No restaurants saved yet',
          textAlign: TextAlign.center,
          style: CsTypography.placeTitle.copyWith(color: AppColors.forestGreen),
        ),
        const SizedBox(height: CsSpacing.xs),
        Text(
          isHotels
              ? "Save hotels you'd like to stay at and they'll appear here."
              : "Save restaurants you'd like to experience and they'll "
                    'appear here.',
          textAlign: TextAlign.center,
          style: CsTypography.metadata.copyWith(color: AppColors.taupe),
        ),
      ],
    ),
  ),
);

void main() {
  group('WishlistBody outer shell', () {
    testWidgets('a dark top zone with an explicit ivory ColoredBox body — '
        'no own Scaffold or back button anymore, embedded in the Passport '
        'shell instead', (tester) async {
      await tester.pumpWidget(
        _shell(selected: _VenueType.restaurants, body: _loadingState()),
      );
      expect(
        find.byWidgetPredicate(
          (w) => w is ColoredBox && w.color == AppColors.deepGreen,
        ),
        findsOneWidget,
      );
      expect(
        find.byWidgetPredicate(
          (w) => w is ColoredBox && w.color == AppColors.ivory,
        ),
        findsOneWidget,
      );
      expect(find.text('YOUR WISHLIST'), findsOneWidget);
    });

    testWidgets('Restaurants/Hotels selector: selected chip is ivory-on-'
        'green, unselected is forest-green-on-green — never gold', (
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

    testWidgets('only Restaurants and Hotels exist — no All chip', (
      tester,
    ) async {
      await tester.pumpWidget(
        _shell(selected: _VenueType.restaurants, body: _loadingState()),
      );
      expect(find.text('All'), findsNothing);
      expect(find.text('Events'), findsNothing);
      expect(find.text('Private Chefs'), findsNothing);
    });
  });

  group('WishlistBody states', () {
    testWidgets('loading renders within the ivory body, "YOUR WISHLIST" '
        'stays', (tester) async {
      await tester.pumpWidget(
        _shell(selected: _VenueType.restaurants, body: _loadingState()),
      );
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      final indicator = tester.widget<CircularProgressIndicator>(
        find.byType(CircularProgressIndicator),
      );
      expect(indicator.color, AppColors.forestGreen);
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

    testWidgets('restaurants empty state shows restaurant-specific copy', (
      tester,
    ) async {
      await tester.pumpWidget(
        _shell(
          selected: _VenueType.restaurants,
          body: _emptyState(isHotels: false),
        ),
      );
      expect(find.text('No restaurants saved yet'), findsOneWidget);
      expect(
        find.textContaining("Save restaurants you'd like to experience"),
        findsOneWidget,
      );
    });

    testWidgets('hotels empty state shows hotel-specific copy', (tester) async {
      await tester.pumpWidget(
        _shell(selected: _VenueType.hotels, body: _emptyState(isHotels: true)),
      );
      expect(find.text('No hotels saved yet'), findsOneWidget);
      expect(
        find.textContaining("Save hotels you'd like to stay at"),
        findsOneWidget,
      );
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

  group('WishlistRowDivider — N-1 separators, no orphan trailing hairline', () {
    Widget list(int itemCount) => MaterialApp(
      home: Scaffold(
        backgroundColor: AppColors.ivory,
        body: ListView.builder(
          itemCount: itemCount,
          itemBuilder: (context, i) => Column(
            children: [
              if (i > 0) const WishlistRowDivider(),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );

    testWidgets('1 row renders zero dividers', (tester) async {
      await tester.pumpWidget(list(1));
      expect(find.byType(WishlistRowDivider), findsNothing);
    });

    testWidgets('3 rows render exactly 2 dividers', (tester) async {
      await tester.pumpWidget(list(3));
      expect(find.byType(WishlistRowDivider), findsNWidgets(2));
    });

    testWidgets('the divider color is a restrained taupe, never gold or '
        'forest-green', (tester) async {
      await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: WishlistRowDivider())),
      );
      final divider = tester.widget<Container>(find.byType(Container));
      final decoration = divider.color;
      expect(decoration, AppColors.taupe.withValues(alpha: 0.55));
      expect(decoration, isNot(AppColors.gold));
      expect(decoration, isNot(AppColors.forestGreen));
    });
  });
}
