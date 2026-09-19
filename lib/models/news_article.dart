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
}
