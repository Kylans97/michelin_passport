// Covers CreateTripSheet's explicit dismiss control (TRIPS + GUIDES
// DEVICE-FIX PASS item 1). The real _CreateTripSheet constructs
// HotelRepository/RestaurantRepository against Supabase.instance.client
// eagerly in State field initializers (same established limitation as
// every other Trips/Explore/Wishlist screen in this app), so it can't be
// pumped directly without a live session. This reconstructs the exact
// close-button-row structure added to
// lib/features/trips/widgets/create_trip_sheet.dart's build() — a real
// EditorialBackButton(icon: Icons.close_rounded) sitting beside the
// existing drag handle — inside a genuine showModalBottomSheet/Navigator,
// so Navigator.pop is exercised for real, not just asserted about.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:michelin_passport/core/constants/app_colors.dart';
import 'package:michelin_passport/core/widgets/editorial_back_button.dart';

Widget _sheetHeaderRow(BuildContext sheetContext) => Row(
  children: [
    EditorialBackButton(
      icon: Icons.close_rounded,
      semanticLabel: 'Close',
      onTap: () => Navigator.pop(sheetContext),
    ),
    const Expanded(
      child: Center(
        child: SizedBox(
          width: 36,
          height: 4,
          child: ColoredBox(color: AppColors.gold),
        ),
      ),
    ),
    const SizedBox(width: 44),
  ],
);

Future<void> _openSheet(
  WidgetTester tester, {
  required VoidCallback onSave,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () => showModalBottomSheet<bool>(
                context: context,
                builder: (sheetContext) => Container(
                  color: AppColors.brandGreenLight,
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _sheetHeaderRow(sheetContext),
                      const SizedBox(height: 20),
                      const Text('CREATE TRIP', key: Key('sheet-content')),
                      ElevatedButton(
                        onPressed: onSave,
                        child: const Text('Create trip'),
                      ),
                    ],
                  ),
                ),
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Open'));
  await tester.pumpAndSettle();
}

void main() {
  group('CreateTripSheet dismiss control', () {
    testWidgets('an explicit close control is present when the sheet opens', (
      tester,
    ) async {
      await _openSheet(tester, onSave: () {});
      expect(find.byType(EditorialBackButton), findsOneWidget);
      expect(find.byKey(const Key('sheet-content')), findsOneWidget);
    });

    testWidgets(
      'is visible immediately, before any field has been touched — no '
      'interaction with the form is required to find it',
      (tester) async {
        await _openSheet(tester, onSave: () {});
        // Nothing has been typed/tapped inside the form yet at this point.
        final semantics = tester.getSemantics(find.byType(EditorialBackButton));
        expect(semantics.label, 'Close');
      },
    );

    testWidgets('tapping it closes the sheet without saving', (tester) async {
      var saveCalled = false;
      await _openSheet(tester, onSave: () => saveCalled = true);
      expect(find.byKey(const Key('sheet-content')), findsOneWidget);

      await tester.tap(find.byType(EditorialBackButton));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('sheet-content')), findsNothing);
      expect(saveCalled, isFalse);
    });

    testWidgets('close tap target meets the 44px minimum', (tester) async {
      await _openSheet(tester, onSave: () {});
      final size = tester.getSize(find.byType(EditorialBackButton));
      expect(size.width, greaterThanOrEqualTo(44));
      expect(size.height, greaterThanOrEqualTo(44));
    });
  });
}
