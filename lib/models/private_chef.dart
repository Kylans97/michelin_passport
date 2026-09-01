// Maps a row from `public.private_chefs` (see
// supabase/migrations/20260817120000_create_private_chefs_foundation.sql).
// Only fields the table actually exposes are modelled — see
// docs/Architecture/PRIVATE_CHEFS.md before adding anything here.
//
// `publicationStatus == 'published'` is the sole, authoritative public
// selection signal for this domain — there is no separate "selected"
// boolean anywhere in this model, deliberately. See PRIVATE_CHEFS.md §14.
//
// This model deliberately carries NO Michelin/Keys recognition field of
// any kind. Recognition belongs exclusively to the canonical Restaurant a
// chef has worked at — see PrivateChefRestaurantHistory and
// PRIVATE_CHEFS.md §10. A chef is never "a 2-star chef"; a restaurant is.
class PrivateChef {
  final String id;
  final String slug;
  final String displayName;
  final String? businessName;
  final String? biography;
  final String? personalizationNote;

  // Free text, not a public.cities FK — matching events.city's own
  // precedent (see the migration's own header comment). No denormalized
  // country name/flag exists on this table, unlike restaurants_full/
  // hotels_full — same situation as Event.countryCode (see event.dart);
  // UI renders the raw ISO code as text rather than fabricating a lookup
  // this table doesn't provide.
  final String? homeCity;
  final String? homeCountryCode;
  final String? serviceAreaText;
  final bool travelAvailable;

  // Null means no stated floor/ceiling — never coerced to 0.
  final int? minimumGuests;
  final int? maximumGuests;

  final bool winePairingAvailable;
  final String? wineNote;

  // price_on_request defaults true at the schema level — the premium-safe
  // default; a chef only shows a number if curation deliberately set one.
  final bool priceOnRequest;
  final double? pricingFrom;
  final String?
  pricingCurrency; // ISO 4217, e.g. 'EUR' — raw code, no symbol mapping.
  final String? pricingUnit; // 'per_person' | 'per_experience'

  final String? instagramUrl;
  final String? websiteUrl;
  final String? profileImageUrl;
  final List<String> languages;

  final String publicationStatus; // 'draft' | 'published' | 'archived'

  // Pop-ups and temporary venues (20260829140000) — see the identical
  // fields on Restaurant for the full field semantics. Sourced from
  // public.private_chefs_full (20260829150000), not the bare
  // private_chefs table this model otherwise maps — see
  // privateChefFullColumns and PrivateChefRepository's own comments for
  // why every read now goes through that view.
  final DateTime? startsOn;
  final DateTime? endsOn;
  final String? parentVenueType;
  final String? parentVenueId;
  final List<int>? openingWeekdays;
  final bool isExpired;

  const PrivateChef({
    required this.id,
    required this.slug,
    required this.displayName,
    this.businessName,
    this.biography,
    this.personalizationNote,
    this.homeCity,
    this.homeCountryCode,
    this.serviceAreaText,
    this.travelAvailable = true,
    this.minimumGuests,
    this.maximumGuests,
    this.winePairingAvailable = false,
    this.wineNote,
    this.priceOnRequest = true,
    this.pricingFrom,
    this.pricingCurrency,
    this.pricingUnit,
    this.instagramUrl,
    this.websiteUrl,
    this.profileImageUrl,
    this.languages = const [],
    this.publicationStatus = 'draft',
    this.startsOn,
    this.endsOn,
    this.parentVenueType,
    this.parentVenueId,
    this.openingWeekdays,
    this.isExpired = false,
  });

  /// True when curation has stated at least one of minimum/maximum guests.
  bool get hasGuestRange => minimumGuests != null || maximumGuests != null;

  /// True when this chef has a scheduled end date at all — a pop-up
  /// residency, whether or not it has already expired.
  bool get isTemporary => endsOn != null;

  /// True when a valid, showable from-price exists — `pricingFrom` alone
  /// is not sufficient: `price_on_request` always wins when true,
  /// regardless of whether a number also happens to be set.
  bool get hasShowablePricingFrom => !priceOnRequest && pricingFrom != null;

  factory PrivateChef.fromJson(Map<String, dynamic> json) => PrivateChef(
    id: json['id'].toString(),
    slug: (json['slug'] as String?) ?? '',
    displayName: (json['display_name'] as String?) ?? '',
    businessName: json['business_name'] as String?,
    biography: json['biography'] as String?,
    personalizationNote: json['personalization_note'] as String?,
    homeCity: json['home_city'] as String?,
    homeCountryCode: json['home_country_code'] as String?,
    serviceAreaText: json['service_area_text'] as String?,
    travelAvailable: (json['travel_available'] as bool?) ?? true,
    minimumGuests: (json['minimum_guests'] as num?)?.toInt(),
    maximumGuests: (json['maximum_guests'] as num?)?.toInt(),
    winePairingAvailable: (json['wine_pairing_available'] as bool?) ?? false,
    wineNote: json['wine_note'] as String?,
    priceOnRequest: (json['price_on_request'] as bool?) ?? true,
    pricingFrom: (json['pricing_from'] as num?)?.toDouble(),
    pricingCurrency: json['pricing_currency'] as String?,
    pricingUnit: json['pricing_unit'] as String?,
    instagramUrl: json['instagram_url'] as String?,
    websiteUrl: json['website_url'] as String?,
    profileImageUrl: json['profile_image_url'] as String?,
    languages:
        (json['languages'] as List?)?.map((e) => e.toString()).toList() ??
        const [],
    publicationStatus: (json['publication_status'] as String?) ?? 'draft',
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
  );
}
