// Covers NewsScreen (News V1) — a real list now, not the old static
// "Coming soon" placeholder. [NewsScreen.loadArticles] is the DI seam
// (same zero-argument-closure convention as PrivacySettingsScreen's own
// loadDiscoverable/setDiscoverable) that lets this be pumped without a
// live Supabase session.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:michelin_passport/core/constants/app_colors.dart';
import 'package:michelin_passport/features/news/news_article_detail_screen.dart';
import 'package:michelin_passport/features/news/news_screen.dart';
import 'package:michelin_passport/models/news_article.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

NewsArticle _article({
  String id = 'a1',
  String title = 'A Story',
  String? imageUrl,
  String? linkUrl,
  DateTime? publishedAt,
}) => NewsArticle(
  id: id,
  title: title,
  body: 'Body text.',
  imageUrl: imageUrl,
  linkUrl: linkUrl,
  publishedAt: publishedAt ?? DateTime(2026, 9, 1),
);

void main() {
  // The "tap opens NewsArticleDetailScreen" test below actually builds
  // that screen, whose initState fires a real SupabaseAnalyticsService
  // call (see that screen's own doc comment) — same
  // Supabase.instance.client-eager limitation as everywhere else in this
  // app's Supabase-backed screens. Faked exactly like
  // friend_profile_screen_navigation_test.dart's own setup: EmptyLocalStorage
  // skips SharedPreferences/platform channels, a MockClient never makes a
  // real network call.
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'https://test.supabase.co',
      publishableKey: 'test-anon-key',
      authOptions: const FlutterAuthClientOptions(
        localStorage: EmptyLocalStorage(),
        autoRefreshToken: false,
        detectSessionInUri: false,
      ),
      httpClient: MockClient(
        (request) async => http.Response('{}', 200, request: request),
      ),
    );
  });

  group('NewsScreen', () {
    testWidgets('renders the title and subtitle, ivory/secondary, never '
        'gold', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: NewsScreen(loadArticles: () async => const []),
        ),
      );
      final title = tester.widget<Text>(find.text('News'));
      expect(title.style?.color, AppColors.ivory);
      expect(title.style?.color, isNot(AppColors.gold));
      final subtitle = tester.widget<Text>(
        find.text('Stories, interviews and the world of Mantelier.'),
      );
      expect(subtitle.style?.color, AppColors.secondaryOnDark);
    });

    testWidgets('no own Scaffold — a tab body, matching Explore/Passport', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: NewsScreen(loadArticles: () async => const []),
        ),
      );
      await tester.pump();
      expect(find.byType(Scaffold), findsNothing);
      expect(
        find.byWidgetPredicate(
          (w) => w is ColoredBox && w.color == AppColors.deepGreen,
        ),
        findsOneWidget,
      );
    });

    testWidgets('no articles -> a quiet empty state, never fabricated '
        'content', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: NewsScreen(loadArticles: () async => const []),
        ),
      );
      await tester.pump();
      expect(find.text('No stories yet.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('renders one card per article, title and formatted date, '
        'newest first as returned by the repository', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: NewsScreen(
            loadArticles: () async => [
              _article(
                id: 'a1',
                title: 'First',
                publishedAt: DateTime(2026, 9, 1),
              ),
              _article(
                id: 'a2',
                title: 'Second',
                publishedAt: DateTime(2026, 8, 1),
              ),
            ],
          ),
        ),
      );
      await tester.pump();
      expect(find.text('First'), findsOneWidget);
      expect(find.text('Second'), findsOneWidget);
      expect(find.text('1 September 2026'), findsOneWidget);
      expect(find.text('1 August 2026'), findsOneWidget);
    });

    testWidgets('an article with no image renders title+date only — no '
        'placeholder box, no half card', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: NewsScreen(
            loadArticles: () async => [_article(imageUrl: null)],
          ),
        ),
      );
      await tester.pump();
      expect(find.byType(Image), findsNothing);
      expect(find.byType(AspectRatio), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('tapping a card opens NewsArticleDetailScreen for that '
        'exact article', (tester) async {
      final article = _article(id: 'a1', title: 'Tap me');
      await tester.pumpWidget(
        MaterialApp(
          home: NewsScreen(loadArticles: () async => [article]),
        ),
      );
      await tester.pump();
      await tester.tap(find.text('Tap me'));
      await tester.pumpAndSettle();
      expect(find.byType(NewsArticleDetailScreen), findsOneWidget);
      final pushed = tester.widget<NewsArticleDetailScreen>(
        find.byType(NewsArticleDetailScreen),
      );
      expect(pushed.article.id, 'a1');
    });

    testWidgets('a load failure shows a retry state, never crashes', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: NewsScreen(
            loadArticles: () async => throw Exception('network down'),
          ),
        ),
      );
      await tester.pump();
      expect(find.text('Could not load News'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
