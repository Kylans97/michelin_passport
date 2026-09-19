import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/news_article.dart';

/// News V1. Publishing happens by hand, via the Supabase dashboard as
/// service_role — there is no admin screen and no write method here on
/// purpose. `news_articles_public_read`'s own RLS policy is the only
/// filter that matters (status = 'published' and published_at in the
/// past); this repository trusts it rather than duplicating the
/// condition client-side.
class NewsRepository {
  NewsRepository(this._client);

  final SupabaseClient _client;

  Future<List<NewsArticle>> getPublishedArticles() async {
    final rows = await _client
        .from('news_articles')
        .select('id, title, body, image_url, link_url, published_at')
        .order('published_at', ascending: false);
    return (rows as List)
        .map((r) => NewsArticle.fromJson(r as Map<String, dynamic>))
        .toList();
  }
}
