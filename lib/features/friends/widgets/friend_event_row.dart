import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/cs_spacing.dart';
import '../../../core/theme/cs_typography.dart';
import '../../../core/widgets/venue_thumbnail.dart';
import '../../../models/event.dart';
import '../../events/event_date_format.dart';

/// One upcoming event on Friend Profile's deep-green canvas: photo, a
/// small-caps [eyebrow] ("GOING", "INTERESTED"), the name, the date in the
/// event's own timezone (date-only events stay date-only, via
/// [formatEventDateRange]) with the city, and the viewer's own intent as
/// one quiet line when there is one. Tapping opens the canonical
/// EventDetailScreen, where the viewer can mark Going or Interested.
class FriendEventRow extends StatelessWidget {
  final Event event;
  final String eyebrow;
  final String? ownLine;
  final VoidCallback onTap;

  const FriendEventRow({
    super.key,
    required this.event,
    required this.eyebrow,
    required this.ownLine,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final date = formatEventDateRange(event);
    final city = event.city?.trim();
    final meta = city == null || city.isEmpty ? date : '$date · $city';

    return Semantics(
      button: true,
      label: [eyebrow, event.name, meta, ?ownLine].join(', '),
      excludeSemantics: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(height: 1, color: AppColors.hairlineOnGreen),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: CsSpacing.sm),
                child: Row(
                  children: [
                    VenueThumbnail(imageUrl: event.imageUrl, size: 64),
                    const SizedBox(width: CsSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            eyebrow.toUpperCase(),
                            style: CsTypography.editorialLabel().copyWith(
                              color: AppColors.secondaryOnDark,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            event.name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: CsTypography.editorialTitle(
                              size: 17,
                            ).copyWith(color: AppColors.textOnDark),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            meta,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: CsTypography.editorialBody.copyWith(
                              color: AppColors.secondaryOnDark,
                              fontSize: 12.5,
                            ),
                          ),
                          if (ownLine != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              ownLine!.toUpperCase(),
                              style: CsTypography.editorialLabel().copyWith(
                                color: AppColors.ivory,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
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

/// A section heading on Friend Profile: small caps, with an optional
/// action on the right ("All 4 →").
class FriendSectionLabel extends StatelessWidget {
  final String text;
  final String? actionLabel;
  final VoidCallback? onAction;

  const FriendSectionLabel(
    this.text, {
    super.key,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Flexible(
        child: Text(
          text.toUpperCase(),
          style: CsTypography.editorialLabel().copyWith(
            color: AppColors.secondaryOnDark,
          ),
        ),
      ),
      if (actionLabel != null && onAction != null)
        InkWell(
          onTap: onAction,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              actionLabel!,
              style: CsTypography.editorialLabel().copyWith(
                color: AppColors.textOnDark,
              ),
            ),
          ),
        ),
    ],
  );
}
