/// The three venue types a claim can be filed against — matches
/// `claims_restaurants`/`claims_hotels`/`claims_private_chefs`' own typed-
/// table split (see `20260828120000_add_venue_claims_submissions_
/// rankings.sql`'s own header for why three tables, not one polymorphic
/// one). [wireValue] is the string `has_approved_venue_claim`'s own
/// `p_venue_type` parameter and every `venue_type`/`subject_type` column
/// elsewhere in this schema already use for the same three values.
enum VenueClaimVenueType {
  restaurant,
  hotel,
  privateChef;

  String get wireValue => switch (this) {
    VenueClaimVenueType.restaurant => 'restaurant',
    VenueClaimVenueType.hotel => 'hotel',
    VenueClaimVenueType.privateChef => 'private_chef',
  };

  String get label => switch (this) {
    VenueClaimVenueType.restaurant => 'Restaurant',
    VenueClaimVenueType.hotel => 'Hotel',
    VenueClaimVenueType.privateChef => 'Private chef',
  };
}

/// The claimant's own role at the business — a fixed 4-value pick, not
/// free text (see the migration's own `role` CHECK constraint).
enum VenueClaimRole {
  owner,
  manager,
  chef,
  other;

  String get wireValue => name;

  String get label => switch (this) {
    VenueClaimRole.owner => 'Owner',
    VenueClaimRole.manager => 'Manager',
    VenueClaimRole.chef => 'Chef',
    VenueClaimRole.other => 'Other',
  };
}

/// `pending`/`approved`/`rejected`/`blocked` — see the migration's own
/// header for why `blocked` is a real 4th status, not a rename of
/// `rejected`. The app never sets any status past `pending` itself; the
/// other three only ever arrive by being read back from a row a human
/// reviewer changed via the Supabase dashboard.
enum VenueClaimStatus {
  pending,
  approved,
  rejected,
  blocked;

  static VenueClaimStatus fromWire(String value) => VenueClaimStatus.values
      .firstWhere((v) => v.name == value, orElse: () => VenueClaimStatus.pending);
}

/// One row read back from whichever of the three typed claims tables
/// matches [venueType] — a thin, read-only summary (just enough to show
/// "you already have a claim on this venue, status: X" and to gate "my
/// venue" management screens on `status == approved`), not a full mirror
/// of every submitted-detail column.
class VenueClaim {
  final String id;
  final VenueClaimVenueType venueType;
  final String venueId;
  final VenueClaimStatus status;
  final DateTime requestedAt;

  const VenueClaim({
    required this.id,
    required this.venueType,
    required this.venueId,
    required this.status,
    required this.requestedAt,
  });

  factory VenueClaim.fromJson(
    Map<String, dynamic> json, {
    required VenueClaimVenueType venueType,
    required String venueIdColumn,
  }) => VenueClaim(
    id: json['id'].toString(),
    venueType: venueType,
    venueId: json[venueIdColumn].toString(),
    status: VenueClaimStatus.fromWire(json['status'] as String),
    requestedAt: DateTime.parse(json['requested_at'] as String),
  );
}
