import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/cs_spacing.dart';
import '../../../core/theme/cs_typography.dart';
import '../../../core/widgets/star_row.dart';
import '../../../models/private_chef_restaurant_history.dart';

/// One restaurant-background item in Chef Detail's BACKGROUND section
/// (renamed from "Restaurant Provenance" in Step 2B — background now also
/// includes non-restaurant items, e.g. education, via the sibling
/// [PrivateChefEducationRow] — but this widget itself is unchanged:
/// restaurant background keeps its own richer shape).
///
/// HARD RULE (PRIVATE_CHEFS.md §10/§15): [StarRow] renders beside the
/// RESTAURANT name, sourced only from [PrivateChefRestaurantHistory.
/// restaurant]'s own current `michelinStars` — never beside the chef's own
/// name, never implying the chef personally holds the recognition. This is
/// the only place in the entire Private Chefs feature a star is ever
/// rendered. Audited explicitly in Step 2B for a non-kitchen role
/// (front-of-house "Service"): the star renders only on the same line as
/// —  and grammatically bound only to — the restaurant's own name (via one
/// `Text.rich` span); `role`/`period_text` render on their own separate
/// line below, in a visually distinct, subordinate style. There is no
/// rendering path where a star could appear adjacent to a role/period
/// value or to the chef's own name — confirmed unambiguous as-is, no
/// change required.
///
/// Canonical rows (`history.isCanonical`) are tappable → the caller's
/// [onTap] (RestaurantDetailScreen) and show the restaurant's city + flag.
/// Text-only rows are never tappable ([onTap] is ignored/absent), never
/// show stars, and never show a fabricated location — only
/// [PrivateChefRestaurantHistory.restaurantNameText] plus role/period.
class PrivateChefProvenanceRow extends StatelessWidget {
  final PrivateChefRestaurantHistory history;
  final VoidCallback? onTap;

  const PrivateChefProvenanceRow({
    super.key,
    required this.history,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final restaurant = history.restaurant;
    final isCanonical = restaurant != null;

    final roleAndPeriod = [
      history.role,
      history.periodText,
    ].where((s) => (s ?? '').trim().isNotEmpty).join(' · ');
    final hasRoleAndPeriod = roleAndPeriod.isNotEmpty;

    final city = restaurant?.cityName.trim() ?? '';
    final flag = restaurant?.flagEmoji.trim() ?? '';
    final hasCity = city.isNotEmpty;
    final hasFlag = flag.isNotEmpty;

    final semanticLabel = isCanonical
        ? [
            restaurant.name,
            if (hasCity) city,
            if (restaurant.countryName.isNotEmpty) restaurant.countryName,
            if (restaurant.hasMichelinStar)
              '${restaurant.michelinStars} Michelin '
                  '${restaurant.michelinStars == 1 ? 'star' : 'stars'}',
          ].join(', ')
        : history.displayName;

    final body = Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (isCanonical && restaurant.hasMichelinStar)
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: history.displayName,
                        style: CsTypography.placeTitle.copyWith(
                          fontSize: 17,
                          color: AppColors.forestGreen,
                        ),
                      ),
                      const WidgetSpan(child: SizedBox(width: CsSpacing.xs)),
                      WidgetSpan(
                        alignment: PlaceholderAlignment.middle,
                        child: StarRow(count: restaurant.michelinStars!),
                      ),
                    ],
                  ),
                )
              else
                Text(
                  history.displayName,
                  style: CsTypography.placeTitle.copyWith(
                    fontSize: 17,
                    color: AppColors.forestGreen,
                  ),
                ),
              if (hasRoleAndPeriod) ...[
                const SizedBox(height: 2),
                Text(
                  roleAndPeriod,
                  style: CsTypography.metadata.copyWith(color: AppColors.taupe),
                ),
              ],
              if (isCanonical && (hasCity || hasFlag)) ...[
                const SizedBox(height: 2),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (hasCity)
                      Flexible(
                        child: Text(
                          city,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: CsTypography.metadata.copyWith(
                            color: AppColors.taupe,
                          ),
                        ),
                      ),
                    if (hasCity && hasFlag) const SizedBox(width: CsSpacing.xs),
                    if (hasFlag)
                      Text(flag, style: const TextStyle(fontSize: 13)),
                  ],
                ),
              ],
            ],
          ),
        ),
        if (isCanonical) ...[
          const SizedBox(width: CsSpacing.sm),
          const Icon(
            Icons.arrow_forward_rounded,
            color: AppColors.taupe,
            size: 18,
          ),
        ],
      ],
    );

    if (!isCanonical) {
      return Semantics(
        label: semanticLabel,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: CsSpacing.sm),
          child: body,
        ),
      );
    }

    return Semantics(
      button: true,
      label: semanticLabel,
      excludeSemantics: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          splashColor: AppColors.forestGreen.withValues(alpha: 0.06),
          highlightColor: AppColors.forestGreen.withValues(alpha: 0.04),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: CsSpacing.sm),
            child: body,
          ),
        ),
      ),
    );
  }
}
