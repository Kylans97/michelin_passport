import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/cs_spacing.dart';
import '../../../core/theme/cs_typography.dart';
import '../../../models/private_chef.dart';

/// Formats a guest range per PRIVATE_CHEFS.md's own field-nullability
/// reasoning — never "null–14 guests", never a fabricated default when
/// neither bound is set (returns null, meaning: omit the line entirely).
String? formatGuestRange(PrivateChef chef) {
  final min = chef.minimumGuests;
  final max = chef.maximumGuests;
  if (min != null && max != null) return '$min–$max guests';
  if (min != null) return 'From $min guests';
  if (max != null) return 'Up to $max guests';
  return null;
}

/// Formats the showable from-price, or null when there's nothing honest to
/// show (price-on-request, or on-request is false but no amount was ever
/// set). No currency-symbol invention — the raw ISO 4217 code is shown as
/// text, matching this codebase's existing precedent of never guessing a
/// symbol mapping (see Visit.currency / EventCard's raw country-code
/// text).
String? formatPricingFrom(PrivateChef chef) {
  if (!chef.hasShowablePricingFrom) return null;
  final amount = chef.pricingFrom!;
  final amountText = amount == amount.roundToDouble()
      ? amount.toStringAsFixed(0)
      : amount.toStringAsFixed(2);
  final currency = (chef.pricingCurrency ?? '').trim();
  final unitLabel = switch (chef.pricingUnit) {
    'per_person' => ' per person',
    'per_experience' => ' per experience',
    _ => '',
  };
  final currencyPrefix = currency.isEmpty ? '' : '$currency ';
  return 'From $currencyPrefix$amountText$unitLabel';
}

/// Chef Detail's "THE EXPERIENCE" section — editorial prose built entirely
/// from conditional [PrivateChef] fields, never a dense specification
/// table (Step 2 brief §17) and never a fact not actually stored on the
/// model (§17/§19). Omits the whole section when [chef] has literally
/// nothing to show, so a thin profile never renders an empty heading.
class PrivateChefExperienceSection extends StatelessWidget {
  final PrivateChef chef;

  const PrivateChefExperienceSection({super.key, required this.chef});

  @override
  Widget build(BuildContext context) {
    final serviceArea = (chef.serviceAreaText ?? '').trim();
    final hasServiceArea = serviceArea.isNotEmpty;
    final personalization = (chef.personalizationNote ?? '').trim();
    final hasPersonalization = personalization.isNotEmpty;
    final wineNote = (chef.wineNote ?? '').trim();
    final guestRange = formatGuestRange(chef);
    final pricingLine = formatPricingFrom(chef);
    final languages = chef.languages.where((l) => l.trim().isNotEmpty).toList();

    final lines = <String>[
      if (hasServiceArea)
        'Available across $serviceArea.'
      else if (chef.travelAvailable)
        'Available for travel.',
      if (guestRange != null) 'For intimate dinners of $guestRange.',
      if (hasPersonalization) personalization,
      if (chef.winePairingAvailable)
        wineNote.isNotEmpty
            ? 'Wine pairing available — $wineNote'
            : 'Wine pairing available.',
      if (chef.priceOnRequest)
        'Price on request.'
      else if (pricingLine != null)
        '$pricingLine.',
      if (languages.isNotEmpty) 'Speaks ${languages.join(', ')}.',
    ];

    if (lines.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'THE EXPERIENCE',
          style: CsTypography.eyebrow.copyWith(color: AppColors.taupe),
        ),
        const SizedBox(height: CsSpacing.md),
        for (var i = 0; i < lines.length; i++) ...[
          if (i > 0) const SizedBox(height: CsSpacing.sm),
          Text(
            lines[i],
            style: CsTypography.body.copyWith(color: AppColors.textPrimary),
          ),
        ],
      ],
    );
  }
}
