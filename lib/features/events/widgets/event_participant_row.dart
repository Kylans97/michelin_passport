import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/cs_spacing.dart';
import '../../../core/theme/cs_typography.dart';
import '../../../core/widgets/star_row.dart';
import '../../../models/restaurant.dart';

/// One row inside [AtThisEventSection] (originally `MichelinParticipantRow`
/// — Events Recognition V2 generalizes it the exact same way Events V2
/// Step 3 generalized the section itself: recognition is a contextual
/// attribute of the participant, never the reason the widget is named,
/// now that a participant can be recognized by Michelin and/or World's 50
/// Best without necessarily holding a Michelin star). A restaurant's name
/// with its Michelin stars inline on the primary line when it holds any
/// (unchanged from the original, byte-for-byte, for every Michelin-starred
/// restaurant — see [AtThisEventSection]'s own doc comment on why this
/// matters for the Andorra Taste regression), then a compact secondary
/// line carrying whichever of [Restaurant.isHallOfFame]/
/// [Restaurant.isWorlds50Best] applies, followed by city and country flag.
///
/// Deliberately NOT [LinkedVenueRow] (`core/widgets/linked_venue_row.dart`)
/// reskinned in place, and NOT a change to [LinkedVenueRow] itself — see
/// this class's own original Step 1A rationale in
/// EVENTS_UI_MICHELIN_PARTICIPATION.md, unchanged by this generalization.
///
/// Name + stars are one [Text.rich] paragraph — a [WidgetSpan] carries the
/// [StarRow], not a separate `Row` positioned after the text — so the
/// stars are genuinely inline with the name, wrap together with it if the
/// name is long, and are never pushed to a far trailing edge with an
/// artificial gap. No line-count cap: the whole screen scrolls, so a
/// pathologically long name simply wraps to as many lines as it needs
/// rather than risking the stars being ellipsis-truncated away — the
/// stars must always remain visible.
///
/// Recognition V2 — World's 50 Best / Hall of Fame presentation:
/// deliberately NEVER added to the primary line (which stays reserved for
/// name + Michelin stars only, exactly as before) — instead surfaced as a
/// compact text label on the SAME secondary line city/flag already use,
/// joined with " · " (task's own restrained-terminology example), never a
/// second row, second badge, or colorful pill (task §7's explicit "avoid
/// giant badges/colorful award pills"). Uses the exact same terminology
/// [RestaurantHero] already established ("Hall of Fame",
/// "World's 50 Best · #N") — no competing wording invented here. A
/// restaurant that is BOTH Hall of Fame and currently World's 50 Best
/// ranked shows "Hall of Fame" only (the higher, rarer honor) — this is
/// expected to be a rare-to-never real combination in practice (a Hall of
/// Fame legend is, by construction, retired from the annual ranking that
/// produces a current rank — see [Restaurant.worlds50BestRank]'s own view
/// derivation), but the row still resolves deterministically if it ever
/// occurs. Gault&Millau is deliberately NOT represented here at all — see
/// [AtThisEventSection]'s own doc comment for why V2 does not implement
/// it.
class EventParticipantRow extends StatelessWidget {
  final Restaurant restaurant;
  final VoidCallback onTap;

  const EventParticipantRow({
    super.key,
    required this.restaurant,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final stars = restaurant.michelinStars;
    final hasStars = stars != null;
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

    final recognitionLabel = restaurant.isHallOfFame
        ? 'Hall of Fame'
        : restaurant.isWorlds50Best
        ? "World's 50 Best · #${restaurant.worlds50BestRank}"
        : null;
    final hasRecognitionLabel = recognitionLabel != null;

    final secondaryText = [
      if (hasRecognitionLabel) recognitionLabel,
      if (hasCity) city,
    ].join(' · ');
    final hasSecondaryText = secondaryText.isNotEmpty;

    // The flag emoji is decorative/supporting only — never the sole
    // accessibility signal for country. Screen-reader users get the
    // restaurant's full identity as one combined label instead of reading
    // each visual line (and the flag glyph) as separate, disconnected
    // nodes. Ordering preserved exactly from the pre-V2 row (name, city,
    // country, stars) for every Michelin-only restaurant — recognitionLabel
    // is appended last, only when present, so no existing semantic string
    // changes for a restaurant that doesn't need it.
    final semanticLabel = [
      restaurant.name,
      if (hasCity) city,
      if (countryLabel.isNotEmpty) countryLabel,
      if (hasStars) '$stars ${stars == 1 ? 'Michelin star' : 'Michelin stars'}',
      if (hasRecognitionLabel) recognitionLabel,
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
                            if (hasStars) ...[
                              const WidgetSpan(
                                child: SizedBox(width: CsSpacing.xs),
                              ),
                              WidgetSpan(
                                alignment: PlaceholderAlignment.middle,
                                child: StarRow(count: stars, size: 12),
                              ),
                            ],
                          ],
                        ),
                      ),
                      if (hasSecondaryText || hasFlag) ...[
                        const SizedBox(height: 3),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (hasSecondaryText)
                              Flexible(
                                child: Text(
                                  secondaryText,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: CsTypography.metadata.copyWith(
                                    color: AppColors.taupe,
                                    fontSize: 12.5,
                                  ),
                                ),
                              ),
                            if (hasSecondaryText && hasFlag)
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
