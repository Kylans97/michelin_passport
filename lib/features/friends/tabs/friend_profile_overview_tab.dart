import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/cs_spacing.dart';
import '../../../core/theme/cs_typography.dart';
import '../../../models/passport_venue.dart';
import '../../map/visited_map_screen.dart';
import '../friend_profile_all_visits_screen.dart';
import '../friend_profile_data.dart';
import '../friend_profile_screen.dart' show openVisitDetail;
import '../widgets/friend_profile_verdict_row.dart';
import '../widgets/friend_profile_widgets.dart';

/// Tab 1 (default): the "in common, one line" bar, the way into the
/// friend's globe, then the friend's latest 3 verdicts.
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
    final recent = data.visits.take(friendVerdictPreviewCount).toList();

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
          const SizedBox(height: CsSpacing.sm),
        ],
        _MapBar(
          friendName: data.friendName,
          countries: data.stats.countries,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => VisitedMapScreen(
                userId: data.identity.id,
                ownerName: data.friendName,
              ),
            ),
          ),
        ),
        const SizedBox(height: CsSpacing.xl),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              "${data.friendName.toUpperCase()}'S VERDICTS",
              style: CsTypography.editorialLabel().copyWith(
                color: AppColors.secondaryOnDark,
              ),
            ),
            if (data.visits.length > friendVerdictPreviewCount)
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
  final List<PassportVenue> venues;
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
                          photoUrl: shown[i].cardImageUrl,
                          venueName: shown[i].name,
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

/// One quiet line into the friend's globe — the same [VisitedMapScreen]
/// the viewer's own Passport opens, pointed at the friend.
class _MapBar extends StatelessWidget {
  final String friendName;
  final int countries;
  final VoidCallback onTap;

  const _MapBar({
    required this.friendName,
    required this.countries,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: "Open $friendName's map",
    child: Material(
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
          child: ExcludeSemantics(
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.hairlineOnGreen),
                  ),
                  alignment: Alignment.center,
                  child: const Icon(
                    Icons.public_rounded,
                    color: AppColors.textOnDark,
                    size: 18,
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
                        if (countries > 0) ...[
                          TextSpan(
                            text:
                                '$countries ${countries == 1 ? 'country' : 'countries'} ',
                            style: const TextStyle(color: AppColors.textOnDark),
                          ),
                          TextSpan(text: "on $friendName's globe"),
                        ] else
                          TextSpan(text: "$friendName's globe"),
                      ],
                    ),
                    maxLines: 2,
                  ),
                ),
                const SizedBox(width: CsSpacing.sm),
                Text(
                  'Map →',
                  style: CsTypography.editorialLabel().copyWith(
                    color: AppColors.textOnDark,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
