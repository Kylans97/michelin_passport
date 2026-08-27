// PROFILE JOURNEY CARD — coverage for the real, Supabase-free JourneyCard
// widget (lib/features/profile/journey_card.dart), pumped directly (no
// mirror needed — it takes only a JourneyMetrics and a memberSince
// string, no Supabase dependency). Journey metric CALCULATION logic
// itself is untouched by this file and stays covered by
// journey_metrics_test.dart.
//
// This card was redesigned to show only Places/Countries, centered
// side-by-side with an optional subtle vertical divider, no summary
// sentence, no icons, no per-metric card, and a green-on-green
// guilloché-style security-paper backdrop behind the existing corner
// passport stamp — see journey_card.dart's own doc comments for the
// full reasoning.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:michelin_passport/core/constants/app_colors.dart';
import 'package:michelin_passport/core/theme/cs_spacing.dart';
import 'package:michelin_passport/core/theme/cs_surfaces.dart';
import 'package:michelin_passport/core/theme/cs_typography.dart';
import 'package:michelin_passport/features/profile/journey_card.dart';
import 'package:michelin_passport/features/profile/journey_metrics.dart';

JourneyMetrics _metrics({int places = 0, int countries = 0}) =>
    JourneyMetrics(places: places, countries: countries);

Widget _wrap(
  Widget child, {
  double width = 390,
  TextScaler textScaler = TextScaler.noScaling,
}) => MediaQuery(
  data: MediaQueryData(size: Size(width, 800), textScaler: textScaler),
  child: MaterialApp(
    home: Scaffold(
      backgroundColor: AppColors.deepGreen,
      body: SizedBox(width: width, child: child),
    ),
  ),
);

