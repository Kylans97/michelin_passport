import 'package:flutter/material.dart';
import '../../../core/theme/cs_spacing.dart';
import '../../../core/widgets/cs_image_placeholder.dart';
import '../../../core/widgets/cs_place_card.dart';
import '../../../core/widgets/key_row.dart';
import '../../../models/hotel.dart';
import '../../hotels/hotel_detail_screen.dart';
import '../passport_view_model.dart';
import 'passport_card_chrome.dart';

// "City, 🇬🇧 Country" — falls back to plain "City, Country" when
// flagEmoji is empty rather than inventing one from countryCode.
String _locationLabel(Hotel hotel) {
  final country = hotel.flagEmoji.isNotEmpty
      ? '${hotel.flagEmoji} ${hotel.countryName}'
      : hotel.countryName;
  return '${hotel.cityName}, $country';
}

/// One unique hotel in the Passport list, scoped to the active
/// venue-type/year filter: stay count and average rating reflect only the
/// stays [stats] was built from. Tapping opens the existing
/// HotelDetailScreen, exactly as before — only the visual presentation
/// (now built on [CsPlaceCard]) changed. KeyRow is reused unchanged
/// (gold-filled keys) — see PassportRestaurantCard's matching note on
/// StarRow.
///
/// Passport UI Polish V2: see PassportRestaurantCard's matching note —
/// "Last stay DATE" removed from the footer; the bookmark is now a real,
/// wired wishlist toggle rather than a static glyph.
class PassportHotelCard extends StatelessWidget {
  final Hotel hotel;
  final PassportVenueStats stats;
  final bool isWishlisted;
  final VoidCallback onToggleWishlist;

  const PassportHotelCard({
    super.key,
    required this.hotel,
    required this.stats,
    required this.isWishlisted,
    required this.onToggleWishlist,
  });

  @override
  Widget build(BuildContext context) {
    final avg = stats.averageRating;

    return CsPlaceCard(
      image: const CsImagePlaceholder(
        borderRadius: BorderRadius.all(Radius.circular(CsRadius.medium)),
      ),
      title: hotel.name,
      subtitle: _locationLabel(hotel),
      awardRow: hotel.hasMichelinKeys
          ? KeyRow(count: hotel.michelinKeys!, size: 14)
          : null,
      bookmark: PassportCardBookmark(
        isWishlisted: isWishlisted,
        onTap: onToggleWishlist,
      ),
      fullWidthFooter: PassportCardFooter(
        // See PassportRestaurantCard's matching note — visitCount is
        // always >= 1 here; avg is null only when unrated, never
        // "never stayed."
        ratingText:
            (avg != null ? '${avg.toStringAsFixed(1)} · ' : '') +
            (stats.visitCount == 1 ? '1 stay' : '${stats.visitCount} stays'),
      ),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => HotelDetailScreen(hotel: hotel)),
      ),
    );
  }
}
