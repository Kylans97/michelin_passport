import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../theme/cs_spacing.dart' show CsRadius;

/// The redesigned bottom-sheet shell — drag handle, rounded top corners
/// ([CsRadius.large], per "larger sheets may use 24"), warm-neutral
/// background, keyboard-aware by construction. Centralizes a shape this
/// app currently repeats by hand in every bottom sheet (country picker,
/// create-trip, hotel/restaurant pickers, plan-venue...) — none of those
/// are changed to use this in Step 1; they keep their own current
/// [AppColors]/[AppRadii] styling until individually migrated, so this is
/// available for new/redesigned sheets without touching existing ones.
///
/// Keyboard handling mirrors the fix already applied to
/// `country_picker_sheet.dart`: the sheet is pushed up by
/// `MediaQuery.viewInsets.bottom` and its own max height is derived from
/// the space actually available above the keyboard, rather than a fixed
/// fraction of the full screen — the same device-size/keyboard robustness
/// bug fixed there, built into this shell from the start.
class CsContentSheet extends StatelessWidget {
  final Widget child;
  final Color backgroundColor;
  final double maxHeightFraction;

  const CsContentSheet({
    super.key,
    required this.child,
    this.backgroundColor = AppColors.warmWhite,
    this.maxHeightFraction = 0.9,
  });

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final bottomInset = mediaQuery.viewInsets.bottom;
    final availableHeight =
        mediaQuery.size.height - mediaQuery.padding.top - bottomInset;
    final maxHeight = availableHeight * maxHeightFraction;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SafeArea(
        top: false,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxHeight),
          child: Container(
            decoration: BoxDecoration(
              color: backgroundColor,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(CsRadius.large),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 14),
                Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.subtleBorderLight,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Flexible(child: child),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
