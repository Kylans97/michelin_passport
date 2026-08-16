import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/cs_spacing.dart';
import '../../../core/theme/cs_typography.dart';

/// The "I'm going" / "Going" attendance action on Event Detail (Social
/// Foundation Step 2B §11-12; reskinned onto the editorial system in
/// Events UI Consistency Step 1). A single control, not attending vs.
/// attending are two visual states of the same button — tapping while
/// attending removes attendance directly (no separate undo link, no
/// confirmation dialog: this is a low-stakes personal toggle, not a
/// permanent-data-loss action like deleting a visit). State is never
/// color-only: each state pairs a distinct icon with a distinct label.
///
/// Deliberately a compact, intrinsically-sized pill — not a
/// `SizedBox(width: double.infinity)` booking button. Attendance is a
/// restrained personal intent marker, not a ticket-purchase CTA, and
/// shouldn't visually compete with the venue-navigation actions elsewhere
/// on the screen. Forest-green throughout, both states — never gold: the
/// "Going" state previously used `AppColors.gold`, which violated the
/// project's own color rule (gold reserved for Michelin stars/Keys only).
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
    final label = going ? 'Going' : "I'm going";
    return Semantics(
      button: true,
      label: going ? 'Going. Tap to remove attendance.' : "Mark as going",
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: busy ? null : onTap,
          borderRadius: BorderRadius.circular(CsRadius.pill),
          splashColor: AppColors.forestGreen.withValues(alpha: 0.12),
          highlightColor: AppColors.forestGreen.withValues(alpha: 0.08),
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: CsSpacing.base,
              vertical: CsSpacing.sm,
            ),
            decoration: BoxDecoration(
              color: going ? AppColors.forestGreen : Colors.transparent,
              borderRadius: BorderRadius.circular(CsRadius.pill),
              border: Border.all(color: AppColors.forestGreen, width: 1),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (busy)
                  SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: going
                          ? AppColors.textOnDark
                          : AppColors.forestGreen,
                    ),
                  )
                else
                  Icon(
                    going
                        ? Icons.check_circle_rounded
                        : Icons.add_circle_outline_rounded,
                    size: 16,
                    color: going ? AppColors.textOnDark : AppColors.forestGreen,
                  ),
                const SizedBox(width: CsSpacing.xs),
                Text(
                  label,
                  style: CsTypography.smallLabel.copyWith(
                    color: going ? AppColors.textOnDark : AppColors.forestGreen,
                    fontWeight: FontWeight.w600,
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
