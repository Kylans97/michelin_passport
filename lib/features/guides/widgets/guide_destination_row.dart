import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/cs_spacing.dart';
import '../../../core/theme/cs_surface_context.dart';
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
/// Dual-surface aware per [CsSurface] (UI Polish pass): [CsSurface.light]
/// (the default, unchanged) is for [GuideFamilySection]'s own ivory
/// blocks — forest-green label, taupe descriptor/arrow, a faint
/// forest-green splash. [CsSurface.dark] is for Explore's "Browse the
/// Guides" row, which sits directly on Explore's own forest-green canvas
/// with no ivory block underneath it — physical-device review found the
/// unparametrized forest-green label there read as forest-green-on-
/// forest-green, essentially unreadable. `surface` defaults to `light` so
/// every existing call site inside Guides renders byte-identical to
/// before this pass.
class GuideDestinationRow extends StatelessWidget {
  final String label;
  final String descriptor;
  final VoidCallback onTap;
  final CsSurface surface;

  const GuideDestinationRow({
    super.key,
    required this.label,
    required this.descriptor,
    required this.onTap,
    this.surface = CsSurface.light,
  });

  @override
  Widget build(BuildContext context) {
    final onDark = surface == CsSurface.dark;
    final labelColor = onDark ? AppColors.ivory : AppColors.forestGreen;
    final subtleColor = onDark ? AppColors.secondaryOnDark : AppColors.taupe;
    final splashBase = onDark ? AppColors.ivory : AppColors.forestGreen;

    return Semantics(
      button: true,
      label: '$label. $descriptor',
      hint: 'Opens the $label guide',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          splashColor: splashBase.withValues(alpha: 0.06),
          highlightColor: splashBase.withValues(alpha: 0.04),
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
                          color: labelColor,
                        ),
                      ),
                    ),
                    const SizedBox(width: CsSpacing.sm),
                    Icon(
                      Icons.arrow_forward_rounded,
                      color: subtleColor,
                      size: 18,
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  descriptor,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  // A VERY slight size step down from CsTypography.
                  // metadata's 14 (not a color change — this token's
                  // contrast on either surface is already-audited and
                  // legible; per physical-device review, 13 was enough on
                  // its own to read as clearly subordinate to the label
                  // without going anywhere near faint).
                  style: CsTypography.metadata.copyWith(
                    color: subtleColor,
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
}
