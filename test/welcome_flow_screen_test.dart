// Covers WelcomeFlow — the six-page first-run carousel. No Supabase
// knowledge of its own (see its own doc comment); onDone, firstName and
// memberNumber are plain constructor values, so this is pumped directly.
//
// Most tests pump with reduced motion on: the globe turns forever and the
// event drawings cross-fade on a timer, so pumpAndSettle would otherwise
// never settle. One test runs with motion on, pumping by time instead.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:michelin_passport/features/onboarding/welcome_flow_screen.dart';

Widget _wrap(
  VoidCallback onDone, {
  String? firstName,
  int? memberNumber,
  bool reduceMotion = true,
}) => MaterialApp(
  home: Builder(
    builder: (context) => MediaQuery(
      data: MediaQuery.of(context).copyWith(disableAnimations: reduceMotion),
      child: WelcomeFlow(
        onDone: onDone,
        firstName: firstName,
        memberNumber: memberNumber,
      ),
    ),
  ),
);

Future<void> _swipeNext(WidgetTester tester) async {
  await tester.drag(find.byType(PageView), const Offset(-600, 0));
  await tester.pumpAndSettle();
}

Future<void> _toLastPage(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    await _swipeNext(tester);
  }
}

const _titles = [
  'The tables, rooms and evenings worth travelling for',
  'Some evenings only happen once',
  'Know where to go',
  'Plan the journey',
  "Keep what you've tasted",
];

void main() {
  group('WelcomeFlow', () {
    testWidgets('opens on the arrival page with a visible Skip and Next', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap(() {}));
      await tester.pumpAndSettle();
      expect(find.text(_titles.first), findsOneWidget);
      expect(find.text('Skip'), findsOneWidget);
      expect(find.text('Next'), findsOneWidget);
    });

    testWidgets('swiping moves through all six pages in order', (tester) async {
      await tester.pumpWidget(_wrap(() {}));
      await tester.pumpAndSettle();
      for (final title in _titles) {
        expect(find.text(title), findsOneWidget);
        expect(find.text('Skip'), findsOneWidget);
        await _swipeNext(tester);
      }
      expect(find.text('Your Passport is ready'), findsOneWidget);
      expect(find.text('Begin'), findsOneWidget);
    });

    testWidgets('Next advances one page', (tester) async {
      await tester.pumpWidget(_wrap(() {}));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      expect(find.text('Some evenings only happen once'), findsOneWidget);
    });

    testWidgets('the last page greets the member by first name and shows '
        'their member number on the cover', (tester) async {
      await tester.pumpWidget(
        _wrap(() {}, firstName: 'Sophie', memberNumber: 128),
      );
      await tester.pumpAndSettle();
      await _toLastPage(tester);
      expect(find.text('Your Passport is ready, Sophie'), findsOneWidget);
      expect(find.text('NO. 128'), findsOneWidget);
      expect(
        find.byWidgetPredicate(
          (w) =>
              w is Semantics &&
              w.properties.label == 'Your Passport, number 128',
        ),
        findsOneWidget,
      );
    });

    testWidgets('without a name or number the last page invents neither', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap(() {}, firstName: '  '));
      await tester.pumpAndSettle();
      await _toLastPage(tester);
      expect(find.text('Your Passport is ready'), findsOneWidget);
      expect(find.text('NO. —'), findsOneWidget);
    });

    testWidgets('Skip and Next are hidden on the last page; Begin is the '
        'only way on', (tester) async {
      await tester.pumpWidget(_wrap(() {}));
      await tester.pumpAndSettle();
      await _toLastPage(tester);
      expect(find.text('Skip'), findsNothing);
      expect(find.text('Next'), findsNothing);
      expect(find.text('Begin'), findsOneWidget);
    });

    testWidgets('tapping Skip on page 1 calls onDone exactly once', (
      tester,
    ) async {
      var calls = 0;
      await tester.pumpWidget(_wrap(() => calls++));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Skip'));
      await tester.pump();
      expect(calls, 1);
    });

    testWidgets('tapping Skip mid-flow also calls onDone', (tester) async {
      var calls = 0;
      await tester.pumpWidget(_wrap(() => calls++));
      await tester.pumpAndSettle();
      await _swipeNext(tester);
      await _swipeNext(tester);
      await tester.tap(find.text('Skip'));
      await tester.pump();
      expect(calls, 1);
    });

    testWidgets('tapping Begin on the last page calls onDone exactly once', (
      tester,
    ) async {
      var calls = 0;
      await tester.pumpWidget(_wrap(() => calls++));
      await tester.pumpAndSettle();
      await _toLastPage(tester);
      await tester.tap(find.text('Begin'));
      await tester.pump();
      expect(calls, 1);
    });

    testWidgets('no copy uses a dash (product owner, 2026-11-20)', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap(() {}, firstName: 'Sophie'));
      await tester.pumpAndSettle();
      for (var page = 0; page < 6; page++) {
        for (final text in tester.widgetList<Text>(find.byType(Text))) {
          final data = text.data ?? '';
          // The cover's own "NO. —" for an unnumbered account is the
          // Passport's, not this flow's copy.
          if (data.startsWith('NO.')) continue;
          expect(data, isNot(contains('—')), reason: data);
          expect(data, isNot(contains('–')), reason: data);
          expect(data, isNot(contains('-')), reason: data);
        }
        if (page < 5) await _swipeNext(tester);
      }
    });

    testWidgets('with motion on, every page still builds and swipes '
        'cleanly', (tester) async {
      await tester.pumpWidget(_wrap(() {}, reduceMotion: false));
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(seconds: 5));
        await tester.drag(find.byType(PageView), const Offset(-600, 0));
        await tester.pump(const Duration(seconds: 1));
        expect(tester.takeException(), isNull);
      }
      expect(find.text('Begin'), findsOneWidget);
    });

    testWidgets('small and large phones: no overflow on any page', (
      tester,
    ) async {
      for (final size in const [
        Size(320, 640),
        Size(375, 667),
        Size(390, 844),
        Size(440, 956),
      ]) {
        await tester.binding.setSurfaceSize(size);
        await tester.pumpWidget(_wrap(() {}, firstName: 'Maximiliaan'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: '$size page 1');
        for (var page = 2; page <= 6; page++) {
          await _swipeNext(tester);
          expect(tester.takeException(), isNull, reason: '$size page $page');
        }
      }
      await tester.binding.setSurfaceSize(null);
    });
  });
}
