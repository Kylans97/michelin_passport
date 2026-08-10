import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../theme/cs_spacing.dart';
import '../theme/cs_surface_context.dart';
import '../theme/cs_typography.dart';

/// The redesigned filter chip — height 44 / radius 22 / ~18 horizontal
/// padding per the brief, dual-surface aware per [CsSurface]. Selected
/// state is always an ivory/deep-green surface swap, never a brass fill
/// ("Muted brass should not become the default selected-filter
/// background"). Not wired into any existing filter bar yet — Explore's/
/// Events'/Trips' filter chips keep their current styling until those
/// screens are individually redesigned.
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
      foreground = selected ? AppColors.textOnDark : AppColors.charcoal;
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
