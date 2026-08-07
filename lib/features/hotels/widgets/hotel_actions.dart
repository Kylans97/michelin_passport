import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/app_colors.dart';

/// The "Add Stay" action for Hotel Detail. Unlike RestaurantActions' visited
/// toggle, this is never a two-state toggle — a hotel can be stayed at many
/// times, so every tap opens Add Stay for a brand new historical row, never
/// "mark/unmark stayed".
class HotelActions extends StatelessWidget {
  final VoidCallback onTapAddStay;

  const HotelActions({super.key, required this.onTapAddStay});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: FilledButton.icon(
        onPressed: onTapAddStay,
        icon: const Icon(Icons.add_circle_outline_rounded, size: 18),
        label: Text(
          'Add Stay',
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w600,
            fontSize: 14,
            letterSpacing: 0.1,
          ),
        ),
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.gold,
          foregroundColor: Colors.black,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }
}
