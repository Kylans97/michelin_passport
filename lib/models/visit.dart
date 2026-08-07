// Maps a row from `public.visits` (see
// supabase/migrations/20260805141519_production_schema_v1.sql and
// supabase/migrations/20260805211243_add_visit_details.sql). visits is
// polymorphic: entity_type + entity_id address either a hotel or a
// restaurant. This app only writes entity_type = 'restaurant' rows so far.

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
  final int? foodRating;
  final int? serviceRating;
  final int? wineRating;
  final int? valueRating;

  final MenuType? menuType;

  final String? notes;
  final double? pricePaid;
  final String? currency;

  // The venue's award frozen at the moment of the visit.
  final int? keysAtVisit;
  final int? starsAtVisit;

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
    this.menuType,
    this.notes,
    this.pricePaid,
    this.currency,
    this.keysAtVisit,
    this.starsAtVisit,
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
    menuType: MenuType.fromDbValue(json['menu_type'] as String?),
    notes: json['notes'] as String?,
    pricePaid: (json['price_paid'] as num?)?.toDouble(),
    currency: json['currency'] as String?,
    keysAtVisit: (json['keys_at_visit'] as num?)?.toInt(),
    starsAtVisit: (json['stars_at_visit'] as num?)?.toInt(),
  );
}
