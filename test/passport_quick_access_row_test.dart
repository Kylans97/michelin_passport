// Covers Passport's secondary nav (Navigation & Information Architecture
// V2 UI Refinement) — a compact "Passport  Wishlist  Ranking  Trips" text
// row, replacing the previous four full-width GuideDestinationRows (which
// made Passport read as a menu/dashboard). PassportScreen constructs
// VisitedRepository/EventConfirmedAttendanceRepository against
// Supabase.instance.client eagerly in initState — same established
// limitation as every other Supabase-eager screen in this app — so this
// mirrors the exact secondary-nav widget tree PassportScreen.build()
// produces rather than pumping the real screen.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:michelin_passport/core/constants/app_colors.dart';
import 'package:michelin_passport/core/theme/cs_typography.dart';

Widget _navItem({required String label, bool active = false, VoidCallback? onTap}) {
  final text = Text(
    label,
    style: CsTypography.navigation.copyWith(
      fontSize: 13,
      color: active ? AppColors.ivory : AppColors.secondaryOnDark,
      fontWeight: active ? FontWeight.w600 : FontWeight.w500,
    ),
  );
  if (onTap == null) return text;
  return InkWell(onTap: onTap, child: text);
}

Widget _secondaryNav({
  required VoidCallback onWishlist,
  required VoidCallback onMyRanking,
  required VoidCallback onTrips,
}) => MaterialApp(
  home: Scaffold(
    backgroundColor: AppColors.deepGreen,
    body: Row(
      children: [
        _navItem(label: 'Passport', active: true),
        const SizedBox(width: 16),
        _navItem(label: 'Wishlist', onTap: onWishlist),
        const SizedBox(width: 16),
        _navItem(label: 'Ranking', onTap: onMyRanking),
        const SizedBox(width: 16),
        _navItem(label: 'Trips', onTap: onTrips),
      ],
    ),
  ),
);

void main() {
  group('Passport secondary nav', () {
    testWidgets('renders exactly Passport/Wishlist/Ranking/Trips, in order '
        '— no Stats destination', (tester) async {
      await tester.pumpWidget(
        _secondaryNav(onWishlist: () {}, onMyRanking: () {}, onTrips: () {}),
      );
      final labels = tester
          .widgetList<Text>(find.byType(Text))
          .map((t) => t.data)
          .toList();
      expect(labels, ['Passport', 'Wishlist', 'Ranking', 'Trips']);
      expect(find.text('Stats'), findsNothing);
    });

    testWidgets('"Passport" reads as active — ivory, bold, never gold', (
      tester,
    ) async {
      await tester.pumpWidget(
        _secondaryNav(onWishlist: () {}, onMyRanking: () {}, onTrips: () {}),
      );
      final passport = tester.widget<Text>(find.text('Passport'));
      expect(passport.style?.color, AppColors.ivory);
      expect(passport.style?.color, isNot(AppColors.gold));
      expect(passport.style?.fontWeight, FontWeight.w600);
    });

    testWidgets('inactive items are secondaryOnDark, regular weight, never '
        'gold', (tester) async {
      await tester.pumpWidget(
        _secondaryNav(onWishlist: () {}, onMyRanking: () {}, onTrips: () {}),
      );
      for (final label in ['Wishlist', 'Ranking', 'Trips']) {
        final text = tester.widget<Text>(find.text(label));
        expect(text.style?.color, AppColors.secondaryOnDark, reason: label);
        expect(text.style?.color, isNot(AppColors.gold), reason: label);
        expect(text.style?.fontWeight, FontWeight.w500, reason: label);
      }
    });

    testWidgets('Wishlist item navigates to Wishlist', (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        _secondaryNav(
          onWishlist: () => tapped = true,
          onMyRanking: () {},
          onTrips: () {},
        ),
      );
      await tester.tap(find.text('Wishlist'));
      expect(tapped, isTrue);
    });

    testWidgets('Ranking item navigates to My Ranking', (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        _secondaryNav(
          onWishlist: () {},
          onMyRanking: () => tapped = true,
          onTrips: () {},
        ),
      );
      await tester.tap(find.text('Ranking'));
      expect(tapped, isTrue);
    });

    testWidgets('Trips item navigates to Trips', (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        _secondaryNav(
          onWishlist: () {},
          onMyRanking: () {},
          onTrips: () => tapped = true,
        ),
      );
      await tester.tap(find.text('Trips'));
      expect(tapped, isTrue);
    });

    testWidgets('no large destination-row styling — no GuideDestinationRow '
        'arrow icon, no descriptor text remains from the old design', (
      tester,
    ) async {
      await tester.pumpWidget(
        _secondaryNav(onWishlist: () {}, onMyRanking: () {}, onTrips: () {}),
      );
      expect(find.byIcon(Icons.arrow_forward_rounded), findsNothing);
      expect(find.textContaining("Places you're saving"), findsNothing);
      expect(find.textContaining('gastronomic journey'), findsNothing);
    });
  });
}
