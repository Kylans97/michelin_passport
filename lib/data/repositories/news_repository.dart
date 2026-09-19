import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/hotel.dart';
import '../../models/news_article.dart';
import '../../models/private_chef.dart';
import '../../models/restaurant.dart';
import 'hotel_repository.dart' show hotelFullColumns;
import 'private_chef_repository.dart' show privateChefFullColumns;
import 'restaurant_repository.dart' show restaurantFullColumns;

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
        .select(
          'id, title, body, image_url, link_url, published_at, '
          'focus_x, focus_y',
        )
        .order('published_at', ascending: false);
    return (rows as List)
        .map((r) => NewsArticle.fromJson(r as Map<String, dynamic>))
        .toList();
  }

  /// The restaurants/hotels/chefs linked to [articleId] — mirrors
  /// EventsRepository.loadLinkedVenues exactly: one join-table id lookup
  /// per type, then one batched `_full` lookup per type, never one query
  /// per linked venue. `news_article_restaurants`/`_hotels`/`_chefs` carry
  /// no `is_host`/`is_venue` flags the way `event_*` do — every link here
  /// just means "this article mentions this venue," so there's nothing to
  /// filter on beyond the link's existence.
  Future<NewsArticleVenues> loadLinkedVenues(String articleId) async {
    final restaurantLinksFuture = _client
        .from('news_article_restaurants')
        .select('restaurant_id')
        .eq('news_article_id', articleId);
    final hotelLinksFuture = _client
        .from('news_article_hotels')
        .select('hotel_id')
        .eq('news_article_id', articleId);
    final chefLinksFuture = _client
        .from('news_article_chefs')
        .select('chef_id')
        .eq('news_article_id', articleId);

    final restaurantLinks = await restaurantLinksFuture;
    final hotelLinks = await hotelLinksFuture;
    final chefLinks = await chefLinksFuture;

    final restaurantIds = [
      for (final row in restaurantLinks as List)
        row['restaurant_id'] as String,
    ];
    final hotelIds = [
      for (final row in hotelLinks as List) row['hotel_id'] as String,
    ];
    final chefIds = [
      for (final row in chefLinks as List) row['chef_id'] as String,
    ];

    final restaurantsFuture = restaurantIds.isEmpty
        ? Future.value(const <Restaurant>[])
        : _client
              .from('restaurants_full')
              .select(restaurantFullColumns)
              .inFilter('id', restaurantIds)
              .then(
                (rows) => [
                  for (final row in rows as List)
                    Restaurant.fromJson(row as Map<String, dynamic>),
                ],
              );
    final hotelsFuture = hotelIds.isEmpty
        ? Future.value(const <Hotel>[])
        : _client
              .from('hotels_full')
              .select(hotelFullColumns)
              .inFilter('id', hotelIds)
              .then(
                (rows) => [
                  for (final row in rows as List)
                    Hotel.fromJson(row as Map<String, dynamic>),
                ],
              );
    final chefsFuture = chefIds.isEmpty
        ? Future.value(const <PrivateChef>[])
        : _client
              .from('private_chefs_full')
              .select(privateChefFullColumns)
              .inFilter('id', chefIds)
              .then(
                (rows) => [
                  for (final row in rows as List)
                    PrivateChef.fromJson(row as Map<String, dynamic>),
                ],
              );

    return NewsArticleVenues(
      restaurants: await restaurantsFuture,
      hotels: await hotelsFuture,
      chefs: await chefsFuture,
    );
  }
}

/// Return type for [NewsRepository.loadLinkedVenues] — the twin of
/// EventsRepository's own `EventVenues`, extended with chefs (News V1
/// links to any venue type; events' own linking predates chef support
/// being added the same way).
class NewsArticleVenues {
  final List<Restaurant> restaurants;
  final List<Hotel> hotels;
  final List<PrivateChef> chefs;

  const NewsArticleVenues({
    required this.restaurants,
    required this.hotels,
    required this.chefs,
  });

  bool get isEmpty => restaurants.isEmpty && hotels.isEmpty && chefs.isEmpty;
}
