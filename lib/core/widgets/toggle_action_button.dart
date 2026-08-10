import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/app_colors.dart';

/// A compact two-state action button (Mark as visited, Wishlist, Add Stay's
/// hotel equivalent). Active uses a quiet brand-green tint, never gold —
/// this is a personal record, not an award/ranking, and gold stays
/// reserved for those. Shared by Restaurant and Hotel Detail so both read
/// as the same product.
class ToggleActionButton extends StatelessWidget {
  final IconData icon;
  final IconData inactiveIcon;
  final String label;
  final bool active;
  final bool enabled;
  final bool saving;
  final VoidCallback onTap;

  const ToggleActionButton({
    super.key,
    required this.icon,
    required this.inactiveIcon,
    required this.label,
    required this.active,
    this.enabled = true,
    this.saving = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final activeTint = AppColors.brandGreen.withValues(alpha: 0.08);
    final activeBorder = AppColors.brandGreen.withValues(alpha: 0.35);

    // Tapping while "disabled" (signed out) still fires onTap, which shows
    // the sign-in message — see call sites. Only a saving in-flight tap is
    // truly ignored.
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: saving ? null : onTap,
        borderRadius: BorderRadius.circular(14),
        splashColor: AppColors.goldAlpha10,
        highlightColor: AppColors.goldAlpha10,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(vertical: 11),
          decoration: BoxDecoration(
            color: active ? activeTint : AppColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: active ? activeBorder : AppColors.cardBorder,
              width: 0.5,
            ),
          ),
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 220),
            opacity: enabled ? 1 : 0.45,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 180),
                  child: saving
                      ? const SizedBox(
                          key: ValueKey('saving'),
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            color: AppColors.brandGreen,
                            strokeWidth: 2,
                          ),
                        )
                      : Icon(
                          active ? icon : inactiveIcon,
                          key: ValueKey(active),
                          color: active
                              ? AppColors.brandGreen
                              : AppColors.textSecondary,
                          size: 19,
                        ),
                ),
                const SizedBox(height: 6),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    color: active
                        ? AppColors.brandGreen
                        : AppColors.textSecondary,
                    fontSize: 11,
                    fontWeight: active ? FontWeight.w600 : FontWeight.w500,
                    letterSpacing: 0.1,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Placeholder shown for the width of a heartbeat while personal state
/// loads, so toggle buttons don't flash from "not yet" to their real state.
class ToggleActionButtonsLoadingRow extends StatelessWidget {
  final int count;
  const ToggleActionButtonsLoadingRow({super.key, this.count = 2});

  @override
  Widget build(BuildContext context) => Row(
    children: List.generate(count, (i) {
      return Expanded(
        child: Padding(
          padding: EdgeInsets.only(right: i == count - 1 ? 0 : 10),
          child: Container(
            height: 52,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.cardBorder, width: 0.5),
            ),
            child: const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                color: AppColors.textSecondary,
                strokeWidth: 1.5,
              ),
            ),
          ),
        ),
      );
    }),
  );
}
