import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/cs_spacing.dart';
import '../../../core/theme/cs_typography.dart';
import '../friend_profile_all_visits_screen.dart';
import '../friend_profile_data.dart';
import '../friend_profile_screen.dart' show openVisitDetail;
import '../widgets/friend_profile_verdict_row.dart';
import '../widgets/friend_profile_widgets.dart';

/// Tab 1 (default): the "in common, one line" bar, then the friend's
/// latest 3 verdicts.
class FriendProfileOverviewTab extends StatelessWidget {
  final FriendProfileLayoutData data;
  final VoidCallback onPlanTapped;

  const FriendProfileOverviewTab({
    super.key,
    required this.data,
    required this.onPlanTapped,
  });

  @override
  Widget build(BuildContext context) {
    final shared = data.sharedWishlistVenues;
    final recent = data.visits.take(3).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        CsSpacing.pageHorizontal,
        CsSpacing.lg,
        CsSpacing.pageHorizontal,
        CsSpacing.xxl,
      ),
      children: [
        if (shared.isNotEmpty) ...[
          _CommonBar(count: shared.length, venues: shared, onTap: onPlanTapped),
          const SizedBox(height: CsSpacing.xl),
        ],
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              "${data.friendName.toUpperCase()}'S VERDICTS",
              style: CsTypography.editorialLabel().copyWith(
                color: AppColors.secondaryOnDark,
              ),
            ),
            if (data.visits.length > 3)
              GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => FriendProfileAllVisitsScreen(
                      friendName: data.friendName,
                      visits: data.visits,
                      coverPhotoByVisitId: data.coverPhotoByVisitId,
                      onTapVisit: (context, fv) => openVisitDetail(context, fv),
                    ),
                  ),
                ),
                child: Text(
                  'All ${data.visits.length} →',
                  style: CsTypography.editorialLabel().copyWith(
                    color: AppColors.textOnDark,
                  ),
                ),
              ),
          ],
        ),
        if (recent.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: CsSpacing.lg),
            child: Text(
              "${data.friendName} hasn't stamped anything yet.",
              style: CsTypography.editorialLead().copyWith(
                color: AppColors.secondaryOnDark,
              ),
            ),
          )
        else
          for (final fv in recent)
            FriendVerdictRow(
              visit: fv,
              photoUrl: data.coverPhotoByVisitId[fv.visit.id],
              onTap: () => openVisitDetail(context, fv),
            ),
      ],
    );
  }
}

class _CommonBar extends StatelessWidget {
  final int count;
  final List<dynamic> venues;
  final VoidCallback onTap;

  const _CommonBar({required this.count, required this.venues, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final shown = venues.take(2).toList();
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(2),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.greenSurface,
            borderRadius: BorderRadius.circular(2),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 34 + (shown.length - 1).clamp(0, 1) * 24,
                height: 34,
                child: Stack(
                  children: [
                    for (var i = 0; i < shown.length; i++)
                      Positioned(
                        left: i * 24.0,
                        child: RoundVenueThumbnail(
                          photoUrl: null,
                          venueName: shown[i].name as String,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: CsSpacing.sm),
              Expanded(
                child: Text.rich(
                  TextSpan(
                    style: CsTypography.editorialBody.copyWith(
                      color: AppColors.secondaryOnDark,
                      fontSize: 13,
                    ),
                    children: [
                      TextSpan(
                        text: '$count place${count == 1 ? '' : 's'} ',
                        style: const TextStyle(color: AppColors.textOnDark),
                      ),
                      const TextSpan(text: 'on both your wishlists'),
                    ],
                  ),
                  maxLines: 2,
                ),
              ),
              const SizedBox(width: CsSpacing.sm),
              Text(
                'Plan →',
                style: CsTypography.editorialLabel().copyWith(color: AppColors.textOnDark),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
