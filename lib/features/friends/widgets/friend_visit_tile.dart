import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/cs_spacing.dart';
import '../../../core/theme/cs_typography.dart';
import '../../../core/widgets/key_row.dart';
import '../../../core/widgets/star_row.dart';
import '../../../core/widgets/venue_thumbnail.dart';
import '../../../models/passport_venue.dart';
import '../../../models/visit.dart';

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

/// One friends-visible visit/stay on Friend Profile's VISITED section
/// (Community/Friends UX Step 1). A compact editorial row — the same
/// photo-ready visual language [GuideVenueCard] established for Guides
/// (leading [VenueThumbnail], name+recognition inline, then a rating/date
/// metadata line, then city+flag) — deliberately not the boxed dark-card
/// treatment this row used before, and deliberately no longer built as a
/// mini résumé: notes and the friend's photo strip are no longer shown
/// here. This is a discovery-first preview, not a visit-detail view; see
/// docs/Architecture/COMMUNITY_FRIENDS_UX.md ("VISITED — what changed and
/// why") for the full reasoning and the RLS access this leaves unchanged.
///
/// Shows exactly what the database returned for this row — never
/// fabricates a rating. The rating shown IS the visit's own rating; there
/// is no separate "friend rating" concept.
///
/// [onTap] opens the canonical RestaurantDetailScreen/HotelDetailScreen —
/// never a social wrapper — so every normal venue action (own Wishlist,
/// external links, own Add Visit) becomes available exactly as if reached
/// from Explore/Passport.
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
    final (recognition, city, country, flag, recognitionLabel) = switch (v) {
      RestaurantVenue(:final restaurant) => (
        restaurant.hasMichelinStar
            ? StarRow(count: restaurant.michelinStars!, size: 12)
            : null,
        restaurant.cityName,
        restaurant.countryName,
        restaurant.flagEmoji,
        restaurant.hasMichelinStar
            ? '${restaurant.michelinStars} ${restaurant.michelinStars == 1 ? 'Michelin star' : 'Michelin stars'}'
            : null,
      ),
      HotelVenue(:final hotel) => (
        hotel.hasMichelinKeys
            ? KeyRow(count: hotel.michelinKeys!, size: 12)
            : null,
        hotel.cityName,
        hotel.countryName,
        hotel.flagEmoji,
        hotel.hasMichelinKeys
            ? '${hotel.michelinKeys} ${hotel.michelinKeys == 1 ? 'Michelin Key' : 'Michelin Keys'}'
            : null,
      ),
    };
    final rating = visit.rating;
    final ratingLabel = rating == null
        ? _formatDate(visit.visitedOn)
        : '$rating/10 · ${_formatDate(visit.visitedOn)}';

    final semanticLabel = [
      v.name,
      if (city.isNotEmpty) city,
      if (country.isNotEmpty) country,
      ?recognitionLabel,
      if (rating != null) 'rated $rating out of 10',
    ].join(', ');

    return Semantics(
      button: true,
      label: semanticLabel,
      excludeSemantics: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          splashColor: AppColors.forestGreen.withValues(alpha: 0.06),
          highlightColor: AppColors.forestGreen.withValues(alpha: 0.04),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: CsSpacing.sm),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const VenueThumbnail(imageUrl: null, size: 52),
                const SizedBox(width: CsSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      recognition == null
                          ? Text(
                              v.name,
                              style: CsTypography.placeTitle.copyWith(
                                fontSize: 17,
                                color: AppColors.forestGreen,
                              ),
                            )
                          : Text.rich(
                              TextSpan(
                                children: [
                                  TextSpan(
                                    text: v.name,
                                    style: CsTypography.placeTitle.copyWith(
                                      fontSize: 17,
                                      color: AppColors.forestGreen,
                                    ),
                                  ),
                                  const WidgetSpan(
                                    child: SizedBox(width: CsSpacing.xs),
                                  ),
                                  WidgetSpan(
                                    alignment: PlaceholderAlignment.middle,
                                    child: recognition,
                                  ),
                                ],
                              ),
                            ),
                      const SizedBox(height: 2),
                      Text(
                        ratingLabel,
                        style: CsTypography.metadata.copyWith(
                          color: AppColors.taupe,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (city.isNotEmpty || flag.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (city.isNotEmpty)
                              Flexible(
                                child: Text(
                                  city,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: CsTypography.metadata.copyWith(
                                    color: AppColors.taupe,
                                  ),
                                ),
                              ),
                            if (city.isNotEmpty && flag.isNotEmpty)
                              const SizedBox(width: CsSpacing.xs),
                            if (flag.isNotEmpty)
                              Text(flag, style: const TextStyle(fontSize: 13)),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
