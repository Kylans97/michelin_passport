/// One row from whichever of restaurant_photos/hotel_photos/
/// private_chef_photos matches a venue's type — the APPROVED/published
/// set, never venue_photo_submissions. Deliberately its own small model
/// rather than reusing PrivateChefPhoto (which carries a chef-specific
/// FK field and is already used elsewhere for that screen's own
/// purposes): this one is venue-type-agnostic by design, since
/// VenueManagementScreen's photo section handles all three types through
/// one shared shape, the same way ManagedVenue itself does.
class PublishedVenuePhoto {
  final String id;
  final String imageUrl;
  final String? altText;
  final int displayOrder;

  const PublishedVenuePhoto({
    required this.id,
    required this.imageUrl,
    this.altText,
    required this.displayOrder,
  });

  factory PublishedVenuePhoto.fromJson(Map<String, dynamic> json) => PublishedVenuePhoto(
    id: json['id'].toString(),
    imageUrl: (json['image_url'] as String?) ?? '',
    altText: json['alt_text'] as String?,
    displayOrder: (json['display_order'] as num?)?.toInt() ?? 0,
  );
}
