import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/key_row.dart';
import '../../../core/widgets/star_row.dart';
import '../../../models/passport_venue.dart';
import '../../../models/undated_visit.dart';
import '../../restaurants/restaurant_detail_screen.dart';
import '../../hotels/hotel_detail_screen.dart';
import '../../../core/analytics/analytics_properties.dart';
import '../../../core/theme/cs_fonts.dart';

/// What the member chose on an undated visit's sheet. The screen that
/// opened it does the work, so it can reload the globe and play the stamp
/// ceremony afterwards.
enum UndatedSheetAction { addDate, remove }

/// The sheet for a dashed pin: a venue the member has been to without a
/// date. Their own pin offers Add the date and Remove; a friend's only
/// says what it is. Shaped like [showVenuePreviewSheet]'s card.
Future<UndatedSheetAction?> showUndatedVisitSheet(
  BuildContext context,
  UndatedVenue undated, {
  required bool isOwn,
}) {
  return showModalBottomSheet<UndatedSheetAction>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => _UndatedVisitSheet(undated: undated, isOwn: isOwn),
  );
}

class _UndatedVisitSheet extends StatelessWidget {
  final UndatedVenue undated;
  final bool isOwn;

  const _UndatedVisitSheet({required this.undated, required this.isOwn});

  @override
  Widget build(BuildContext context) {
    final venue = undated.venue;
    final isHotel = venue is HotelVenue;
    final award = isHotel
        ? (undated.visit.keysAtVisit ?? 0)
        : (undated.visit.starsAtVisit ?? 0);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: AppColors.cardBorder, width: 0.5),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                venue.name,
                style: CsFonts.serif(
                  color: AppColors.textPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                _locationLine(venue),
                style: CsFonts.sans(
                  color: AppColors.textSecondary,
                  fontSize: 13.5,
                ),
              ),
              const SizedBox(height: 14),
              if (award > 0)
                isHotel ? KeyRow(count: award) : StarRow(count: award),
              if (award > 0) const SizedBox(height: 14),
              Text(
                isOwn
                    ? 'Date unknown · on your map, not yet in your Passport'
                    : 'Date unknown',
                style: CsFonts.sans(
                  color: AppColors.textSecondary,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 20),
              if (isOwn) ...[
                _button(
                  label: 'Add the date',
                  filled: true,
                  onPressed: () =>
                      Navigator.pop(context, UndatedSheetAction.addDate),
                ),
                const SizedBox(height: 10),
              ],
              _button(
                label: isHotel ? 'View hotel' : 'View restaurant',
                filled: !isOwn,
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => switch (venue) {
                        RestaurantVenue(:final restaurant) =>
                          RestaurantDetailScreen(
                            restaurant: restaurant,
                            openSource: AnalyticsOpenSource.map,
                          ),
                        HotelVenue(:final hotel) => HotelDetailScreen(
                          hotel: hotel,
                          openSource: AnalyticsOpenSource.map,
                        ),
                      },
                    ),
                  );
                },
              ),
              if (isOwn) ...[
                const SizedBox(height: 6),
                Center(
                  child: TextButton(
                    onPressed: () =>
                        Navigator.pop(context, UndatedSheetAction.remove),
                    child: Text(
                      'Remove from my map',
                      style: CsFonts.sans(
                        color: AppColors.textSecondary,
                        fontSize: 13.5,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _button({
    required String label,
    required bool filled,
    required VoidCallback onPressed,
  }) {
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(14),
    );
    const padding = EdgeInsets.symmetric(vertical: 14);
    final text = Text(label, style: CsFonts.sans(fontWeight: FontWeight.w600));
    return SizedBox(
      width: double.infinity,
      child: filled
          ? FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.deepGreen,
                foregroundColor: AppColors.textOnDark,
                padding: padding,
                shape: shape,
              ),
              onPressed: onPressed,
              child: text,
            )
          : OutlinedButton(
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.deepGreen,
                side: const BorderSide(color: AppColors.deepGreen),
                padding: padding,
                shape: shape,
              ),
              onPressed: onPressed,
              child: text,
            ),
    );
  }

  String _locationLine(PassportVenue venue) => switch (venue) {
    RestaurantVenue(:final restaurant) =>
      '${restaurant.flagEmoji} ${restaurant.cityName}, ${restaurant.countryName}',
    HotelVenue(:final hotel) =>
      '${hotel.flagEmoji} ${hotel.cityName}, ${hotel.countryName}',
  };
}
