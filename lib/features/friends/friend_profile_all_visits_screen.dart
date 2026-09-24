import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/theme/cs_spacing.dart';
import '../../core/theme/cs_typography.dart';
import '../../core/widgets/editorial_back_button.dart';
import 'friend_profile_screen.dart' show FriendVenueVisit;
import 'widgets/friend_profile_verdict_row.dart';

/// "All →" from the Overview tab's "{NAME}'S VERDICTS" preview — the same
/// [FriendVerdictRow] widget, just every visit instead of the latest 3, so
/// the preview and the full list can never visually drift apart.
class FriendProfileAllVisitsScreen extends StatelessWidget {
  final String friendName;
  final List<FriendVenueVisit> visits;
  final Map<String, String> coverPhotoByVisitId;
  final void Function(BuildContext context, FriendVenueVisit visit) onTapVisit;

  const FriendProfileAllVisitsScreen({
    super.key,
    required this.friendName,
    required this.visits,
    required this.coverPhotoByVisitId,
    required this.onTapVisit,
  });

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.deepGreen,
    body: SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              CsSpacing.base,
              CsSpacing.sm,
              CsSpacing.base,
              0,
            ),
            child: EditorialBackButton(color: AppColors.ivory),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              CsSpacing.pageHorizontal,
              CsSpacing.md,
              CsSpacing.pageHorizontal,
              0,
            ),
            child: Text(
              "${friendName.toUpperCase()}'S VERDICTS",
              style: CsTypography.editorialLabel().copyWith(
                color: AppColors.secondaryOnDark,
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(
                horizontal: CsSpacing.pageHorizontal,
              ).copyWith(bottom: CsSpacing.xxl),
              itemCount: visits.length,
              itemBuilder: (context, i) => FriendVerdictRow(
                visit: visits[i],
                photoUrl: coverPhotoByVisitId[visits[i].visit.id],
                onTap: () => onTapVisit(context, visits[i]),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
