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
/// that's a [StarRow]/[KeyRow], but nothing here assumes that; a future
/// numeric "#12" ranking slot (World's 50 Best, Step 2C) drops in the same
/// way with no change to this widget.
class GuideVenueCard extends StatelessWidget {
  final String title;
  final String locationLabel;
  final Widget distinction;
  final VoidCallback onTap;

  const GuideVenueCard({
    super.key,
    required this.title,
    required this.locationLabel,
    required this.distinction,
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
        splashColor: AppColors.textOnDark.withValues(alpha: 0.06),
        highlightColor: AppColors.textOnDark.withValues(alpha: 0.04),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: CsSpacing.sm),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
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
                        color: AppColors.textOnDark,
                      ),
                    ),
                    if (locationLabel.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        locationLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: CsTypography.metadata.copyWith(
                          color: AppColors.secondaryOnDark,
                        ),
                      ),
                    ],
                    const SizedBox(height: 4),
                    distinction,
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

/// A 0.5px hairline between [GuideVenueCard] rows — the same treatment
/// [GuideFamilySection] already uses under each family title, reused here
/// so a long results list reads as one continuous editorial index rather
/// than a stack of separate cards.
class GuideVenueCardDivider extends StatelessWidget {
  const GuideVenueCardDivider({super.key});

  @override
  Widget build(BuildContext context) =>
      Container(height: 0.5, color: AppColors.subtleBorderDark);
}
