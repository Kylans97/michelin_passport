import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/app_colors.dart';

/// The optional "Would you recommend this event?" Yes/No control —
/// Events V2 Step 4.1, shown inside [AttendanceDetailsSheet] between the
/// overall rating and the Photos section. Three-valued ([value] is
/// `bool?`, matching `EventConfirmedAttendance.wouldRecommend` exactly):
/// `null` = no answer (never rendered as "No" selected), `true` = Yes,
/// `false` = No.
///
/// Tapping the already-selected choice again clears the answer back to
/// `null` — the only way to explicitly clear from this UI, deliberately
/// not a separate third "clear" button. This mirrors RatingMeter's own
/// compact shape (a small, fixed set of tap targets, no extra chrome) over
/// inventing a new interaction idiom for a single new optional field.
///
/// Selected state is never conveyed by color alone: the selected pill also
/// gets a leading check glyph and a heavier border, on top of the same
/// forestGreen fill every other selected control in this sheet already
/// uses (RatingMeter's segments/pill) — deep green / forest green / ivory
/// only, no gold accent, per this app's design system.
class RecommendationSelector extends StatelessWidget {
  final bool? value;
  final ValueChanged<bool?> onChanged;

  const RecommendationSelector({
    super.key,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Would you recommend this event?',
          style: GoogleFonts.inter(
            color: AppColors.textPrimary,
            fontSize: 13.5,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _RecommendationChoice(
                label: 'Yes',
                selected: value == true,
                onTap: () => onChanged(value == true ? null : true),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _RecommendationChoice(
                label: 'No',
                selected: value == false,
                onTap: () => onChanged(value == false ? null : false),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _RecommendationChoice extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _RecommendationChoice({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    behavior: HitTestBehavior.opaque,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      height: 40,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: selected
            ? AppColors.forestGreen.withValues(alpha: 0.12)
            : AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: selected
              ? AppColors.forestGreen.withValues(alpha: 0.5)
              : AppColors.cardBorder,
          width: selected ? 1.0 : 0.5,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (selected) ...[
            const Icon(
              Icons.check_rounded,
              size: 16,
              color: AppColors.forestGreen,
            ),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: GoogleFonts.inter(
              color: selected ? AppColors.forestGreen : AppColors.textSecondary,
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    ),
  );
}
