import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/cs_typography.dart';

/// A World's 50 Best ranking's numeral, e.g. "#3" or "#100" — knows only a
/// rank number and how to render it, nothing about Restaurant, Hotel,
/// repositories or list_type (see the Guides Step 2C brief's "no huge
/// generic award system" instruction). Passed into [GuideVenueCard]'s
/// [leading] slot rather than folded into that widget directly, so
/// GuideVenueCard itself stays presentation-only and unaware that ranking
/// is even a concept.
///
/// `#1`/`#12`/`#100` rather than zero-padded `01`/`12`/`100` — the Step 2C
/// brief's own stated preference: clearer, less decorative. Cormorant
/// Garamond (CsTypography.largeMetric — "a serif numeral treatment for
/// scores/ratings/counts", already the app's established "this is a
/// number worth reading, not a heading" role) at a subdued secondaryOnDark
/// tone, deliberately not gold and not a badge/circle — the brief is
/// explicit that the rank should read as editorial, not as a sports
/// leaderboard position.
///
/// Rendered in a fixed-width box (wide enough for "#100") so the venue
/// text column that follows always starts at the same horizontal position
/// regardless of whether a given row shows "#1" or "#100" — without this,
/// a scrolling list of ranks would visibly zig-zag.
class GuideRankMark extends StatelessWidget {
  final int rank;

  const GuideRankMark({super.key, required this.rank});

  static const double _columnWidth = 44;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: _columnWidth,
    child: Text(
      '#$rank',
      style: CsTypography.largeMetric.copyWith(
        color: AppColors.secondaryOnDark,
        fontSize: 20,
      ),
    ),
  );
}
