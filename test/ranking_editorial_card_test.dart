// PASSPORT — RANKING UI REDESIGN V1 (Color Hierarchy Correction pass):
// covers RankingEditorialCard, the shared ivory horizontal card
// PersonalRankingCard/HotelRankingCard both build on — an ivory personal
// -object card floating on Ranking's deep-green Passport canvas, matching
// Passport's own restaurant/hotel collection cards. Purely presentational
// — pumped directly, no Supabase involved — proving the six required
// facts (rank/place/where/recognition/score/visit-count) render
// correctly, the image sits flush left at the full card height with the
// rank integrated onto it (no "#", no separate empty column), the
// chevron/rank badge/score never use gold, and the layout survives narrow
// widths and long/two-line content.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:michelin_passport/core/constants/app_colors.dart';
import 'package:michelin_passport/core/widgets/cs_image_placeholder.dart';
import 'package:michelin_passport/core/widgets/star_row.dart';
import 'package:michelin_passport/features/rankings/widgets/ranking_editorial_card.dart';

Widget _wrap(Widget child, {double width = 390}) => MaterialApp(
  home: Scaffold(
    backgroundColor: AppColors.background,
    body: SizedBox(width: width, child: child),
  ),
);

RankingEditorialCard _card({
  int rank = 1,
  String? imageUrl,
  String title = 'ABAC',
  String subtitle = 'Barcelona 🇪🇸',
  Widget? recognition,
  String scoreText = '10.0',
  String visitText = '1 visit',
  VoidCallback? onTap,
}) => RankingEditorialCard(
  rank: rank,
  imageUrl: imageUrl,
  title: title,
  subtitle: subtitle,
  recognition: recognition,
  scoreText: scoreText,
  visitText: visitText,
  onTap: onTap ?? () {},
);

