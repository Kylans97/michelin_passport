import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/cs_spacing.dart';
import '../../../core/theme/cs_typography.dart';
import '../../../core/widgets/key_row.dart';
import '../../../core/widgets/star_row.dart';
import '../../../models/passport_venue.dart';
import '../../../models/visit.dart';
import 'friend_photo_strip.dart';

const _monthNames = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

String _formatDate(DateTime date) =>
    '${date.day} ${_monthNames[date.month - 1]} ${date.year}';

/// One friends-visible visit/stay on a Friend Profile (Social Foundation
/// Step 2 §13, tap-to-navigate added in Step 2B §2/§5). Built fresh for
/// the dark editorial system rather than reusing RestaurantVisitsCard/
/// _VisitTile (light-card, per-restaurant only) — the physically-approved
/// Profile design is dark green/ivory/CsTypography, and Friend Profile
/// additions follow it, not the legacy light-card screens.
///
/// Shows exactly what the database returned for this row — never
/// fabricates a rating/note/photo that isn't present. The rating shown
/// here IS the visit's own rating; there is no separate "friend rating"
/// concept.
///
/// [onTap] opens the canonical RestaurantDetailScreen/HotelDetailScreen —
/// never a social wrapper — so every normal venue action (own Wishlist,
/// external links, own Add Visit) becomes available exactly as if reached
/// from Explore/Passport. Whole-row tap, plus a subtle trailing chevron
/// (matching FriendWishlistTile's own navigable-row language) rather than
/// a prominent "View restaurant" button, per the task's explicit
/// restrained-navigation instruction.
class FriendVisitTile extends StatelessWidget {
  final PassportVenue venue;
  final Visit visit;
  final VoidCallback onTap;

  const FriendVisitTile({
    super.key,
    required this.venue,
    required this.visit,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final v = venue;
    final (awardBadge, location) = switch (v) {
      RestaurantVenue(:final restaurant) => (
        restaurant.hasMichelinStar
            ? StarRow(count: restaurant.michelinStars!, size: 12)
            : null,
        '${restaurant.cityName}, ${restaurant.countryName}',
      ),
      HotelVenue(:final hotel) => (
        hotel.hasMichelinKeys
            ? KeyRow(count: hotel.michelinKeys!, size: 12)
            : null,
        '${hotel.cityName}, ${hotel.countryName}',
      ),
    };
    final rating = visit.rating;
    final notes = visit.notes;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(CsRadius.medium),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(CsSpacing.base),
          decoration: BoxDecoration(
            color: AppColors.brandGreenLight,
            borderRadius: BorderRadius.circular(CsRadius.medium),
            border: Border.all(color: AppColors.subtleBorderDark),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      v.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: CsTypography.bodyMedium.copyWith(
                        color: AppColors.textOnDark,
                      ),
                    ),
                  ),
                  if (rating != null) ...[
                    const SizedBox(width: CsSpacing.sm),
                    Text(
                      '$rating/10',
                      style: CsTypography.metadata.copyWith(
                        color: AppColors.gold,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                  const SizedBox(width: CsSpacing.xs),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: AppColors.secondaryOnDark,
                    size: 18,
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                location,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: CsTypography.metadata.copyWith(
                  color: AppColors.secondaryOnDark,
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Flexible(
                    child: Text(
                      _formatDate(visit.visitedOn),
                      overflow: TextOverflow.ellipsis,
                      style: CsTypography.metadata.copyWith(
                        color: AppColors.secondaryOnDark,
                      ),
                    ),
                  ),
                  if (awardBadge != null) ...[
                    const SizedBox(width: CsSpacing.sm),
                    awardBadge,
                  ],
                ],
              ),
              if (notes != null && notes.trim().isNotEmpty) ...[
                const SizedBox(height: CsSpacing.sm),
                Text(
                  notes.trim(),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: CsTypography.body.copyWith(
                    color: AppColors.textOnDark,
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
              ],
              const SizedBox(height: CsSpacing.sm),
              FriendPhotoStrip(visitId: visit.id),
            ],
          ),
        ),
      ),
    );
  }
}
