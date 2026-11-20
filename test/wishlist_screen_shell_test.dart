// Covers WishlistBody's outer shell, Restaurants/Hotels/Events selector,
// and loading/error/empty states. WishlistBody constructs WishlistRepository
// against Supabase.instance.client eagerly in initState — same
// established limitation as every other Supabase-eager screen in this
// app — so this mirrors the exact widget tree WishlistBody's build()
// produces rather than pumping the real widget. [WishlistView] itself
// has no Supabase dependency, so it (and the real EventWishlistCard/
// EventWishlistEmptyState widgets) are used directly here rather than
// re-mirrored.
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
//
// "Wishlist, calmer" (2026-11-20): the chip row and the "YOUR WISHLIST"
// title gave way to one selector line, WishlistViewSelector, with the +
// beside it; the selector's rows and the by-place view are covered in
// wishlist_view_model_test.dart.
//
// EVENT WISHLIST V1 adds the third Events tab — see event_wishlist_card_
// test.dart/event_wishlist_empty_state_test.dart for that tab's own
// content widgets' direct coverage, and event_wishlist_schedule_test.dart
// for the Upcoming/Past date classification this shell's own UPCOMING/PAST
// section headers are driven by.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:michelin_passport/core/constants/app_colors.dart';
import 'package:michelin_passport/core/theme/cs_spacing.dart';
import 'package:michelin_passport/core/theme/cs_typography.dart';
import 'package:michelin_passport/core/widgets/cs_image_placeholder.dart';
import 'package:michelin_passport/features/wishlist/widgets/event_wishlist_card.dart';
import 'package:michelin_passport/features/wishlist/widgets/event_wishlist_empty_state.dart';
import 'package:michelin_passport/features/wishlist/widgets/wishlist_view_selector.dart';
import 'package:michelin_passport/features/wishlist/wishlist_view_model.dart';
import 'package:michelin_passport/models/event.dart';

// Mirrors WishlistBody's own top row — the selector line and the +, no
// title/subtitle (those live once in the shared Passport header).
Widget _filterRow({required WishlistView selected}) => Padding(
  padding: const EdgeInsets.fromLTRB(
    CsSpacing.pageHorizontal,
    CsSpacing.xs,
    CsSpacing.pageHorizontal - CsSpacing.sm,
    CsSpacing.md,
  ),
  child: Row(
    children: [
      Expanded(
        child: Align(
          alignment: Alignment.centerLeft,
          child: WishlistViewSelector(view: selected, count: 3, onTap: () {}),
        ),
      ),
      IconButton(
        onPressed: () {},
        icon: const Icon(Icons.add_rounded, size: 26),
        color: AppColors.textOnDark,
        tooltip: 'Add to wishlist',
      ),
    ],
  ),
);

