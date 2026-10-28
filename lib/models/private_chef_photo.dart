import 'photo_framing.dart';

// Maps a row from `public.private_chef_photos` (see
// supabase/migrations/20260818120000_add_private_chef_photos_and_biography_limit.sql).
// A small, admin-curated Detail-hero gallery — up to 5 rows per chef,
// enforced at the database layer. `displayOrder` is the sole ordering
// signal (no separate `isCover` field exists on the table or here); the
// lowest `displayOrder` among a chef's photos is always the cover/first
// hero image.
class PrivateChefPhoto {
  final String id;
  final String privateChefId;
  final String imageUrl;
  final String? altText;
  final int displayOrder;
  final PhotoFraming framing;

  /// Whether the venue chose this photo for its small cards, and its crop
  /// there (is_card/card_focus_x/card_focus_y/card_zoom, 20261015120000)
  /// — separate from [framing], which is the header crop.
  final bool isCard;
  final PhotoFraming cardFraming;

  const PrivateChefPhoto({
    required this.id,
    required this.privateChefId,
    required this.imageUrl,
    this.altText,
    this.displayOrder = 0,
    this.framing = PhotoFraming.center,
    this.isCard = false,
    this.cardFraming = PhotoFraming.center,
  });

  factory PrivateChefPhoto.fromJson(Map<String, dynamic> json) =>
      PrivateChefPhoto(
        id: json['id'].toString(),
        privateChefId: json['private_chef_id'].toString(),
        imageUrl: (json['image_url'] as String?) ?? '',
        altText: json['alt_text'] as String?,
        displayOrder: (json['display_order'] as num?)?.toInt() ?? 0,
        framing: PhotoFraming.fromJson(json),
        isCard: (json['is_card'] as bool?) ?? false,
        cardFraming: PhotoFraming.fromJson(json, prefix: 'card_'),
      );
}
