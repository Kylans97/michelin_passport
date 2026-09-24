// Maps a row from `public.restaurants_full` (see
// supabase/migrations/20260805141519_production_schema_v1.sql). Only fields
// the view actually exposes are modelled — see that view's SELECT list
// before adding anything here.
class Restaurant {
  final String id;
  final String restaurantCode;
  final String name;

  // NULL means the restaurant does not currently hold a Michelin star. It is
  // never coerced to 0 — see DATABASE_ARCHITECTURE.md section 3.3.
  final int? michelinStars;

  // Creation provenance only — the primary reason this row was originally
  // created (e.g. 'michelin_star', 'hall_of_fame', 'gault_millau'). A
  // single historical fact, written once at insert and never rewritten as
  // recognition changes. MUST NOT be read to derive current guide
  // recognition of any kind — see isHallOfFame below for why that
  // distinction is load-bearing, and
  // docs/Architecture/Michelin_Database/GAULT_MILLAU_CATALOGUE_ARCHITECTURE_REVIEW.md
  // for the full reasoning. A restaurant can freely have
  // inclusionReason == 'michelin_star' and isHallOfFame == true at the same
  // time — that is the real-world state for every current Hall of Fame
  // member, all of whom were first catalogued for a Michelin star.
  final String inclusionReason;

  // True when the restaurant currently holds World's 50 Best "Best of the
  // Best" Hall of Fame membership. Sourced directly from
  // restaurants_full.is_hall_of_fame, which derives it from
  // worlds_50_best.list_type = 'hall_of_fame' — the authoritative source —
  // never from inclusionReason. Fixes a prior bug: inclusion_reason is
  // never actually set to 'hall_of_fame' by the import path (every current
  // Hall of Fame member also holds a Michelin star, so import always picks
  // 'michelin_star' instead), which made the old
  // `inclusionReason == 'hall_of_fame'` derivation return false for every
  // real Hall of Fame restaurant.
  final bool isHallOfFame;

  final String cityName;
  final String? region;
  final String countryCode;
  final String countryName;
  final String flagEmoji;

  final String address;

  final String? googlePlaceId;
  final String? michelinUrl;
  final String? websiteUrl;
  final String? bookingUrl;

  // Human-readable international format (e.g. "+31 (0)10 436 07 66") --
  // not a URI. Restaurant Enrichment Step 1D. See
  // lib/core/utils/phone_utils.dart for deriving a tel: URI from this at
  // call time. Nullable -- most restaurants have none populated yet.
  final String? phone;

  // Non-null only for a restaurant inside a non-Key hotel.
  final String? propertyName;

  // True when a hotel_restaurants link exists OR propertyName is set.
  final bool isInHotel;
  final String? hotelId;
  final String? hotelName;

  final int? worlds50BestRank;

  // Pop-ups and temporary venues (20260829140000). Both null means an
  // ordinary permanent restaurant — every row before this feature, and
  // most rows after it. See that migration's own header comment for the
  // full field semantics (parent venue is generic across restaurant/
  // hotel/private chef, opening_weekdays is a set of ISO weekday
  // numbers 1=Monday..7=Sunday).
  final DateTime? startsOn;
  final DateTime? endsOn;
  final String? parentVenueType;
  final String? parentVenueId;
  final List<int>? openingWeekdays;

  // Sourced directly from restaurants_full.is_expired (20260829150000),
  // never recomputed client-side from endsOn — the view's own
  // current_date is the authoritative "today," not the device clock.
  final bool isExpired;

  // Present since the initial production schema (20260805141519) but
  // never modelled until now — see MODERATION_MANUAL_CHECKPOINTS.md
  // checkpoint 4/5 for why. 'open' | 'temporarily_closed' |
  // 'permanently_closed'; see resolveLifecycleState in
  // lib/core/utils/venue_lifecycle.dart for how this combines with
  // isExpired. statusNote carries the banner copy for a temporary
  // closure (DATA_UPDATE_PROCESS.md §7's interface contract).
  final String status;
  final DateTime? statusSince;
  final String? statusNote;

  // Row creation timestamp — present since the initial production schema
  // but not modelled until Fresh Finds needed a real "most recently
  // added" sort key (client-side selection, same as every other Explore
  // discovery section — see discovery_selectors.dart).
  final DateTime? createdAt;

  // Non-null only when this row was added because of a
  // missing_listing_reports submission (set by hand on the same INSERT
  // that creates the row — see that table's own migration). Never read
  // from missing_listing_reports itself, which has no client select
  // grant at all — this is purely a presence check on the restaurant's
  // own, already-world-readable row.
  final String? missingListingReportId;

