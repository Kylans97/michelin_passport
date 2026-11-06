// News in three parts and the article page with a photo band, Q&A and
// inline photos (20261101270000_add_news_sections_and_photos.sql).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:michelin_passport/core/analytics/analytics_service.dart';
import 'package:michelin_passport/data/repositories/news_repository.dart';
import 'package:michelin_passport/features/news/news_article_detail_screen.dart';
import 'package:michelin_passport/features/news/news_screen.dart';
import 'package:michelin_passport/features/news/widgets/news_mentions_section.dart';
import 'package:michelin_passport/models/news_article.dart';

NewsArticle _article({
  String id = 'a1',
  String title = 'A Story',
  String body = 'Body text.',
  NewsSection section = NewsSection.story,
  DateTime? publishedAt,
}) => NewsArticle(
  id: id,
  title: title,
  body: body,
  section: section,
  publishedAt: publishedAt ?? DateTime(2026, 9, 1),
);

NewsArticlePhoto _photo(
  String id,
  int after, {
  int order = 0,
  String? caption,
}) => NewsArticlePhoto(
  id: id,
  imageUrl: 'https://example.test/$id.jpg',
  afterParagraph: after,
  displayOrder: order,
  caption: caption,
);

const _noVenues = NewsArticleVenues(restaurants: [], hotels: [], chefs: []);

