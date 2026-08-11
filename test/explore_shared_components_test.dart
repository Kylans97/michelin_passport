// Covers the two small, additive shared-component changes Explore's Step 3
// redesign needed: CsSearchField's new clear (×) button, and
// CountryFilterControl's new optional dark-surface support (mirroring
// YearFilterControl's established surface pattern). Both changes are
// additive — existing call sites that don't pass the new bits are
// unaffected — see each widget's own doc comment.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:michelin_passport/core/theme/cs_surface_context.dart';
import 'package:michelin_passport/core/widgets/country_filter_control.dart';
import 'package:michelin_passport/core/widgets/cs_search_field.dart';
import 'package:michelin_passport/models/venue_country.dart';

Widget _wrap(Widget child) => MaterialApp(
  home: Scaffold(body: Center(child: child)),
);

void main() {
  group('CsSearchField clear button', () {
    testWidgets('no clear button when the query is empty', (tester) async {
      await tester.pumpWidget(_wrap(const CsSearchField()));
      expect(find.byIcon(Icons.close_rounded), findsNothing);
    });

    testWidgets('clear button appears once text is entered', (tester) async {
      await tester.pumpWidget(_wrap(const CsSearchField()));
      await tester.enterText(find.byType(TextField), 'Amsterdam');
      await tester.pump();
      expect(find.byIcon(Icons.close_rounded), findsOneWidget);
    });

    testWidgets('tapping clear empties the field and calls onChanged '
        "with ''", (tester) async {
      String? lastValue;
      final controller = TextEditingController();
      await tester.pumpWidget(
        _wrap(
          CsSearchField(
            controller: controller,
            onChanged: (v) => lastValue = v,
          ),
        ),
      );
      await tester.enterText(find.byType(TextField), 'Maastricht');
      await tester.pump();
      expect(lastValue, 'Maastricht');

      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pump();
      expect(controller.text, '');
      expect(lastValue, '');
      expect(find.byIcon(Icons.close_rounded), findsNothing);
    });

    testWidgets('works the same with no external controller supplied', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap(const CsSearchField()));
      await tester.enterText(find.byType(TextField), 'Paris');
      await tester.pump();
      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pump();
      expect(find.text('Paris'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });

  group('CountryFilterControl dark-surface support', () {
    const netherlands = VenueCountry(
      name: 'Netherlands',
      code: 'NL',
      flag: '🇳🇱',
    );

    testWidgets('defaults (no surface passed) render unchanged — the '
        'original light-surface trigger', (tester) async {
      await tester.pumpWidget(
        _wrap(
          CountryFilterControl(
            selected: null,
            countries: const [netherlands],
            onChanged: (_) {},
          ),
        ),
      );
      expect(find.text('All countries'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('CsSurface.dark renders with no exceptions, both '
        'selected and unselected', (tester) async {
      for (final selected in [null, netherlands]) {
        await tester.pumpWidget(
          _wrap(
            CountryFilterControl(
              selected: selected,
              countries: const [netherlands],
              onChanged: (_) {},
              surface: CsSurface.dark,
            ),
          ),
        );
        expect(tester.takeException(), isNull);
      }
      expect(find.text('Netherlands'), findsOneWidget);
    });

    testWidgets('a long country name in a narrow squeezed row ellipsizes '
        "instead of overflowing (Guides Step 2C's GuideYearSelector-plus-"
        'CountryFilterControl row)', (tester) async {
      const uae = VenueCountry(
        name: 'United Arab Emirates',
        code: 'AE',
        flag: '🇦🇪',
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 320,
              child: Row(
                children: [
                  const SizedBox(width: 220), // simulate a sibling control
                  Expanded(
                    child: CountryFilterControl(
                      selected: uae,
                      countries: const [uae],
                      onChanged: (_) {},
                      surface: CsSurface.dark,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
    });
  });
}
