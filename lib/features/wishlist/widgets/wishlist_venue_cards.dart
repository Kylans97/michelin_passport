import 'package:flutter/material.dart';
import '../../../core/widgets/cs_header_drawing.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/cs_spacing.dart';
import '../../../core/theme/cs_typography.dart';
import '../../../core/widgets/cs_place_card.dart';
import '../../../core/widgets/key_row.dart';
import '../../../core/widgets/star_row.dart';
import '../../../core/widgets/venue_thumbnail.dart';
import '../../../models/booking_window.dart';
import '../../../models/hotel.dart';
import '../../../models/restaurant.dart';
import '../../hotels/hotel_detail_screen.dart';
import '../../passport/widgets/passport_card_chrome.dart';
import '../../restaurants/restaurant_detail_screen.dart';
import '../../../core/analytics/analytics_properties.dart';

/// PASSPORT — WISHLIST UI POLISH V1: a saved restaurant, in the exact same
/// ivory `CsPlaceCard` family as Passport's own collection cards
/// ([PassportRestaurantCard]) — same image slot, same serif title, same
/// award row, same bookmark chrome. Deliberately NOT a reuse of
/// [PassportRestaurantCard] itself: that widget requires
/// [PassportVenueStats] (visit count/average rating), a concept that
/// doesn't exist for a wishlisted-but-never-visited venue. No
/// [CsPlaceCard.fullWidthFooter] here for the same reason — Wishlist is
/// not visit history, so a rating/visit-count footer would be either
/// fabricated or misleading; the card answers exactly what/where/
/// recognition/saved, nothing else.
///
/// The one footer it does carry is the member's own plan
/// (20261101400000): the month they'd like to go and, when the
/// restaurant's booking window is known, when that month opens. Tapping
/// it ([onEditPlan]) sets, changes or clears the month. Without
/// [onEditPlan] (no signed-in member) there is no footer.
///
/// [onRemove] always means "remove from wishlist" — every card in this
/// list is, by definition, already wishlisted, so [PassportCardBookmark]
/// is used here as a filled, remove-only affordance rather than a
/// toggle between two states.
class WishlistRestaurantCard extends StatelessWidget {
  final Restaurant restaurant;
  final VoidCallback onRemove;
  final WishlistPlan? plan;
  final VoidCallback? onEditPlan;

  /// Decides whether the opening date needs its year; tests pass a fixed one.
  final DateTime? now;

  const WishlistRestaurantCard({
    super.key,
    required this.restaurant,
    required this.onRemove,
    this.plan,
    this.onEditPlan,
    this.now,
  });

  @override
  Widget build(BuildContext context) => CsPlaceCard(
    image: VenueThumbnail(
      imageUrl: restaurant.cardImageUrl,
      framing: restaurant.cardFraming,
      drawing: HeaderDrawing.restaurant(restaurant.id),
      width: 96,
      height: 96,
      borderRadius: const BorderRadius.all(Radius.circular(CsRadius.medium)),
    ),
    title: restaurant.name,
    subtitle: _locationLabel(
      cityName: restaurant.cityName,
      countryName: restaurant.countryName,
      flagEmoji: restaurant.flagEmoji,
    ),
    awardRow: restaurant.hasMichelinStar
        ? StarRow(count: restaurant.michelinStars!, size: 14)
        : null,
    bookmark: PassportCardBookmark(isWishlisted: true, onTap: onRemove),
    fullWidthFooter: onEditPlan == null
        ? null
        : WishlistPlanFooter(
            plan: plan,
            onTap: onEditPlan!,
            now: now ?? DateTime.now(),
          ),
    onTap: () => Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RestaurantDetailScreen(
          restaurant: restaurant,
          openSource: AnalyticsOpenSource.wishlist,
        ),
      ),
    ),
  );
}

/// "Going in May 2027" and, when known, when May's bookings open — or,
/// with no month yet, a quiet invitation to set one.
class WishlistPlanFooter extends StatelessWidget {
  final WishlistPlan? plan;
  final VoidCallback onTap;
  final DateTime now;

  const WishlistPlanFooter({
    super.key,
    required this.plan,
    required this.onTap,
    required this.now,
  });

  @override
  Widget build(BuildContext context) {
    final plan = this.plan;
    final status = plan?.statusLine(now);
    return Semantics(
      button: true,
      label: plan == null
          ? 'Set when you would like to go'
          : 'Change the month',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(CsRadius.small),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              plan?.status == BookingStatus.open ||
                      plan?.status == BookingStatus.opensToday
                  ? Icons.event_available_outlined
                  : Icons.calendar_month_outlined,
              color: AppColors.forestGreen,
              size: 16,
            ),
            const SizedBox(width: CsSpacing.sm),
            Expanded(
              child: plan == null
                  ? Text(
                      'When would you like to go?',
                      style: CsTypography.metadata.copyWith(
                        color: AppColors.taupe,
                      ),
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          plan.monthLabel,
                          style: CsTypography.bodyMedium.copyWith(
                            color: AppColors.forestGreen,
                          ),
                        ),
                        if (status != null) ...[
                          const SizedBox(height: 2),
                          Text(status, style: CsTypography.metadata),
                        ],
                      ],
                    ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: AppColors.taupe,
              size: 18,
            ),
          ],
        ),
      ),
    );
  }
}

/// The hotel counterpart to [WishlistRestaurantCard] — same shell, Keys
/// instead of Stars, Hotel Detail instead of Restaurant Detail. See that
/// class's own doc comment for why this isn't a reuse of
/// [PassportHotelCard].
class WishlistHotelCard extends StatelessWidget {
  final Hotel hotel;
  final VoidCallback onRemove;

  const WishlistHotelCard({
    super.key,
    required this.hotel,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) => CsPlaceCard(
    image: VenueThumbnail(
      imageUrl: hotel.cardImageUrl,
      framing: hotel.cardFraming,
      drawing: HeaderDrawing.hotel(hotel.id),
      width: 96,
      height: 96,
      borderRadius: const BorderRadius.all(Radius.circular(CsRadius.medium)),
    ),
    title: hotel.name,
    subtitle: _locationLabel(
      cityName: hotel.cityName,
      countryName: hotel.countryName,
      flagEmoji: hotel.flagEmoji,
    ),
    awardRow: hotel.hasMichelinKeys
        ? KeyRow(count: hotel.michelinKeys!, size: 14)
        : null,
    bookmark: PassportCardBookmark(isWishlisted: true, onTap: onRemove),
    onTap: () => Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => HotelDetailScreen(
          hotel: hotel,
          openSource: AnalyticsOpenSource.wishlist,
        ),
      ),
    ),
  );
}

// "City, 🇳🇱 Country" — matches PassportRestaurantCard/PassportHotelCard's
// own location-label rule exactly, falling back to plain "City, Country"
// when flagEmoji is empty rather than inventing one from countryCode.
String _locationLabel({
  required String cityName,
  required String countryName,
  required String flagEmoji,
}) {
  final country = flagEmoji.isNotEmpty
      ? '$flagEmoji $countryName'
      : countryName;
  return '$cityName, $country';
}