void main() {
  group('NewsArticle', () {
    test('section reads from the wire, unknown values as a story', () {
      expect(NewsSection.fromWire('about'), NewsSection.about);
      expect(NewsSection.fromWire('interview'), NewsSection.interview);
      expect(NewsSection.fromWire('story'), NewsSection.story);
      expect(NewsSection.fromWire(null), NewsSection.story);
      expect(NewsSection.fromWire('podcast'), NewsSection.story);
      final parsed = NewsArticle.fromJson({
        'id': 'x',
        'title': 'T',
        'body': 'B',
        'published_at': '2026-11-02T10:00:00Z',
        'section': 'interview',
      });
      expect(parsed.section, NewsSection.interview);
    });

    test('a card shows card_title, or the title when there is none', () {
      final parsed = NewsArticle.fromJson({
        'id': 'x',
        'title': 'Fine Dining, Wherever You Are: A Conversation',
        'card_title': 'Fine Dining, Wherever You Are',
        'body': 'B',
        'published_at': '2026-11-06T10:00:00Z',
      });
      expect(parsed.title, 'Fine Dining, Wherever You Are: A Conversation');
      expect(parsed.shortTitle, 'Fine Dining, Wherever You Are');
      expect(_article(title: 'Only one').shortTitle, 'Only one');
      expect(
        NewsArticle(
          id: 'y',
          title: 'Kept',
          cardTitle: '  ',
          body: 'B',
          publishedAt: DateTime(2026, 11, 6),
        ).shortTitle,
        'Kept',
      );
    });

    test('blocks read the Q: and > prefixes, everything else is text', () {
      final a = _article(
        body:
            'Intro.\n\nQ: Where does a menu start?\n\nWith a product.\n\n'
            '> Every plate starts at the market.\n\nQuiet text with Q: inside.',
      );
      expect(a.blocks.map((b) => b.kind).toList(), [
        NewsBlockKind.text,
        NewsBlockKind.question,
        NewsBlockKind.text,
        NewsBlockKind.quote,
        NewsBlockKind.text,
      ]);
      expect(a.blocks[1].text, 'Where does a menu start?');
      expect(a.blocks[3].text, 'Every plate starts at the market.');
      expect(a.blocks[4].text, 'Quiet text with Q: inside.');
    });

    test('photos group by place and order; past the end goes to the end', () {
      final groups = groupNewsPhotos([
        _photo('c', 2, order: 1),
        _photo('a', 0),
        _photo('b', 2),
        _photo('z', 9),
      ], 3);
      expect(groups.keys.toList(), [0, 2, 3]);
      expect(groups[2]!.map((p) => p.id), ['b', 'c']);
      expect(groups[3]!.map((p) => p.id), ['z']);
    });
  });

  group('NewsScreen', () {
    testWidgets('Why Mantelier on top, then Interviews, then Stories', (
      tester,
    ) async {
      // A phone-tall surface, so the lazily built list builds all three.
      tester.view.physicalSize = const Size(1170, 2532);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: NewsScreen(
            loadArticles: () async => [
              _article(id: 's', title: 'A story'),
              _article(
                id: 'i',
                title: 'An interview',
                section: NewsSection.interview,
              ),
              _article(
                id: 'w',
                title: 'Why we built it',
                body: 'The reason, first.',
                section: NewsSection.about,
              ),
            ],
          ),
        ),
      );
      await tester.pump();
      final why = tester.getTopLeft(find.text('WHY MANTELIER')).dy;
      final interviews = tester.getTopLeft(find.text('INTERVIEWS')).dy;
      final stories = tester.getTopLeft(find.text('STORIES')).dy;
      expect(why, lessThan(interviews));
      expect(interviews, lessThan(stories));
      expect(find.text('Why we built it'), findsOneWidget);
      expect(find.text('The reason, first.'), findsOneWidget);
      expect(find.text('An interview'), findsOneWidget);
      expect(find.text('A story'), findsOneWidget);
    });

    testWidgets('an empty section is left out entirely', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: NewsScreen(
            loadArticles: () async => [_article(title: 'Only a story')],
          ),
        ),
      );
      await tester.pump();
      expect(find.text('WHY MANTELIER'), findsNothing);
      expect(find.text('INTERVIEWS'), findsNothing);
      expect(find.text('STORIES'), findsOneWidget);
    });
  });

  group('NewsArticleDetailScreen', () {
    Future<void> pumpDetail(
      WidgetTester tester,
      NewsArticle article,
      List<NewsArticlePhoto> photos,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: NewsArticleDetailScreen(
            article: article,
            analytics: NoopAnalyticsService(),
            loadVenues: () async => _noVenues,
            loadPhotos: () async => photos,
          ),
        ),
      );
      await tester.pump();
    }

    testWidgets('an interview shows its questions, quote and photos in place', (
      tester,
    ) async {
      await pumpDetail(
        tester,
        _article(
          title: 'At the table',
          section: NewsSection.interview,
          body:
              'Intro.\n\nQ: Where does it start?\n\nAt the market.\n\n> A quote.',
        ),
        [
          _photo('p1', 1, caption: 'The dining room'),
          _photo('g1', 3),
          _photo('g2', 3, order: 1),
        ],
      );
      expect(find.textContaining('INTERVIEW'), findsOneWidget);
      expect(find.text('Where does it start?'), findsOneWidget);
      expect(find.text('A quote.'), findsOneWidget);
      expect(find.text('The dining room'), findsOneWidget);
      // One single photo and one two-photo gallery.
      expect(find.byType(PageView), findsOneWidget);
      // The single photo sits between the intro and the question.
      final intro = tester.getTopLeft(find.text('Intro.')).dy;
      final caption = tester.getTopLeft(find.text('The dining room')).dy;
      final question = tester.getTopLeft(find.text('Where does it start?')).dy;
      expect(intro, lessThan(caption));
      expect(caption, lessThan(question));
    });

    testWidgets('each question has its own rule above it, answers none', (
      tester,
    ) async {
      await pumpDetail(
        tester,
        _article(
          section: NewsSection.interview,
          body: 'Intro.\n\nQ: One?\n\nAnswer.\n\nQ: Two?\n\nAnswer two.',
        ),
        const [],
      );
      final rules = find.byKey(const ValueKey('news-question-rule'));
      expect(rules, findsNWidgets(2));
      final rule = tester.getTopLeft(rules.first).dy;
      final question = tester.getTopLeft(find.text('One?')).dy;
      final intro = tester.getBottomLeft(find.text('Intro.')).dy;
      expect(intro, lessThan(rule));
      expect(rule, lessThan(question));
    });

    testWidgets('small photos sit as one row of squares with their credit '
        'said once', (tester) async {
      await pumpDetail(tester, _article(body: 'One.\n\nTwo.'), [
        for (var i = 0; i < 4; i++)
          NewsArticlePhoto(
            id: 's$i',
            imageUrl: 'https://example.test/s$i.jpg',
            afterParagraph: 9,
            displayOrder: i,
            caption: 'Photos: a chef',
            isSmall: true,
          ),
      ]);
      expect(find.byType(PageView), findsNothing);
      expect(find.text('Photos: a chef'), findsOneWidget);
      final two = tester.getTopLeft(find.text('Two.')).dy;
      final credit = tester.getTopLeft(find.text('Photos: a chef')).dy;
      expect(two, lessThan(credit));
    });

    testWidgets('a failed photo lookup still shows the article', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: NewsArticleDetailScreen(
            article: _article(title: 'Still here'),
            analytics: NoopAnalyticsService(),
            loadVenues: () async => _noVenues,
            loadPhotos: () async => throw Exception('offline'),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
      expect(find.text('Still here'), findsOneWidget);
      expect(find.text('Body text.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('NewsMentionsSection', () {
    testWidgets('lists the short title and opens the article on a tap', (
      tester,
    ) async {
      NewsArticle? opened;
      final article = NewsArticle(
        id: 'i',
        title: 'A long title: with a conversation after it',
        cardTitle: 'A long title',
        body: 'B',
        section: NewsSection.interview,
        publishedAt: DateTime(2026, 11, 6),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: NewsMentionsSection(
              articles: [article],
              onTapArticle: (a) => opened = a,
            ),
          ),
        ),
      );
      expect(find.text('IN THE NEWS'), findsOneWidget);
      expect(find.text('A long title'), findsOneWidget);
      expect(find.textContaining('Interview · '), findsOneWidget);
      await tester.tap(find.text('A long title'));
      expect(opened, same(article));
    });

    testWidgets('renders nothing without articles', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: NewsMentionsSection(articles: const [], onTapArticle: (_) {}),
          ),
        ),
      );
      expect(find.text('IN THE NEWS'), findsNothing);
    });
  });
}
