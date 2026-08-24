// Covers NewsScreen (Navigation & Information Architecture V2's third
// primary destination). Unlike most tab bodies in this app, NewsScreen has
// no Supabase dependency at all — pure static content — so it's pumped
// directly rather than mirrored.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:michelin_passport/core/constants/app_colors.dart';
import 'package:michelin_passport/core/widgets/cs_coming_soon.dart';
import 'package:michelin_passport/features/news/news_screen.dart';

void main() {
  group('NewsScreen', () {
    testWidgets('renders the title and subtitle, ivory/secondary, never '
        'gold', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: NewsScreen()));
      final title = tester.widget<Text>(find.text('News'));
      expect(title.style?.color, AppColors.ivory);
      expect(title.style?.color, isNot(AppColors.gold));
      final subtitle = tester.widget<Text>(
        find.text('Stories, interviews and the world of Chasing Stars.'),
      );
      expect(subtitle.style?.color, AppColors.secondaryOnDark);
    });

    testWidgets('no own Scaffold — a tab body, matching Explore/Passport', (
      tester,
    ) async {
      await tester.pumpWidget(const MaterialApp(home: NewsScreen()));
      expect(find.byType(Scaffold), findsNothing);
      expect(
        find.byWidgetPredicate(
          (w) => w is ColoredBox && w.color == AppColors.deepGreen,
        ),
        findsOneWidget,
      );
    });

    testWidgets('shows a restrained Coming Soon state — no fake articles', (
      tester,
    ) async {
      await tester.pumpWidget(const MaterialApp(home: NewsScreen()));
      expect(find.byType(CsComingSoon), findsOneWidget);
      expect(find.text('Coming soon'), findsOneWidget);
      final comingSoon = tester.widget<CsComingSoon>(
        find.byType(CsComingSoon),
      );
      expect(comingSoon.icon, Icons.article_outlined);
      expect(tester.takeException(), isNull);
    });
  });
}
