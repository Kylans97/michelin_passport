import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/app_colors.dart';

/// A compact 1-10 rating control: a slim gold fill-meter with a large,
/// comfortable tap target per segment, plus an explicit "Not rated" pill.
/// Used for every optional rating in the visit sheet (overall, food,
/// service, wine, value) so all five share one consistent design.
class RatingMeter extends StatelessWidget {
  final String label;
  final int? value;
  final ValueChanged<int?> onChanged;

  const RatingMeter({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: GoogleFonts.inter(
                  color: AppColors.textPrimary,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              child: Text(
                value == null ? 'Not rated' : '$value/10',
                key: ValueKey(value),
                style: GoogleFonts.inter(
                  color: value == null
                      ? AppColors.textSecondary
                      : AppColors.gold,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            _NotRatedPill(
              selected: value == null,
              onTap: () => onChanged(null),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Row(
                children: [
                  for (var i = 1; i <= 10; i++)
                    Expanded(
                      child: _MeterSegment(
                        filled: value != null && i <= value!,
                        isFirst: i == 1,
                        isLast: i == 10,
                        onTap: () => onChanged(i),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _NotRatedPill extends StatelessWidget {
  final bool selected;
  final VoidCallback onTap;
  const _NotRatedPill({required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    behavior: HitTestBehavior.opaque,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      width: 32,
      height: 32,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: selected ? AppColors.goldMuted : AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: selected ? AppColors.goldBorder60 : AppColors.cardBorder,
          width: selected ? 1.0 : 0.5,
        ),
      ),
      child: Text(
        '—',
        style: GoogleFonts.inter(
          color: selected ? AppColors.gold : AppColors.textSecondary,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
  );
}

class _MeterSegment extends StatelessWidget {
  final bool filled;
  final bool isFirst;
  final bool isLast;
  final VoidCallback onTap;
  const _MeterSegment({
    required this.filled,
    required this.isFirst,
    required this.isLast,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    behavior: HitTestBehavior.opaque,
    child: SizedBox(
      height: 32,
      child: Center(
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          height: 8,
          margin: const EdgeInsets.symmetric(horizontal: 1.5),
          decoration: BoxDecoration(
            color: filled ? AppColors.gold : AppColors.surface,
            borderRadius: BorderRadius.horizontal(
              left: isFirst ? const Radius.circular(4) : Radius.zero,
              right: isLast ? const Radius.circular(4) : Radius.zero,
            ),
          ),
        ),
      ),
    ),
  );
}
