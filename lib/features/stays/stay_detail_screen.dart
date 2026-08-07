import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/app_colors.dart';
import '../../core/widgets/key_row.dart';
import '../../models/hotel.dart';
import '../../models/visit.dart';
import '../restaurants/widgets/detail_section.dart';
import '../visits/widgets/rating_display_row.dart';

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

String _formatStayDate(DateTime date) =>
    '${date.day} ${_monthNames[date.month - 1]} ${date.year}';

/// Shows exactly what the user recorded during a single stay. This is
/// historical information: [stay.keysAtVisit] is the hotel's Michelin Keys
/// at the time of the stay and is shown as-is, never replaced by the
/// hotel's current Michelin Keys.
class StayDetailScreen extends StatelessWidget {
  final Hotel hotel;
  final Visit stay;

  const StayDetailScreen({super.key, required this.hotel, required this.stay});

  @override
  Widget build(BuildContext context) {
    final keys = stay.keysAtVisit;
    final notes = stay.notes;

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
              hotel.name,
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
                  _formatStayDate(stay.visitedOn),
                  style: GoogleFonts.inter(
                    color: AppColors.textSecondary,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (keys != null && keys > 0) ...[
                  const SizedBox(width: 10),
                  KeyRow(count: keys, size: 14),
                ],
              ],
            ),
            const SizedBox(height: 32),

            const SectionLabel('RATINGS'),
            const SizedBox(height: 18),
            RatingDisplayRow(label: 'Overall', value: stay.rating),
            const SizedBox(height: 20),
            RatingDisplayRow(label: 'Service', value: stay.serviceRating),
            const SizedBox(height: 20),
            RatingDisplayRow(label: 'Value', value: stay.valueRating),

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
