import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/cs_spacing.dart';
import '../../../core/theme/cs_typography.dart';
import '../../../core/widgets/cs_image_placeholder.dart';

/// Private Chefs' landing empty state — first-class, not an error.
/// Production currently has zero published chefs, so this is the state
/// most real users see today; it must read as intentional, not broken.
/// Deliberately does not say "No chefs found," mention Lucas, promise a
/// date, or say "database" — see the Step 2 brief §9. Visual language
/// matches [GuideCatalogueEmptyState] (same placeholder mark, same
/// typography roles) so it reads as the same family of considered empty
/// state, not a one-off.
class PrivateChefsEmptyState extends StatelessWidget {
  const PrivateChefsEmptyState({super.key});

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
            'Private Chefs are coming soon',
            textAlign: TextAlign.center,
            style: CsTypography.placeTitle.copyWith(
              color: AppColors.forestGreen,
            ),
          ),
          const SizedBox(height: CsSpacing.xs),
          Text(
            "We're curating a small collection of exceptional chefs for "
            'private dining experiences.',
            textAlign: TextAlign.center,
            style: CsTypography.metadata.copyWith(color: AppColors.taupe),
          ),
        ],
      ),
    ),
  );
}

/// Private Chefs' landing/detail loading state — the same restrained
/// spinner language as [GuideCatalogueLoading].
class PrivateChefsLoadingState extends StatelessWidget {
  const PrivateChefsLoadingState({super.key});

  @override
  Widget build(BuildContext context) => const Center(
    child: CircularProgressIndicator(
      color: AppColors.forestGreen,
      strokeWidth: 1.5,
    ),
  );
}

/// Private Chefs' landing/detail error state — never a raw Supabase
/// error string, matching [GuideCatalogueErrorState]'s exact language.
class PrivateChefsErrorState extends StatelessWidget {
  final VoidCallback onRetry;

  const PrivateChefsErrorState({super.key, required this.onRetry});

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
            'Unable to load Private Chefs',
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

/// Private Chef Detail's not-found state — a chef id/slug that fails to
/// resolve (removed, archived, or never existed) gets a restrained,
/// dedicated message rather than a generic error or a raw exception.
class PrivateChefNotFoundState extends StatelessWidget {
  const PrivateChefNotFoundState({super.key});

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
            "This chef isn't available",
            textAlign: TextAlign.center,
            style: CsTypography.placeTitle.copyWith(
              color: AppColors.forestGreen,
            ),
          ),
          const SizedBox(height: CsSpacing.xs),
          Text(
            'This profile may no longer be part of the Private Chefs '
            'collection.',
            textAlign: TextAlign.center,
            style: CsTypography.metadata.copyWith(color: AppColors.taupe),
          ),
        ],
      ),
    ),
  );
}
