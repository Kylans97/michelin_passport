import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/theme/cs_spacing.dart';
import '../../core/theme/cs_typography.dart';
import '../../core/widgets/editorial_back_button.dart';
import 'friends_activity.dart';
import 'widgets/friend_activity_row.dart';

/// Every Friends' Activity item, newest first — "All activity →" from the
/// Community FRIENDS tab, which previews only the latest few. Takes the
/// already-loaded list rather than loading again.
class FriendsActivityScreen extends StatelessWidget {
  final List<FriendActivity> activity;
  final Map<String, String> countryNameByCode;

  const FriendsActivityScreen({
    super.key,
    required this.activity,
    this.countryNameByCode = const {},
  });

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.deepGreen,
    body: SafeArea(
      bottom: false,
      child: CustomScrollView(
        slivers: [
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: CsSpacing.base),
              child: Align(
                alignment: Alignment.centerLeft,
                child: EditorialBackButton(color: AppColors.ivory),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              CsSpacing.pageHorizontal,
              CsSpacing.xs,
              CsSpacing.pageHorizontal,
              CsSpacing.md,
            ),
            sliver: SliverToBoxAdapter(
              child: Text(
                "Friends' Activity",
                style: CsTypography.screenTitle.copyWith(
                  color: AppColors.ivory,
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: EdgeInsets.fromLTRB(
              CsSpacing.pageHorizontal,
              0,
              CsSpacing.pageHorizontal,
              CsSpacing.xxl + MediaQuery.paddingOf(context).bottom,
            ),
            sliver: SliverList.builder(
              itemCount: activity.length,
              itemBuilder: (context, i) => FriendActivityRow(
                activity: activity[i],
                countryNameByCode: countryNameByCode,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
