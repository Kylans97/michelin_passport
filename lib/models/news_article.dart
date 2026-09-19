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

  const NewsArticle({
    required this.id,
    required this.title,
    required this.body,
    this.imageUrl,
    this.linkUrl,
    required this.publishedAt,
  });

  factory NewsArticle.fromJson(Map<String, dynamic> json) => NewsArticle(
    id: json['id'] as String,
    title: json['title'] as String,
    body: json['body'] as String,
    imageUrl: json['image_url'] as String?,
    linkUrl: json['link_url'] as String?,
    publishedAt: DateTime.parse(json['published_at'] as String),
  );

  /// [body] split into paragraphs on blank lines — the one piece of
  /// "Markdown-ish" handling News V1 actually does. Empty pieces (e.g.
  /// from trailing blank lines) are dropped.
  List<String> get paragraphs => body
      .split(RegExp(r'\n\s*\n'))
      .map((p) => p.trim())
      .where((p) => p.isNotEmpty)
      .toList();
}
