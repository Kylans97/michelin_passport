import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/private_chef.dart';
import '../../models/private_chef_education.dart';
import '../../models/private_chef_photo.dart';
import '../../models/private_chef_restaurant_history.dart';
import '../../models/restaurant.dart';
import '../../models/venue_country.dart';
import 'country_lookup.dart' show resolveVenueCountries;
import 'restaurant_repository.dart' show restaurantFullColumns;

// Explicit column list matching public.private_chefs as deployed by
// supabase/migrations/20260817120000_create_private_chefs_foundation.sql.
// Keep in sync with PrivateChef.fromJson. Deliberately never `select('*')`
// — matches restaurantFullColumns/hotelFullColumns' own established
// convention. Deliberately excludes `id`-adjacent internal-only columns
// this table doesn't have (there are none — every column here is public
// presentation data, see PRIVATE_CHEFS.md §13/§45 on why evidence columns
// were never added to any client-readable Private Chefs table).
const privateChefFullColumns =
    'id, slug, display_name, business_name, biography, '
    'personalization_note, home_city, home_country_code, service_area_text, '
    'travel_available, minimum_guests, maximum_guests, '
    'wine_pairing_available, wine_note, price_on_request, pricing_from, '
    'pricing_currency, pricing_unit, instagram_url, website_url, '
    'profile_image_url, languages, publication_status';

/// Read-only — Private Chefs is an admin-managed catalogue, same as
/// RestaurantRepository/HotelRepository/EventsRepository: no write methods
/// here, and none are planned for this repository (curation happens via
/// service-role import scripts, not the app). Request an Experience
/// (Step 3) will be its own, separate write path against
/// `private_chef_enquiries`, not added here.
class PrivateChefRepository {
  PrivateChefRepository(this._client);

  final SupabaseClient _client;

  /// The published catalogue, editorially ordered.
  ///
  /// `publication_status = 'published'` is explicitly re-applied here even
  /// though `private_chefs_public_read` RLS already restricts anon/
  /// authenticated reads to published rows — deliberately, not as a
  /// redundant security measure (RLS is the actual, sole authoritative
  /// boundary, see docs/Architecture/DATABASE_GUIDE.md's Row Level
  /// Security note) but so this method's own query documents exactly what
  /// it means to return, matching every other explicit-filter convention
  /// already used throughout RestaurantRepository/HotelRepository (e.g.
  /// `starsOnly`) — and so it keeps behaving correctly if this repository
  /// is ever reused under a service-role context where RLS would not
  /// apply at all.
  ///
  /// Ordering: no editorial `display_order`/ranking field exists on this
  /// table (unlike `private_chef_restaurant_history.display_order`), and
  /// this domain has no popularity/ranking concept to invent one from —
  /// see PRIVATE_CHEFS.md's explicit "do not invent popularity" rule.
  /// `display_name` ascending is the smallest honest, deterministic
  /// fallback.
  Future<List<PrivateChef>> getPublishedChefs() async {
    final rows = await _client
        .from('private_chefs')
        .select(privateChefFullColumns)
        .eq('publication_status', 'published')
        .order('display_name');
    return [
      for (final row in rows as List)
        PrivateChef.fromJson(row as Map<String, dynamic>),
    ];
  }

  /// One published chef by id, or null if it doesn't exist or isn't
  /// published (a draft/archived chef must not resolve here — see
  /// PRIVATE_CHEFS.md §8).
  Future<PrivateChef?> getPrivateChefById(String id) async {
    final rows = await _client
        .from('private_chefs')
        .select(privateChefFullColumns)
        .eq('id', id)
        .eq('publication_status', 'published')
        .limit(1);
    final list = rows as List;
    if (list.isEmpty) return null;
    return PrivateChef.fromJson(list.first as Map<String, dynamic>);
  }

  /// One published chef by slug — for a future stable/shareable URL-style
  /// route. Not currently called by any screen (catalogue rows already
  /// hold the full model and navigate with it directly, matching
  /// RestaurantDetailScreen/HotelDetailScreen's own constructor-takes-the-
  /// model convention), kept because `slug` is the schema's own stable
  /// public identity for a chef and a lookup by it is a genuine, cheap,
  /// single-purpose method — not spec work for a feature that doesn't
  /// exist yet.
  Future<PrivateChef?> getPrivateChefBySlug(String slug) async {
    final rows = await _client
        .from('private_chefs')
        .select(privateChefFullColumns)
        .eq('slug', slug)
        .eq('publication_status', 'published')
        .limit(1);
    final list = rows as List;
    if (list.isEmpty) return null;
    return PrivateChef.fromJson(list.first as Map<String, dynamic>);
  }

