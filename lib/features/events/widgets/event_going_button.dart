import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/app_spacing.dart';

/// The "I'm going" / "Going" attendance action on Event Detail (Social
/// Foundation Step 2B §11-12). A single control, not attending vs.
/// attending are two visual states of the same button — tapping while
/// attending removes attendance directly (no separate undo link, no
/// confirmation dialog: this is a low-stakes personal toggle, not a
/// permanent-data-loss action like deleting a visit). State is never
/// color-only: each state pairs a distinct icon with a distinct label.
class EventGoingButton extends StatelessWidget {
  final bool going;
  final bool busy;
  final VoidCallback onTap;

  const EventGoingButton({
    super.key,
    required this.going,
    required this.busy,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (going) {
      return SizedBox(
        width: double.infinity,
        height: 46,
        child: OutlinedButton.icon(
          onPressed: busy ? null : onTap,
          icon: busy
              ? const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    color: AppColors.gold,
                    strokeWidth: 2,
                  ),
                )
              : const Icon(Icons.check_circle_rounded, size: 16),
          label: Text(
            'Going',
            style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13),
          ),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.gold,
            side: const BorderSide(color: AppColors.gold, width: 1),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadii.md),
            ),
          ),
        ),
      );
    }
    return SizedBox(
      width: double.infinity,
      height: 46,
      child: FilledButton.icon(
        onPressed: busy ? null : onTap,
        icon: busy
            ? const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  color: AppColors.textOnDark,
                  strokeWidth: 2,
                ),
              )
            : const Icon(Icons.add_circle_outline_rounded, size: 16),
        label: Text(
          "I'm going",
          style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13),
        ),
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.brandGreen,
          foregroundColor: AppColors.textOnDark,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.md),
          ),
        ),
      ),
    );
  }
}
