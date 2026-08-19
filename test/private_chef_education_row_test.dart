// Covers PrivateChefEducationRow — institution/program/optional-period
// rendering, non-tappability, no invented metadata, and the gold audit.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:michelin_passport/core/constants/app_colors.dart';
import 'package:michelin_passport/features/private_chefs/widgets/private_chef_education_row.dart';
import 'package:michelin_passport/models/private_chef_education.dart';

const _education = PrivateChefEducation(
  id: 'e1',
  privateChefId: 'c1',
  institution: 'De Rooi Pannen',
  program: 'Horeca Ondernemend Management',
);

Widget _wrap(Widget child) => MaterialApp(
  home: Scaffold(backgroundColor: AppColors.ivory, body: child),
);

void main() {
  group('PrivateChefEducationRow', () {
    testWidgets('renders institution and program', (tester) async {
      await tester.pumpWidget(
        _wrap(const PrivateChefEducationRow(education: _education)),
      );
      expect(find.text('De Rooi Pannen'), findsOneWidget);
      expect(find.text('Horeca Ondernemend Management'), findsOneWidget);
    });

    testWidgets('no period_text -> no period line, no invented dates', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(const PrivateChefEducationRow(education: _education)),
      );
      expect(find.textContaining('–'), findsNothing);
      expect(find.textContaining('20'), findsNothing);
    });

    testWidgets('period_text present -> renders as its own line', (
      tester,
    ) async {
      const withPeriod = PrivateChefEducation(
        id: 'e1',
        privateChefId: 'c1',
        institution: 'De Rooi Pannen',
        program: 'Horeca Ondernemend Management',
        periodText: '2015–2017',
      );
      await tester.pumpWidget(
        _wrap(const PrivateChefEducationRow(education: withPeriod)),
      );
      expect(find.text('2015–2017'), findsOneWidget);
    });

    testWidgets('never tappable — no InkWell, no arrow affordance, no '
        'stars', (tester) async {
      await tester.pumpWidget(
        _wrap(const PrivateChefEducationRow(education: _education)),
      );
      expect(find.byType(InkWell), findsNothing);
      expect(find.byIcon(Icons.arrow_forward_rounded), findsNothing);
      expect(find.byIcon(Icons.star_rounded), findsNothing);
    });

    testWidgets('gold audit', (tester) async {
      await tester.pumpWidget(
        _wrap(const PrivateChefEducationRow(education: _education)),
      );
      final texts = tester.widgetList<Text>(find.byType(Text));
      for (final text in texts) {
        expect(text.style?.color, isNot(AppColors.gold));
      }
    });

    testWidgets('320px / 1.6x — no overflow with long institution/program '
        'names', (tester) async {
      const longEducation = PrivateChefEducation(
        id: 'e1',
        privateChefId: 'c1',
        institution: 'A Genuinely Long Institution Name For Testing Purposes',
        program:
            'An Equally Long Program Name Spanning Several Words For Testing',
        periodText: '2015–2017',
      );
      await tester.binding.setSurfaceSize(const Size(320, 844));
      await tester.pumpWidget(
        _wrap(const PrivateChefEducationRow(education: longEducation)),
      );
      expect(tester.takeException(), isNull);
      await tester.binding.setSurfaceSize(null);

      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(1.6)),
            child: Scaffold(
              backgroundColor: AppColors.ivory,
              body: const PrivateChefEducationRow(education: longEducation),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
    });
  });
}
