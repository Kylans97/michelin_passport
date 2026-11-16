/// A luxury train or small ship — one row of `public.journeys_full`
/// (20261101500000_add_journeys.sql). Editorial catalogue only: there is
/// no award on a journey, and nothing about one is ever drawn in gold.
/// Plan: docs/Architecture/JOURNEYS_PLAN.md.
enum JourneyKind {
  train,
  ship;

  static JourneyKind fromDb(String value) =>
      value == 'ship' ? JourneyKind.ship : JourneyKind.train;

  String get label => switch (this) {
    JourneyKind.train => 'Train',
    JourneyKind.ship => 'Ship',
  };
}

enum JourneyStatus {
  operating,
  announced,
  retired;

  static JourneyStatus fromDb(String? value) => switch (value) {
    'announced' => JourneyStatus.announced,
    'retired' => JourneyStatus.retired,
    _ => JourneyStatus.operating,
  };
}

class Journey {
  final String id;
  final String journeyCode;
  final String slug;
  final JourneyKind kind;

  /// river / expedition / sailing_yacht / motor_yacht / yacht, null for a
  /// train or when not known.
  final String? shipType;
  final String name;
  final JourneyStatus status;
  final DateTime? firstDepartureOn;
  final String? summary;
  final String? cabinsText;
  final int? guestCapacity;
  final String? diningText;
  final String? officialUrl;

  /// Set only when the journey runs in a single country; otherwise
  /// [regionsText] is what the card says.
  final String? primaryCountryCode;
  final String? countryName;
  final String? flagEmoji;
  final String? regionsText;
  final String operatorCode;
  final String operatorName;
  final int routeCount;
  final List<String> routeCountryCodes;

  const Journey({
    required this.id,
    required this.journeyCode,
    required this.slug,
    required this.kind,
    required this.name,
    required this.operatorCode,
    required this.operatorName,
    this.shipType,
    this.status = JourneyStatus.operating,
    this.firstDepartureOn,
    this.summary,
    this.cabinsText,
    this.guestCapacity,
    this.diningText,
    this.officialUrl,
    this.primaryCountryCode,
    this.countryName,
    this.flagEmoji,
    this.regionsText,
    this.routeCount = 0,
    this.routeCountryCodes = const [],
  });

  factory Journey.fromMap(Map<String, dynamic> map) => Journey(
    id: map['id'] as String,
    journeyCode: map['journey_code'] as String,
    slug: map['slug'] as String,
    kind: JourneyKind.fromDb(map['kind'] as String),
    shipType: map['ship_type'] as String?,
    name: map['name'] as String,
    status: JourneyStatus.fromDb(map['status'] as String?),
    firstDepartureOn: map['first_departure_on'] == null
        ? null
        : DateTime.parse(map['first_departure_on'] as String),
    summary: map['summary'] as String?,
    cabinsText: map['cabins_text'] as String?,
    guestCapacity: (map['guest_capacity'] as num?)?.toInt(),
    diningText: map['dining_text'] as String?,
    officialUrl: map['official_url'] as String?,
    primaryCountryCode: (map['primary_country_code'] as String?)?.trim(),
    countryName: map['country_name'] as String?,
    flagEmoji: map['flag_emoji'] as String?,
    regionsText: map['regions_text'] as String?,
    operatorCode: map['operator_code'] as String,
    operatorName: map['operator_name'] as String,
    routeCount: (map['route_count'] as num?)?.toInt() ?? 0,
    routeCountryCodes: [
      for (final code in (map['route_country_codes'] as List?) ?? const [])
        (code as String).trim(),
    ],
  );

  /// The one place line under a journey's name: the single country when
  /// there is one, else the regions it sails or runs through.
  String? get whereLine {
    final country = (countryName ?? '').trim();
    final regions = (regionsText ?? '').trim();
    if (regions.isNotEmpty) return regions;
    if (country.isNotEmpty) return country;
    return null;
  }

  /// "Train" or the kind of ship, for the quiet eyebrow above the name.
  String get kindLabel => switch (shipType) {
    'river' => 'River ship',
    'expedition' => 'Expedition ship',
    'sailing_yacht' => 'Sailing yacht',
    'motor_yacht' => 'Motor yacht',
    'yacht' => 'Yacht',
    _ => kind.label,
  };
}

/// One route of a journey (`public.journey_routes`). [nights] is exact
/// when the operator states it; otherwise [durationText] carries the
/// length as published ("8 days"), and both may be null.
class JourneyRoute {
  final String id;
  final String routeCode;
  final String name;
  final String fromPlace;
  final String toPlace;
  final String? fromCountryCode;
  final int? nights;
  final String? durationText;
  final String? seasonText;
  final String? departurePatternText;

  const JourneyRoute({
    required this.id,
    required this.routeCode,
    required this.name,
    required this.fromPlace,
    required this.toPlace,
    this.fromCountryCode,
    this.nights,
    this.durationText,
    this.seasonText,
    this.departurePatternText,
  });

  factory JourneyRoute.fromMap(Map<String, dynamic> map) => JourneyRoute(
    id: map['id'] as String,
    routeCode: map['route_code'] as String,
    name: map['name'] as String,
    fromPlace: map['from_place'] as String,
    toPlace: map['to_place'] as String,
    fromCountryCode: (map['from_country_code'] as String?)?.trim(),
    nights: (map['nights'] as num?)?.toInt(),
    durationText: map['duration_text'] as String?,
    seasonText: map['season_text'] as String?,
    departurePatternText: map['departure_pattern_text'] as String?,
  );

  bool get isRoundTrip => fromPlace == toPlace;

  /// "Cusco → Arequipa", or "From Edinburgh" for a round trip.
  String get endpoints =>
      isRoundTrip ? 'From $fromPlace' : '$fromPlace → $toPlace';

  /// "2 nights", "Day journey", the published text, or null. Never a
  /// computed figure.
  String? get lengthLabel {
    final n = nights;
    if (n != null) {
      if (n == 0) return 'Day journey';
      return n == 1 ? '1 night' : '$n nights';
    }
    final text = (durationText ?? '').trim();
    return text.isEmpty ? null : text;
  }
}

enum JourneyTravelVisibility {
  private,
  friends;

  String get dbValue => name;

  static JourneyTravelVisibility fromDb(String? value) => value == 'friends'
      ? JourneyTravelVisibility.friends
      : JourneyTravelVisibility.private;
}

/// A member's confirmed travel aboard a journey (`public.journey_travels`)
/// — the only thing that puts a journey stamp in the Passport.
class JourneyTravel {
  final String id;
  final String journeyId;
  final String? routeId;
  final DateTime departedOn;
  final DateTime? arrivedOn;
  final int? rating;
  final String? comment;
  final JourneyTravelVisibility visibility;

  const JourneyTravel({
    required this.id,
    required this.journeyId,
    required this.departedOn,
    this.routeId,
    this.arrivedOn,
    this.rating,
    this.comment,
    this.visibility = JourneyTravelVisibility.private,
  });

  factory JourneyTravel.fromMap(Map<String, dynamic> map) => JourneyTravel(
    id: map['id'] as String,
    journeyId: map['journey_id'] as String,
    routeId: map['route_id'] as String?,
    departedOn: DateTime.parse(map['departed_on'] as String),
    arrivedOn: map['arrived_on'] == null
        ? null
        : DateTime.parse(map['arrived_on'] as String),
    rating: (map['rating'] as num?)?.toInt(),
    comment: map['comment'] as String?,
    visibility: JourneyTravelVisibility.fromDb(map['visibility'] as String?),
  );
}
