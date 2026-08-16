import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/cs_spacing.dart';
import '../../../core/theme/cs_typography.dart';

/// One destination in a [GuideFamilySection]'s editorial index — a whole
/// tappable row, not just an arrow. Deliberately not a Material
/// [ListTile]: no default leading/trailing slots, no dense-list feel — a
/// large editorial [label] (Cormorant, the same weight a venue name reads
/// at elsewhere in the app) with a short [descriptor] beneath it, and a
/// plain arrow — not the chevron used everywhere else in this app's
/// settings-style rows — as a deliberately different, more "table of
/// contents" cue that this is an index entry, not a settings item.
///
/// Splash/highlight are a faint forest-green tint rather than Material's
/// default ripple, matching the ivory canvas.
class GuideDestinationRow extends StatelessWidget {
  final String label;
  final String descriptor;
  final VoidCallback onTap;

  const GuideDestinationRow({
    super.key,
    required this.label,
    required this.descriptor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: '$label. $descriptor',
    hint: 'Opens the $label guide',
    child: Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        splashColor: AppColors.forestGreen.withValues(alpha: 0.06),
        highlightColor: AppColors.forestGreen.withValues(alpha: 0.04),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: CsSpacing.sm),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: CsTypography.placeTitle.copyWith(
                        color: AppColors.forestGreen,
                      ),
                    ),
                  ),
                  const SizedBox(width: CsSpacing.sm),
                  const Icon(
                    Icons.arrow_forward_rounded,
                    color: AppColors.taupe,
                    size: 18,
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                descriptor,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                // A VERY slight size step down from CsTypography.metadata's
                // 14 (not a color change — taupe's contrast on ivory is
                // already-audited and legible; per physical-device review,
                // 13 was enough on its own to read as clearly subordinate
                // to the label without going anywhere near faint).
                style: CsTypography.metadata.copyWith(
                  color: AppColors.taupe,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
