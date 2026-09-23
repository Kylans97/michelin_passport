// Covers WelcomeFlow — the four-screen first-run carousel. No Supabase
// knowledge of its own (see its own doc comment); onDone is a plain
// VoidCallback, so this is pumped directly with no DI seam needed beyond
// that.

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:michelin_passport/features/onboarding/welcome_flow_screen.dart';

Widget _wrap(VoidCallback onDone) =>
    MaterialApp(home: WelcomeFlow(onDone: onDone));

Future<void> _swipeNext(WidgetTester tester) async {
  await tester.drag(find.byType(PageView), const Offset(-600, 0));
  await tester.pumpAndSettle();
}

void main() {
  group('WelcomeFlow', () {
    testWidgets('opens on page 1 with its title, body, and a visible Skip',
        (tester) async {
      await tester.pumpWidget(_wrap(() {}));
      expect(
        find.text('Some evenings only happen once'),
        findsOneWidget,
      );
      expect(
        find.textContaining('Four-hands dinners, guest chefs'),
        findsOneWidget,
      );
      expect(find.text('Skip'), findsOneWidget);
    });

    testWidgets('swiping moves through all four pages in order, each with '
        'its own title and body', (tester) async {
      await tester.pumpWidget(_wrap(() {}));
      expect(
        find.text('Some evenings only happen once'),
        findsOneWidget,
      );

      await _swipeNext(tester);
      expect(find.text('Know where to go'), findsOneWidget);
      expect(
        find.textContaining("World's 50 Best and Gault&Millau"),
        findsOneWidget,
      );
      expect(find.text('Skip'), findsOneWidget);

      await _swipeNext(tester);
      expect(find.text("Keep what you've tasted"), findsOneWidget);
      expect(
        find.textContaining("Where you've been, where you still want to "
            'go'),
        findsOneWidget,
      );
      expect(find.text('Skip'), findsOneWidget);

      await _swipeNext(tester);
      expect(find.text('Welcome to Mantelier'), findsOneWidget);
      expect(find.text('Get started'), findsOneWidget);
    });

    testWidgets('Skip is hidden on the final page — its own CTA is the '
        'only dismiss action there', (tester) async {
      await tester.pumpWidget(_wrap(() {}));
      await _swipeNext(tester);
      await _swipeNext(tester);
      await _swipeNext(tester);
      expect(find.text('Welcome to Mantelier'), findsOneWidget);
      expect(find.text('Skip'), findsNothing);
    });

    testWidgets('the final page shows the monogram, not a body sentence', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap(() {}));
      await _swipeNext(tester);
      await _swipeNext(tester);
      await _swipeNext(tester);
      expect(find.byType(SvgPicture), findsOneWidget);
    });

    testWidgets('tapping Skip on page 1 calls onDone exactly once', (
      tester,
    ) async {
      var calls = 0;
      await tester.pumpWidget(_wrap(() => calls++));
      await tester.tap(find.text('Skip'));
      await tester.pump();
      expect(calls, 1);
    });

    testWidgets('tapping Skip on page 2 (mid-flow) also calls onDone', (
      tester,
    ) async {
      var calls = 0;
      await tester.pumpWidget(_wrap(() => calls++));
      await _swipeNext(tester);
      await tester.tap(find.text('Skip'));
      await tester.pump();
      expect(calls, 1);
    });

    testWidgets('tapping "Get started" on the final page calls onDone '
        'exactly once', (tester) async {
      var calls = 0;
      await tester.pumpWidget(_wrap(() => calls++));
      await _swipeNext(tester);
      await _swipeNext(tester);
      await _swipeNext(tester);
      await tester.tap(find.text('Get started'));
      await tester.pump();
      expect(calls, 1);
    });

    testWidgets('320px and 390px widths — no overflow across all four '
        'pages', (tester) async {
      for (final width in [320.0, 390.0]) {
        await tester.binding.setSurfaceSize(Size(width, 844));
        await tester.pumpWidget(_wrap(() {}));
        expect(tester.takeException(), isNull);
        await _swipeNext(tester);
        expect(tester.takeException(), isNull);
        await _swipeNext(tester);
        expect(tester.takeException(), isNull);
        await _swipeNext(tester);
        expect(tester.takeException(), isNull);
      }
      await tester.binding.setSurfaceSize(null);
    });
  });
}