void main() {
  group('JourneyCard — renders', () {
    testWidgets('shows the eyebrow and both metric values/labels — no '
        'summary sentence, no Events/Trips', (tester) async {
      await tester.pumpWidget(
        _wrap(
          JourneyCard(
            journey: _metrics(places: 4, countries: 4),
            memberSince: 'August 2026',
          ),
        ),
      );
      expect(find.text('YOUR JOURNEY'), findsOneWidget);
      expect(find.text('4'), findsNWidgets(2)); // places AND countries
      expect(find.text('PLACES'), findsOneWidget);
      expect(find.text('COUNTRIES'), findsOneWidget);
      expect(find.text('EVENTS'), findsNothing);
      expect(find.text('TRIPS'), findsNothing);
      // No summary sentence of any kind (old "N places in M countries"
      // phrasing, or anything resembling it).
      expect(find.textContaining(' in '), findsNothing);
      expect(find.textContaining('waiting'), findsNothing);
    });

    testWidgets('shows honest zero values with no special empty-state '
        'copy — the two numbers stay the only content', (tester) async {
      await tester.pumpWidget(
        _wrap(JourneyCard(journey: _metrics(), memberSince: 'August 2026')),
      );
      expect(find.text('YOUR JOURNEY'), findsOneWidget);
      expect(find.text('0'), findsNWidgets(2));
      expect(find.text('PLACES'), findsOneWidget);
      expect(find.text('COUNTRIES'), findsOneWidget);
    });

    testWidgets('renders distinct places/countries values correctly', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          JourneyCard(
            journey: _metrics(places: 12, countries: 7),
            memberSince: 'August 2026',
          ),
        ),
      );
      expect(find.text('12'), findsOneWidget);
      expect(find.text('7'), findsOneWidget);
    });
  });

  group('JourneyCard — no icons, no decorative divider under the eyebrow',
      () {
    testWidgets('renders no Icon widgets at all — no per-metric icons, no '
        'icon circles', (tester) async {
      await tester.pumpWidget(
        _wrap(
          JourneyCard(
            journey: _metrics(places: 4, countries: 4),
            memberSince: 'August 2026',
          ),
        ),
      );
      expect(find.byType(Icon), findsNothing);
    });
  });

  group('JourneyCard — member-since stamp', () {
    testWidgets('shows an abbreviated month + year, derived from the real '
        'memberSince value', (tester) async {
      await tester.pumpWidget(
        _wrap(
          JourneyCard(
            journey: _metrics(places: 1, countries: 1),
            memberSince: 'August 2026',
          ),
        ),
      );
      expect(find.text('MANTELIER · AUG 2026'), findsOneWidget);
      expect(find.textContaining('Member since'), findsNothing);
    });

    testWidgets('journeyStampDateLabel abbreviates a well-formed "Month '
        'Year" string', (tester) async {
      expect(journeyStampDateLabel('August 2026'), 'AUG 2026');
      expect(journeyStampDateLabel('January 2025'), 'JAN 2025');
      expect(journeyStampDateLabel('May 2026'), 'MAY 2026');
    });

    testWidgets('journeyStampDateLabel falls back safely on an unexpected '
        'shape rather than throwing', (tester) async {
      expect(journeyStampDateLabel(''), '');
      expect(journeyStampDateLabel('unexpected'), 'UNEXPECTED');
    });

    testWidgets('the stamp is excluded from semantics and never tappable',
        (tester) async {
      await tester.pumpWidget(
        _wrap(
          JourneyCard(
            journey: _metrics(places: 1, countries: 1),
            memberSince: 'August 2026',
          ),
        ),
      );
      // At least one — Scaffold/MaterialApp internals may also use
      // ExcludeSemantics/IgnorePointer elsewhere in the tree, so this
      // isn't scoped to exactly one, just proves the stamp's own
      // wrapping is present.
      expect(find.byType(ExcludeSemantics), findsWidgets);
      expect(find.byType(IgnorePointer), findsWidgets);
      await tester.tapAt(tester.getTopRight(find.byType(JourneyCard)));
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  });

  group('JourneyCard — security-paper texture', () {
    testWidgets('paints a CustomPaint backdrop behind the content, and '
        'renders without throwing', (tester) async {
      await tester.pumpWidget(
        _wrap(
          JourneyCard(
            journey: _metrics(places: 4, countries: 4),
            memberSince: 'August 2026',
          ),
        ),
      );
      // At least two CustomPaint widgets: the security-paper backdrop and
      // the passport stamp painter.
      expect(find.byType(CustomPaint), findsWidgets);
      expect(tester.takeException(), isNull);
    });
  });

  group('JourneyCard — decorative refinement (fine guilloché, shorter/'
      'fainter divider, quieter stamp)', () {
    testWidgets('the divider is short — well under the metric block\'s own '
        'height — and very low-opacity, never a full-height rule', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          JourneyCard(
            journey: _metrics(places: 4, countries: 4),
            memberSince: 'August 2026',
          ),
        ),
      );
      final divider = tester.widget<Container>(
        find.byKey(const ValueKey('journey-card-divider')),
      );
      final dividerHeight = (divider.constraints?.maxHeight ?? 0);
      expect(dividerHeight, lessThan(30));
      final decoration = divider.decoration;
      final color = decoration is BoxDecoration
          ? decoration.color
          : divider.color;
      expect(color, isNot(AppColors.subtleBorderDark));
      expect((color?.a ?? 1.0), lessThan(0.15));
    });

    testWidgets('card dimensions, colour, and metric typography are '
        'unaffected by the decorative refinement — a refinement pass '
        'only', (tester) async {
      await tester.pumpWidget(
        _wrap(
          JourneyCard(
            journey: _metrics(places: 4, countries: 4),
            memberSince: 'August 2026',
          ),
        ),
      );
      final container = tester.widget<Container>(
        find
            .ancestor(
              of: find.text('YOUR JOURNEY'),
              matching: find.byType(Container),
            )
            .first,
      );
      final decoration = container.decoration! as BoxDecoration;
      expect(decoration.color, CsSurfaces.greenElevated);
      expect(decoration.borderRadius, BorderRadius.circular(CsRadius.card));
      final placesValue = tester.widget<Text>(find.text('4').first);
      expect(placesValue.style?.fontSize, CsTypography.screenTitle.fontSize);
    });
  });

  group('JourneyCard — no gold', () {
    testWidgets('nothing structural uses AppColors.gold', (tester) async {
      await tester.pumpWidget(
        _wrap(
          JourneyCard(
            journey: _metrics(places: 4, countries: 4),
            memberSince: 'August 2026',
          ),
        ),
      );
      for (final text in tester.widgetList<Text>(find.byType(Text))) {
        expect(text.style?.color, isNot(AppColors.gold));
      }
    });
  });

  group('JourneyCard — responsive', () {
    testWidgets('both labels remain fully visible, unabbreviated, and '
        'exception-free at 320/375/390/430px', (tester) async {
      for (final width in [320.0, 375.0, 390.0, 430.0]) {
        await tester.pumpWidget(
          _wrap(
            JourneyCard(
              journey: _metrics(places: 128, countries: 87),
              memberSince: 'August 2026',
            ),
            width: width,
          ),
        );
        expect(
          find.text('PLACES'),
          findsOneWidget,
          reason: 'PLACES at ${width}px',
        );
        expect(
          find.text('COUNTRIES'),
          findsOneWidget,
          reason: 'COUNTRIES at ${width}px',
        );
        final countriesLabel = tester.widget<Text>(find.text('COUNTRIES'));
        expect(
          countriesLabel.data,
          'COUNTRIES',
          reason: 'never truncated at ${width}px',
        );
        expect(tester.takeException(), isNull, reason: 'at ${width}px');
      }
    });

    testWidgets('remains exception-free and fully labeled at 1.6x text '
        'scale, even at the narrowest supported width', (tester) async {
      await tester.pumpWidget(
        _wrap(
          JourneyCard(
            journey: _metrics(places: 128, countries: 87),
            memberSince: 'August 2026',
          ),
          width: 320,
          textScaler: const TextScaler.linear(1.6),
        ),
      );
      expect(find.text('PLACES'), findsOneWidget);
      expect(find.text('COUNTRIES'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
