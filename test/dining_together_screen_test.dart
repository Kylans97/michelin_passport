// Covers DiningTogetherScreen (Community Typography + Dining Together
// Refinement) — an editorial concept/preview page, no Supabase
// dependency at all, so the real widget is pumped directly.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:michelin_passport/core/constants/app_colors.dart';
import 'package:michelin_passport/core/widgets/editorial_back_button.dart';
import 'package:michelin_passport/features/community/dining_together_screen.dart';

void main() {
  group('DiningTogetherScreen', () {
    testWidgets('renders the title and lead line, ivory, never gold', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(home: DiningTogetherScreen()),
      );
      await tester.pumpAndSettle();
      final title = tester.widget<Text>(find.text('Dining Together'));
      expect(title.style?.color, AppColors.ivory);
      expect(title.style?.color, isNot(AppColors.gold));
      final lead = tester.widget<Text>(
        find.text('Great tables are better shared.'),
      );
      expect(lead.style?.color, AppColors.ivory);
    });

    testWidgets('owns a Scaffold + back button — a pushed screen', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(home: DiningTogetherScreen()),
      );
      await tester.pumpAndSettle();
      expect(find.byType(Scaffold), findsOneWidget);
      expect(find.byType(EditorialBackButton), findsOneWidget);
    });

    testWidgets('explains the concept — editorial copy present', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(home: DiningTogetherScreen()),
      );
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Mantelier is built for people who travel'),
        findsOneWidget,
      );
      expect(
        find.textContaining('discover other people who want to experience'),
        findsOneWidget,
      );
      expect(
        find.textContaining('Finding others interested in the same '
            'restaurant'),
        findsOneWidget,
      );
    });

    testWidgets('shows a restrained "Coming soon" at the bottom', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(home: DiningTogetherScreen()),
      );
      await tester.pumpAndSettle();
      expect(find.text('Coming soon'), findsOneWidget);
    });

    testWidgets('contains no functional matching/chat/booking controls — '
        'no fake waitlist, no fake matching button, no fake member '
        'profiles', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: DiningTogetherScreen()),
      );
      await tester.pumpAndSettle();
      expect(find.byType(TextField), findsNothing);
      expect(find.byType(TextFormField), findsNothing);
      expect(find.byType(ElevatedButton), findsNothing);
      expect(find.byType(TextButton), findsNothing);
      expect(find.byType(OutlinedButton), findsNothing);
      expect(find.byType(CircleAvatar), findsNothing);
    });

    testWidgets('no overflow at 320px / 1.6x text scale', (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 844));
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(320, 844),
              textScaler: TextScaler.linear(1.6),
            ),
            child: const DiningTogetherScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.binding.setSurfaceSize(null);
    });
  });
}
