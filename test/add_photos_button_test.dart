// Covers AddPhotosButton — shared by VisitPhotosSection (Restaurant/Hotel,
// unlimited) and AttendancePhotosSection (Events, capped at
// maxEventAttendancePhotos). Events V2 Step 4's final photo-limit
// correction added the optional `enabled` parameter; every test here
// proves the pre-existing default (`enabled` omitted) renders and behaves
// exactly as before, and that the new disabled state never looks like an
// error (no AppColors.error anywhere).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:michelin_passport/core/constants/app_colors.dart';
import 'package:michelin_passport/features/photos/widgets/add_photos_button.dart';

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  group('AddPhotosButton — default (enabled omitted), Restaurant/Hotel\'s '
      'exact existing shape', () {
    testWidgets('renders the label and fires onTap', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        _wrap(
          AddPhotosButton(
            busy: false,
            label: 'Add photos',
            onTap: () => taps++,
          ),
        ),
      );
      expect(find.text('Add photos'), findsOneWidget);
      await tester.tap(find.byType(OutlinedButton));
      expect(taps, 1);
    });

    testWidgets('is tappable — onPressed is non-null', (tester) async {
      await tester.pumpWidget(
        _wrap(AddPhotosButton(busy: false, label: 'Add photos', onTap: () {})),
      );
      final button = tester.widget<OutlinedButton>(find.byType(OutlinedButton));
      expect(button.onPressed, isNotNull);
    });

    testWidgets('busy=true still disables (pre-existing behavior, '
        'unaffected by the enabled parameter\'s addition)', (tester) async {
      await tester.pumpWidget(
        _wrap(AddPhotosButton(busy: true, label: 'Add photos', onTap: () {})),
      );
      final button = tester.widget<OutlinedButton>(find.byType(OutlinedButton));
      expect(button.onPressed, isNull);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });
  });

  group('AddPhotosButton — enabled: false (Step 4\'s photo-limit reached '
      'state)', () {
    testWidgets('disables the button — onPressed is null', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        _wrap(
          AddPhotosButton(
            busy: false,
            enabled: false,
            label: 'Add more photos',
            onTap: () => taps++,
          ),
        ),
      );
      final button = tester.widget<OutlinedButton>(find.byType(OutlinedButton));
      expect(button.onPressed, isNull);
      await tester.tap(find.byType(OutlinedButton), warnIfMissed: false);
      expect(taps, 0);
    });

    testWidgets('never uses AppColors.error — a limit is not a failure', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          AddPhotosButton(
            busy: false,
            enabled: false,
            label: 'Add more photos',
            onTap: () {},
          ),
        ),
      );
      final button = tester.widget<OutlinedButton>(find.byType(OutlinedButton));
      final style = button.style!;
      expect(style.foregroundColor?.resolve({}), isNot(AppColors.error));
      final icon = tester.widget<Icon>(find.byType(Icon));
      expect(icon.color, isNot(AppColors.error));
    });

    testWidgets('the icon/text tint is muted (textSecondary), not the '
        'active gold tone', (tester) async {
      await tester.pumpWidget(
        _wrap(
          AddPhotosButton(
            busy: false,
            enabled: false,
            label: 'Add more photos',
            onTap: () {},
          ),
        ),
      );
      final icon = tester.widget<Icon>(find.byType(Icon));
      expect(icon.color, AppColors.textSecondary);
    });

    testWidgets('still renders its label — disabled, not hidden', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          AddPhotosButton(
            busy: false,
            enabled: false,
            label: 'Add more photos',
            onTap: () {},
          ),
        ),
      );
      expect(find.text('Add more photos'), findsOneWidget);
    });
  });
}
