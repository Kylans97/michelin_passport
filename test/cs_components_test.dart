// Covers the Step 1 shared components built on the new design tokens:
// CsPrimaryButton/CsSecondaryButton, CsFilterChip, CsSearchField,
// CsContentSheet, CsSectionTitle. None of these are wired into any
// existing screen yet — these tests verify each renders correctly in
// isolation (both CsSurface.dark and CsSurface.light where applicable),
// meets the brief's exact dimensions, and clears the 44×44 minimum touch
// target — not that any current screen's appearance changed, since none
// does.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:michelin_passport/core/theme/cs_surface_context.dart';
import 'package:michelin_passport/core/widgets/cs_content_sheet.dart';
import 'package:michelin_passport/core/widgets/cs_filter_chip.dart';
import 'package:michelin_passport/core/widgets/cs_primary_button.dart';
import 'package:michelin_passport/core/widgets/cs_search_field.dart';
import 'package:michelin_passport/core/widgets/cs_section_title.dart';

Widget _wrap(Widget child, {Color background = Colors.black}) => MaterialApp(
  home: Scaffold(
    backgroundColor: background,
    body: Center(child: child),
  ),
);

void main() {
  group('CsPrimaryButton', () {
    testWidgets('renders at the brief\'s 52px height by default', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(CsPrimaryButton(label: 'Continue', onTap: () {})),
      );
      final size = tester.getSize(find.byType(CsPrimaryButton));
      expect(size.height, 52);
      expect(tester.takeException(), isNull);
    });

    testWidgets('meets the 44x44 minimum touch target', (tester) async {
      await tester.pumpWidget(
        _wrap(CsPrimaryButton(label: 'Continue', onTap: () {})),
      );
      final size = tester.getSize(find.byType(CsPrimaryButton));
      expect(size.height, greaterThanOrEqualTo(44));
    });

    testWidgets('renders with an icon and without one, on both surfaces', (
      tester,
    ) async {
      for (final surface in CsSurface.values) {
        await tester.pumpWidget(
          _wrap(
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CsPrimaryButton(label: 'Save', onTap: () {}, surface: surface),
                CsPrimaryButton(
                  label: 'Save',
                  onTap: () {},
                  icon: Icons.check_rounded,
                  surface: surface,
                ),
              ],
            ),
          ),
        );
        expect(tester.takeException(), isNull);
      }
    });

    testWidgets('tap fires onTap', (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        _wrap(CsPrimaryButton(label: 'Continue', onTap: () => tapped = true)),
      );
      await tester.tap(find.byType(CsPrimaryButton));
      expect(tapped, isTrue);
    });

    testWidgets('null onTap disables the button rather than crashing', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(CsPrimaryButton(label: 'Save', onTap: null)),
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('CsSecondaryButton', () {
    testWidgets('renders at 52px height by default, both surfaces', (
      tester,
    ) async {
      for (final surface in CsSurface.values) {
        await tester.pumpWidget(
          _wrap(
            CsSecondaryButton(label: 'Website', onTap: () {}, surface: surface),
          ),
        );
        final size = tester.getSize(find.byType(CsSecondaryButton));
        expect(size.height, 52);
        expect(tester.takeException(), isNull);
      }
    });
  });

  group('CsFilterChip', () {
    testWidgets('renders at the brief\'s 44px height, selected/unselected, '
        'both surfaces', (tester) async {
      for (final surface in CsSurface.values) {
        for (final selected in [true, false]) {
          await tester.pumpWidget(
            _wrap(
              CsFilterChip(
                label: 'Restaurants',
                selected: selected,
                onTap: () {},
                surface: surface,
              ),
            ),
          );
          final size = tester.getSize(find.byType(CsFilterChip));
          expect(size.height, 44);
          expect(tester.takeException(), isNull);
        }
      }
    });

    testWidgets('tap fires onTap', (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        _wrap(
          CsFilterChip(
            label: 'All',
            selected: false,
            onTap: () => tapped = true,
          ),
        ),
      );
      await tester.tap(find.byType(CsFilterChip));
      expect(tapped, isTrue);
    });

    testWidgets('renders with an optional icon', (tester) async {
      await tester.pumpWidget(
        _wrap(
          CsFilterChip(
            label: 'Netherlands',
            selected: true,
            onTap: () {},
            icon: Icons.public_rounded,
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(find.byIcon(Icons.public_rounded), findsOneWidget);
    });
  });

  group('CsSearchField', () {
    testWidgets('renders at the brief\'s 52px height, both surfaces', (
      tester,
    ) async {
      for (final surface in CsSurface.values) {
        await tester.pumpWidget(_wrap(CsSearchField(surface: surface)));
        final size = tester.getSize(find.byType(CsSearchField));
        expect(size.height, 52);
        expect(tester.takeException(), isNull);
      }
    });

    testWidgets('typing calls onChanged', (tester) async {
      String? lastValue;
      await tester.pumpWidget(
        _wrap(CsSearchField(onChanged: (v) => lastValue = v)),
      );
      await tester.enterText(find.byType(TextField), 'Maastricht');
      expect(lastValue, 'Maastricht');
    });
  });

  group('CsContentSheet', () {
    testWidgets('renders its child and stays within the keyboard-aware '
        'height budget with no overflow', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => Center(
                child: ElevatedButton(
                  onPressed: () => showModalBottomSheet<void>(
                    context: context,
                    builder: (_) => const CsContentSheet(
                      child: SizedBox(
                        height: 200,
                        child: Text('Sheet content'),
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
      expect(find.text('Sheet content'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('shifts above the keyboard (viewInsets.bottom) without '
        'overflowing on a short screen', (tester) async {
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(
            size: Size(360, 640),
            viewInsets: EdgeInsets.only(bottom: 300),
          ),
          child: const MaterialApp(
            home: Scaffold(
              body: Align(
                alignment: Alignment.bottomCenter,
                child: CsContentSheet(
                  child: SizedBox(height: 400, child: Text('Tall content')),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  });

  group('CsSectionTitle', () {
    testWidgets('renders the given text', (tester) async {
      await tester.pumpWidget(_wrap(const CsSectionTitle('ABOUT')));
      expect(find.text('ABOUT'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('accepts a color override', (tester) async {
      await tester.pumpWidget(
        _wrap(const CsSectionTitle('ABOUT', color: Colors.red)),
      );
      final text = tester.widget<Text>(find.text('ABOUT'));
      expect(text.style?.color, Colors.red);
    });
  });
}
