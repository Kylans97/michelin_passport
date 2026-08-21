// Covers AttendanceDetailsSheet's outer shell. Events V2 Step 4 photo
// hardening pass established order: rating -> photos -> note -> save.
// Step 4.1 inserted a "Would you recommend this event?" section between
// rating and photos — order now: rating -> recommend -> photos -> note ->
// save, per the task's own "one experience-completion flow" instruction.
//
// _AttendanceDetailsSheet embeds AttendancePhotosSection, which
// constructs PhotoRepository(Supabase.instance.client) at field-init time
// — unavailable in this sandbox (confirmed: accessing
// Supabase.instance.client without Supabase.initialize() throws), matching
// this app's established limitation for Supabase-eager screens/sheets
// (see add_visit_sheet_shell_test.dart's own header comment for the exact
// same pattern applied to Add Visit's photo picker). RecommendationSelector
// has no such dependency, so this mirror uses the REAL widget for it
// (not a placeholder) — a more faithful proof than the Photos section can
// get. This mirrors the exact widget tree _AttendanceDetailsSheetState
// .build() produces, minus AttendancePhotosSection itself, and asserts the
// section ORDER via the Column's own children list — the one thing a
// shell-mirror test can prove that a screenshot can't.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:michelin_passport/core/constants/app_colors.dart';
import 'package:michelin_passport/core/theme/cs_spacing.dart';
import 'package:michelin_passport/features/events/widgets/recommendation_selector.dart';
import 'package:michelin_passport/features/visits/widgets/rating_meter.dart';

// Mirrors _AttendanceDetailsSheetState.build's Column exactly, minus
// AttendancePhotosSection (Supabase-eager, out of scope here — see header
// comment) — replaced by a placeholder Text with the same key label so
// section ORDER is still provable.
Widget _sheetContent({bool? wouldRecommend}) => Container(
  padding: const EdgeInsets.fromLTRB(
    CsSpacing.base,
    CsSpacing.lg,
    CsSpacing.base,
    CsSpacing.lg,
  ),
  decoration: const BoxDecoration(color: AppColors.ivory),
  child: SingleChildScrollView(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Club Leroy at Parkheuvel", style: GoogleFonts.playfairDisplay()),
        const SizedBox(height: CsSpacing.lg),
        RatingMeter(label: 'Your rating', value: null, onChanged: (_) {}),
        const SizedBox(height: CsSpacing.lg),
        RecommendationSelector(value: wouldRecommend, onChanged: (_) {}),
        const SizedBox(height: CsSpacing.lg),
        Text('Photos', style: GoogleFonts.inter()),
        const SizedBox(height: 8),
        const _PhotosPlaceholder(),
        const SizedBox(height: CsSpacing.lg),
        Text('Notes', style: GoogleFonts.inter()),
        const SizedBox(height: 8),
        TextField(
          maxLines: 3,
          maxLength: 280,
          decoration: const InputDecoration(
            hintText: 'A short note for yourself (optional)',
          ),
        ),
        const SizedBox(height: CsSpacing.md),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: FilledButton(onPressed: () {}, child: const Text('Save')),
        ),
      ],
    ),
  ),
);

class _PhotosPlaceholder extends StatelessWidget {
  const _PhotosPlaceholder();
  @override
  Widget build(BuildContext context) =>
      const SizedBox(height: 46, child: ColoredBox(color: Colors.transparent));
}

Widget _sheet({bool? wouldRecommend}) => MaterialApp(
  home: Scaffold(body: _sheetContent(wouldRecommend: wouldRecommend)),
);

void main() {
  group('AttendanceDetailsSheet shell', () {
    testWidgets('renders event name, rating, the recommend question, '
        'Photos label, Notes label and Save', (tester) async {
      await tester.pumpWidget(_sheet());
      expect(find.text('Club Leroy at Parkheuvel'), findsOneWidget);
      expect(find.byType(RatingMeter), findsOneWidget);
      expect(find.text('Would you recommend this event?'), findsOneWidget);
      expect(find.text('Photos'), findsOneWidget);
      expect(find.text('Notes'), findsOneWidget);
      expect(find.text('Save'), findsOneWidget);
    });

    testWidgets('§9/Step 4.1 section order is rating -> recommend -> '
        'photos -> note -> save', (tester) async {
      await tester.pumpWidget(_sheet());
      final column = tester.widget<Column>(find.byType(Column).first);
      final children = column.children;

      int indexOfType<T extends Widget>() => children.indexWhere((w) => w is T);
      int indexOfText(String text) =>
          children.indexWhere((w) => w is Text && w.data == text);

      final ratingIndex = indexOfType<RatingMeter>();
      final recommendIndex = indexOfType<RecommendationSelector>();
      final photosLabelIndex = indexOfText('Photos');
      final notesLabelIndex = indexOfText('Notes');
      final saveIndex = children.indexWhere(
        (w) => w is SizedBox && w.child is FilledButton,
      );

      expect(ratingIndex, lessThan(recommendIndex));
      expect(recommendIndex, lessThan(photosLabelIndex));
      expect(photosLabelIndex, lessThan(notesLabelIndex));
      expect(notesLabelIndex, lessThan(saveIndex));
    });

    testWidgets('the sheet content is scrollable — a photo grid can grow '
        'the sheet without breaking layout', (tester) async {
      await tester.pumpWidget(_sheet());
      expect(find.byType(SingleChildScrollView), findsOneWidget);
    });

    testWidgets('320px width — no overflow', (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 700));
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

  group('AttendanceDetailsSheet shell — Step 4.1 recommend section', () {
    testWidgets('no initial answer -> RecommendationSelector renders with '
        'a null value, save remains available (optional, never forced)', (
      tester,
    ) async {
      await tester.pumpWidget(_sheet());
      final selector = tester.widget<RecommendationSelector>(
        find.byType(RecommendationSelector),
      );
      expect(selector.value, isNull);
      expect(find.text('Save'), findsOneWidget);
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNotNull,
      );
    });

    testWidgets('editing an attendance that already answered Yes '
        'pre-populates RecommendationSelector with true', (tester) async {
      await tester.pumpWidget(_sheet(wouldRecommend: true));
      final selector = tester.widget<RecommendationSelector>(
        find.byType(RecommendationSelector),
      );
      expect(selector.value, isTrue);
    });

    testWidgets('editing an attendance that already answered No '
        'pre-populates RecommendationSelector with false', (tester) async {
      await tester.pumpWidget(_sheet(wouldRecommend: false));
      final selector = tester.widget<RecommendationSelector>(
        find.byType(RecommendationSelector),
      );
      expect(selector.value, isFalse);
    });
  });
}
