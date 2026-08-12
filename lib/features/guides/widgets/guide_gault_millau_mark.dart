import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/cs_typography.dart';
import '../../../models/gault_millau_award.dart';

/// Formats a [GaultMillauAward] into the single truthful line
/// [GuideGaultMillauMark] renders — extracted as a pure, testable function
/// mirroring guide_view_model.dart's own reasoning (the widget that uses it
/// can be pumped in a widget test, but keeping the branching logic itself
/// pure/unit-testable avoids needing a widget test for every data-shape
/// case).
///
/// Never fabricates a number: an unscored tier shows its [distinctionLabel]
/// verbatim (e.g. "Toques d'Or", "H!P") rather than a made-up score, and a
/// row with neither a score, toque count, nor label formats to null (the
/// caller omits the distinction slot entirely — see GuideVenueCard's own
/// `distinction` being optional).
String? formatGaultMillauDistinction(GaultMillauAward award) {
  if ((award.recognitionType == GaultMillauRecognitionType.unscoredTopTier ||
          award.recognitionType == GaultMillauRecognitionType.unscoredCasual) &&
      award.distinctionLabel != null &&
      award.distinctionLabel!.isNotEmpty) {
    return award.distinctionLabel;
  }

  final parts = <String>[];
  if (award.score != null) {
    // 17.5 stays "17.5", 18.0 renders as "18" — half-points only show a
    // decimal when the data actually has one, matching how the source
    // material itself writes whole scores (e.g. Michel Kayser's own site:
    // "18/20", never "18.0/20").
    final score = award.score!;
    final scoreText = score == score.roundToDouble()
        ? score.toInt().toString()
        : score.toString();
    parts.add('$scoreText/20');
  }
  if (award.toqueCount != null) {
    final toqueWord = award.toqueCount == 1 ? 'Toque' : 'Toques';
    final colour = award.toqueColour == 'red' ? ' (Red)' : '';
    parts.add('${award.toqueCount} $toqueWord$colour');
  }
  if (parts.isNotEmpty) return parts.join(' · ');

  if (award.distinctionLabel != null && award.distinctionLabel!.isNotEmpty) {
    return award.distinctionLabel;
  }
  return null;
}

/// A Gault&Millau restaurant's distinction, rendered in [GuideVenueCard]'s
/// `distinction` slot — the same role [StarRow]/[GuideRankMark] play for
/// Michelin/World's 50 Best. Presentation-only: knows nothing about
/// Supabase, repositories, or business logic, per the Step 2D brief.
///
/// Deliberately plain text at the established `secondaryOnDark` metadata
/// tone — no badge, no gold treatment, no gradient (the brief is explicit
/// that recognition strength must never be color-coded alone, and that this
/// widget should match the app's quiet editorial aesthetic rather than
/// reach for a "gold guide" cliché).
class GuideGaultMillauMark extends StatelessWidget {
  final GaultMillauAward award;

  const GuideGaultMillauMark({super.key, required this.award});

  @override
  Widget build(BuildContext context) {
    final text = formatGaultMillauDistinction(award);
    if (text == null) return const SizedBox.shrink();
    return Text(
      text,
      style: CsTypography.metadata.copyWith(
        color: AppColors.secondaryOnDark,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}
