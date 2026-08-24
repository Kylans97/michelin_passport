// Covers the "Collections" entry point ExploreScreen adds (originally
// "Browse the Guides" in Navigation Step 1; relabeled by Navigation &
// Information Architecture V2 §3 — same GuidesScreen destination, new
// copy) — GuideDestinationRow itself is already fully covered by
// guides_widgets_test.dart, so this file only exercises the actual copy
// used in Explore and confirms it doesn't overflow, mirroring the
// established precedent (guides_screen_test.dart's own "destination
// routing" note): ExploreScreen constructs repositories against
// Supabase.instance.client eagerly in initState, so it can't itself be
// pumped in a widget test without a live session — the presentation seam
// (this exact row, this exact copy) is what's tested instead.
//
// UI Polish pass: Explore's own canvas is deep-green, not ivory, so this
// row must pass `surface: CsSurface.dark` (matching the real call site in
// explore_screen.dart) — physical-device review found the row rendering
// forest-green-on-deep-green (i.e. defaulting to CsSurface.light, meant
// for GuideFamilySection's ivory blocks) essentially unreadable here.
// (Green Token Consistency Migration: this comment previously said
// "forest-green canvas," which was already inaccurate before that
// migration — Explore has used AppColors.deepGreen the whole time —
// corrected here so this file doesn't keep confusing the two greens.)

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:michelin_passport/core/constants/app_colors.dart';
import 'package:michelin_passport/core/theme/cs_surface_context.dart';
import 'package:michelin_passport/features/guides/widgets/guide_destination_row.dart';

const _label = 'Collections';
const _descriptor = "Michelin, World's 50 Best & Gault&Millau.";

Widget _wrap(Widget child) => MaterialApp(
  home: Scaffold(backgroundColor: AppColors.deepGreen, body: child),
);

void main() {
  group('Explore "Collections" entry', () {
    testWidgets('renders the exact label and descriptor used in '
        'ExploreScreen', (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        _wrap(
          GuideDestinationRow(
            label: _label,
            descriptor: _descriptor,
            onTap: () => tapped = true,
            surface: CsSurface.dark,
          ),
        ),
      );
      expect(find.text(_label), findsOneWidget);
      expect(find.text(_descriptor), findsOneWidget);
      await tester.tap(find.text(_label));
      expect(tapped, isTrue);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'UI Polish: on Explore\'s deep-green canvas, the label is ivory '
      '(not forest-green) — legible, never gold',
      (tester) async {
        await tester.pumpWidget(
          _wrap(
            GuideDestinationRow(
              label: _label,
              descriptor: _descriptor,
              onTap: () {},
              surface: CsSurface.dark,
            ),
          ),
        );
        final label = tester.widget<Text>(find.text(_label));
        expect(label.style?.color, AppColors.ivory);
        expect(label.style?.color, isNot(AppColors.forestGreen));
        expect(label.style?.color, isNot(AppColors.gold));

        final descriptor = tester.widget<Text>(find.text(_descriptor));
        expect(descriptor.style?.color, AppColors.secondaryOnDark);

        final arrow = tester.widget<Icon>(
          find.byIcon(Icons.arrow_forward_rounded),
        );
        expect(arrow.color, AppColors.secondaryOnDark);
        expect(arrow.color, isNot(AppColors.gold));
      },
    );

    testWidgets(
      'defaulting to CsSurface.light (no surface passed) still renders '
      'forest-green on ivory — GuideFamilySection\'s own call sites stay '
      'byte-identical',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              backgroundColor: AppColors.ivory,
              body: GuideDestinationRow(
                label: _label,
                descriptor: _descriptor,
                onTap: () {},
              ),
            ),
          ),
        );
        final label = tester.widget<Text>(find.text(_label));
        expect(label.style?.color, AppColors.forestGreen);
      },
    );

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
              surface: CsSurface.dark,
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
                surface: CsSurface.dark,
              ),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
    });
  });
}
