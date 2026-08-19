import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/cs_spacing.dart';
import '../../../core/theme/cs_typography.dart';
import '../../../core/widgets/cs_image_placeholder.dart';
import '../../../models/private_chef.dart';
import '../private_chef_descriptors.dart';

/// The Private Chefs landing's editorial discovery card (Step 2C) —
/// replaces the compact circular-avatar [PrivateChefRow]/[PrivateChefAvatar]
/// list-row entirely: a large portrait cover photo, then identity, then up
/// to 3 quiet descriptors, the whole block one tappable region into the
/// existing [PrivateChefDetailScreen]. No "View chef" button, no score, no
/// rating, no price badge, no decorative gold — the card existing on this
/// screen at all is the selection signal, same as [PrivateChefRow] before
/// it.
class PrivateChefDiscoveryCard extends StatelessWidget {
  final PrivateChef chef;

  /// The chef's cover photo URL (lowest `display_order` in
  /// `private_chef_photos`), or null if the chef has none yet — never
  /// `profile_image_url` (Step 2C §7: the landing uses only the cover
  /// photo, matching Chef Detail's own hero-image priority).
  final String? coverImageUrl;

  /// Pre-formatted "City, Country" (already resolved to a full country
  /// name where possible), or null — matches [PrivateChefHero.location]'s
  /// own "caller already assembled the string" convention.
  final String? location;

  final VoidCallback onTap;

  const PrivateChefDiscoveryCard({
    super.key,
    required this.chef,
    required this.coverImageUrl,
    required this.location,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final businessName = chef.businessName?.trim() ?? '';
    final hasBusinessName = businessName.isNotEmpty;
    final hasLocation = (location ?? '').isNotEmpty;
    final subtitle = [
      if (hasBusinessName) businessName,
      if (hasLocation) location!,
    ].join(' · ');
    final descriptors = chefDescriptors(chef);

    final semanticLabel = [
      chef.displayName,
      if (subtitle.isNotEmpty) subtitle,
      if (descriptors.isNotEmpty) descriptors.join(', '),
    ].join(', ');

    return Semantics(
      button: true,
      label: semanticLabel,
      excludeSemantics: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(CsRadius.card),
          onTap: onTap,
          splashColor: AppColors.forestGreen.withValues(alpha: 0.06),
          highlightColor: AppColors.forestGreen.withValues(alpha: 0.04),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _ChefCoverPhoto(imageUrl: coverImageUrl),
              const SizedBox(height: CsSpacing.md),
              Text(
                chef.displayName,
                style: CsTypography.placeTitle.copyWith(
                  color: AppColors.forestGreen,
                ),
              ),
              if (subtitle.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: CsTypography.metadata.copyWith(color: AppColors.taupe),
                ),
              ],
              if (descriptors.isNotEmpty) ...[
                const SizedBox(height: CsSpacing.sm),
                Text(
                  descriptors.join('   ·   '),
                  style: CsTypography.eyebrow.copyWith(
                    color: AppColors.deepGreen,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// The large portrait cover image — near-full content width, a fixed
/// editorial aspect ratio (never distorted/stretched), [CsRadius.card]
/// corners matching this app's established "editorial, not bubbly" card
/// radius (not a new arbitrary value), and the same branded
/// [CsImagePlaceholder] fallback used everywhere else in this app on
/// missing/failed images — at full card size, never a small circular
/// avatar (Step 2C §10).
class _ChefCoverPhoto extends StatelessWidget {
  final String? imageUrl;

  const _ChefCoverPhoto({required this.imageUrl});

  // Portrait, editorial — significantly taller than the 16:9/1:1 shapes
  // used for venue/event photography elsewhere in this app, matching the
  // supplied reference chef photography's own portrait orientation.
  static const double _aspectRatio = 4 / 5;

  // Slightly above dead-center: a chef portrait's most important detail
  // (the face) sits above the vertical midpoint more often than not, and
  // there's no per-photo focal-point column in the schema to do better
  // than a single sensible default (Step 2C §5 — a controlled alignment,
  // not a destructive crop of the source image). A general default for
  // portrait chef photography, not tuned to any one chef's photo.
  static const Alignment _focalAlignment = Alignment(0, -0.3);

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(CsRadius.card);
    final url = (imageUrl ?? '').trim();
    if (url.isEmpty) {
      return AspectRatio(
        aspectRatio: _aspectRatio,
        child: CsImagePlaceholder(borderRadius: radius, logoScale: 0.28),
      );
    }
    return AspectRatio(
      aspectRatio: _aspectRatio,
      child: ClipRRect(
        borderRadius: radius,
        child: Image.network(
          url,
          fit: BoxFit.cover,
          alignment: _focalAlignment,
          errorBuilder: (_, _, _) =>
              CsImagePlaceholder(borderRadius: radius, logoScale: 0.28),
        ),
      ),
    );
  }
}
