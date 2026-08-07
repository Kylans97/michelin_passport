import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/app_colors.dart';

/// Read-only counterpart to [RatingMeter]: a label, a static gold fill-meter,
/// and the numeric value — or "Not rated" when [value] is null. Used on the
/// Visit Detail screen, where ratings are a historical record rather than
/// editable input.
class RatingDisplayRow extends StatelessWidget {
  final String label;
  final int? value;

  const RatingDisplayRow({super.key, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final filled = value;
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
            Text(
              value == null ? 'Not rated' : '$value/10',
              style: GoogleFonts.inter(
                color: value == null ? AppColors.textSecondary : AppColors.gold,
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            for (var i = 1; i <= 10; i++)
              Expanded(
                child: Container(
                  height: 8,
                  margin: const EdgeInsets.symmetric(horizontal: 1.5),
                  decoration: BoxDecoration(
                    color: (filled != null && i <= filled)
                        ? AppColors.gold
                        : AppColors.surface,
                    borderRadius: BorderRadius.horizontal(
                      left: i == 1 ? const Radius.circular(4) : Radius.zero,
                      right: i == 10 ? const Radius.circular(4) : Radius.zero,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}
