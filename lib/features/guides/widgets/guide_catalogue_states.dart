import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/cs_spacing.dart';
import '../../../core/theme/cs_typography.dart';
import '../../../core/widgets/cs_image_placeholder.dart';

/// A Guide catalogue's loading state — the same restrained
/// `CircularProgressIndicator(strokeWidth: 1.5)` language already used
/// everywhere else in Chasing Stars (see ExploreScreen's search-mode
/// loading state), never a skeleton or shimmer package.
class GuideCatalogueLoading extends StatelessWidget {
  const GuideCatalogueLoading({super.key});

  @override
  Widget build(BuildContext context) => const Center(
    child: CircularProgressIndicator(
      color: AppColors.textOnDark,
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
              color: AppColors.textOnDark,
            ),
          ),
          const SizedBox(height: CsSpacing.xs),
          Text(
            hasActiveFilters
                ? 'Try adjusting your search or filters.'
                : 'This guide has no places to show yet.',
            textAlign: TextAlign.center,
            style: CsTypography.metadata.copyWith(
              color: AppColors.secondaryOnDark,
            ),
          ),
        ],
      ),
    ),
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
          const Icon(
            Icons.wifi_off_rounded,
            color: AppColors.secondaryOnDark,
            size: 32,
          ),
          const SizedBox(height: CsSpacing.base),
          Text(
            'Unable to load places',
            textAlign: TextAlign.center,
            style: CsTypography.body.copyWith(color: AppColors.secondaryOnDark),
          ),
          const SizedBox(height: CsSpacing.md),
          TextButton(
            onPressed: onRetry,
            child: Text(
              'Retry',
              style: CsTypography.bodyMedium.copyWith(
                color: AppColors.textOnDark,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
