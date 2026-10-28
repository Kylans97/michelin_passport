import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/cs_spacing.dart';
import '../../../core/theme/cs_typography.dart';
import '../../../core/widgets/cs_place_card.dart';
import '../../../core/widgets/key_row.dart';
import '../../../core/widgets/star_row.dart';
import '../../../core/widgets/venue_thumbnail.dart';
import '../../../models/passport_venue.dart';
import '../../../models/planned_venue.dart';
import '../../../models/resolved_planned_venue.dart';

const _monthNames = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

String _formatPlanDate(ResolvedPlannedVenue item) {
  final start = item.plan.startDate;
  final end = item.plan.endDate;
  final startLabel =
      '${start.day} ${_monthNames[start.month - 1]} ${start.year}';
  if (end == null) return startLabel;
  return '$startLabel – ${end.day} ${_monthNames[end.month - 1]} '
      '${end.year}';
}

// "Paris, 🇫🇷 France" — the same location line Passport's own cards use;
// falls back to plain "City, Country" when flagEmoji is empty rather than
// inventing one from the country code.
String _locationLabel(PassportVenue venue) {
  final (city, flag, country) = switch (venue) {
    RestaurantVenue(:final restaurant) => (
      restaurant.cityName,
      restaurant.flagEmoji,
      restaurant.countryName,
    ),
    HotelVenue(:final hotel) => (
      hotel.cityName,
      hotel.flagEmoji,
      hotel.countryName,
    ),
  };
  final countryPart = flag.isNotEmpty ? '$flag $country' : country;
  return '$city, $countryPart';
}

/// One planned restaurant visit / hotel stay — used both under
/// "PLANNED VISITS" (standalone, no trip) and inside Trip Detail's
/// Stay/Dining lists. Tapping opens the venue's existing Detail screen;
/// edit/cancel live behind [onLongPress] to keep the card itself calm.
///
/// Trips restyle (2026-10-28): built on [CsPlaceCard] — the same ivory
/// photo card Passport's collection, Wishlist and Rankings already use —
/// rather than its own dark row, so a planned venue looks like the same
/// place everywhere it appears. The thumbnail is the venue's card photo
/// ([Restaurant.cardImageUrl]/[Hotel.cardImageUrl], card photo else cover,
/// per CLAUDE.md's card-photo rule); the plan date is the eyebrow; stars/
/// Keys come straight from [item.venue] (already resolved, no new query)
/// and stay the only gold on the card. A cancelled plan is dimmed and
/// labelled rather than struck through. [trailing] is an optional
/// top-right control — Trip Detail's explicit "remove from trip".
class PlannedVenueRow extends StatelessWidget {
  final ResolvedPlannedVenue item;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final Widget? trailing;

  const PlannedVenueRow({
    super.key,
    required this.item,
    required this.onTap,
    this.onLongPress,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final venue = item.venue;
    final isCancelled = item.plan.status == PlannedVenueStatus.cancelled;
    final isCompleted = item.plan.status == PlannedVenueStatus.completed;
    final (imageUrl, framing) = switch (venue) {
      RestaurantVenue(:final restaurant) => (
        restaurant.cardImageUrl,
        restaurant.cardFraming,
      ),
      HotelVenue(:final hotel) => (hotel.cardImageUrl, hotel.cardFraming),
    };
    final distinction = switch (venue) {
      RestaurantVenue(:final restaurant) when restaurant.hasMichelinStar =>
        StarRow(count: restaurant.michelinStars!, size: 12),
      HotelVenue(:final hotel) when hotel.hasMichelinKeys => KeyRow(
        count: hotel.michelinKeys!,
        size: 12,
      ),
      _ => null,
    };
    final location = _locationLabel(venue);
    final statusSuffix = isCancelled
        ? '. Cancelled'
        : isCompleted
        ? '. Completed'
        : '';

    final card = CsPlaceCard(
      image: VenueThumbnail(
        imageUrl: imageUrl,
        framing: framing,
        width: _imageSize,
        height: _imageSize,
        borderRadius: const BorderRadius.all(Radius.circular(CsRadius.medium)),
      ),
      imageSize: _imageSize,
      eyebrow: _formatPlanDate(item).toUpperCase(),
      title: venue.name,
      subtitle: location,
      awardRow: distinction,
      footer: (isCompleted || isCancelled)
          ? Text(
              item.plan.status.label,
              style: CsTypography.smallLabel.copyWith(color: AppColors.taupe),
            )
          : null,
      bookmark: trailing,
      onTap: onTap,
      onLongPress: onLongPress,
    );

    return Semantics(
      button: true,
      label: '${venue.name}, $location. ${_formatPlanDate(item)}$statusSuffix',
      child: isCancelled ? Opacity(opacity: 0.6, child: card) : card,
    );
  }
}

const double _imageSize = 72;
