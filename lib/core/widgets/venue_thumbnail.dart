import 'package:flutter/material.dart';
import '../theme/app_spacing.dart';
import 'cs_image_placeholder.dart';

/// A photo-first thumbnail slot for a discovery card (Explore) — shared by
/// [RestaurantTile] and [HotelTile], so this one widget covers both.
/// [imageUrl] is null at every restaurant/hotel call site today (neither
/// catalogue table carries a venue image yet), which always renders the
/// branded [CsImagePlaceholder] rather than a generic empty block; passing
/// a real [imageUrl] later is the only change needed to light up real
/// photography — size and corner treatment already assume a photo will
/// fill this slot, and a failed load falls back to the same placeholder.
class VenueThumbnail extends StatelessWidget {
  final String? imageUrl;
  final double size;

  const VenueThumbnail({super.key, required this.imageUrl, this.size = 84});

  // ~15% larger than CsImagePlaceholder's own 0.40 default (0.40 × 1.15).
  // Explicit here rather than changing that default, since the default is
  // also what EventCard relies on — this must only affect restaurant/hotel
  // thumbnails, never Events.
  static const double _logoScale = 0.46;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AppRadii.sm);
    if (imageUrl == null || imageUrl!.isEmpty) {
      return CsImagePlaceholder(
        width: size,
        height: size,
        borderRadius: radius,
        logoScale: _logoScale,
      );
    }
    return ClipRRect(
      borderRadius: radius,
      child: SizedBox(
        width: size,
        height: size,
        child: Image.network(
          imageUrl!,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => CsImagePlaceholder(
            width: size,
            height: size,
            borderRadius: radius,
            logoScale: _logoScale,
          ),
        ),
      ),
    );
  }
}
