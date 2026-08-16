import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../theme/cs_typography.dart';

/// A single quiet "Label →" affordance — no card background, no
/// icon-heavy styling, just text and a chevron. Used for restrained
/// secondary entry points on Restaurant/Hotel Detail's ivory content
/// canvas ("Award history", "Plan visit") that shouldn't compete with the
/// content around them. Forest-green, never gold — Step 1B's color rule
/// reserves gold for Michelin stars/Keys only.
class SubtleTextAction extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const SubtleTextAction({super.key, required this.label, required this.onTap});

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
              style: CsTypography.smallLabel.copyWith(
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
