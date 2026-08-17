import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../theme/cs_spacing.dart';
import '../theme/cs_surface_context.dart';
import '../theme/cs_typography.dart';

/// The redesigned filter chip — height 44 / radius 22 / ~18 horizontal
/// padding per the brief, dual-surface aware per [CsSurface]. Selected
/// state is always an ivory/deep-green surface swap, never a brass fill
/// ("Muted brass should not become the default selected-filter
/// background"). Wired into Wishlist's Restaurants/Hotels selector
/// (`CsSurface.dark`, the default); Explore's/Events'/Trips' own filter
/// chips keep their current styling until those screens are individually
/// redesigned.
///
/// Green Token Consistency Migration: on `CsSurface.dark`, the
/// *unselected* background is deliberately [AppColors.forestGreen], not
/// [AppColors.deepGreen] — this is the one intentional case forestGreen
/// remains in active use, matching [CsSurfaces.greenElevated]'s own
/// documented role: a panel/pill lifted one shade off whatever deepGreen
/// canvas it sits on (Wishlist's header, now), so it stays visually
/// distinct from that canvas rather than disappearing into it. forestGreen
/// is never used for a canvas/masthead/hero itself — only for a surface
/// that's already sitting *on* one.
class CsFilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final CsSurface surface;
  final IconData? icon;

  const CsFilterChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.surface = CsSurface.dark,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final onDark = surface == CsSurface.dark;

    final Color background;
    final Color foreground;
    if (onDark) {
      background = selected ? AppColors.ivory : AppColors.forestGreen;
      foreground = selected ? AppColors.deepGreen : AppColors.textOnDark;
    } else {
      background = selected ? AppColors.deepGreen : AppColors.warmWhite;
      foreground = selected ? AppColors.textOnDark : AppColors.forestGreen;
    }
    final border = onDark
        ? AppColors.subtleBorderDark
        : AppColors.subtleBorderLight;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Container(
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 18),
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: border, width: 0.5),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 16, color: foreground),
                const SizedBox(width: CsSpacing.xs),
              ],
              Text(
                label,
                style: CsTypography.smallLabel.copyWith(color: foreground),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
