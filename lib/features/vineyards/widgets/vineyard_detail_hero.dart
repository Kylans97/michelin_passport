import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/cs_spacing.dart';
import '../../../core/theme/cs_typography.dart';
import '../../../core/widgets/editorial_back_button.dart';
import '../../../models/vineyard.dart';

/// The top of a wine estate's page. Its own widget beside VenueDetailHero,
/// PrivateChefHero, EventDetailHero and JourneyDetailHero (CLAUDE.md: the
/// heroes stay separate, settled, do not unify). An estate has no photo
/// until it supplies one, so this hero is typographic: deep green, the
/// region as an eyebrow, the name, and where it is.
class VineyardDetailHero extends StatelessWidget {
  final Vineyard vineyard;

  const VineyardDetailHero({super.key, required this.vineyard});

  @override
  Widget build(BuildContext context) {
    final eyebrow = [
      'Wine estate',
      if ((vineyard.region ?? '').trim().isNotEmpty) vineyard.region!.trim(),
    ].join(' · ');
    final where = [
      if ((vineyard.city ?? '').trim().isNotEmpty) vineyard.city!.trim(),
      if ((vineyard.countryName ?? '').trim().isNotEmpty)
        vineyard.countryName!.trim(),
    ].join(', ');
    return ColoredBox(
      color: AppColors.deepGreen,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            CsSpacing.base,
            0,
            CsSpacing.base,
            CsSpacing.xl,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const EditorialBackButton(color: AppColors.ivory),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: CsSpacing.pageHorizontal - CsSpacing.base,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: CsSpacing.md),
                    Text(
                      eyebrow.toUpperCase(),
                      style: CsTypography.eyebrow.copyWith(
                        color: AppColors.secondaryOnDark,
                      ),
                    ),
                    const SizedBox(height: CsSpacing.sm),
                    Text(
                      vineyard.name,
                      style: CsTypography.displayHero.copyWith(
                        color: AppColors.ivory,
                      ),
                    ),
                    if (where.isNotEmpty) ...[
                      const SizedBox(height: CsSpacing.xs),
                      Text(
                        where,
                        style: CsTypography.body.copyWith(
                          color: AppColors.secondaryOnDark,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