  /// A chef's restaurant provenance, ordered for display. Two queries
  /// total — the history rows, then one batched `restaurants_full` lookup
  /// for every canonical `restaurant_id` among them — never one query per
  /// row, mirroring EventsRepository.loadLinkedVenues exactly.
  ///
  /// Does not re-check the parent chef's publication_status: this method
  /// is only ever called for a chef already resolved via
  /// [getPrivateChefById]/[getPrivateChefBySlug] (both already published-
  /// gated), and `private_chef_restaurant_history_public_read`'s own RLS
  /// policy independently re-enforces the same parent-published rule
  /// regardless of what this method's own query does — see
  /// PRIVATE_CHEFS.md §50.
  Future<List<PrivateChefRestaurantHistory>> getRestaurantHistory(
    String privateChefId,
  ) async {
    final rows = await _client
        .from('private_chef_restaurant_history')
        .select(
          'id, private_chef_id, restaurant_id, restaurant_name_text, '
          'role, period_text, display_order',
        )
        .eq('private_chef_id', privateChefId)
        .order('display_order');
    final list = rows as List;

    final restaurantIds = <String>{
      for (final row in list)
        if (row['restaurant_id'] != null) row['restaurant_id'] as String,
    };

    var restaurantsById = const <String, Restaurant>{};
    if (restaurantIds.isNotEmpty) {
      final restaurantRows = await _client
          .from('restaurants_full')
          .select(restaurantFullColumns)
          .inFilter('id', restaurantIds.toList());
      restaurantsById = {
        for (final row in restaurantRows as List)
          (row as Map<String, dynamic>)['id'].toString(): Restaurant.fromJson(
            row,
          ),
      };
    }

    return [
      for (final row in list)
        PrivateChefRestaurantHistory.fromRow(
          row as Map<String, dynamic>,
          restaurant: row['restaurant_id'] != null
              ? restaurantsById[row['restaurant_id'] as String]
              : null,
        ),
    ];
  }

  /// A chef's Detail-hero gallery, ordered — at most 5 rows, enforced at
  /// the database layer (`private_chef_photos_max_five` trigger), not
  /// re-enforced here.
  Future<List<PrivateChefPhoto>> getChefPhotos(String privateChefId) async {
    final rows = await _client
        .from('private_chef_photos')
        .select('id, private_chef_id, image_url, alt_text, display_order')
        .eq('private_chef_id', privateChefId)
        .order('display_order');
    return [
      for (final row in rows as List)
        PrivateChefPhoto.fromJson(row as Map<String, dynamic>),
    ];
  }

  /// The landing editorial card's cover image for a batch of chefs — one
  /// query for every id the caller already has (from [getPublishedChefs]),
  /// never one per chef, mirroring [getRestaurantHistory]'s own batched-
  /// lookup shape. The cover is each chef's lowest-`display_order` photo
  /// (Step 2C — the same photo Detail's hero also shows first, see
  /// `PrivateChefHero`'s own gallery ordering). A chef with zero
  /// `private_chef_photos` rows is simply absent from the returned map;
  /// callers render the branded large placeholder in that case, matching
  /// `PrivateChefHero`'s own no-photo fallback.
  Future<Map<String, PrivateChefPhoto>> getCoverPhotos(
    List<String> privateChefIds,
  ) async {
    if (privateChefIds.isEmpty) return {};
    final rows = await _client
        .from('private_chef_photos')
        .select('id, private_chef_id, image_url, alt_text, display_order')
        .inFilter('private_chef_id', privateChefIds)
        .order('private_chef_id')
        .order('display_order');
    final coverByChefId = <String, PrivateChefPhoto>{};
    for (final row in rows as List) {
      final photo = PrivateChefPhoto.fromJson(row as Map<String, dynamic>);
      // Rows arrive display_order-ascending within each chef, so the
      // first one seen per chef is always the cover — putIfAbsent skips
      // every later (higher-display_order) row for that same chef.
      coverByChefId.putIfAbsent(photo.privateChefId, () => photo);
    }
    return coverByChefId;
  }

  /// Full country names for a set of `home_country_code` values (e.g.
  /// `{'NL'}` -> `{'NL': VenueCountry(name: 'Netherlands', ...)}`), reusing
  /// the same `public.countries` resolver Restaurant/Hotel already share
  /// (Step 2C §12) rather than a Private-Chefs-specific code->name map.
  /// Callers already have the codes from already-loaded [PrivateChef] rows,
  /// so this takes codes directly instead of re-querying `private_chefs`
  /// for them (unlike [RestaurantRepository.getCountries], which has no
  /// full rows on hand yet at the point it needs the codes).
  Future<Map<String, VenueCountry>> getCountryNames(
    Set<String> countryCodes,
  ) async {
    final countries = await resolveVenueCountries(_client, countryCodes);
    return {for (final country in countries) country.code: country};
  }

  /// A chef's education background, ordered — the second, distinct
  /// source the Detail screen's "Background" section reads from
  /// alongside [getRestaurantHistory] (see the education migration's own
  /// header comment for why these stay two small typed tables rather
  /// than one generalized "background" table).
  Future<List<PrivateChefEducation>> getEducationHistory(
    String privateChefId,
  ) async {
    final rows = await _client
        .from('private_chef_education')
        .select(
          'id, private_chef_id, institution, program, period_text, display_order',
        )
        .eq('private_chef_id', privateChefId)
        .order('display_order');
    return [
      for (final row in rows as List)
        PrivateChefEducation.fromJson(row as Map<String, dynamic>),
    ];
  }
}
