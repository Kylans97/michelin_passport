import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/app_colors.dart';
import '../../core/widgets/star_row.dart';
import '../../models/restaurant.dart';
import '../../models/visit.dart';
import '../restaurants/widgets/detail_section.dart';
import 'widgets/rating_display_row.dart';

const _monthNames = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

String _formatVisitDate(DateTime date) =>
    '${date.day} ${_monthNames[date.month - 1]} ${date.year}';

/// Shows exactly what the user recorded during a single visit. This is
/// historical information: [visit.starsAtVisit] is the restaurant's award at
/// the time of the visit and is shown as-is, never replaced by the
/// restaurant's current Michelin stars.
class VisitDetailScreen extends StatelessWidget {
  final Restaurant restaurant;
  final Visit visit;

  const VisitDetailScreen({
    super.key,
    required this.restaurant,
    required this.visit,
  });

  @override
  Widget build(BuildContext context) {
    final stars = visit.starsAtVisit;
    final menuType = visit.menuType;
    final notes = visit.notes;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        foregroundColor: AppColors.textPrimary,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              restaurant.name,
              style: GoogleFonts.playfairDisplay(
                color: AppColors.textPrimary,
                fontSize: 26,
                fontWeight: FontWeight.w700,
                height: 1.15,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Text(
                  _formatVisitDate(visit.visitedOn),
                  style: GoogleFonts.inter(
                    color: AppColors.textSecondary,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (stars != null && stars > 0) ...[
                  const SizedBox(width: 10),
                  StarRow(count: stars, size: 14),
                ],
              ],
            ),
            const SizedBox(height: 32),

            const SectionLabel('RATINGS'),
            const SizedBox(height: 18),
            RatingDisplayRow(label: 'Overall', value: visit.rating),
            const SizedBox(height: 20),
            RatingDisplayRow(label: 'Food', value: visit.foodRating),
            const SizedBox(height: 20),
            RatingDisplayRow(label: 'Service', value: visit.serviceRating),
            const SizedBox(height: 20),
            RatingDisplayRow(label: 'Wine', value: visit.wineRating),
            const SizedBox(height: 20),
            RatingDisplayRow(label: 'Value', value: visit.valueRating),

            if (menuType != null) ...[
              const SizedBox(height: 32),
              const SectionLabel('MENU'),
              const SizedBox(height: 10),
              Text(
                menuType.label,
                style: GoogleFonts.inter(
                  color: AppColors.textPrimary,
                  fontSize: 14.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],

            if (notes != null && notes.isNotEmpty) ...[
              const SizedBox(height: 32),
              const SectionLabel('NOTES'),
              const SizedBox(height: 10),
              DetailCard(
                child: Text(
                  notes,
                  style: GoogleFonts.inter(
                    color: AppColors.textPrimary,
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
