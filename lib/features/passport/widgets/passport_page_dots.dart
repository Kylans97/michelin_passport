import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';

/// The Passport booklet's one page-indicator style — an 18×6 ivory-green
/// pill for the active page, 6×6 dots otherwise. Used by both the cover's
/// own volume stack (Round 1) and the open book's pager (Round 2) — was
/// two near-identical private widgets before this; promoted to one shared
/// public widget the moment a real second caller needed the exact same
/// thing, the same threshold this codebase already applies to
/// `drawArcText`/`drawIconGlyph` in passport_stamp_painters.dart.
class PassportPageDots extends StatelessWidget {
  final int count;
  final int activeIndex;
  const PassportPageDots({super.key, required this.count, required this.activeIndex});

  @override
  Widget build(BuildContext context) {
    if (count <= 1) return const SizedBox.shrink();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < count; i++) ...[
          if (i > 0) const SizedBox(width: 6),
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: i == activeIndex ? 18 : 6,
            height: 6,
            decoration: BoxDecoration(
              color: i == activeIndex
                  ? AppColors.forestGreen
                  : AppColors.secondaryOnDark.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(3),
            ),
          ),
        ],
      ],
    );
  }
}
