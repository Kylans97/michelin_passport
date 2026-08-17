// Covers PrivateChefsEmptyState/LoadingState/ErrorState/NotFoundState —
// exact copy (never "No chefs found", never "database", never a promised
// date, never Lucas), retry wiring, and the gold audit.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:michelin_passport/core/constants/app_colors.dart';
import 'package:michelin_passport/features/private_chefs/widgets/private_chef_states.dart';

Widget _wrap(Widget child) => MaterialApp(
  home: Scaffold(backgroundColor: AppColors.ivory, body: child),
);

void main() {
  group('PrivateChefsEmptyState', () {
    testWidgets('renders the editorial "coming soon" copy', (tester) async {
      await tester.pumpWidget(_wrap(const PrivateChefsEmptyState()));
      expect(find.text('Private Chefs are coming soon'), findsOneWidget);
      expect(
        find.textContaining(
          "We're curating a small collection of exceptional chefs",
        ),
        findsOneWidget,
      );
    });

    testWidgets('never says "No chefs found", "database", or mentions '
        'Lucas', (tester) async {
      await tester.pumpWidget(_wrap(const PrivateChefsEmptyState()));
      expect(find.textContaining('No chefs found'), findsNothing);
      expect(find.textContaining('database'), findsNothing);
      expect(find.textContaining('Lucas'), findsNothing);
    });

    testWidgets('gold audit', (tester) async {
      await tester.pumpWidget(_wrap(const PrivateChefsEmptyState()));
      final texts = tester.widgetList<Text>(find.byType(Text));
      for (final text in texts) {
        expect(text.style?.color, isNot(AppColors.gold));
      }
    });

    testWidgets('320px / 1.6x — no overflow', (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 844));
      await tester.pumpWidget(_wrap(const PrivateChefsEmptyState()));
      expect(tester.takeException(), isNull);
      await tester.binding.setSurfaceSize(null);

      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(1.6)),
            child: const Scaffold(
              backgroundColor: AppColors.ivory,
              body: PrivateChefsEmptyState(),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('PrivateChefsLoadingState', () {
    testWidgets('renders a spinner', (tester) async {
      await tester.pumpWidget(_wrap(const PrivateChefsLoadingState()));
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });
  });

  group('PrivateChefsErrorState', () {
    testWidgets('never surfaces a raw exception/error string', (tester) async {
      await tester.pumpWidget(_wrap(PrivateChefsErrorState(onRetry: () {})));
      expect(find.text('Unable to load Private Chefs'), findsOneWidget);
      expect(find.textContaining('Exception'), findsNothing);
      expect(find.textContaining('Supabase'), findsNothing);
      expect(find.textContaining('Postgrest'), findsNothing);
    });

    testWidgets('Retry fires onRetry', (tester) async {
      var retried = false;
      await tester.pumpWidget(
        _wrap(PrivateChefsErrorState(onRetry: () => retried = true)),
      );
      await tester.tap(find.text('Retry'));
      expect(retried, isTrue);
    });
  });

  group('PrivateChefNotFoundState', () {
    testWidgets('renders a restrained not-found message', (tester) async {
      await tester.pumpWidget(_wrap(const PrivateChefNotFoundState()));
      expect(find.text("This chef isn't available"), findsOneWidget);
    });

    testWidgets('never shows a stack trace or raw exception', (tester) async {
      await tester.pumpWidget(_wrap(const PrivateChefNotFoundState()));
      expect(find.textContaining('Exception'), findsNothing);
      expect(find.textContaining('#0'), findsNothing);
    });
  });
}
