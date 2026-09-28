import 'hotel.dart';
import 'private_chef.dart';
import 'restaurant.dart';

/// A venue the signed-in user actively manages — sourced from
/// venue_managers_restaurants/_hotels/_private_chefs (revoked_at is
/// null), never from the claims tables. Mirrors PassportVenue's own
/// sealed restaurant/hotel split (see passport_venue.dart), extended
/// with a third private-chef variant — kept as genuinely separate
/// domain objects, never a polymorphic entity_type/entity_id shape,
/// matching this schema's own deliberate split.
sealed class ManagedVenue {
  const ManagedVenue();

  String get id;
  String get name;
  String? get cityName;

  /// Small, all-caps type label for the row — "Restaurant"/"Hotel"/
  /// "Private chef", matching VenueClaimVenueType.label's own wording.
  String get typeLabel;

  /// The venue_type value every venue_managers_*/venue_about_submissions/
  /// claims_* row uses on the wire — 'restaurant'/'hotel'/'private_chef'.
  /// Matches VenueClaimVenueType.wireValue exactly (same three strings,
  /// same reason .name alone can't produce 'private_chef').
  String get venueTypeWireValue;
}

class ManagedRestaurant extends ManagedVenue {
  final Restaurant restaurant;
  const ManagedRestaurant(this.restaurant);

  @override
  String get id => restaurant.id;

  @override
  String get name => restaurant.name;

  @override
  String? get cityName => restaurant.cityName;

  @override
  String get typeLabel => 'Restaurant';

  @override
  String get venueTypeWireValue => 'restaurant';
}

class ManagedHotel extends ManagedVenue {
  final Hotel hotel;
  const ManagedHotel(this.hotel);

  @override
  String get id => hotel.id;

  @override
  String get name => hotel.name;

  @override
  String? get cityName => hotel.cityName;

  @override
  String get typeLabel => 'Hotel';

  @override
  String get venueTypeWireValue => 'hotel';
}

class ManagedPrivateChef extends ManagedVenue {
  final PrivateChef chef;
  const ManagedPrivateChef(this.chef);

  @override
  String get id => chef.id;

  @override
  String get name => chef.displayName;

  @override
  String? get cityName => chef.homeCity;

  @override
  String get typeLabel => 'Private chef';

  @override
  String get venueTypeWireValue => 'private_chef';
}
