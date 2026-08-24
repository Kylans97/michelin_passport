// Covers PassportScreen's persistent shell (Passport Unified Experience
// V1) — Passport/Wishlist/Ranking/Trips are one continuous page with a
// local tab bar switching the content region in place, never
// Navigator.push, never a back button between them. PassportScreen
// injects passportBody/wishlistBody/rankingBody/tripsBody (see its own
// doc comment) — the same constructor-injection seam this app's other
// Supabase-eager screens already use — so the REAL widget is pumped
// directly with fake bodies, no mirror of its build() logic.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:michelin_passport/core/constants/app_colors.dart';
import 'package:michelin_passport/features/passport/passport_screen.dart';

/// A fake subsection body that records how many times it was actually
/// constructed/initialized — proves lazy construction (never built until
/// first visited) and state preservation across repeated tab switches
/// (never rebuilt on a revisit) far more rigorously than a plain Text
/// widget could.
class _CountingBody extends StatefulWidget {
  final String label;
  final ValueNotifier<int> initCount;
  const _CountingBody({required this.label, required this.initCount});

  @override
  State<_CountingBody> createState() => _CountingBodyState();
}

class _CountingBodyState extends State<_CountingBody> {
  @override
  void initState() {
    super.initState();
    widget.initCount.value++;
  }

  @override
  Widget build(BuildContext context) => Text(widget.label);
}

class _PushRecordingObserver extends NavigatorObserver {
  int pushCount = 0;

  @override
  void didPush(Route route, Route? previousRoute) {
    pushCount++;
    super.didPush(route, previousRoute);
  }
}

class _Harness {
  final ValueNotifier<int> passportInits = ValueNotifier(0);
  final ValueNotifier<int> wishlistInits = ValueNotifier(0);
  final ValueNotifier<int> rankingInits = ValueNotifier(0);
  final ValueNotifier<int> tripsInits = ValueNotifier(0);
  final observer = _PushRecordingObserver();

  Widget wrap({double width = 390}) => MaterialApp(
    navigatorObservers: [observer],
    home: Scaffold(
      body: SizedBox(
        width: width,
        child: PassportScreen(
          passportBody: _CountingBody(
            label: 'FAKE PASSPORT BODY',
            initCount: passportInits,
          ),
          wishlistBody: _CountingBody(
            label: 'FAKE WISHLIST BODY',
            initCount: wishlistInits,
          ),
          rankingBody: _CountingBody(
            label: 'FAKE RANKING BODY',
            initCount: rankingInits,
          ),
          tripsBody: _CountingBody(
            label: 'FAKE TRIPS BODY',
            initCount: tripsInits,
          ),
        ),
      ),
    ),
  );
}

int _activeIndex(WidgetTester tester) =>
    tester.widget<IndexedStack>(find.byType(IndexedStack)).index!;

// The tab bar's own SingleChildScrollView safety net (see
// _PassportLocalTabBar's doc comment) means a tab past the visible edge
// needs scrolling into view before it can be tapped, exactly as a real
// user would need to scroll it — ensureVisible does that.
Future<void> _tapTab(WidgetTester tester, String label) async {
  final finder = find.text(label);
  await tester.ensureVisible(finder);
  await tester.pump();
  await tester.tap(finder);
}

