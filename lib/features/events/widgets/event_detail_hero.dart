import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/cs_spacing.dart';
import '../../../core/theme/cs_typography.dart';
import '../../../core/widgets/editorial_back_button.dart';

/// The current-generation hero for Event Detail (Events UI Consistency
/// Step 1) — a fresh, Cs-token-based primitive, deliberately NOT a
/// modification of [DetailHero] (`detail_hero.dart`), which stays exactly
/// as it is: that widget is also shared with both Award History screens
/// and every other screen still out of scope for this redesign, and
/// editing it would risk changing their appearance too. This is a
/// parallel component, mirroring [VenueDetailHero]'s own "one small
/// primitive genuinely reused twice" reasoning from the Restaurant/Hotel
/// Detail redesign — except an event genuinely has no wishlist concept, so
/// this hero carries no toggle/actions overlay at all, just identity.
///
/// Unlike [VenueDetailHero] (whose no-photo fallback is a plain gradient,
/// since no restaurant/hotel photo exists in the catalogue at all today),
/// events already have a real `image_url` column and an established
/// branded-monogram fallback ([CsImagePlaceholder], via [backgroundImage]
/// — the caller supplies either a real `Image.network` with its own
/// [CsImagePlaceholder] `errorBuilder`, or the placeholder directly when
/// no URL exists at all). This hero always renders whatever
/// [backgroundImage] it's given, photo or placeholder alike, under the
/// same legibility vignette.
///
/// Deliberately minimal: image/placeholder and a back action, nothing
/// else in real Event Detail usage — no badge stack, no gold, no
/// marketplace-style pricing chip. "Curated," not "ticket marketplace."
///
/// Events V2 Time Precision Phase B — Event Detail Hierarchy UX
/// correction: [eventTypeLabel] and [dateRangeLine] are optional, and the
/// production call site (`event_detail_screen.dart`) no longer supplies
/// either — that information moved to Event Essentials, directly below
/// the hero.
///
/// Events V2 Time Precision Phase B — hero/Essentials title correction
/// (physical-device finding on the first genuine date-only pilot): [title]
/// and [cityCountryLine] are now ALSO optional, and the production call
/// site no longer supplies either — the Event name itself moved to Event
/// Essentials (as its first element, directly below the hero, rendered at
/// [CsTypography.placeTitle]), so there is exactly ONE visible Event
/// title in the whole top hierarchy rather than one here and a second one
/// in Essentials. All four text parameters stay supported (not removed
/// outright) so this widget's own direct tests, and any future caller
/// with a genuine reason to show more identity text in the hero, are not
/// forced into a wider redesign of this primitive to do so.
///
/// Editorial Hero + Essentials/Actions polish pass (a further
/// physical-device finding on the same pilot): [eventTypeLabel] moved
/// BACK into real Event Detail usage — the production call site now
/// supplies exactly this one field and nothing else — as a subtle
/// editorial category eyebrow near the lower-left of the hero ("DINNER",
/// not a chip/badge, no gold, no icon). Title/date/venue/admission still
/// never appear here; the hero stays photography-ready in every respect
/// except this one small, deliberately quiet category label. The
/// bottom-weighted vignette is a lighter, shorter treatment than the
/// title-era version above it (lower peak opacity, a shorter transition
/// zone) — "the smallest solution consistent with existing design
/// patterns," proportional to a single small text line rather than a
/// multi-line title block; still present at all, even with only
/// [eventTypeLabel] showing, because a real photo benefits from the same
/// legibility treatment once Event photography exists.
class EventDetailHero extends StatelessWidget {
  final String? title;
  final String? eventTypeLabel;
  final String? cityCountryLine;
  final String? dateRangeLine;
  final Widget backgroundImage;
  final double expandedHeight;

  const EventDetailHero({
    super.key,
    this.title,
    this.eventTypeLabel,
    this.cityCountryLine,
    this.dateRangeLine,
    required this.backgroundImage,
    this.expandedHeight = 300,
  });

  @override
  Widget build(BuildContext context) {
    final hasOverlayText =
        title != null ||
        eventTypeLabel != null ||
        cityCountryLine != null ||
        dateRangeLine != null;
    return SliverAppBar(
      expandedHeight: expandedHeight,
      pinned: true,
      backgroundColor: AppColors.deepGreen,
      foregroundColor: AppColors.textOnDark,
      leadingWidth: 56,
      leading: const Padding(
        padding: EdgeInsets.only(left: CsSpacing.sm),
        child: EditorialBackButton(),
      ),
      title: title == null
          ? null
          : Text(
              title!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: CsTypography.bodyMedium.copyWith(
                color: AppColors.textOnDark,
              ),
            ),
      flexibleSpace: FlexibleSpaceBar(
        collapseMode: CollapseMode.parallax,
        background: Stack(
          fit: StackFit.expand,
          children: [
            backgroundImage,
            // Bottom-weighted vignette so the eyebrow label stays legible
            // over a real photo or the monogram placeholder alike —
            // deliberately lighter and shorter than an earlier title-era
            // version of this same gradient: a single small eyebrow line
            // doesn't need anywhere near as much of the image darkened as
            // a multi-line title block once did. Kept even with no
            // overlay text at all (EventType.other), since a real photo
            // still benefits from the same bottom-weighted legibility
            // treatment once Event photography exists.
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Color(0x6616302A),
                    Color(0xCC16302A),
                  ],
                  stops: [0.0, 0.7, 1.0],
                ),
              ),
            ),
            if (hasOverlayText)
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    CsSpacing.pageHorizontal,
                    CsSpacing.hero,
                    CsSpacing.pageHorizontal,
                    CsSpacing.lg,
                  ),
                  child: SingleChildScrollView(
                    physics: const NeverScrollableScrollPhysics(),
                    reverse: true,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (eventTypeLabel != null) ...[
                          Text(
                            eventTypeLabel!,
                            style: CsTypography.smallLabel.copyWith(
                              color: AppColors.textOnDark.withValues(
                                alpha: 0.75,
                              ),
                              letterSpacing: 1.2,
                            ),
                          ),
                          const SizedBox(height: CsSpacing.xs),
                        ],
                        if (title != null) ...[
                          Text(
                            title!,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: CsTypography.displayHero.copyWith(
                              color: AppColors.textOnDark,
                              fontSize: 30,
                              height: 1.1,
                            ),
                          ),
                          const SizedBox(height: CsSpacing.sm),
                        ],
                        if (cityCountryLine != null) ...[
                          Text(
                            cityCountryLine!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: CsTypography.bodyMedium.copyWith(
                              color: AppColors.textOnDark.withValues(
                                alpha: 0.85,
                              ),
                              fontSize: 14,
                            ),
                          ),
                        ],
                        if (dateRangeLine != null) ...[
                          const SizedBox(height: CsSpacing.xs),
                          Text(
                            dateRangeLine!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: CsTypography.smallLabel.copyWith(
                              color: AppColors.textOnDark.withValues(
                                alpha: 0.7,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
