import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/cs_spacing.dart';
import '../../../core/theme/cs_typography.dart';
import '../../../core/widgets/venue_thumbnail.dart';

/// One result in a Guide catalogue's browsing list — a compact editorial
/// index row, the same visual family as [GuideDestinationRow] on the
/// Guides landing page, separated by hairlines rather than boxed cards, so
/// a long list of many venues stays quiet and scannable.
///
/// Step 1B — PHOTO-READY: the leading slot is now [VenueThumbnail], the
/// same photo-first thumbnail already used by Explore's RestaurantTile/
/// HotelTile — [imageUrl] is null at every current call site (neither
/// catalogue table carries a venue image yet, same as Explore's own
/// today), which renders the branded [CsImagePlaceholder] as a fallback
/// occupying the exact same frame a real photo will later fill. No new
/// image infrastructure was built for this — [VenueThumbnail] already IS
/// the "nullable imageUrl + fallback" seam this row needs.
///
/// Presentation-only: knows nothing about Restaurant, Hotel, stars, Keys,
/// rank or Gault&Millau. Recognition is expressed through two independent,
/// optional slots so each Guide family can put its own primary "why is
/// this venue in this guide" signal in the right place:
/// - [inlineRecognition]: rendered directly beside [title] on the same
///   line (Michelin's [StarRow]/[KeyRow] — a single glyph row that reads
///   naturally inline, wrapping together with a long name rather than
///   ever being pushed off-screen).
/// - [metadataLine]: rendered as its own line directly under the title,
///   above the city — for recognition that's inherently textual rather
///   than glyph-based (World's 50 Best's rank/year, Gault&Millau's score),
///   which would read wrong crammed inline with the name.
/// Both default to null/unused; a call site supplies whichever one fits
/// its Guide.
class GuideVenueCard extends StatelessWidget {
  final String title;
  final Widget? inlineRecognition;
  final Widget? metadataLine;
  final String cityName;
  final String countryName;
  final String flagEmoji;

  /// A truthful, spoken description of [inlineRecognition]/[metadataLine]
  /// for screen readers, e.g. "3 Michelin stars" or "ranked number 12,
  /// 2026" — recognition must never be gold-icon-only for accessibility.
  final String? recognitionSemanticLabel;

  /// Null at every current call site (no catalogue table carries a venue
  /// image yet) — the seam that lights up real photography the moment one
  /// does, with zero further changes to this widget.
  final String? imageUrl;

  final VoidCallback onTap;

  const GuideVenueCard({
    super.key,
    required this.title,
    this.inlineRecognition,
    this.metadataLine,
    this.cityName = '',
    this.countryName = '',
    this.flagEmoji = '',
    this.recognitionSemanticLabel,
    this.imageUrl,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final city = cityName.trim();
    final hasCity = city.isNotEmpty;
    final flag = flagEmoji.trim();
    final hasFlag = flag.isNotEmpty;

    // The flag is decorative/supporting only — never the sole
    // accessibility signal for country, and never inferred from the
    // Guide itself, only from the venue's own canonical fields.
    final semanticLabel = [
      title,
      if (hasCity) city,
      if (countryName.isNotEmpty) countryName,
      if (recognitionSemanticLabel != null &&
          recognitionSemanticLabel!.isNotEmpty)
        recognitionSemanticLabel!,
    ].join(', ');

    return Semantics(
      button: true,
      label: semanticLabel,
      excludeSemantics: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          splashColor: AppColors.forestGreen.withValues(alpha: 0.06),
          highlightColor: AppColors.forestGreen.withValues(alpha: 0.04),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: CsSpacing.sm),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                VenueThumbnail(imageUrl: imageUrl, size: 52),
                const SizedBox(width: CsSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // No maxLines/ellipsis: a long name wraps cleanly
                      // rather than being truncated or shrunk — see
                      // EventParticipantRow's identical reasoning for
                      // Event participants, the established precedent
                      // this row deliberately mirrors.
                      inlineRecognition == null
                          ? Text(
                              title,
                              style: CsTypography.placeTitle.copyWith(
                                fontSize: 17,
                                color: AppColors.forestGreen,
                              ),
                            )
                          : Text.rich(
                              TextSpan(
                                children: [
                                  TextSpan(
                                    text: title,
                                    style: CsTypography.placeTitle.copyWith(
                                      fontSize: 17,
                                      color: AppColors.forestGreen,
                                    ),
                                  ),
                                  const WidgetSpan(
                                    child: SizedBox(width: CsSpacing.xs),
                                  ),
                                  WidgetSpan(
                                    alignment: PlaceholderAlignment.middle,
                                    child: inlineRecognition!,
                                  ),
                                ],
                              ),
                            ),
                      if (metadataLine != null) ...[
                        const SizedBox(height: 2),
                        metadataLine!,
                      ],
                      if (hasCity || hasFlag) ...[
                        const SizedBox(height: 2),
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
                                  ),
                                ),
                              ),
                            if (hasCity && hasFlag)
                              const SizedBox(width: CsSpacing.xs),
                            if (hasFlag)
                              Text(flag, style: const TextStyle(fontSize: 13)),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A hairline between [GuideVenueCard] rows (and, since Step 1A, between
/// destinations inside a [GuideFamilySection] ivory block) — at zero
/// vertical margin here rather than [SectionDivider]'s generous
/// [CsSpacing.lg] padding: a dense results list needs a tight separator
/// between rows, not the wide gap [SectionDivider] uses between major page
/// sections.
///
/// Step 1A: physical-device review found the original 0.5px/taupe-40%
/// treatment nearly invisible against the ivory canvas. Rather than invent
/// an unproven new value, this now uses [SectionDivider]'s own already
/// on-device-approved thickness (0.75px) at a modestly higher opacity
/// (taupe 55%, up from 40%) — [SectionDivider] itself (used by Restaurant/
/// Hotel/Event Detail) is deliberately left unchanged, since a list of
/// many rows needs a touch more contrast than a rule between two large
/// text blocks does.
class GuideVenueCardDivider extends StatelessWidget {
  const GuideVenueCardDivider({super.key});

  @override
  Widget build(BuildContext context) =>
      Container(height: 0.75, color: AppColors.taupe.withValues(alpha: 0.55));
}
