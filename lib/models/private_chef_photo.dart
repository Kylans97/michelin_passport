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

  const PrivateChefPhoto({
    required this.id,
    required this.privateChefId,
    required this.imageUrl,
    this.altText,
    this.displayOrder = 0,
  });

  factory PrivateChefPhoto.fromJson(Map<String, dynamic> json) =>
      PrivateChefPhoto(
        id: json['id'].toString(),
        privateChefId: json['private_chef_id'].toString(),
        imageUrl: (json['image_url'] as String?) ?? '',
        altText: json['alt_text'] as String?,
        displayOrder: (json['display_order'] as num?)?.toInt() ?? 0,
      );
}
