import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/cs_spacing.dart';
import '../../../core/theme/cs_typography.dart';
import '../../../core/widgets/cs_image_placeholder.dart';

/// One result in a Guide catalogue's browsing list — deliberately not
/// [RestaurantTile]/[HotelTile] (Explore's ivory boxed cards): those would
/// make a Guides catalogue look like old Explore rather than earning its
/// own identity (see the Guides Step 2B brief). Reads instead as a compact
/// editorial index row, the same visual family as [GuideDestinationRow] on
/// the Guides landing page — a small monogram thumbnail, name, location,
/// and a [distinction] slot — separated by hairlines rather than boxed
/// cards, so a long list of many venues stays quiet and scannable.
///
/// Presentation-only: knows nothing about Restaurant, Hotel, stars, Keys or
/// World's 50 Best. [distinction] is any widget the caller builds — today
/// that's a [StarRow]/[KeyRow] for Michelin, omitted (null) for World's 50
/// Best (Step 2C), which has nothing to put there yet (cross-recognition
/// is deferred) — but nothing here assumes any particular content.
///
/// [leading] (Step 2C addition) is an optional widget rendered before the
/// monogram thumbnail — World's 50 Best passes a [GuideRankMark] there, so
/// the rank reads as the row's hero (leftmost, first thing seen) while the
/// thumbnail stays in place for future photography. Both additions default
/// to null/unused, so Michelin's existing calls (which pass neither)
/// render byte-identical to before Step 2C — this widget's own visual
/// contract for Michelin is unchanged.
class GuideVenueCard extends StatelessWidget {
  final String title;
  final String locationLabel;
  final Widget? leading;
  final Widget? distinction;
  final VoidCallback onTap;

  const GuideVenueCard({
    super.key,
    required this.title,
    required this.locationLabel,
    this.leading,
    this.distinction,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: locationLabel.isEmpty ? title : '$title. $locationLabel',
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
              if (leading != null) ...[
                leading!,
                const SizedBox(width: CsSpacing.sm),
              ],
              const CsImagePlaceholder(
                width: 52,
                height: 52,
                borderRadius: BorderRadius.all(Radius.circular(10)),
                logoScale: 0.42,
              ),
              const SizedBox(width: CsSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: CsTypography.placeTitle.copyWith(
                        fontSize: 17,
                        color: AppColors.forestGreen,
                      ),
                    ),
                    if (locationLabel.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        locationLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: CsTypography.metadata.copyWith(
                          color: AppColors.taupe,
                        ),
                      ),
                    ],
                    if (distinction != null) ...[
                      const SizedBox(height: 4),
                      distinction!,
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
