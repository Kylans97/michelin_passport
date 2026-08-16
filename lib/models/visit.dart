// Maps a row from `public.visits` (see
// supabase/migrations/20260805141519_production_schema_v1.sql,
// supabase/migrations/20260805211243_add_visit_details.sql,
// supabase/migrations/20260814120000_social_foundation_step2_visit_visibility.sql,
// and supabase/migrations/20260816120000_add_hotel_room_experience_ratings.sql).
// visits is polymorphic: entity_type + entity_id address either a hotel or
// a restaurant. This app only writes entity_type = 'restaurant' rows so far.
//
// IMPORTANT (UI Consistency Step 1E): the room_rating/experience_rating
// migration has NOT been deployed to production as of this model change —
// see that migration's own header. Reading/writing those two fields
// against production will fail (PGRST204, same class of failure the
// codebase has hit before over a missing deployed column) until the
// migration ships. Do not test the five-dimension Add Stay save path
// against production before then.

/// The two permitted values of `visits.visibility` (Social Foundation
/// Step 2). Ratings, notes, and photos are NOT independently visible —
/// they inherit this exact value from their parent visit, enforced at the
/// database level (visits_read/photos_read RLS), not just in Flutter.
enum VisitVisibility {
  private('private'),
  friends('friends');

  final String dbValue;
  const VisitVisibility(this.dbValue);

  /// Parses defensively: an unrecognised or null value fails safe to
  /// [private] — the more restrictive option — rather than throwing or
  /// silently defaulting to the more exposed value.
  static VisitVisibility fromDbValue(String? value) {
    for (final v in VisitVisibility.values) {
      if (v.dbValue == value) return v;
    }
    return VisitVisibility.private;
  }
}

/// The three permitted values of `visits.menu_type`. Stores the exact
/// database strings via [dbValue] — do not rename these without a migration.
enum MenuType {
  tastingMenu('tasting_menu'),
  aLaCarte('a_la_carte'),
  both('both');

  final String dbValue;
  const MenuType(this.dbValue);

  /// Parses defensively: an unrecognised or null value returns null rather
  /// than throwing, matching the column's own optionality.
  static MenuType? fromDbValue(String? value) {
    if (value == null) return null;
    for (final type in MenuType.values) {
      if (type.dbValue == value) return type;
    }
    return null;
  }

  /// Human-readable label for display in the UI.
  String get label => switch (this) {
    MenuType.tastingMenu => 'Tasting menu',
    MenuType.aLaCarte => 'À la carte',
    MenuType.both => 'Both',
  };
}

class Visit {
  final String id;
  final String userId;
  final String entityType;
  final String entityId;
  final DateTime visitedOn;

  // Overall rating, 1-10, nullable. Never renamed to "overall_rating" — the
  // database column is `rating`.
  final int? rating;

  // Optional per-aspect sub-ratings, each 1-10. Independently nullable: a
  // visit may rate food but not wine (e.g. no wine was consumed), or record
  // no sub-ratings at all.
  //
  // foodRating/wineRating are restaurant-only concepts (always null on a
  // hotel stay); roomRating/experienceRating are hotel-only concepts
  // (always null on a restaurant visit, and always null on every existing
  // hotel stay row too, until the Step 1E migration ships and a user rates
  // a new stay — see this file's own top-of-file migration-status note).
  // serviceRating/valueRating apply to both venue types.
  final int? foodRating;
  final int? serviceRating;
  final int? wineRating;
  final int? valueRating;
  final int? roomRating;
  final int? experienceRating;

  final MenuType? menuType;

  final String? notes;
  final double? pricePaid;
  final String? currency;

  // The venue's award frozen at the moment of the visit.
  final int? keysAtVisit;
  final int? starsAtVisit;

  // Social Foundation Step 2. Defaults to private both here and at the
  // database column level — never inferred as friends-visible just
  // because a row is missing the column (old rows are backfilled by the
  // migration itself, so this default only ever matters for a Visit
  // constructed in Flutter before being saved).
  final VisitVisibility visibility;

  const Visit({
    required this.id,
    required this.userId,
    required this.entityType,
    required this.entityId,
    required this.visitedOn,
    this.rating,
    this.foodRating,
    this.serviceRating,
    this.wineRating,
    this.valueRating,
    this.roomRating,
    this.experienceRating,
    this.menuType,
    this.notes,
    this.pricePaid,
    this.currency,
    this.keysAtVisit,
    this.starsAtVisit,
    this.visibility = VisitVisibility.private,
  });

  factory Visit.fromJson(Map<String, dynamic> json) => Visit(
    id: json['id'].toString(),
    userId: json['user_id'].toString(),
    entityType: (json['entity_type'] as String?) ?? '',
    entityId: json['entity_id'].toString(),
    visitedOn: DateTime.parse(json['visited_on'] as String),
    rating: (json['rating'] as num?)?.toInt(),
    foodRating: (json['food_rating'] as num?)?.toInt(),
    serviceRating: (json['service_rating'] as num?)?.toInt(),
    wineRating: (json['wine_rating'] as num?)?.toInt(),
    valueRating: (json['value_rating'] as num?)?.toInt(),
    // Absent on a historical row read before the Step 1E migration ships
    // (the column won't exist yet in production) exactly as absent as a
    // brand-new row nobody has rated this dimension on — both parse to
    // null the same way every other optional rating already does.
    roomRating: (json['room_rating'] as num?)?.toInt(),
    experienceRating: (json['experience_rating'] as num?)?.toInt(),
    menuType: MenuType.fromDbValue(json['menu_type'] as String?),
    notes: json['notes'] as String?,
    pricePaid: (json['price_paid'] as num?)?.toDouble(),
    currency: json['currency'] as String?,
    keysAtVisit: (json['keys_at_visit'] as num?)?.toInt(),
    starsAtVisit: (json['stars_at_visit'] as num?)?.toInt(),
    visibility: VisitVisibility.fromDbValue(json['visibility'] as String?),
  );
}
