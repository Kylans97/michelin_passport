import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/cs_spacing.dart';
import '../../../core/theme/cs_typography.dart';
import '../../../core/widgets/cs_image_placeholder.dart';

/// A Guide catalogue's loading state — the same restrained
/// `CircularProgressIndicator(strokeWidth: 1.5)` language already used
/// everywhere else in Mantelier (see ExploreScreen's search-mode
/// loading state), never a skeleton or shimmer package.
class GuideCatalogueLoading extends StatelessWidget {
  const GuideCatalogueLoading({super.key});

  @override
  Widget build(BuildContext context) => const Center(
    child: CircularProgressIndicator(
      color: AppColors.forestGreen,
      strokeWidth: 1.5,
    ),
  );
}

/// A Guide catalogue's empty state — two distinct variants sharing one
/// visual language, matching [ExploreSearchEmptyState]'s restrained
/// deep-green treatment:
///
/// - [hasActiveFilters] true: an active search/country/star-or-Key filter
///   matched nothing — "Try adjusting your search or filters."
/// - [hasActiveFilters] false: the unfiltered catalogue itself came back
///   empty — a genuinely different situation (see the Guides Step 2B
///   brief's distinction between "no data" and "no matches"), so it gets
///   its own copy rather than implying the user did something wrong.
class GuideCatalogueEmptyState extends StatelessWidget {
  final bool hasActiveFilters;

  const GuideCatalogueEmptyState({super.key, required this.hasActiveFilters});

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 56),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CsImagePlaceholder(
            width: 56,
            height: 56,
            borderRadius: BorderRadius.all(Radius.circular(14)),
            logoScale: 0.5,
          ),
          const SizedBox(height: CsSpacing.lg),
          Text(
            'No places found',
            textAlign: TextAlign.center,
            style: CsTypography.placeTitle.copyWith(
              color: AppColors.forestGreen,
            ),
          ),
          const SizedBox(height: CsSpacing.xs),
          Text(
            hasActiveFilters
                ? 'Try adjusting your search or filters.'
                : 'This guide has no places to show yet.',
            textAlign: TextAlign.center,
            style: CsTypography.metadata.copyWith(color: AppColors.taupe),
          ),
        ],
      ),
    ),
  );
}

/// A Guide catalogue's subtle result count — "50 places" / "1 place",
/// never "50 WORLD'S 50 BEST RESTAURANTS" (see the Guides Step 2B/2C
/// briefs). Shared by both World's 50 Best catalogues (Step 2C); the two
/// Michelin catalogues (Step 2B) keep their own small private
/// `_ResultCountLine` copies rather than being migrated onto this one —
/// see the Step 2C report for why touching the already-approved Michelin
/// screen files wasn't worth it for a purely internal de-duplication.
class GuideResultCountLine extends StatelessWidget {
  final int count;
  final bool loading;

  const GuideResultCountLine({
    super.key,
    required this.count,
    required this.loading,
  });

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(
        count == 1 ? '1 place' : '$count places',
        style: CsTypography.eyebrow.copyWith(color: AppColors.taupe),
      ),
      if (loading) ...[
        const SizedBox(width: CsSpacing.sm),
        const SizedBox(
          width: 10,
          height: 10,
          child: CircularProgressIndicator(
            color: AppColors.taupe,
            strokeWidth: 1.2,
          ),
        ),
      ],
    ],
  );
}

/// A Guide catalogue's error state — reuses [ExploreSearchErrorState]'s
/// language exactly (same icon, same restrained copy, same retry
/// treatment) rather than inventing a second error style. Never surfaces a
/// raw Supabase/database error string.
class GuideCatalogueErrorState extends StatelessWidget {
  final VoidCallback onRetry;

  const GuideCatalogueErrorState({super.key, required this.onRetry});

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 56),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.wifi_off_rounded, color: AppColors.taupe, size: 32),
          const SizedBox(height: CsSpacing.base),
          Text(
            'Unable to load places',
            textAlign: TextAlign.center,
            style: CsTypography.body.copyWith(color: AppColors.taupe),
          ),
          const SizedBox(height: CsSpacing.md),
          TextButton(
            onPressed: onRetry,
            child: Text(
              'Retry',
              style: CsTypography.bodyMedium.copyWith(
                color: AppColors.forestGreen,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
