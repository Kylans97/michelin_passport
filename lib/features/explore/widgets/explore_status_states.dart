import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/app_colors.dart';

/// "No restaurants found" / "No hotels found" / "No places found" —
/// message is the only thing that varies by venue type.
class ExploreEmptyState extends StatelessWidget {
  final String message;
  const ExploreEmptyState({super.key, required this.message});

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(
          Icons.search_off_rounded,
          color: AppColors.textSecondary,
          size: 40,
        ),
        const SizedBox(height: 12),
        Text(message, style: GoogleFonts.inter(color: AppColors.textSecondary)),
      ],
    ),
  );
}

class ExploreErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const ExploreErrorState({
    super.key,
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(
          Icons.wifi_off_rounded,
          color: AppColors.textSecondary,
          size: 40,
        ),
        const SizedBox(height: 12),
        Text(message, style: GoogleFonts.inter(color: AppColors.textSecondary)),
        const SizedBox(height: 12),
        TextButton(
          onPressed: onRetry,
          child: Text('Retry', style: GoogleFonts.inter(color: AppColors.gold)),
        ),
      ],
    ),
  );
}
