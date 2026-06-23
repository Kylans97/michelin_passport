import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/app_colors.dart';

class StatCard extends StatelessWidget {
  final String value;
  final String label;
  final IconData icon;

  const StatCard({
    super.key,
    required this.value,
    required this.label,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.cardBorder, width: 0.5),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: AppColors.gold, size: 20),
            const SizedBox(height: 10),
            Text(
              value,
              style: GoogleFonts.playfairDisplay(
                color: AppColors.gold,
                fontSize: 28,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                color: AppColors.textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w500,
                letterSpacing: 0.8,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
