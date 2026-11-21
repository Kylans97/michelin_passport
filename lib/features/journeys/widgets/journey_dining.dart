import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/cs_spacing.dart';
import '../../../core/theme/cs_typography.dart';
import '../../../core/widgets/cs_editorial_glyphs.dart';
import '../../../models/journey.dart';

/// "The table aboard": the journey's dining text as an italic pull quote
/// between two short brass rules, then its dining partners from our
/// catalogue as a short menu of places, each with its city and its own
/// MICHELIN stars (gold, as everywhere a star is drawn), opening the
/// restaurant's page. The quote is the operator's text, never rewritten.
class JourneyDining extends StatelessWidget {
  final String diningText;
  final List<JourneyDiningPartner> partners;
  final ValueChanged<String> onOpenRestaurant;

  const JourneyDining({
    super.key,
    required this.diningText,
    required this.partners,
    required this.onOpenRestaurant,
  });

  @override
  Widget build(BuildContext context) {
    final quote = diningText.trim();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (quote.isNotEmpty) ...[
          const _Rule(),
          const SizedBox(height: CsSpacing.base),
          Text(
            quote,
            textAlign: TextAlign.center,
            style: CsTypography.editorialLead(
              size: 21,
            ).copyWith(color: AppColors.forestGreen, height: 1.4),
          ),
          const SizedBox(height: CsSpacing.base),
          const _Rule(),
        ],
        if (partners.isNotEmpty) ...[
          if (quote.isNotEmpty) const SizedBox(height: CsSpacing.xl),
          Text(
            'FROM THE KITCHEN OF',
            style: CsTypography.eyebrow.copyWith(color: AppColors.taupe),
          ),
          const SizedBox(height: CsSpacing.sm),
          for (final partner in partners)
            _PartnerRow(
              partner: partner,
              onTap: () => onOpenRestaurant(partner.id),
            ),
        ],
      ],
    );
  }
}

class _Rule extends StatelessWidget {
  const _Rule();

  @override
  Widget build(BuildContext context) => Center(
    child: Container(width: 32, height: 1, color: AppColors.mutedBrass),
  );
}

class _PartnerRow extends StatelessWidget {
  final JourneyDiningPartner partner;
  final VoidCallback onTap;

  const _PartnerRow({required this.partner, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final stars = partner.michelinStars ?? 0;
    final city = (partner.cityName ?? '').trim();
    return Semantics(
      button: true,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: CsSpacing.md),
          decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: AppColors.subtleBorderLight)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      partner.name,
                      style: CsTypography.editorialLead(size: 19).copyWith(
                        fontStyle: FontStyle.normal,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    if (city.isNotEmpty)
                      Text(
                        city,
                        style: CsTypography.metadata.copyWith(
                          color: AppColors.taupe,
                        ),
                      ),
                  ],
                ),
              ),
              if (stars > 0) ...[
                CsEditorialStarRow(count: stars, size: 13),
                const SizedBox(width: CsSpacing.md),
              ],
              const Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: AppColors.taupe,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
