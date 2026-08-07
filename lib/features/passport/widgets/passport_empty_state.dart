import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/app_colors.dart';

/// Shared shape for both Passport empty states: no visits logged at all, or
/// a year filter with nothing in it. Only the message differs.
class PassportEmptyState extends StatelessWidget {
  final String message;

  const PassportEmptyState({super.key, required this.message});

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.menu_book_outlined,
            color: AppColors.textSecondary,
            size: 48,
          ),
          const SizedBox(height: 16),
          Text(
            message,
            textAlign: TextAlign.center,
            style: GoogleFonts.playfairDisplay(
              color: AppColors.textSecondary,
              fontSize: 17,
            ),
          ),
        ],
      ),
    ),
  );
}
