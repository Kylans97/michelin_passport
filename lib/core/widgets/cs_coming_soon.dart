import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../theme/cs_spacing.dart';
import '../theme/cs_typography.dart';

/// Navigation & Information Architecture V2 — one restrained, reusable
/// "not built yet" state for a destination that has a real, permanent
/// place in the product's navigation but no content of its own today
/// (News V1, Community's own future concepts). Deliberately NOT an
/// error/empty-data state (never [Icons.wifi_off_rounded]-style copy,
/// never framed as something having gone wrong) and deliberately NOT
/// construction/placeholder-app styling — no emoji, no gradient, no
/// cartoon illustration, no fake disabled control pretending to be a real
/// one. A single quiet glyph (outlined, never gold — gold stays reserved
/// for Michelin stars/Keys), a title, and an optional short description,
/// centered on the surrounding dark-green/ivory canvas it's placed on.
///
/// Use this ONLY where functionality genuinely does not exist yet — never
/// as a substitute for already-working functionality (see this file's own
/// callers: [NewsScreen] has no content source at all yet;
/// [CommunityScreen] uses this only for the concepts beyond its own
/// already-real Community Rankings content, never for that content
/// itself).
class CsComingSoon extends StatelessWidget {
  final String title;
  final String? description;
  final IconData icon;

  /// Navigation V2 UI Refinement — a smaller footprint for use as one of
  /// several stacked sections on a single scrolling page (Community's Hot
  /// Right Now / Meet the Community / Dining Together), so three of these
  /// in a row still read as a coherent page rather than a wall of empty
  /// states. Full-page callers (NewsScreen, Passport's Stats destination)
  /// are unaffected by this flag defaulting to false.
  final bool compact;

  const CsComingSoon({
    super.key,
    required this.title,
    this.description,
    this.icon = Icons.hourglass_top_rounded,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 24 : 40,
        vertical: compact ? 28 : 56,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: AppColors.secondaryOnDark, size: compact ? 24 : 32),
          SizedBox(height: compact ? CsSpacing.md : CsSpacing.lg),
          Text(
            title,
            textAlign: TextAlign.center,
            style: CsTypography.placeTitle.copyWith(color: AppColors.ivory),
          ),
          if (description != null) ...[
            const SizedBox(height: CsSpacing.xs),
            Text(
              description!,
              textAlign: TextAlign.center,
              style: CsTypography.body.copyWith(
                color: AppColors.secondaryOnDark,
              ),
            ),
          ],
        ],
      ),
    ),
  );
}
