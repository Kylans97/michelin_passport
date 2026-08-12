// Covers the "Browse the Guides" entry point ExploreScreen adds in
// Navigation Step 1 — GuideDestinationRow itself is already fully covered
// by guides_widgets_test.dart, so this file only exercises the actual copy
// used in Explore and confirms it doesn't overflow, mirroring the
// established precedent (guides_screen_test.dart's own "destination
// routing" note): ExploreScreen constructs repositories against
// Supabase.instance.client eagerly in initState, so it can't itself be
// pumped in a widget test without a live session — the presentation seam
// (this exact row, this exact copy) is what's tested instead.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:michelin_passport/core/constants/app_colors.dart';
import 'package:michelin_passport/features/guides/widgets/guide_destination_row.dart';

const _label = 'Browse the Guides';
const _descriptor = "Michelin, World's 50 Best & Gault&Millau.";

Widget _wrap(Widget child) => MaterialApp(
  home: Scaffold(backgroundColor: AppColors.deepGreen, body: child),
);

void main() {
  group('Explore "Browse the Guides" entry', () {
    testWidgets('renders the exact label and descriptor used in '
        'ExploreScreen', (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        _wrap(
          GuideDestinationRow(
            label: _label,
            descriptor: _descriptor,
            onTap: () => tapped = true,
          ),
        ),
      );
      expect(find.text(_label), findsOneWidget);
      expect(find.text(_descriptor), findsOneWidget);
      await tester.tap(find.text(_label));
      expect(tapped, isTrue);
      expect(tester.takeException(), isNull);
    });

    testWidgets('320px and 390px widths — no overflow with this exact copy', (
      tester,
    ) async {
      for (final width in [320.0, 390.0]) {
        await tester.binding.setSurfaceSize(Size(width, 844));
        await tester.pumpWidget(
          _wrap(
            GuideDestinationRow(
              label: _label,
              descriptor: _descriptor,
              onTap: () {},
            ),
          ),
        );
        expect(tester.takeException(), isNull);
      }
      await tester.binding.setSurfaceSize(null);
    });

    testWidgets('1.6x text scale — no overflow with this exact copy', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(1.6)),
            child: Scaffold(
              backgroundColor: AppColors.deepGreen,
              body: GuideDestinationRow(
                label: _label,
                descriptor: _descriptor,
                onTap: () {},
              ),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
    });
  });
}
