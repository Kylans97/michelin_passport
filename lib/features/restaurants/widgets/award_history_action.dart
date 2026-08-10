import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/app_colors.dart';

/// The single subtle "Award history →" affordance shown below Restaurant
/// Detail's current-awards card. Deliberately plain (no card background,
/// no icon-heavy styling) so it reads as a quiet secondary action, not a
/// competing block of content — RestaurantAwardsCard itself stays exactly
/// as it was.
class AwardHistoryAction extends StatelessWidget {
  final VoidCallback onTap;
  const AwardHistoryAction({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.transparent,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      splashColor: AppColors.goldAlpha10,
      highlightColor: AppColors.goldAlpha10,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 2),
        child: Row(
          children: [
            Text(
              'Award history',
              style: GoogleFonts.inter(
                color: AppColors.textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 6),
            const Icon(
              Icons.chevron_right_rounded,
              color: AppColors.textSecondary,
              size: 16,
            ),
          ],
        ),
      ),
    ),
  );
}
