// Covers OnboardingGate — the layer between AuthGate and the real app that
// decides whether THIS signed-in account still needs the first-run welcome
// flow. hasSeenWelcome/markWelcomeSeen are constructor-injected (same
// convention as every other Supabase-backed screen in this app), so the
// REAL widget is pumped directly.

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:michelin_passport/features/onboarding/onboarding_gate.dart';
import 'package:michelin_passport/features/onboarding/welcome_flow_screen.dart';

Widget _wrap(Widget child) => MaterialApp(home: child);

void main() {
  group('OnboardingGate', () {
    testWidgets('shows the branded splash while the check is pending', (
      tester,
    ) async {
      // A Completer that's never completed, not Future.delayed — a real
      // Timer left pending when the test tears down its widget tree trips
      // flutter_test's own "Timer is still pending" assertion; an
      // uncompleted Future involves no Timer at all.
      final neverResolves = Completer<bool>();
      addTearDown(() => neverResolves.complete(true));
      await tester.pumpWidget(
        _wrap(
          OnboardingGate(
            userId: 'user-1',
            hasSeenWelcome: (id) => neverResolves.future,
            child: const Text('App'),
          ),
        ),
      );
      // One pump only — the fetch above deliberately never resolves
      // within it, and BrandedSplash's own spinner animates forever, so
      // pumpAndSettle would never terminate here.
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('App'), findsNothing);
      expect(find.byType(WelcomeFlow), findsNothing);
    });

    testWidgets('an account that has already seen the welcome flow goes '
        'straight to the app, never WelcomeFlow', (tester) async {
      await tester.pumpWidget(
        _wrap(
          OnboardingGate(
            userId: 'user-1',
            hasSeenWelcome: (id) async => true,
            child: const Text('App'),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
      expect(find.text('App'), findsOneWidget);
      expect(find.byType(WelcomeFlow), findsNothing);
    });

    testWidgets('an account that has NOT seen it shows WelcomeFlow, not '
        'the app', (tester) async {
      await tester.pumpWidget(
        _wrap(
          OnboardingGate(
            userId: 'user-1',
            hasSeenWelcome: (id) async => false,
            child: const Text('App'),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
      expect(find.byType(WelcomeFlow), findsOneWidget);
      expect(find.text('App'), findsNothing);
    });

    testWidgets('completing WelcomeFlow calls markWelcomeSeen with the '
        'right userId, then shows the app', (tester) async {
      final markedFor = <String>[];
      await tester.pumpWidget(
        _wrap(
          OnboardingGate(
            userId: 'user-42',
            hasSeenWelcome: (id) async => false,
            markWelcomeSeen: (id) async => markedFor.add(id),
            child: const Text('App'),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
      expect(find.byType(WelcomeFlow), findsOneWidget);

      await tester.tap(find.text('Skip'));
      await tester.pump();
      await tester.pump();

      expect(markedFor, ['user-42']);
      expect(find.text('App'), findsOneWidget);
      expect(find.byType(WelcomeFlow), findsNothing);
    });

    testWidgets('a fetch failure defaults to "already seen" rather than '
        'permanently blocking app entry behind the splash', (tester) async {
      await tester.pumpWidget(
        _wrap(
          OnboardingGate(
            userId: 'user-1',
            hasSeenWelcome: (id) async => throw Exception('network error'),
            child: const Text('App'),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
      expect(find.text('App'), findsOneWidget);
      expect(find.byType(WelcomeFlow), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a markWelcomeSeen failure still lets the person into the '
        'app rather than trapping them on WelcomeFlow', (tester) async {
      await tester.pumpWidget(
        _wrap(
          OnboardingGate(
            userId: 'user-1',
            hasSeenWelcome: (id) async => false,
            markWelcomeSeen: (id) async => throw Exception('network error'),
            child: const Text('App'),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
      expect(find.byType(WelcomeFlow), findsOneWidget);

      await tester.tap(find.text('Skip'));
      await tester.pump();
      await tester.pump();

      expect(find.text('App'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a different userId (e.g. a different account signing in '
        'on the same device) triggers a fresh check', (tester) async {
      final checkedIds = <String>[];
      Widget build(String userId) => _wrap(
        OnboardingGate(
          userId: userId,
          hasSeenWelcome: (id) async {
            checkedIds.add(id);
            return id == 'user-1'; // user-1 already seen, user-2 has not
          },
          child: const Text('App'),
        ),
      );

      await tester.pumpWidget(build('user-1'));
      await tester.pump();
      await tester.pump();
      expect(find.text('App'), findsOneWidget);

      await tester.pumpWidget(build('user-2'));
      await tester.pump();
      await tester.pump();
      expect(find.byType(WelcomeFlow), findsOneWidget);
      expect(checkedIds, ['user-1', 'user-2']);
    });
  });
}
