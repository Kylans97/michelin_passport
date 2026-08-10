import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../theme/app_spacing.dart';

/// A photo-first thumbnail slot for a discovery card (Explore). No
/// catalogue table carries a venue image yet, so [imageUrl] is null at
/// every call site today. The placeholder is a plain, extremely restrained
/// dark-green tonal surface — no icon/pictogram. A generic star/bed glyph
/// reads as decoration standing in for a missing feature; a quiet tonal
/// panel reads as considered restraint, and is the more premium choice
/// until real venue photography exists. Passing a real [imageUrl] later is
/// the only change needed — size and corner treatment already assume a
/// photo will fill this slot.
class VenueThumbnail extends StatelessWidget {
  final String? imageUrl;
  final double size;

  const VenueThumbnail({super.key, required this.imageUrl, this.size = 84});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadii.sm),
      child: SizedBox(
        width: size,
        height: size,
        child: imageUrl != null
            ? Image.network(
                imageUrl!,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const _TonalPlaceholder(),
              )
            : const _TonalPlaceholder(),
      ),
    );
  }
}

class _TonalPlaceholder extends StatelessWidget {
  const _TonalPlaceholder();

  @override
  Widget build(BuildContext context) => const DecoratedBox(
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [AppColors.brandGreenLight, AppColors.brandGreen],
      ),
    ),
  );
}
