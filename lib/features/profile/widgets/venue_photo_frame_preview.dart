import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/cs_spacing.dart';
import '../../../core/theme/cs_typography.dart';

/// Shows a photo cropped exactly the way it will really appear on a
/// venue's public page — the real numbers, not approximations:
///
/// - restaurant/hotel HEADER: VenueDetailHero — full width, fixed 300px
///   height (a real device's width supplies the rest; this frame does
///   the same, not a hardcoded ratio), center alignment (the neutral
///   default — no deliberate alignment has ever been chosen for this
///   slot, since it's never rendered a real photo yet).
/// - restaurant/hotel CARD: VenueThumbnail's own default — a 1:1 square,
///   center alignment.
/// - private chef HEADER: PrivateChefHero/_HeroImage — full width, fixed
///   320px height, Alignment(0, -0.8) (that file's own comment: biased
///   toward the top so a face clears the iOS Dynamic Island).
/// - private chef CARD: PrivateChefDiscoveryCard/_ChefCoverPhoto — 4:5
///   portrait, Alignment(0, -0.3).
///
/// Deliberately read-only — no drag-to-reposition. There is no schema
/// field on venue_photo_submissions (or, for that matter, any consuming
/// code reading the APPROVED tables' own focus_x/focus_y) to persist a
/// chosen position into, so offering one here would be exactly the kind
/// of "preview that doesn't match what ships" the feature must avoid.
/// See VenueManagementScreen's own photos-section doc comment for the
/// full reasoning.
class VenuePhotoFramePreview extends StatelessWidget {
  final ImageProvider image;
  final String venueTypeWireValue;

  const VenuePhotoFramePreview({
    super.key,
    required this.image,
    required this.venueTypeWireValue,
  });

  @override
  Widget build(BuildContext context) {
    final isChef = venueTypeWireValue == 'private_chef';
    final headerHeight = isChef ? 320.0 : 300.0;
    final headerAlignment = isChef ? const Alignment(0, -0.8) : Alignment.center;
    final cardAspectRatio = isChef ? 4 / 5 : 1.0;
    final cardAlignment = isChef ? const Alignment(0, -0.3) : Alignment.center;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _frameLabel('AS THE HEADER'),
        const SizedBox(height: CsSpacing.sm),
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(
            width: double.infinity,
            height: headerHeight,
            child: Image(image: image, fit: BoxFit.cover, alignment: headerAlignment),
          ),
        ),
        const SizedBox(height: CsSpacing.md),
        _frameLabel('AS A CARD'),
        const SizedBox(height: CsSpacing.sm),
        SizedBox(
          width: 160,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: AspectRatio(
              aspectRatio: cardAspectRatio,
              child: Image(image: image, fit: BoxFit.cover, alignment: cardAlignment),
            ),
          ),
        ),
      ],
    );
  }

  Widget _frameLabel(String text) =>
      Text(text, style: CsTypography.eyebrow.copyWith(color: AppColors.taupe));
}
