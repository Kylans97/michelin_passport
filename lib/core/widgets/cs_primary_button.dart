import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../theme/cs_surface_context.dart';
import '../theme/cs_typography.dart';

/// The redesigned filled call-to-action button — the Step 1 counterpart to
/// [PrimaryButton] in `app_button.dart`, which keeps its current styling
/// unchanged for every screen using it today. Height 52 / radius 14 (a
/// component-specific value from the brief, distinct from the general
/// [CsRadius] scale), dual-surface aware per [CsSurface]: ivory/warm-
/// neutral fill with deep-green text on a green environment, or a
/// deep-green fill with ivory text on a light one — never a brass fill,
/// per the brief's explicit "Do not use: gold buttons". Exceeds the
/// 44×44 minimum touch target at any reasonable width.
class CsPrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final IconData? icon;
  final CsSurface surface;
  final double height;

  const CsPrimaryButton({
    super.key,
    required this.label,
    required this.onTap,
    this.icon,
    this.surface = CsSurface.dark,
    this.height = 52,
  });

  @override
  Widget build(BuildContext context) {
    final onDark = surface == CsSurface.dark;
    final background = onDark ? AppColors.ivory : AppColors.deepGreen;
    final foreground = onDark ? AppColors.deepGreen : AppColors.textOnDark;

    final style = FilledButton.styleFrom(
      backgroundColor: background,
      foregroundColor: foreground,
      disabledBackgroundColor: background.withValues(alpha: 0.4),
      disabledForegroundColor: foreground.withValues(alpha: 0.6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    );
    final labelText = Text(
      label,
      style: CsTypography.bodyMedium.copyWith(color: foreground),
    );

    return SizedBox(
      height: height,
      child: icon == null
          ? FilledButton(onPressed: onTap, style: style, child: labelText)
          : FilledButton.icon(
              onPressed: onTap,
              icon: Icon(icon, size: 18),
              label: labelText,
              style: style,
            ),
    );
  }
}

/// The redesigned outlined/tonal counterpart — no fill, no bright brass,
/// same dual-surface awareness as [CsPrimaryButton]. The Step 1
/// counterpart to [SecondaryButton] in `app_button.dart`.
class CsSecondaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final IconData? icon;
  final CsSurface surface;
  final double height;

  const CsSecondaryButton({
    super.key,
    required this.label,
    required this.onTap,
    this.icon,
    this.surface = CsSurface.dark,
    this.height = 52,
  });

  @override
  Widget build(BuildContext context) {
    final onDark = surface == CsSurface.dark;
    final foreground = onDark ? AppColors.textOnDark : AppColors.deepGreen;
    final border = onDark
        ? AppColors.subtleBorderDark
        : AppColors.subtleBorderLight;

    final style = OutlinedButton.styleFrom(
      foregroundColor: foreground,
      side: BorderSide(color: border, width: 1),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    );
    final labelText = Text(
      label,
      style: CsTypography.bodyMedium.copyWith(color: foreground),
    );

    return SizedBox(
      height: height,
      child: icon == null
          ? OutlinedButton(onPressed: onTap, style: style, child: labelText)
          : OutlinedButton.icon(
              onPressed: onTap,
              icon: Icon(icon, size: 18),
              label: labelText,
              style: style,
            ),
    );
  }
}