  // No latitude/longitude here. `location` is PostGIS
  // geography(Point,4326); over PostgREST it comes back as an EWKB hex
  // string, not GeoJSON or a {lat, lng} pair, and decoding that client-side
  // isn't safe to guess at. restaurants_full can project scalar
  // ST_Y/ST_X(location::geometry) once
  // supabase/migrations/20260807140000_add_venue_coordinates.sql is
  // applied, but that column list is NOT part of restaurantFullColumns —
  // every other feature (Explore, Passport, Rankings, Detail, Wishlist,
  // Visits/Stays) reads restaurants_full through this model and must keep
  // working whether or not that migration has landed. The Map feature reads
  // coordinates directly via MapRepository instead, deliberately bypassing
  // Restaurant entirely for that.
  const Restaurant({
    required this.id,
    required this.restaurantCode,
    required this.name,
    required this.michelinStars,
    required this.inclusionReason,
    this.isHallOfFame = false,
    required this.cityName,
    this.region,
    required this.countryCode,
    required this.countryName,
    required this.flagEmoji,
    required this.address,
    this.googlePlaceId,
    this.michelinUrl,
    this.websiteUrl,
    this.bookingUrl,
    this.phone,
    this.propertyName,
    this.isInHotel = false,
    this.hotelId,
    this.hotelName,
    this.worlds50BestRank,
    this.startsOn,
    this.endsOn,
    this.parentVenueType,
    this.parentVenueId,
    this.openingWeekdays,
    this.isExpired = false,
    this.status = 'open',
    this.statusSince,
    this.statusNote,
    this.createdAt,
    this.missingListingReportId,
  });

  /// True when the restaurant currently holds at least one Michelin star.
  bool get hasMichelinStar => michelinStars != null;

  /// True when the restaurant has a current World's 50 Best rank.
  bool get isWorlds50Best => worlds50BestRank != null;

  /// True when this restaurant has a scheduled end date at all — a
  /// pop-up or other temporary venue, whether or not it has already
  /// expired. Never true for an ordinary permanent restaurant.
  bool get isTemporary => endsOn != null;

  bool get isTemporarilyClosed => status == 'temporarily_closed';
  bool get isPermanentlyClosed => status == 'permanently_closed';

  factory Restaurant.fromJson(Map<String, dynamic> json) => Restaurant(
    id: json['id'].toString(),
    restaurantCode: (json['restaurant_code'] as String?) ?? '',
    name: (json['name'] as String?) ?? '',
    michelinStars: (json['michelin_stars'] as num?)?.toInt(),
    inclusionReason: (json['inclusion_reason'] as String?) ?? '',
    isHallOfFame: (json['is_hall_of_fame'] as bool?) ?? false,
    cityName: (json['city_name'] as String?) ?? '',
    region: json['region'] as String?,
    countryCode: (json['country_code'] as String?) ?? '',
    countryName: (json['country_name'] as String?) ?? '',
    flagEmoji: (json['flag_emoji'] as String?) ?? '',
    address: (json['address'] as String?) ?? '',
    googlePlaceId: json['google_place_id'] as String?,
    michelinUrl: json['michelin_url'] as String?,
    websiteUrl: json['website_url'] as String?,
    bookingUrl: json['booking_url'] as String?,
    phone: json['phone'] as String?,
    propertyName: json['property_name'] as String?,
    isInHotel: (json['is_in_hotel'] as bool?) ?? false,
    hotelId: json['hotel_id'] as String?,
    hotelName: json['hotel_name'] as String?,
    worlds50BestRank: (json['worlds_50_best_rank'] as num?)?.toInt(),
    startsOn: json['starts_on'] == null
        ? null
        : DateTime.parse(json['starts_on'] as String),
    endsOn: json['ends_on'] == null
        ? null
        : DateTime.parse(json['ends_on'] as String),
    parentVenueType: json['parent_venue_type'] as String?,
    parentVenueId: json['parent_venue_id'] as String?,
    openingWeekdays: (json['opening_weekdays'] as List?)
        ?.map((d) => (d as num).toInt())
        .toList(),
    isExpired: (json['is_expired'] as bool?) ?? false,
    status: (json['status'] as String?) ?? 'open',
    statusSince: json['status_since'] == null
        ? null
        : DateTime.parse(json['status_since'] as String),
    statusNote: json['status_note'] as String?,
    createdAt: json['created_at'] == null
        ? null
        : DateTime.parse(json['created_at'] as String),
    missingListingReportId: json['missing_listing_report_id'] as String?,
  );
}
