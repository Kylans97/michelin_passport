import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/cs_spacing.dart';
import '../../../core/theme/cs_surface_context.dart';
import '../../../core/theme/cs_typography.dart';
import '../../../core/widgets/cs_primary_button.dart';

/// The "Did you make it?" Yes/No/Not now prompt — Events V2 Step 4.
/// Restrained by design (§6/§24's explicit instruction): a single card,
/// never a modal popup, no achievement-badge styling. Used on both Event
/// Detail (embedded inline, [surface] = light/ivory) and the Events
/// screen's own top-of-list nudge (dark/deep-green canvas), which is why
/// [surface] exists at all rather than hardcoding one palette.
class AttendancePromptCard extends StatelessWidget {
  final String eventName;
  final bool busy;
  final VoidCallback onYes;
  final VoidCallback onNo;
  final VoidCallback onNotNow;
  final CsSurface surface;

  const AttendancePromptCard({
    super.key,
    required this.eventName,
    required this.busy,
    required this.onYes,
    required this.onNo,
    required this.onNotNow,
    this.surface = CsSurface.light,
  });

  @override
  Widget build(BuildContext context) {
    final onDark = surface == CsSurface.dark;
    final cardColor = onDark ? AppColors.forestGreen : AppColors.surface;
    final titleColor = onDark ? AppColors.textOnDark : AppColors.textPrimary;
    final borderColor = onDark
        ? AppColors.subtleBorderDark
        : AppColors.cardBorder.withValues(alpha: 0.55);

    return Container(
      padding: const EdgeInsets.all(CsSpacing.base),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Did you make it?',
            style: CsTypography.bodyMedium.copyWith(color: titleColor),
          ),
          const SizedBox(height: 4),
          Text(
            eventName,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: CsTypography.metadata.copyWith(
              color: onDark ? AppColors.secondaryOnDark : AppColors.taupe,
            ),
          ),
          const SizedBox(height: CsSpacing.base),
          Row(
            children: [
              Expanded(
                child: CsPrimaryButton(
                  label: busy ? '...' : 'Yes',
                  onTap: busy ? null : onYes,
                  surface: surface,
                  height: 44,
                ),
              ),
              const SizedBox(width: CsSpacing.sm),
              Expanded(
                child: CsSecondaryButton(
                  label: 'No',
                  onTap: busy ? null : onNo,
                  surface: surface,
                  height: 44,
                ),
              ),
            ],
          ),
          const SizedBox(height: CsSpacing.sm),
          Center(
            child: TextButton(
              onPressed: busy ? null : onNotNow,
              child: Text(
                'Not now',
                style: CsTypography.smallLabel.copyWith(
                  color: onDark ? AppColors.secondaryOnDark : AppColors.taupe,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
