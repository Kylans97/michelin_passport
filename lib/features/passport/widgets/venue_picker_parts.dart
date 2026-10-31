import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/cs_editorial_glyphs.dart' show CsCountryLabel;
import '../../../core/widgets/key_row.dart';
import '../../../core/widgets/star_row.dart';
import '../../../core/widgets/venue_thumbnail.dart';
import '../../../models/passport_venue.dart';

/// Pieces shared by the green venue pickers — Passport's add-visit flow
/// and Wishlist's add sheet — so both look and behave the same.

String venuePickerName(PassportVenue v) => switch (v) {
  RestaurantVenue(:final restaurant) => restaurant.name,
  HotelVenue(:final hotel) => hotel.name,
};

/// The Restaurant/Hotel toggle chip on the green venue pickers.
class VenueTypeChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const VenueTypeChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Material(
    color: selected ? AppColors.ivory : Colors.transparent,
    borderRadius: BorderRadius.circular(999),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          border: selected
              ? null
              : Border.all(color: AppColors.hairlineOnGreen),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            color: selected ? AppColors.forestGreen : AppColors.textOnDark,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    ),
  );
}

/// [52pt photo or initial tile | name + stars/keys + City · CC | trailing]
/// — the row shape of every green venue picker: Passport's add-visit flow
/// (shortcuts and search results) and Wishlist's add sheet. [trailing]
/// defaults to a chevron.
class VenuePickerRow extends StatelessWidget {
  final PassportVenue venue;
  final VoidCallback onTap;
  final Widget? trailing;
  const VenuePickerRow({
    super.key,
    required this.venue,
    required this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final award = switch (venue) {
      RestaurantVenue(:final restaurant) =>
        (restaurant.michelinStars ?? 0) > 0
            ? StarRow(count: restaurant.michelinStars!, size: 12)
            : null,
      HotelVenue(:final hotel) =>
        (hotel.michelinKeys ?? 0) > 0
            ? KeyRow(count: hotel.michelinKeys!, size: 12)
            : null,
    };
    final cityName = switch (venue) {
      RestaurantVenue(:final restaurant) => restaurant.cityName,
      HotelVenue(:final hotel) => hotel.cityName,
    };
    final countryCode = venue.countryCode;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              VenueThumbnail(
                imageUrl: venue.cardImageUrl,
                framing: venue.cardFraming,
                size: 52,
                borderRadius: const BorderRadius.all(Radius.circular(4)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      venuePickerName(venue),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.cormorantGaramond(
                        color: AppColors.textOnDark,
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        if (award != null) ...[award, const SizedBox(width: 6)],
                        Flexible(
                          child: CsCountryLabel(
                            cityName: cityName,
                            countryCode: countryCode,
                            style: GoogleFonts.inter(
                              color: AppColors.secondaryOnDark,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              trailing ??
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: AppColors.secondaryOnDark,
                    size: 20,
                  ),
            ],
          ),
        ),
      ),
    );
  }
}
