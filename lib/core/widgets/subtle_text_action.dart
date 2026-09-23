import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../theme/cs_typography.dart';

/// A single quiet "Label →" affordance — no card background, no
/// icon-heavy styling, just text and a chevron. Used for restrained
/// secondary entry points on Restaurant/Hotel Detail's ivory content
/// canvas ("Award history", "Plan visit") that shouldn't compete with the
/// content around them. Forest-green, never gold — Step 1B's color rule
/// reserves gold for Michelin stars/Keys only.
///
/// [labelStyle] defaults to [CsTypography.smallLabel] (12px), the
/// restrained size every existing call site above still uses unchanged.
/// Private Chef Detail's own CONNECT links (Instagram/Website) pass
/// [CsTypography.metadata] (14px) instead — those read as flowing text on
/// their own, with no icon or compact toolbar grid to excuse a small size
/// the way Award history/Plan visit's inline placement does, and 12px
/// there read as uncomfortably small. Restaurant/Hotel Detail's own
/// comparable links (this widget itself, plus VenueUtilityActions'
/// Website/Call row) are ALSO 12px — there wasn't a bigger existing size
/// to copy, so this reaches for [CsTypography.metadata], an established
/// named role already used everywhere else in this app for exactly this
/// "readable but secondary" register, rather than a one-off number.
class SubtleTextAction extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final TextStyle? labelStyle;
  const SubtleTextAction({
    super.key,
    required this.label,
    required this.onTap,
    this.labelStyle,
  });

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.transparent,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      splashColor: AppColors.forestGreen.withValues(alpha: 0.08),
      highlightColor: AppColors.forestGreen.withValues(alpha: 0.08),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style:
                  labelStyle ??
                  CsTypography.smallLabel.copyWith(
                    color: AppColors.forestGreen,
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(width: 6),
            const Icon(
              Icons.chevron_right_rounded,
              color: AppColors.forestGreen,
              size: 16,
            ),
          ],
        ),
      ),
    ),
  );
}