void main() {
  group('RankingEditorialCard', () {
    testWidgets('renders rank, title, subtitle, score and visit text', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap(_card()));
      expect(find.text('1'), findsOneWidget);
      expect(find.text('ABAC'), findsOneWidget);
      expect(find.text('Barcelona 🇪🇸'), findsOneWidget);
      expect(find.text('10.0'), findsOneWidget);
      expect(find.text('· 1 visit'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the rank never renders with a leading "#"', (tester) async {
      await tester.pumpWidget(_wrap(_card(rank: 3)));
      expect(find.text('3'), findsOneWidget);
      expect(find.text('#3'), findsNothing);
      expect(find.textContaining('#'), findsNothing);
    });

    testWidgets('renders the branded monogram fallback in the image frame '
        'when no image URL exists', (tester) async {
      await tester.pumpWidget(_wrap(_card(imageUrl: null)));
      expect(find.byType(CsImagePlaceholder), findsOneWidget);
      // The monogram itself renders via Image.asset — the absence under
      // test is a real NETWORK photo, not "any Image widget at all".
      final networkImages = find.byWidgetPredicate(
        (w) => w is Image && w.image is NetworkImage,
      );
      expect(networkImages, findsNothing);
    });

    testWidgets('renders a real network image (not the monogram) when an '
        'image URL is provided', (tester) async {
      await tester.pumpWidget(
        _wrap(_card(imageUrl: 'https://example.com/photo.jpg')),
      );
      expect(find.byType(Image), findsOneWidget);
      final image = tester.widget<Image>(find.byType(Image));
      expect(image.image, isA<NetworkImage>());
    });

    testWidgets('renders the recognition slot when provided, nothing when '
        'omitted', (tester) async {
      await tester.pumpWidget(
        _wrap(_card(recognition: const StarRow(count: 2, size: 12))),
      );
      expect(find.byType(StarRow), findsOneWidget);

      await tester.pumpWidget(_wrap(_card()));
      expect(find.byType(StarRow), findsNothing);
    });

    testWidgets('tapping the card fires onTap exactly once', (tester) async {
      var taps = 0;
      await tester.pumpWidget(_wrap(_card(onTap: () => taps++)));
      await tester.tap(find.byType(RankingEditorialCard));
      expect(taps, 1);
    });

    testWidgets('the score reads as compact supporting metadata — smaller '
        'than the restaurant/hotel name, no longer competing with it as a '
        'second headline', (tester) async {
      await tester.pumpWidget(_wrap(_card()));
      final nameSize = tester.widget<Text>(find.text('ABAC')).style?.fontSize;
      final scoreSize = tester
          .widget<Text>(find.text('10.0'))
          .style
          ?.fontSize;
      expect(nameSize, isNotNull);
      expect(scoreSize, isNotNull);
      expect(scoreSize!, lessThan(nameSize!));
    });

    testWidgets('the score is still slightly heavier than the visit count '
        '— the one remaining distinction between them, both otherwise the '
        'same compact metadata size', (tester) async {
      await tester.pumpWidget(_wrap(_card()));
      final scoreStyle = tester.widget<Text>(find.text('10.0')).style;
      final visitStyle = tester.widget<Text>(find.text('· 1 visit')).style;
      expect(scoreStyle?.fontSize, visitStyle?.fontSize);
      expect(
        scoreStyle!.fontWeight!.value,
        greaterThan(visitStyle!.fontWeight!.value),
      );
    });

    testWidgets('the rank badge, score and chevron never use gold', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap(_card()));
      final rankText = tester.widget<Text>(find.text('1'));
      expect(rankText.style?.color, isNot(AppColors.gold));
      final scoreText = tester.widget<Text>(find.text('10.0'));
      expect(scoreText.style?.color, isNot(AppColors.gold));
      final chevron = tester.widget<Icon>(
        find.byIcon(Icons.chevron_right_rounded),
      );
      expect(chevron.color, isNot(AppColors.gold));
    });

    testWidgets('the card surface is ivory, not deep green — matching '
        "Passport's own restaurant/hotel collection cards, since the card "
        'now floats on the deep-green Ranking canvas rather than an ivory '
        'one', (tester) async {
      await tester.pumpWidget(_wrap(_card()));
      final container = tester.widget<Container>(
        find
            .descendant(
              of: find.byType(RankingEditorialCard),
              matching: find.byType(Container),
            )
            .first,
      );
      final decoration = container.decoration as BoxDecoration;
      expect(decoration.color, AppColors.ivory);
    });

    testWidgets('the restaurant name renders in a dark ink, never an '
        'on-dark ivory color — a regression guard for the ivory-card '
        'inversion', (tester) async {
      await tester.pumpWidget(_wrap(_card()));
      final title = tester.widget<Text>(find.text('ABAC'));
      expect(title.style?.color, isNot(AppColors.ivory));
      expect(title.style?.color, isNot(AppColors.textOnDark));
    });

    testWidgets('the image column occupies roughly 30-32% of the card '
        'width, not a fixed square thumbnail', (tester) async {
      const cardWidth = 400.0;
      await tester.pumpWidget(_wrap(_card(), width: cardWidth));
      final imageBox = tester
          .getSize(find.byType(RankingEditorialCard))
          .width;
      // The rank badge (attached to the image) sits at the image's own
      // left edge with an 8px inset — its own left edge is a reliable
      // proxy for "the image column starts here".
      final badgeLeft = tester.getTopLeft(find.text('1')).dx;
      expect(badgeLeft, lessThan(imageBox * 0.15));
      // And the title (in the info column) should start noticeably past
      // ~25% of the card width, confirming a real image column exists
      // rather than a tiny fixed thumbnail with a big empty gap.
      final titleLeft = tester.getTopLeft(find.text('ABAC')).dx;
      expect(titleLeft, greaterThan(imageBox * 0.22));
      expect(titleLeft, lessThan(imageBox * 0.42));
    });

    testWidgets('a long editorial name wraps onto a second line rather '
        'than ellipsizing at the first', (tester) async {
      await tester.pumpWidget(
        _wrap(
          _card(
            title: '8 1/2 Otto e Mezzo – Bombana',
            scoreText: '6.0',
            subtitle: 'Hong Kong 🇭🇰',
          ),
          width: 340,
        ),
      );
      final text = tester.widget<Text>(
        find.text('8 1/2 Otto e Mezzo – Bombana'),
      );
      expect(text.maxLines, 2);
      expect(tester.takeException(), isNull);
    });

    testWidgets('an extremely long name still truncates rather than '
        'overflowing once it exceeds two lines', (tester) async {
      await tester.pumpWidget(
        _wrap(
          _card(
            title:
                '8 1/2 Otto e Mezzo – Bombana Extremely Long Venue Name That '
                'Cannot Possibly Fit On Two Lines Either',
          ),
          width: 320,
        ),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('the divider is short, not a full-width rule', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap(_card(), width: 400));
      final dividerFinder = find.byWidgetPredicate(
        (w) => w is Container && w.color == AppColors.subtleBorderLight,
      );
      expect(dividerFinder, findsOneWidget);
      final dividerWidth = tester.getSize(dividerFinder).width;
      final cardWidth = tester.getSize(find.byType(RankingEditorialCard)).width;
      // Short — a fraction of the card width, never anywhere close to
      // spanning the info column, let alone reaching the chevron.
      expect(dividerWidth, lessThan(cardWidth * 0.2));
      expect(dividerWidth, greaterThan(0));
    });

    for (final width in [320.0, 375.0, 390.0, 430.0]) {
      testWidgets('no overflow at ${width.toInt()}px — long name, long '
          'city, 3 stars, double-digit score, multi-digit visits', (
        tester,
      ) async {
        await tester.pumpWidget(
          _wrap(
            _card(
              rank: 12,
              title: 'A Considerably Long Restaurant Name For This Width',
              subtitle: 'A Fairly Long City Name 🇳🇱',
              recognition: const StarRow(count: 3, size: 12),
              scoreText: '10.0',
              visitText: '128 visits',
            ),
            width: width,
          ),
        );
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('no overflow at 1.6x text scale, 320px', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(1.6)),
            child: Scaffold(
              backgroundColor: AppColors.background,
              body: SizedBox(
                width: 320,
                child: _card(recognition: const StarRow(count: 2, size: 12)),
              ),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('image present and image absent use identical card '
        'geometry (same overall card height)', (tester) async {
      await tester.pumpWidget(_wrap(_card(imageUrl: null)));
      final heightWithoutImage = tester
          .getSize(find.byType(RankingEditorialCard))
          .height;

      await tester.pumpWidget(
        _wrap(_card(imageUrl: 'https://example.com/photo.jpg')),
      );
      final heightWithImage = tester
          .getSize(find.byType(RankingEditorialCard))
          .height;

      expect(heightWithImage, heightWithoutImage);
    });
  });
}
