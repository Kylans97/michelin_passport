import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/cs_spacing.dart';
import '../../../core/theme/cs_typography.dart';
import '../wishlist_view_model.dart';
import 'wishlist_view_selector.dart' show wishlistViewIcon;

/// One place on "Everything, by place": the region, its country and what
/// is saved there, then a compact row per saved thing — a kind icon, the
/// name, the kind and town. Tapping a row opens that thing's own page.
class WishlistPlaceCard extends StatelessWidget {
  final WishlistPlaceGroup group;
  final ValueChanged<Object> onTapItem;

  const WishlistPlaceCard({
    super.key,
    required this.group,
    required this.onTapItem,
  });

  @override
  Widget build(BuildContext context) {
    final summary = wishlistGroupSummary(group);
    final subtitle = group.isOnTheMove
        ? '$summary · they cross borders'
        : [?group.country, summary].join(' · ');
    return Container(
      padding: const EdgeInsets.fromLTRB(
        CsSpacing.base,
        CsSpacing.base,
        CsSpacing.base,
        CsSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: AppColors.forestGreen,
        borderRadius: BorderRadius.circular(CsRadius.large),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            group.title,
            style: CsTypography.sectionTitle.copyWith(
              color: AppColors.textOnDark,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: CsTypography.metadata.copyWith(
              color: AppColors.secondaryOnDark,
            ),
          ),
          const SizedBox(height: CsSpacing.sm),
          for (final item in group.items)
            _PlaceRow(item: item, onTap: () => onTapItem(item.target)),
        ],
      ),
    );
  }
}

class _PlaceRow extends StatelessWidget {
  final WishlistPlaceItem item;
  final VoidCallback onTap;

  const _PlaceRow({required this.item, required this.onTap});

  String get _kindLabel => switch (item.kind) {
    WishlistView.restaurants => 'Restaurant',
    WishlistView.hotels => 'Hotel',
    WishlistView.events => 'Event',
    WishlistView.estates => 'Wine estate',
    WishlistView.trains => 'Train',
    WishlistView.ships => 'Ship',
    WishlistView.everything => '',
  };

  @override
  Widget build(BuildContext context) {
    final detail = [_kindLabel, ?item.town].join(' · ');
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(CsRadius.medium),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 52),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: CsSpacing.sm),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: const BoxDecoration(
                  color: AppColors.deepGreen,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  wishlistViewIcon(item.kind),
                  size: 16,
                  color: AppColors.textOnDark,
                ),
              ),
              const SizedBox(width: CsSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: CsTypography.placeTitle.copyWith(
                        color: AppColors.textOnDark,
                        fontSize: 16,
                        height: 1.3,
                      ),
                    ),
                    Text(
                      detail,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: CsTypography.metadata.copyWith(
                        color: AppColors.secondaryOnDark,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: AppColors.secondaryOnDark,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
