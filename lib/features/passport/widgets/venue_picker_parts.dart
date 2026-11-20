import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show OverflowBoxFit;
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/cs_editorial_glyphs.dart' show CsCountryLabel;
import '../../../core/widgets/key_row.dart';
import '../../../core/widgets/star_row.dart';
import '../../../core/widgets/cs_header_drawing.dart';
import '../../../core/widgets/venue_thumbnail.dart';
import '../../../models/journey.dart';
import '../../../models/passport_venue.dart';
import '../../../models/vineyard.dart';
import '../../../core/theme/cs_fonts.dart';

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
          style: CsFonts.sans(
            color: selected ? AppColors.forestGreen : AppColors.textOnDark,
            fontSize: 13.5,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    ),
  );
}

/// How far a picker row's tap highlight reaches past the content on
/// each side, so the rounded highlight doesn't hug — and look cut off
/// at — the thumbnail. [PickerRowList] lets rows bleed by exactly this
/// much, so the thumbnails still line up with the search field above.
const double pickerRowBleed = 10;

/// Lays out picker rows so each row's highlight reaches [pickerRowBleed]
/// past both edges of the column, while the rows' content keeps the
/// column's own left and right edges.
class PickerRowList extends StatelessWidget {
  final List<Widget> children;
  const PickerRowList({super.key, required this.children});

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => OverflowBox(
      fit: OverflowBoxFit.deferToChild,
      minWidth: constraints.maxWidth + 2 * pickerRowBleed,
      maxWidth: constraints.maxWidth + 2 * pickerRowBleed,
      child: Column(children: children),
    ),
  );
}

/// [52pt thumbnail | title + detail line | trailing] — the row of every
/// green picker. [trailing] defaults to a chevron. Use inside a
/// [PickerRowList].
class PickerRow extends StatelessWidget {
  final Widget thumbnail;
  final String title;
  final Widget detail;
  final VoidCallback onTap;
  final Widget? trailing;
  const PickerRow({
    super.key,
    required this.thumbnail,
    required this.title,
    required this.detail,
    required this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.transparent,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      splashColor: AppColors.ivory.withValues(alpha: 0.06),
      highlightColor: AppColors.ivory.withValues(alpha: 0.06),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          vertical: 8,
          horizontal: pickerRowBleed,
        ),
        child: Row(
          children: [
            thumbnail,
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: CsFonts.serif(
                      color: AppColors.textOnDark,
                      fontSize: 15.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  detail,
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

/// A restaurant or hotel as a [PickerRow]: photo, name, stars or Keys,
/// City · CC. Shared by Passport's add-visit flow and Wishlist's add sheet.
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
    return PickerRow(
      onTap: onTap,
      trailing: trailing,
      title: venuePickerName(venue),
      thumbnail: VenueThumbnail(
        imageUrl: venue.cardImageUrl,
        framing: venue.cardFraming,
        size: 52,
        borderRadius: const BorderRadius.all(Radius.circular(4)),
      ),
      detail: Row(
        children: [
          if (award != null) ...[award, const SizedBox(width: 6)],
          Flexible(
            child: CsCountryLabel(
              cityName: cityName,
              countryCode: venue.countryCode,
              style: CsFonts.sans(
                color: AppColors.secondaryOnDark,
                fontSize: 12.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A wine estate as a [PickerRow]: its line drawing, name, and where it
/// is. No award row — the World's 50 Best Vineyards rank is not a MICHELIN
/// distinction.
class VineyardPickerRow extends StatelessWidget {
  final Vineyard vineyard;
  final VoidCallback onTap;
  final Widget? trailing;
  const VineyardPickerRow({
    super.key,
    required this.vineyard,
    required this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) => PickerRow(
    onTap: onTap,
    trailing: trailing,
    title: vineyard.name,
    thumbnail: VenueThumbnail(
      imageUrl: null,
      drawing: HeaderDrawing.vineyard(vineyard.id),
      size: 52,
      borderRadius: const BorderRadius.all(Radius.circular(4)),
    ),
    detail: Text(
      vineyard.cardPlaceLabel,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: CsFonts.sans(color: AppColors.secondaryOnDark, fontSize: 12.5),
    ),
  );
}

/// A train or ship as a [PickerRow]: its line drawing, name, and its kind
/// with the operator.
class JourneyPickerRow extends StatelessWidget {
  final Journey journey;
  final VoidCallback onTap;
  final Widget? trailing;
  const JourneyPickerRow({
    super.key,
    required this.journey,
    required this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) => PickerRow(
    onTap: onTap,
    trailing: trailing,
    title: journey.name,
    thumbnail: VenueThumbnail(
      imageUrl: null,
      drawing: HeaderDrawing.journey(
        journey.id,
        journey.kind,
        shipType: journey.shipType,
      ),
      size: 52,
      borderRadius: const BorderRadius.all(Radius.circular(4)),
    ),
    detail: Text(
      '${journey.kindLabel} · ${journey.operatorName}',
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: CsFonts.sans(color: AppColors.secondaryOnDark, fontSize: 12.5),
    ),
  );
}
