import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../theme/cs_surface_context.dart';
import '../theme/cs_typography.dart';

/// The redesigned search field — height 52 / radius 16 per the brief,
/// dual-surface aware per [CsSurface]: a warm ivory surface on a green
/// environment, or a soft neutral/subtle-border surface on a light one.
/// Icons stay simple/functional (a plain search glyph), matching the
/// brief's restrained-iconography direction. Not wired into any existing
/// search field yet — Explore's/Events'/trip-picker search fields keep
/// their current [TextField] styling until those screens are individually
/// redesigned; see the Step 1 report for why centralizing them without
/// changing their rendered appearance wasn't practical this pass.
class CsSearchField extends StatelessWidget {
  final TextEditingController? controller;
  final String hintText;
  final ValueChanged<String>? onChanged;
  final CsSurface surface;
  final bool autofocus;

  const CsSearchField({
    super.key,
    this.controller,
    this.hintText = 'Search…',
    this.onChanged,
    this.surface = CsSurface.dark,
    this.autofocus = false,
  });

  @override
  Widget build(BuildContext context) {
    final onDark = surface == CsSurface.dark;
    final background = onDark ? AppColors.ivory : AppColors.warmWhite;
    final foreground = AppColors.charcoal;
    final hint = AppColors.taupe;
    final border = onDark ? Colors.transparent : AppColors.subtleBorderLight;

    return SizedBox(
      height: 52,
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        autofocus: autofocus,
        style: CsTypography.body.copyWith(color: foreground),
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: CsTypography.body.copyWith(color: hint),
          prefixIcon: Icon(Icons.search_rounded, color: hint, size: 20),
          filled: true,
          fillColor: background,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: border, width: 0.5),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: border, width: 0.5),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(
              color: AppColors.mutedBrass,
              width: 1.5,
            ),
          ),
        ),
      ),
    );
  }
}
