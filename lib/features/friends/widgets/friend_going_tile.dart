import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/cs_spacing.dart';
import '../../../core/theme/cs_typography.dart';
import '../../../models/event.dart';
import '../../events/event_date_format.dart';

/// One upcoming event a friend is going to (Social Foundation Step 2B
/// §13-14). Same visual language as FriendVisitTile/FriendWishlistTile —
/// dark editorial system, whole-row tap, trailing chevron. [onTap] opens
/// the canonical, unmodified EventDetailScreen — never a social wrapper,
/// mirroring the venue-navigation rule exactly.
class FriendGoingTile extends StatelessWidget {
  final Event event;
  final VoidCallback onTap;

  const FriendGoingTile({super.key, required this.event, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final location = [
      if (event.venueName != null && event.venueName!.isNotEmpty)
        event.venueName,
      if (event.city != null && event.city!.isNotEmpty) event.city,
    ].where((s) => s != null && s.isNotEmpty).join(', ');

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(CsRadius.medium),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(CsSpacing.base),
          decoration: BoxDecoration(
            color: AppColors.brandGreenLight,
            borderRadius: BorderRadius.circular(CsRadius.medium),
            border: Border.all(color: AppColors.subtleBorderDark),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      event.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: CsTypography.bodyMedium.copyWith(
                        color: AppColors.textOnDark,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      location.isEmpty
                          ? formatEventDateRange(event)
                          : '${formatEventDateRange(event)} · $location',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: CsTypography.metadata.copyWith(
                        color: AppColors.secondaryOnDark,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: CsSpacing.sm),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.secondaryOnDark,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
