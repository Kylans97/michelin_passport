import 'package:flutter/material.dart';
import '../../../core/widgets/cs_image_placeholder.dart';

/// A small, chef-specific image primitive — deliberately NOT
/// [VenueThumbnail]: that widget's rounded-square corner treatment is
/// built for venue photography (buildings, dining rooms) and reads wrong
/// for a person. This reuses exactly the same fallback logic
/// ([CsImagePlaceholder] on null/empty/failed load) with a circular clip
/// instead — a person-portrait convention — rather than introducing any
/// new image-loading infrastructure.
class PrivateChefAvatar extends StatelessWidget {
  final String? imageUrl;
  final double size;

  const PrivateChefAvatar({super.key, required this.imageUrl, this.size = 84});

  static const double _logoScale = 0.5;

  @override
  Widget build(BuildContext context) {
    if (imageUrl == null || imageUrl!.isEmpty) {
      return ClipOval(
        child: CsImagePlaceholder(
          width: size,
          height: size,
          logoScale: _logoScale,
        ),
      );
    }
    return ClipOval(
      child: SizedBox(
        width: size,
        height: size,
        child: Image.network(
          imageUrl!,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => CsImagePlaceholder(
            width: size,
            height: size,
            logoScale: _logoScale,
          ),
        ),
      ),
    );
  }
}
