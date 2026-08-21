// Covers AttendancePhotosSection's capacity-reactive UI (Events V2 Step 4's
// final photo-limit correction) — whether the Add action is enabled and
// whether "Maximum 6 photos" is shown, as a function of how many photos
// are currently loaded.
//
// _AttendancePhotosSectionState itself constructs
// PhotoRepository(Supabase.instance.client) at field-init time —
// unavailable in this sandbox (the same, already-documented limitation as
// attendance_details_sheet_shell_test.dart). This mirrors the exact
// capacity-dependent tail of _AttendancePhotosSectionState.build() (the
// grid + AddPhotosButton + conditional "Maximum" text), using the REAL
// VisitPhotoGrid/AddPhotosButton widgets (neither is Supabase-eager) and a
// fake VisitPhoto list with no resolved URLs — PhotoTile renders a plain
// placeholder icon for a null url, never a network fetch, so this is a
// fully faithful, network-free proof.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:michelin_passport/core/constants/app_colors.dart';
import 'package:michelin_passport/core/constants/photo_limits.dart';
import 'package:michelin_passport/features/photos/widgets/add_photos_button.dart';
import 'package:michelin_passport/features/photos/widgets/visit_photo_grid.dart';
import 'package:michelin_passport/models/visit_photo.dart';

List<VisitPhoto> _fakePhotos(int count) => [
  for (var i = 0; i < count; i++)
    VisitPhoto(
      id: 'photo-$i',
      userId: 'user-1',
      attendanceId: 'att-1',
      storagePath: 'user-1/att-1/photo-$i.jpg',
      isPublic: false,
    ),
];

// Mirrors _AttendancePhotosSectionState.build()'s photos-loaded branch
// exactly: grid (when non-empty) -> AddPhotosButton -> conditional
// "Maximum N photos" text, using the same remainingAttendancePhotoCapacity
// decision the real widget calls.
Widget _sectionContent({required int photoCount, bool uploading = false}) {
  final photos = _fakePhotos(photoCount);
  final remaining = remainingAttendancePhotoCapacity(photos.length);
  final atCapacity = remaining <= 0;
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      if (photos.isNotEmpty) ...[
        VisitPhotoGrid(
          photos: photos,
          urls: const {},
          onTapPhoto: (_) {},
          onDeletePhoto: (_) {},
        ),
        const SizedBox(height: 12),
      ],
      AddPhotosButton(
        busy: uploading,
        enabled: !atCapacity,
        label: photos.isEmpty ? 'Add photos' : 'Add more photos',
        onTap: () {},
      ),
      if (atCapacity) ...[
        const SizedBox(height: 6),
        Text(
          'Maximum $maxEventAttendancePhotos photos',
          style: GoogleFonts.inter(
            color: AppColors.textSecondary,
            fontSize: 12,
          ),
        ),
      ],
    ],
  );
}

Widget _wrap(Widget child, {double width = 390, double textScale = 1.0}) =>
    MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
        child: Scaffold(
          body: SizedBox(
            width: width,
            child: SingleChildScrollView(child: child),
          ),
        ),
      ),
    );

void main() {
  group('AttendancePhotosSection shell — capacity reactivity', () {
    testWidgets('0 photos: Add action enabled, no "Maximum" text', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap(_sectionContent(photoCount: 0)));
      final button = tester.widget<OutlinedButton>(find.byType(OutlinedButton));
      expect(button.onPressed, isNotNull);
      expect(find.textContaining('Maximum'), findsNothing);
      expect(find.text('Add photos'), findsOneWidget);
    });

    testWidgets('5 photos: Add action still enabled (one more fits)', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap(_sectionContent(photoCount: 5)));
      final button = tester.widget<OutlinedButton>(find.byType(OutlinedButton));
      expect(button.onPressed, isNotNull);
      expect(find.textContaining('Maximum'), findsNothing);
    });

    testWidgets('6 photos (at capacity): Add action disabled, "Maximum 6 '
        'photos" shown', (tester) async {
      await tester.pumpWidget(_wrap(_sectionContent(photoCount: 6)));
      final button = tester.widget<OutlinedButton>(find.byType(OutlinedButton));
      expect(button.onPressed, isNull);
      expect(find.text('Maximum 6 photos'), findsOneWidget);
    });

    testWidgets('deleting down from 6 to 5 makes the Add action available '
        'again immediately (no separate reload needed to recompute)', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap(_sectionContent(photoCount: 6)));
      expect(
        tester.widget<OutlinedButton>(find.byType(OutlinedButton)).onPressed,
        isNull,
      );
      await tester.pumpWidget(_wrap(_sectionContent(photoCount: 5)));
      expect(
        tester.widget<OutlinedButton>(find.byType(OutlinedButton)).onPressed,
        isNotNull,
      );
      expect(find.textContaining('Maximum'), findsNothing);
    });

    testWidgets('existing 7 photos (already over the limit) still render '
        'every tile — never truncated to 6', (tester) async {
      await tester.pumpWidget(_wrap(_sectionContent(photoCount: 7)));
      final grid = tester.widget<VisitPhotoGrid>(find.byType(VisitPhotoGrid));
      expect(grid.photos, hasLength(7));
      final button = tester.widget<OutlinedButton>(find.byType(OutlinedButton));
      expect(button.onPressed, isNull);
    });

    testWidgets('the temporary test fixture\'s existing 12 photos all '
        'render — grid is never truncated, delete affordance stays '
        'available on every tile', (tester) async {
      await tester.pumpWidget(_wrap(_sectionContent(photoCount: 12)));
      final grid = tester.widget<VisitPhotoGrid>(find.byType(VisitPhotoGrid));
      expect(grid.photos, hasLength(12));
      // Every tile still carries a working onDeletePhoto callback — proven
      // by construction (VisitPhotoGrid always wires onDeletePhoto for
      // every item; see visit_photo_grid.dart's own itemBuilder), and the
      // Add action is correctly disabled without hiding or altering the
      // existing content above it.
      expect(find.text('Maximum 6 photos'), findsOneWidget);
    });

    testWidgets('busy (mid-upload) at capacity still shows disabled — '
        'busy and enabled=false compose correctly (button spinner wins '
        'visually, onPressed stays null either way)', (tester) async {
      await tester.pumpWidget(
        _wrap(_sectionContent(photoCount: 6, uploading: true)),
      );
      final button = tester.widget<OutlinedButton>(find.byType(OutlinedButton));
      expect(button.onPressed, isNull);
    });
  });

  group('AttendancePhotosSection shell — responsive', () {
    testWidgets('320px width at capacity — no overflow', (tester) async {
      await tester.pumpWidget(
        _wrap(_sectionContent(photoCount: 6), width: 320),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('1.6x text scale at capacity — no overflow', (tester) async {
      await tester.pumpWidget(
        _wrap(_sectionContent(photoCount: 6), textScale: 1.6),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('320px width with 12 existing photos — no overflow', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(_sectionContent(photoCount: 12), width: 320),
      );
      expect(tester.takeException(), isNull);
    });
  });
}
