import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/cs_spacing.dart';
import '../../../core/theme/cs_typography.dart';
import '../wishlist_view_model.dart';

/// The quiet icon for each wishlist kind — the selector sheet and the
/// by-place rows use the same ones.
IconData wishlistViewIcon(WishlistView view) => switch (view) {
  WishlistView.everything => Icons.place_outlined,
  WishlistView.restaurants => Icons.restaurant_outlined,
  WishlistView.hotels => Icons.hotel_outlined,
  WishlistView.events => Icons.event_outlined,
  WishlistView.estates => Icons.wine_bar_outlined,
  WishlistView.trains => Icons.train_outlined,
  WishlistView.ships => Icons.directions_boat_outlined,
};

/// "Restaurants 18 ▾" — the one line at the top of the Wishlist that says
/// what is showing and opens [showWishlistViewSheet]. Replaces both the
/// chip row and the large "YOUR WISHLIST" title.
class WishlistViewSelector extends StatelessWidget {
  final WishlistView view;

  /// Null while loading: the line shows the label alone.
  final int? count;
  final VoidCallback? onTap;

  const WishlistViewSelector({
    super.key,
    required this.view,
    required this.count,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: count == null
        ? 'Showing ${view.label}. Change what is shown'
        : 'Showing ${view.label}, $count. Change what is shown',
    excludeSemantics: true,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(CsRadius.medium),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 44),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Flexible(
              child: Text(
                view.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: CsTypography.sectionTitle.copyWith(
                  color: AppColors.textOnDark,
                ),
              ),
            ),
            if (count != null) ...[
              const SizedBox(width: CsSpacing.sm),
              Text(
                '$count',
                style: CsTypography.metadata.copyWith(
                  color: AppColors.secondaryOnDark,
                ),
              ),
            ],
            const SizedBox(width: CsSpacing.xs),
            const Icon(
              Icons.keyboard_arrow_down_rounded,
              color: AppColors.textOnDark,
              size: 20,
            ),
          ],
        ),
      ),
    ),
  );
}

/// The selector's sheet: "Everything, by place" first, then each kind the
/// member has saved, with its count and a check on the current one.
/// Returns the chosen view, or null when dismissed.
Future<WishlistView?> showWishlistViewSheet(
  BuildContext context, {
  required WishlistContents contents,
  required WishlistView current,
}) => showModalBottomSheet<WishlistView>(
  context: context,
  backgroundColor: AppColors.deepGreen,
  shape: const RoundedRectangleBorder(
    borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
  ),
  builder: (sheetContext) => SafeArea(
    child: Padding(
      padding: const EdgeInsets.fromLTRB(
        CsSpacing.pageHorizontal,
        CsSpacing.md,
        CsSpacing.pageHorizontal,
        CsSpacing.lg,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.hairlineOnGreen,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: CsSpacing.lg),
          Text(
            'Show on your wishlist',
            style: CsTypography.sectionTitle.copyWith(
              color: AppColors.textOnDark,
            ),
          ),
          const SizedBox(height: CsSpacing.md),
          for (final view in contents.selectorViews(current))
            _ViewRow(
              view: view,
              count: contents.countOf(view),
              selected: view == current,
              onTap: () => Navigator.pop(sheetContext, view),
            ),
        ],
      ),
    ),
  ),
);

class _ViewRow extends StatelessWidget {
  final WishlistView view;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  const _ViewRow({
    required this.view,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Semantics(
    selected: selected,
    button: true,
    child: InkWell(
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 56),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: AppColors.subtleBorderDark)),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 36,
              child: Icon(
                wishlistViewIcon(view),
                size: 20,
                color: selected
                    ? AppColors.textOnDark
                    : AppColors.secondaryOnDark,
              ),
            ),
            const SizedBox(width: CsSpacing.sm),
            Expanded(
              child: Text(
                view.sheetLabel,
                style: CsTypography.body.copyWith(
                  color: AppColors.textOnDark,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ),
            Text(
              '$count',
              style: CsTypography.metadata.copyWith(
                color: AppColors.secondaryOnDark,
              ),
            ),
            SizedBox(
              width: 32,
              child: selected
                  ? const Icon(
                      Icons.check_rounded,
                      size: 18,
                      color: AppColors.textOnDark,
                    )
                  : null,
            ),
          ],
        ),
      ),
    ),
  );
}
