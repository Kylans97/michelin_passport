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
/// Deliberately minimal: image/placeholder, back action, an optional
/// small event-type eyebrow, the event name, and a compact city/country
/// line — no badge stack, no gold, no marketplace-style pricing chip.
/// "Curated," not "ticket marketplace."
///
/// Events V2 Time Precision Phase B — Event Detail Hierarchy UX
/// correction: [eventTypeLabel] and [dateRangeLine] are now BOTH optional,
/// and the production call site (`event_detail_screen.dart`) no longer
/// supplies either — that information moved to Event Essentials, directly
/// below the hero, so the hero can do one job well (image, title, "where")
/// rather than repeating facts the very next section already states.
/// [dateRangeLine] stays a supported parameter (not removed outright) so
/// this widget's own direct tests, and any future caller with a genuine
/// reason to show a date in the hero, are not forced into a wider redesign
/// of this primitive to do so.
class EventDetailHero extends StatelessWidget {
  final String title;
  final String? eventTypeLabel;
  final String cityCountryLine;
  final String? dateRangeLine;
  final Widget backgroundImage;
  final double expandedHeight;

  const EventDetailHero({
    super.key,
    required this.title,
    this.eventTypeLabel,
    required this.cityCountryLine,
    this.dateRangeLine,
    required this.backgroundImage,
    this.expandedHeight = 300,
  });

  @override
  Widget build(BuildContext context) {
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
      title: Text(
        title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: CsTypography.bodyMedium.copyWith(color: AppColors.textOnDark),
      ),
      flexibleSpace: FlexibleSpaceBar(
        collapseMode: CollapseMode.parallax,
        background: Stack(
          fit: StackFit.expand,
          children: [
            backgroundImage,
            // Bottom-weighted vignette so the title/metadata stay legible
            // over a real photo or the monogram placeholder alike.
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Color(0x8C16302A),
                    Color(0xE616302A),
                  ],
                  stops: [0.0, 0.55, 1.0],
                ),
              ),
            ),
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
                            color: AppColors.textOnDark.withValues(alpha: 0.75),
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: CsSpacing.xs),
                      ],
                      Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: CsTypography.displayHero.copyWith(
                          color: AppColors.textOnDark,
                          fontSize: 30,
                          height: 1.1,
                        ),
                      ),
                      const SizedBox(height: CsSpacing.sm),
                      Text(
                        cityCountryLine,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: CsTypography.bodyMedium.copyWith(
                          color: AppColors.textOnDark.withValues(alpha: 0.85),
                          fontSize: 14,
                        ),
                      ),
                      if (dateRangeLine != null) ...[
                        const SizedBox(height: CsSpacing.xs),
                        Text(
                          dateRangeLine!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: CsTypography.smallLabel.copyWith(
                            color: AppColors.textOnDark.withValues(alpha: 0.7),
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
