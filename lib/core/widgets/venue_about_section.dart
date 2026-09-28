import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../theme/cs_spacing.dart';
import '../theme/cs_typography.dart';

/// The editorial "ABOUT" paragraph seam (UI Consistency Step 1B —
/// physical-device polish, §19-21). Neither [Restaurant] nor [Hotel] has
/// an editorial-copy column of its own (no `description`/`about`/
/// `summary` column on `restaurants_full`/`hotels_full`) — the text
/// shown here comes from `venue_about_current` instead (the latest
/// APPROVED row in `venue_about_submissions`, a venue manager's own
/// submitted copy, reviewed by hand before it ever reaches this widget —
/// see `VenueAboutRepository`/`VenueManagementScreen`). Both
/// `RestaurantDetailScreen` and `HotelDetailScreen` load that value
/// themselves (`_loadAboutText`/`_aboutText`) and pass it through here.
///
/// Renders nothing ([SizedBox.shrink], never a "No description
/// available." placeholder) whenever [text] is null or blank — true both
/// when nothing has ever been approved for a venue, and while an
/// about-text lookup is still in flight (both call sites start `_aboutText`
/// at `null`) — so this section simply doesn't exist on the page until
/// there's real, approved copy to show.
///
/// [heading] defaults to "ABOUT", unchanged for Restaurant/Hotel Detail.
/// PrivateChefDetailScreen passes "FROM THE TEAM" instead: that screen
/// already has its OWN, older "ABOUT" section rendering
/// `private_chefs.biography` (a verified catalogue fact, left untouched —
/// see that screen's own doc comment), so reusing "ABOUT" here too would
/// read as a duplicated section rather than two genuinely different kinds
/// of content sitting next to each other.
class VenueAboutSection extends StatelessWidget {
  final String? text;
  final String heading;
  const VenueAboutSection({super.key, required this.text, this.heading = 'ABOUT'});

  @override
  Widget build(BuildContext context) {
    final copy = text?.trim();
    if (copy == null || copy.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          heading,
          style: CsTypography.eyebrow.copyWith(color: AppColors.taupe),
        ),
        const SizedBox(height: CsSpacing.md),
        Text(
          copy,
          style: CsTypography.body.copyWith(
            color: AppColors.forestGreen,
            height: 1.6,
          ),
        ),
      ],
    );
  }
}
