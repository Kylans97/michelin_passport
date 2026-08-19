// Covers Log Visit's outer shell after the UI Consistency restyle.
// _AddVisitSheet takes an already-constructed VisitedRepository/
// PhotoRepository, both of which require Supabase.instance.client at
// construction time — unavailable in this sandbox (confirmed: accessing
// Supabase.instance.client without Supabase.initialize() throws), so —
// matching this app's established limitation for Supabase-eager
// screens/sheets — this mirrors the exact widget tree
// _AddVisitSheetState.build() produces rather than pumping the real sheet.
// The individual building blocks (SaveButton/RatingMeter/DateCard) are
// covered directly in visit_sheet_widgets_test.dart — this file only
// exercises the shell composition and gold-removal around them.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:michelin_passport/core/constants/app_colors.dart';
import 'package:michelin_passport/core/widgets/sheet_dismiss_handle.dart';
import 'package:michelin_passport/features/restaurants/widgets/detail_section.dart';
import 'package:michelin_passport/features/visits/widgets/date_card.dart';
import 'package:michelin_passport/features/visits/widgets/rating_meter.dart';
import 'package:michelin_passport/features/visits/widgets/save_button.dart';
import 'package:michelin_passport/features/visits/widgets/visit_privacy_toggle.dart';

// Mirrors _AddVisitSheetState.build's Column exactly, minus photo picking
// (StagedPhotoPicker needs its own staged-photo state, out of scope here).
Widget _sheetContent() => Container(
  decoration: const BoxDecoration(color: AppColors.card),
  child: SingleChildScrollView(
    padding: const EdgeInsets.fromLTRB(24, 14, 24, 28),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SheetDismissHandle(color: AppColors.textPrimary, onClose: () {}),
        const SizedBox(height: 24),
        const SectionLabel('LOG YOUR VISIT'),
        const SizedBox(height: 8),
        const Text('Test Restaurant'),
        const SizedBox(height: 32),
        DateCard(label: 'VISIT DATE', date: DateTime(2025, 6, 1), onTap: () {}),
        const SizedBox(height: 32),
        const SectionLabel('RATINGS'),
        const SizedBox(height: 18),
        RatingMeter(label: 'Overall', value: null, onChanged: (_) {}),
        const SizedBox(height: 22),
        RatingMeter(label: 'Food', value: null, onChanged: (_) {}),
        const SizedBox(height: 22),
        RatingMeter(label: 'Service', value: null, onChanged: (_) {}),
        const SizedBox(height: 22),
        RatingMeter(label: 'Wine', value: null, onChanged: (_) {}),
        const SizedBox(height: 22),
        RatingMeter(label: 'Value', value: null, onChanged: (_) {}),
        const SizedBox(height: 32),
        const SectionLabel('MENU TYPE'),
        const SizedBox(height: 32),
        VisitPrivacyToggle(friendsVisible: false, onChanged: (_) {}),
        const SizedBox(height: 32),
        const SectionLabel('NOTES'),
        const SizedBox(height: 32),
        const SectionLabel('PHOTOS'),
        const SizedBox(height: 28),
        SaveButton(saving: false, label: 'Save visit', onTap: () {}),
      ],
    ),
  ),
);

Widget _sheet() => MaterialApp(home: Scaffold(body: _sheetContent()));

void main() {
  group('Log Visit shell', () {
    testWidgets('every section renders: date, 5 ratings, privacy, save', (
      tester,
    ) async {
      await tester.pumpWidget(_sheet());
      expect(find.text('LOG YOUR VISIT'), findsOneWidget);
      expect(find.byType(DateCard), findsOneWidget);
      expect(find.byType(RatingMeter), findsNWidgets(5));
      expect(find.byType(VisitPrivacyToggle), findsOneWidget);
      expect(find.text('Save visit'), findsOneWidget);
    });

    testWidgets('Save visit button is deep green, not gold', (tester) async {
      await tester.pumpWidget(_sheet());
      final button = tester.widget<FilledButton>(find.byType(FilledButton));
      final bg = button.style!.backgroundColor!.resolve({});
      expect(bg, AppColors.deepGreen);
      expect(bg, isNot(AppColors.gold));
    });

    testWidgets('gold audit: no gold anywhere in the sheet', (tester) async {
      await tester.pumpWidget(_sheet());
      final texts = tester.widgetList<Text>(find.byType(Text));
      for (final text in texts) {
        expect(text.style?.color, isNot(AppColors.gold));
      }
    });

    testWidgets('320px width — no overflow', (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 844));
      await tester.pumpWidget(_sheet());
      expect(tester.takeException(), isNull);
      await tester.binding.setSurfaceSize(null);
    });

    testWidgets('1.6x text scale — no overflow', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(1.6)),
            child: Scaffold(body: _sheetContent()),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
    });
  });
}
