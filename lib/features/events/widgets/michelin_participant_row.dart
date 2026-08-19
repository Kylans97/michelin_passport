import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/cs_spacing.dart';
import '../../../core/theme/cs_typography.dart';
import '../../../core/widgets/star_row.dart';
import '../../../models/restaurant.dart';

/// One row inside [AtThisEventSection] (Events UI Consistency Step
/// 1A; section renamed from `MichelinAtEventSection` in Events V2 Step 3)
/// — a restaurant's name with its Michelin stars inline on the
/// primary line, then city and country flag on a quieter secondary line.
///
/// Deliberately NOT [LinkedVenueRow] (`core/widgets/linked_venue_row.dart`)
/// reskinned in place, and NOT a change to [LinkedVenueRow] itself.
/// [LinkedVenueRow] is actively used by Restaurant Detail's "AT THIS
/// HOTEL" and Hotel Detail's "DINING" sections, both already physically
/// approved with its current name-then-recognition-BELOW layout — the
/// stars-inline-with-name shape this row needs is a genuinely different
/// visual structure, not a value tweak, so changing [LinkedVenueRow] to
/// produce it would either alter those two already-approved screens or
/// require a mode flag that leaves one shape effectively dead code. A
/// small, Event-specific row is the lower-risk, clearer architecture (see
/// the Step 1A architecture note in EVENTS_UI_MICHELIN_PARTICIPATION.md).
///
/// Name + stars are one [Text.rich] paragraph — a [WidgetSpan] carries the
/// [StarRow], not a separate `Row` positioned after the text — so the
/// stars are genuinely inline with the name, wrap together with it if the
/// name is long, and are never pushed to a far trailing edge with an
/// artificial gap. No line-count cap: the whole screen scrolls, so a
/// pathologically long name simply wraps to as many lines as it needs
/// rather than risking the stars being ellipsis-truncated away — the
/// stars must always remain visible.
class MichelinParticipantRow extends StatelessWidget {
  final Restaurant restaurant;
  final VoidCallback onTap;

  const MichelinParticipantRow({
    super.key,
    required this.restaurant,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final stars = restaurant.michelinStars!;
    final city = restaurant.cityName.trim();
    final hasCity = city.isNotEmpty;
    final flag = restaurant.flagEmoji.trim();
    final hasFlag = flag.isNotEmpty;
    // countryName is preferred (a screen reader announcing "NL" reads as
    // the letters N, L; "Netherlands" is the actual word) — countryCode is
    // only a fallback for the rare row where countryName wasn't resolved.
    final countryLabel = restaurant.countryName.isNotEmpty
        ? restaurant.countryName
        : restaurant.countryCode;

    // The flag emoji is decorative/supporting only — never the sole
    // accessibility signal for country. Screen-reader users get the
    // restaurant's full identity as one combined label instead of reading
    // each visual line (and the flag glyph) as separate, disconnected
    // nodes.
    final semanticLabel = [
      restaurant.name,
      if (hasCity) city,
      if (countryLabel.isNotEmpty) countryLabel,
      '$stars ${stars == 1 ? 'Michelin star' : 'Michelin stars'}',
    ].join(', ');

    return Semantics(
      button: true,
      label: semanticLabel,
      excludeSemantics: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(CsRadius.medium),
          splashColor: AppColors.forestGreen.withValues(alpha: 0.08),
          highlightColor: AppColors.forestGreen.withValues(alpha: 0.08),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: CsSpacing.sm),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: restaurant.name,
                              style: CsTypography.bodyMedium.copyWith(
                                color: AppColors.forestGreen,
                              ),
                            ),
                            const WidgetSpan(
                              child: SizedBox(width: CsSpacing.xs),
                            ),
                            WidgetSpan(
                              alignment: PlaceholderAlignment.middle,
                              child: StarRow(count: stars, size: 12),
                            ),
                          ],
                        ),
                      ),
                      if (hasCity || hasFlag) ...[
                        const SizedBox(height: 3),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (hasCity)
                              Flexible(
                                child: Text(
                                  city,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: CsTypography.metadata.copyWith(
                                    color: AppColors.taupe,
                                    fontSize: 12.5,
                                  ),
                                ),
                              ),
                            if (hasCity && hasFlag)
                              const SizedBox(width: CsSpacing.xs),
                            if (hasFlag)
                              Text(
                                flag,
                                style: const TextStyle(fontSize: 12.5),
                              ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: CsSpacing.sm),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.taupe,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
