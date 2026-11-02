import 'package:flutter/widgets.dart' show Alignment;

/// One News V1 article — minimal by design (News V1 spec): title, body,
/// an optional image, an optional single outbound link (matching
/// `events.official_url`'s own shape), and `published_at`, the date this
/// list and its own RLS policy both key off. No categories, tags,
/// comments, or read state — deliberately out of scope for V1.
///
/// [body] is plain text with paragraphs separated by a blank line — not
/// real Markdown. See `news_articles.body`'s own migration comment.
class NewsArticle {
  final String id;

  /// Where the article sits on the News tab (news_articles.section,
  /// 20261101270000): the one [NewsSection.about] heads it as "Why
  /// Mantelier", then [NewsSection.interview], then [NewsSection.story].
  final NewsSection section;
  final String title;
  final String body;
  final String? imageUrl;
  final String? linkUrl;
  final DateTime publishedAt;

  /// Normalized 0..1 crop-focus coordinates for [imageUrl] — matches
  /// restaurant_photos/hotel_photos/private_chef_photos' own focus_x/
  /// focus_y exactly (20260828130000_add_photo_duplicate_detection_and_
  /// focus_point.sql). Default 0.5/0.5 (center) at the database level;
  /// always present once a row is fetched, never actually null.
  final double focusX;
  final double focusY;

  const NewsArticle({
    required this.id,
    this.section = NewsSection.story,
    required this.title,
    required this.body,
    this.imageUrl,
    this.linkUrl,
    required this.publishedAt,
    this.focusX = 0.5,
    this.focusY = 0.5,
  });

  factory NewsArticle.fromJson(Map<String, dynamic> json) => NewsArticle(
    id: json['id'] as String,
    section: NewsSection.fromWire(json['section'] as String?),
    title: json['title'] as String,
    body: json['body'] as String,
    imageUrl: json['image_url'] as String?,
    linkUrl: json['link_url'] as String?,
    publishedAt: DateTime.parse(json['published_at'] as String),
    focusX: ((json['focus_x'] as num?) ?? 0.5).toDouble(),
    focusY: ((json['focus_y'] as num?) ?? 0.5).toDouble(),
  );

  /// [focusX]/[focusY] converted to Flutter's own -1..1 [Alignment]
  /// coordinate space for a `BoxFit.cover` image — the same "keep
  /// headroom, push the subject down" technique PrivateChefHero's
  /// hardcoded `_focalAlignment` already uses, here driven by a
  /// per-article stored value instead of one fixed constant.
  double get alignmentX => focusX * 2 - 1;
  double get alignmentY => focusY * 2 - 1;

  /// [body] split into paragraphs on blank lines — the one piece of
  /// "Markdown-ish" handling News V1 actually does. Empty pieces (e.g.
  /// from trailing blank lines) are dropped.
  List<String> get paragraphs => body
      .split(RegExp(r'\n\s*\n'))
      .map((p) => p.trim())
      .where((p) => p.isNotEmpty)
      .toList();

  /// [paragraphs], each read for the two prefixes the body may carry
  /// (20261101270000): "Q: " for an interviewer's question, "> " for a
  /// pull quote. Anything else is plain text.
  List<NewsBlock> get blocks => [
    for (final p in paragraphs)
      if (p.startsWith('Q:'))
        NewsBlock(NewsBlockKind.question, p.substring(2).trim())
      else if (p.startsWith('>'))
        NewsBlock(NewsBlockKind.quote, p.substring(1).trim())
      else
        NewsBlock(NewsBlockKind.text, p),
  ];
}

enum NewsSection {
  about,
  interview,
  story;

  /// Unknown or missing (an older row, a newer server) reads as a story,
  /// the plain list — never hidden.
  static NewsSection fromWire(String? value) => switch (value) {
    'about' => NewsSection.about,
    'interview' => NewsSection.interview,
    _ => NewsSection.story,
  };
}

enum NewsBlockKind { text, question, quote }

class NewsBlock {
  const NewsBlock(this.kind, this.text);

  final NewsBlockKind kind;
  final String text;
}

/// A photo inside an article (news_article_photos, 20261101270000).
/// [afterParagraph] 0 is before the first paragraph, n after paragraph n.
class NewsArticlePhoto {
  final String id;
  final String imageUrl;
  final String? caption;
  final int afterParagraph;
  final int displayOrder;
  final double focusX;
  final double focusY;

  /// news_article_photos.size (20261101280000): small photos sit as a row
  /// of squares, large ones full width.
  final bool isSmall;

  const NewsArticlePhoto({
    required this.id,
    required this.imageUrl,
    this.caption,
    this.afterParagraph = 0,
    this.displayOrder = 0,
    this.focusX = 0.5,
    this.focusY = 0.5,
    this.isSmall = false,
  });

  factory NewsArticlePhoto.fromJson(Map<String, dynamic> json) =>
      NewsArticlePhoto(
        id: json['id'] as String,
        imageUrl: json['image_url'] as String,
        caption: json['caption'] as String?,
        afterParagraph: (json['after_paragraph'] as num?)?.toInt() ?? 0,
        displayOrder: (json['display_order'] as num?)?.toInt() ?? 0,
        focusX: ((json['focus_x'] as num?) ?? 0.5).toDouble(),
        focusY: ((json['focus_y'] as num?) ?? 0.5).toDouble(),
        isSmall: json['size'] == 'small',
      );

  Alignment get alignment => Alignment(focusX * 2 - 1, focusY * 2 - 1);
}

/// [photos] grouped by where they go, each group in display order: one
/// photo shows full width, two or more as a gallery. A place past the
/// last paragraph moves to the end.
Map<int, List<NewsArticlePhoto>> groupNewsPhotos(
  List<NewsArticlePhoto> photos,
  int paragraphCount,
) {
  final sorted = [...photos]
    ..sort((a, b) {
      final byPlace = a.afterParagraph.compareTo(b.afterParagraph);
      return byPlace != 0 ? byPlace : a.displayOrder.compareTo(b.displayOrder);
    });
  final groups = <int, List<NewsArticlePhoto>>{};
  for (final photo in sorted) {
    final place = photo.afterParagraph > paragraphCount
        ? paragraphCount
        : photo.afterParagraph;
    groups.putIfAbsent(place, () => []).add(photo);
  }
  return groups;
}
