// PROFILE PRIVACY & DISCOVERABILITY V1: covers PrivacySettingsScreen — the
// "Allow members to find me" toggle. Both loadDiscoverable/setDiscoverable
// are constructor-injected (hand-rolled fakes, no mocking framework,
// mirroring DeleteAccountScreen's own identical pattern), so — unlike most
// Supabase-eager screens in this app — the REAL widget is pumped directly;
// it never touches Supabase unless both injected callbacks are omitted
// (production default only).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:michelin_passport/core/constants/app_colors.dart';
import 'package:michelin_passport/features/profile/privacy_settings_screen.dart';

Widget _wrap({
  required Future<bool> Function() loadDiscoverable,
  required Future<void> Function(bool value) setDiscoverable,
}) => MaterialApp(
  home: PrivacySettingsScreen(
    loadDiscoverable: loadDiscoverable,
    setDiscoverable: setDiscoverable,
  ),
);

void main() {
  group('PrivacySettingsScreen — load', () {
    testWidgets('shows a loading indicator, then the toggle reflecting the '
        'backend value (true)', (tester) async {
      await tester.pumpWidget(
        _wrap(
          loadDiscoverable: () async => true,
          setDiscoverable: (_) async {},
        ),
      );
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      await tester.pumpAndSettle();
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text('Allow members to find me'), findsOneWidget);
      final toggle = tester.widget<Switch>(find.byType(Switch));
      expect(toggle.value, isTrue);
    });

    testWidgets('reflects the backend value (false)', (tester) async {
      await tester.pumpWidget(
        _wrap(
          loadDiscoverable: () async => false,
          setDiscoverable: (_) async {},
        ),
      );
      await tester.pumpAndSettle();
      final toggle = tester.widget<Switch>(find.byType(Switch));
      expect(toggle.value, isFalse);
    });

    testWidgets('shows the exact supporting copy — never calls the profile '
        '"private" or implies content is hidden', (tester) async {
      await tester.pumpWidget(
        _wrap(
          loadDiscoverable: () async => true,
          setDiscoverable: (_) async {},
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.text(
          'Let other Chasing Stars members find your name and username '
          'in Find Friends.',
        ),
        findsOneWidget,
      );
      expect(
        find.text(
          'Your visits, wishlist and trips keep their existing privacy '
          'settings.',
        ),
        findsOneWidget,
      );
      expect(find.textContaining('private'), findsNothing);
    });

    testWidgets('load failure shows a restrained error with a working '
        'retry', (tester) async {
      var attempt = 0;
      await tester.pumpWidget(
        _wrap(
          loadDiscoverable: () async {
            attempt++;
            if (attempt == 1) throw Exception('network down');
            return true;
          },
          setDiscoverable: (_) async {},
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.text('Could not load your privacy settings'),
        findsOneWidget,
      );
      expect(find.byType(Switch), findsNothing);
      expect(find.textContaining('Exception'), findsNothing);

      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(find.byType(Switch), findsOneWidget);
      expect(
        find.text('Could not load your privacy settings'),
        findsNothing,
      );
    });
  });

  group('PrivacySettingsScreen — toggle', () {
    testWidgets('true → false: calls setDiscoverable(false) exactly once '
        'and the switch reflects the new state', (tester) async {
      final calls = <bool>[];
      await tester.pumpWidget(
        _wrap(
          loadDiscoverable: () async => true,
          setDiscoverable: (value) async => calls.add(value),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();
      expect(calls, [false]);
      final toggle = tester.widget<Switch>(find.byType(Switch));
      expect(toggle.value, isFalse);
    });

    testWidgets('false → true: calls setDiscoverable(true) exactly once', (
      tester,
    ) async {
      final calls = <bool>[];
      await tester.pumpWidget(
        _wrap(
          loadDiscoverable: () async => false,
          setDiscoverable: (value) async => calls.add(value),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();
      expect(calls, [true]);
      final toggle = tester.widget<Switch>(find.byType(Switch));
      expect(toggle.value, isTrue);
    });

    testWidgets('update failure leaves the switch showing the last '
        'CONFIRMED value, never the attempted one — no incorrect '
        'persisted state is ever shown', (tester) async {
      await tester.pumpWidget(
        _wrap(
          loadDiscoverable: () async => true,
          setDiscoverable: (_) async => throw Exception('write failed'),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();

      final toggle = tester.widget<Switch>(find.byType(Switch));
      expect(toggle.value, isTrue); // unchanged — write never succeeded
      expect(find.text('Could not update. Please try again.'), findsOneWidget);
      expect(find.textContaining('Exception'), findsNothing);
    });

    testWidgets('after an update failure, a subsequent toggle can still '
        'succeed', (tester) async {
      var attempt = 0;
      final calls = <bool>[];
      await tester.pumpWidget(
        _wrap(
          loadDiscoverable: () async => true,
          setDiscoverable: (value) async {
            attempt++;
            if (attempt == 1) throw Exception('transient');
            calls.add(value);
          },
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();
      expect(calls, isEmpty);

      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();
      expect(calls, [false]);
      final toggle = tester.widget<Switch>(find.byType(Switch));
      expect(toggle.value, isFalse);
      expect(
        find.text('Could not update. Please try again.'),
        findsNothing,
      );
    });

    testWidgets('reopening the screen (fresh load) shows the persisted '
        'value, not any locally-remembered one', (tester) async {
      // Simulates "leave and reopen Settings" — a brand-new screen
      // instance with its own fresh _load(), exactly like a real
      // Navigator push/pop/push would produce.
      await tester.pumpWidget(
        _wrap(
          loadDiscoverable: () async => false,
          setDiscoverable: (_) async {},
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.widget<Switch>(find.byType(Switch)).value, isFalse);

      // Pump an unrelated root first to fully unmount the previous screen
      // instance (matching "the user left and reopened Settings" — a
      // genuinely new State, not the same one receiving updated props).
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(
        _wrap(
          loadDiscoverable: () async => true,
          setDiscoverable: (_) async {},
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.widget<Switch>(find.byType(Switch)).value, isTrue);
    });
  });

  group('PrivacySettingsScreen — visual', () {
    testWidgets('deep-green canvas, ivory title, no gold anywhere', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          loadDiscoverable: () async => true,
          setDiscoverable: (_) async {},
        ),
      );
      await tester.pumpAndSettle();
      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
      expect(scaffold.backgroundColor, AppColors.deepGreen);
      final title = tester.widget<Text>(find.text('Privacy'));
      expect(title.style?.color, AppColors.ivory);
      for (final text in tester.widgetList<Text>(find.byType(Text))) {
        expect(text.style?.color, isNot(AppColors.gold));
      }
    });
  });
}