Widget _shell({required WishlistView selected, required Widget body}) =>
    MaterialApp(
      home: Scaffold(
        backgroundColor: AppColors.deepGreen,
        body: ColoredBox(
          color: AppColors.deepGreen,
          child: Column(
            children: [
              _filterRow(selected: selected),
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

// Mirrors WishlistBody's private _eventSectionHeader exactly.
Widget _eventSectionHeader(String label) => Padding(
  padding: const EdgeInsets.fromLTRB(
    CsSpacing.pageHorizontal,
    CsSpacing.md,
    CsSpacing.pageHorizontal,
    CsSpacing.sm,
  ),
  child: Text(
    label,
    style: CsTypography.eyebrow.copyWith(color: AppColors.secondaryOnDark),
  ),
);

Event _event({String id = 'e1', String name = "'t Preuvenemint"}) => Event(
  id: id,
  name: name,
  startDate: DateTime.utc(2026, 9, 1),
  endDate: DateTime.utc(2026, 9, 1),
  timezone: 'UTC',
  countryCode: 'NL',
  city: 'Maastricht',
  eventType: EventType.festival,
  createdAt: DateTime.utc(2026, 1, 1),
);

void main() {
  group('WishlistBody outer shell', () {
    testWidgets('a single persistent deep-green canvas runs the whole way '
        'down — no separate ivory content sheet, no own Scaffold or back '
        'button anymore, embedded in the Passport shell instead', (
      tester,
    ) async {
      await tester.pumpWidget(
        _shell(
          selected: WishlistView.restaurants,
          body: _loadingState(),
        ),
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
      // The large title is gone: the Wishlist tab already says where you
      // are (product owner, 2026-11-20).
      expect(find.text('YOUR WISHLIST'), findsNothing);
      final label = tester.widget<Text>(find.text('Restaurants'));
      expect(label.style?.color, AppColors.textOnDark);
    });

    testWidgets('one selector line instead of a chip row: the current '
        'view, its count, and an Add button beside it', (tester) async {
      await tester.pumpWidget(
        _shell(selected: WishlistView.restaurants, body: _loadingState()),
      );
      expect(find.byType(WishlistViewSelector), findsOneWidget);
      expect(find.text('Restaurants'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
      expect(find.byTooltip('Add to wishlist'), findsOneWidget);
      expect(find.text('Hotels'), findsNothing);
    });

    testWidgets('the selector names Events when Events is showing', (
      tester,
    ) async {
      await tester.pumpWidget(
        _shell(selected: WishlistView.events, body: _loadingState()),
      );
      expect(find.text('Events'), findsOneWidget);
    });

    testWidgets('no redundant Trips shortcut anywhere in the body', (
      tester,
    ) async {
      await tester.pumpWidget(
        _shell(
          selected: WishlistView.restaurants,
          body: _loadingState(),
        ),
      );
      expect(find.text('Trips'), findsNothing);
      expect(find.text('View trips'), findsNothing);
    });
  });

  group('WishlistBody states — Restaurants/Hotels', () {
    testWidgets('loading renders on the deep-green canvas, the selector '
        'line stays', (tester) async {
      await tester.pumpWidget(
        _shell(
          selected: WishlistView.restaurants,
          body: _loadingState(),
        ),
      );
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      final indicator = tester.widget<CircularProgressIndicator>(
        find.byType(CircularProgressIndicator),
      );
      expect(indicator.color, AppColors.textOnDark);
      expect(find.byType(WishlistViewSelector), findsOneWidget);
    });

    testWidgets('error state shows restrained copy and a working retry, '
        'never a raw backend error', (tester) async {
      var retried = false;
      await tester.pumpWidget(
        _shell(
          selected: WishlistView.restaurants,
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
          selected: WishlistView.restaurants,
          body: _emptyState(isHotels: false),
        ),
      );
      expect(find.text('No restaurants saved yet.'), findsOneWidget);
      expect(find.byType(CsImagePlaceholder), findsOneWidget);
    });

    testWidgets('hotels empty state shows hotel-specific copy', (tester) async {
      await tester.pumpWidget(
        _shell(
          selected: WishlistView.hotels,
          body: _emptyState(isHotels: true),
        ),
      );
      expect(find.text('No hotels saved yet.'), findsOneWidget);
    });

    testWidgets('empty state never renders gold', (tester) async {
      await tester.pumpWidget(
        _shell(
          selected: WishlistView.restaurants,
          body: _emptyState(isHotels: false),
        ),
      );
      for (final text in tester.widgetList<Text>(find.byType(Text))) {
        expect(text.style?.color, isNot(AppColors.gold));
      }
    });
  });

  group('WishlistBody states — Events (EVENT WISHLIST V1)', () {
    testWidgets('zero saved events shows the dedicated Events empty state, '
        'the tab itself stays visible/selectable', (tester) async {
      await tester.pumpWidget(
        _shell(
          selected: WishlistView.events,
          body: const EventWishlistEmptyState(),
        ),
      );
      expect(find.text('Events'), findsOneWidget);
      expect(find.text('No saved events yet.'), findsOneWidget);
    });

    testWidgets('a saved event renders under an UPCOMING header', (
      tester,
    ) async {
      await tester.pumpWidget(
        _shell(
          selected: WishlistView.events,
          body: Column(
            children: [
              _eventSectionHeader('UPCOMING'),
              EventWishlistCard(event: _event(), onRemove: () {}),
            ],
          ),
        ),
      );
      expect(find.text('UPCOMING'), findsOneWidget);
      expect(find.text('PAST'), findsNothing);
      expect(find.text("'t Preuvenemint"), findsOneWidget);
    });

    testWidgets('multiple saved events all render', (tester) async {
      await tester.pumpWidget(
        _shell(
          selected: WishlistView.events,
          body: Column(
            children: [
              _eventSectionHeader('UPCOMING'),
              EventWishlistCard(
                event: _event(id: 'e1', name: 'Festival One'),
                onRemove: () {},
              ),
              EventWishlistCard(
                event: _event(id: 'e2', name: 'Festival Two'),
                onRemove: () {},
              ),
            ],
          ),
        ),
      );
      expect(find.text('Festival One'), findsOneWidget);
      expect(find.text('Festival Two'), findsOneWidget);
    });

    testWidgets('PAST only appears alongside UPCOMING when both exist — '
        'a past saved event stays reachable', (tester) async {
      await tester.pumpWidget(
        _shell(
          selected: WishlistView.events,
          body: Column(
            children: [
              _eventSectionHeader('UPCOMING'),
              EventWishlistCard(
                event: _event(id: 'upcoming', name: 'Future Gala'),
                onRemove: () {},
              ),
              _eventSectionHeader('PAST'),
              EventWishlistCard(
                event: _event(id: 'past', name: 'Old Dinner'),
                onRemove: () {},
              ),
            ],
          ),
        ),
      );
      expect(find.text('UPCOMING'), findsOneWidget);
      expect(find.text('PAST'), findsOneWidget);
      expect(find.text('Future Gala'), findsOneWidget);
      expect(find.text('Old Dinner'), findsOneWidget);
    });

    testWidgets('PAST header is absent when there are no past saved '
        'events', (tester) async {
      await tester.pumpWidget(
        _shell(
          selected: WishlistView.events,
          body: Column(
            children: [
              _eventSectionHeader('UPCOMING'),
              EventWishlistCard(event: _event(), onRemove: () {}),
            ],
          ),
        ),
      );
      expect(find.text('PAST'), findsNothing);
    });
  });
}
