import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../theme/cs_spacing.dart';
import '../theme/cs_typography.dart';

/// The editorial "ABOUT" paragraph seam (UI Consistency Step 1B —
/// physical-device polish, §19-21). Neither [Restaurant] nor [Hotel] has
/// an editorial-copy field today (no `description`/`about`/`summary`
/// column on `restaurants_full`/`hotels_full` — confirmed by reading both
/// models; nothing was added here, per the task's explicit "do not
/// migrate, prepare the UI only" instruction).
///
/// This widget IS wired into both detail screens today, always called
/// with `text: null` at present — so it renders nothing
/// ([SizedBox.shrink], never a "No description available." placeholder)
/// until a real editorial-copy field exists on the model. The day that
/// field lands, the call site changes from `text: null` to the real
/// value and this section starts rendering with zero other changes
/// needed — see the Step 1B report's ABOUT DATA section for the
/// recommended future enrichment-pipeline architecture (an offline
/// enrichment process writes concise, sourced copy into the database;
/// this app never scrapes a venue's website at runtime).
class VenueAboutSection extends StatelessWidget {
  final String? text;
  const VenueAboutSection({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    final copy = text?.trim();
    if (copy == null || copy.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'ABOUT',
          style: CsTypography.eyebrow.copyWith(color: AppColors.taupe),
        ),
        const SizedBox(height: CsSpacing.md),
        Text(
          copy,
          style: CsTypography.body.copyWith(
            color: AppColors.forestGreen,
            height: 1.6,
          ),
        ),
      ],
    );
  }
}
