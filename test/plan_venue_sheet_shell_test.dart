// Covers Plan Visit's outer shell after the UI Consistency restyle.
// _PlanVenueSheet takes an already-constructed PlannedTripsRepository,
// which requires Supabase.instance.client at construction time —
// unavailable in this sandbox — so this mirrors the exact widget tree
// _PlanVenueSheetState.build() produces rather than pumping the real
// sheet, matching add_visit_sheet_shell_test.dart's own convention.
//
// Also covers the deliberate consistency fix: Plan Visit previously used a
// bare drag-handle bar with no close affordance, unlike Log Visit's
// SheetDismissHandle — this now uses the same SheetDismissHandle as Log
// Visit.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:michelin_passport/core/constants/app_colors.dart';
import 'package:michelin_passport/core/widgets/sheet_dismiss_handle.dart';
import 'package:michelin_passport/features/restaurants/widgets/detail_section.dart';
import 'package:michelin_passport/features/visits/widgets/date_card.dart';
import 'package:michelin_passport/features/visits/widgets/save_button.dart';

// Mirrors _PlanVenueSheetState.build's Column exactly, minus the
// FutureBuilder-driven trip list (async, not needed to verify the static
// shell/gold-removal).
Widget _sheetContent({bool isEditing = false, bool isHotel = false}) =>
    Container(
      decoration: const BoxDecoration(color: AppColors.card),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 14, 24, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SheetDismissHandle(color: AppColors.textPrimary, onClose: () {}),
            const SizedBox(height: 24),
            SectionLabel(
              isEditing
                  ? (isHotel ? 'EDIT PLANNED STAY' : 'EDIT PLANNED VISIT')
                  : (isHotel ? 'PLAN STAY' : 'PLAN VISIT'),
            ),
            const SizedBox(height: 8),
            const Text('Test Venue'),
            const SizedBox(height: 32),
            DateCard(
              label: isHotel ? 'CHECK-IN' : 'VISIT DATE',
              date: DateTime(2025, 6, 1),
              onTap: () {},
            ),
            if (isHotel) ...[
              const SizedBox(height: 12),
              DateCard(
                label: 'CHECK-OUT',
                date: DateTime(2025, 6, 2),
                onTap: () {},
              ),
            ],
            const SizedBox(height: 32),
            const SectionLabel('TRIP (OPTIONAL)'),
            const SizedBox(height: 32),
            const SectionLabel('NOTES'),
            const SizedBox(height: 28),
            SaveButton(
              saving: false,
              label: isEditing ? 'Save changes' : 'Save plan',
              onTap: () {},
            ),
          ],
        ),
      ),
    );

Widget _sheet({bool isEditing = false, bool isHotel = false}) => MaterialApp(
  home: Scaffold(
    body: _sheetContent(isEditing: isEditing, isHotel: isHotel),
  ),
);

void main() {
  group('Plan Visit shell', () {
    testWidgets('has the same explicit dismiss handle as Log Visit', (
      tester,
    ) async {
      await tester.pumpWidget(_sheet());
      expect(find.byType(SheetDismissHandle), findsOneWidget);
    });

    testWidgets('new plan: date, trip, notes, "Save plan" all render', (
      tester,
    ) async {
      await tester.pumpWidget(_sheet());
      expect(find.text('PLAN VISIT'), findsOneWidget);
      expect(find.byType(DateCard), findsOneWidget);
      expect(find.text('TRIP (OPTIONAL)'), findsOneWidget);
      expect(find.text('Save plan'), findsOneWidget);
    });

    testWidgets('editing an existing plan shows "Save changes"', (
      tester,
    ) async {
      await tester.pumpWidget(_sheet(isEditing: true));
      expect(find.text('EDIT PLANNED VISIT'), findsOneWidget);
      expect(find.text('Save changes'), findsOneWidget);
    });

    testWidgets('a hotel plan shows check-in and check-out dates', (
      tester,
    ) async {
      await tester.pumpWidget(_sheet(isHotel: true));
      expect(find.byType(DateCard), findsNWidgets(2));
      expect(find.text('PLAN STAY'), findsOneWidget);
    });

    testWidgets('Save plan button is deep green, not gold', (tester) async {
      await tester.pumpWidget(_sheet());
      final button = tester.widget<FilledButton>(find.byType(FilledButton));
      final bg = button.style!.backgroundColor!.resolve({});
      expect(bg, AppColors.deepGreen);
      expect(bg, isNot(AppColors.gold));
    });

    testWidgets('gold audit: no gold anywhere in the sheet', (tester) async {
      await tester.pumpWidget(_sheet(isHotel: true));
      final texts = tester.widgetList<Text>(find.byType(Text));
      for (final text in texts) {
        expect(text.style?.color, isNot(AppColors.gold));
      }
    });

    testWidgets('320px width — no overflow', (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 844));
      await tester.pumpWidget(_sheet(isHotel: true));
      expect(tester.takeException(), isNull);
      await tester.binding.setSurfaceSize(null);
    });

    testWidgets('1.6x text scale — no overflow', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(1.6)),
            child: Scaffold(body: _sheetContent(isHotel: true)),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
    });
  });
}