void main() {
  group('PassportScreen — Passport default', () {
    testWidgets('shows the header, PASSPORT active, and the passport body — '
        'the other three bodies are not built yet (lazy)', (tester) async {
      final h = _Harness();
      await tester.pumpWidget(h.wrap());

      expect(find.text('Passport'), findsOneWidget);
      expect(
        find.text('Your collection of remarkable places.'),
        findsOneWidget,
      );
      expect(find.text('PASSPORT'), findsOneWidget);
      expect(find.text('FAKE PASSPORT BODY'), findsOneWidget);
      expect(_activeIndex(tester), 0);

      expect(h.passportInits.value, 1);
      expect(h.wishlistInits.value, 0);
      expect(h.rankingInits.value, 0);
      expect(h.tripsInits.value, 0);
      expect(tester.takeException(), isNull);
    });
  });

  group('PassportScreen — subsection switching', () {
    testWidgets('tapping WISHLIST swaps only the content region — the '
        'header and tab bar persist, and no back button ever appears', (
      tester,
    ) async {
      final h = _Harness();
      await tester.pumpWidget(h.wrap());

      await _tapTab(tester, 'WISHLIST');
      await tester.pump();

      expect(find.text('Passport'), findsOneWidget); // header persists
      expect(
        find.text('Your collection of remarkable places.'),
        findsOneWidget,
      );
      expect(find.text('PASSPORT'), findsOneWidget); // tab bar persists
      expect(find.text('WISHLIST'), findsOneWidget);
      expect(_activeIndex(tester), 1);
      expect(h.wishlistInits.value, 1);

      expect(find.byType(BackButton), findsNothing);
      expect(find.byIcon(Icons.arrow_back_rounded), findsNothing);
      expect(find.byIcon(Icons.arrow_back_ios_rounded), findsNothing);
      expect(
        h.observer.pushCount,
        1,
      ); // only the initial route — never an additional push
      expect(tester.takeException(), isNull);
    });

    testWidgets('tapping RANKING swaps the content region the same way — '
        'no back button, no push', (tester) async {
      final h = _Harness();
      await tester.pumpWidget(h.wrap());

      await _tapTab(tester, 'RANKING');
      await tester.pump();

      expect(find.text('Passport'), findsOneWidget);
      expect(_activeIndex(tester), 2);
      expect(h.rankingInits.value, 1);
      expect(find.byType(BackButton), findsNothing);
      expect(h.observer.pushCount, 1);
      expect(tester.takeException(), isNull);
    });

    testWidgets('tapping TRIPS swaps the content region the same way — no '
        'back button, no push', (tester) async {
      final h = _Harness();
      await tester.pumpWidget(h.wrap());

      await _tapTab(tester, 'TRIPS');
      await tester.pump();

      expect(find.text('Passport'), findsOneWidget);
      expect(_activeIndex(tester), 3);
      expect(h.tripsInits.value, 1);
      expect(find.byType(BackButton), findsNothing);
      expect(h.observer.pushCount, 1);
      expect(tester.takeException(), isNull);
    });
  });

  group('PassportScreen — repeated switching', () {
    testWidgets('switching Passport → Wishlist → Ranking → Trips → Passport '
        '→ Wishlist repeatedly never re-initializes an already-visited '
        'body (state survives), never pushes a route, never duplicates the '
        'header, and never crashes', (tester) async {
      final h = _Harness();
      await tester.pumpWidget(h.wrap());

      for (final label in [
        'WISHLIST',
        'RANKING',
        'TRIPS',
        'PASSPORT',
        'WISHLIST',
        'PASSPORT',
      ]) {
        await _tapTab(tester, label);
        await tester.pump();
      }

      // Each body was constructed exactly once despite multiple revisits.
      expect(h.passportInits.value, 1);
      expect(h.wishlistInits.value, 1);
      expect(h.rankingInits.value, 1);
      expect(h.tripsInits.value, 1);

      // Ends back on Passport.
      expect(_activeIndex(tester), 0);
      expect(find.text('Passport'), findsOneWidget); // never duplicated
      expect(
        find.text('Your collection of remarkable places.'),
        findsOneWidget,
      );

      expect(h.observer.pushCount, 1); // still just the initial route
      expect(tester.takeException(), isNull);
    });
  });

  group('PassportScreen — local tab bar visual hierarchy', () {
    testWidgets('the active tab is ivory + bold; inactive tabs are muted — '
        'and this swaps correctly when the selection changes', (tester) async {
      final h = _Harness();
      await tester.pumpWidget(h.wrap());

      Text styleOf(String label) => tester.widget<Text>(find.text(label));

      expect(styleOf('PASSPORT').style?.color, AppColors.ivory);
      expect(styleOf('PASSPORT').style?.fontWeight, FontWeight.w600);
      expect(styleOf('WISHLIST').style?.color, AppColors.secondaryOnDark);
      expect(styleOf('WISHLIST').style?.fontWeight, FontWeight.w500);

      await _tapTab(tester, 'WISHLIST');
      await tester.pump();

      expect(styleOf('WISHLIST').style?.color, AppColors.ivory);
      expect(styleOf('WISHLIST').style?.fontWeight, FontWeight.w600);
      expect(styleOf('PASSPORT').style?.color, AppColors.secondaryOnDark);
      expect(styleOf('PASSPORT').style?.fontWeight, FontWeight.w500);
    });

    for (final width in [320.0, 375.0, 390.0, 430.0]) {
      testWidgets('all four tabs render, in order, no wrapping/overflow at '
          '${width.toInt()}px', (tester) async {
        final h = _Harness();
        await tester.pumpWidget(h.wrap(width: width));

        final labels = ['PASSPORT', 'WISHLIST', 'RANKING', 'TRIPS'];
        for (final label in labels) {
          expect(find.text(label), findsOneWidget, reason: label);
        }
        final ys = labels
            .map((l) => tester.getTopLeft(find.text(l)).dy)
            .toSet();
        expect(ys.length, 1, reason: 'all four sit on the same row');
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('spreads across the available width rather than clustering '
        'left — the gap between Passport and Trips grows with the '
        'screen width (spaceBetween, not a fixed gap)', (tester) async {
      final h390 = _Harness();
      await tester.pumpWidget(h390.wrap(width: 390));
      final tripsX390 = tester.getTopLeft(find.text('TRIPS')).dx;

      final h430 = _Harness();
      await tester.pumpWidget(h430.wrap(width: 430));
      final tripsX430 = tester.getTopLeft(find.text('TRIPS')).dx;

      expect(
        tripsX430,
        greaterThan(tripsX390),
        reason: 'TRIPS should sit further right on a wider screen',
      );
    });
  });

  group('PassportScreen — map action', () {
    testWidgets('the map button is present and restrained (no gold)', (
      tester,
    ) async {
      final h = _Harness();
      await tester.pumpWidget(h.wrap());
      final icon = tester.widget<Icon>(find.byIcon(Icons.map_outlined));
      expect(icon.color, isNot(AppColors.gold));
      expect(tester.takeException(), isNull);
    });
  });
}
