import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants/app_colors.dart';
import '../../core/theme/cs_spacing.dart';
import '../../core/theme/cs_typography.dart';
import 'widgets/personal_rankings_tab.dart';

/// My Ranking: purely personal (per-unique-restaurant aggregation — see
/// rankings_view_model.dart). Navigation & Information Architecture V2 UI
/// Refinement — this screen previously also hosted a "Community" tab
/// (community_rankings_tab.dart's CommunityRankingsTab); that content
/// moved to CommunityScreen (see community_screen.dart /
/// community_rankings_screen.dart), which is where any ranking based on
/// other users now belongs. This screen shows only the current user's own
/// visited/rated content.
class RankingsScreen extends StatelessWidget {
  const RankingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = Supabase.instance.client.auth.currentUser?.id ?? '';
    return Scaffold(
      backgroundColor: AppColors.background,
      body: NestedScrollView(
        headerSliverBuilder: (_, _) => [
          SliverAppBar(
            // Primary Tab Header Consistency Step 1: replaces the
            // Material title: slot (which always vertically CENTERS its
            // content within toolbarHeight, with no way to pin it to a
            // fixed offset the way the other four tabs' plain
            // SafeArea+Padding headers do) with a manually-positioned
            // flexibleSpace — the only way to make "Rankings" start at
            // the same SafeArea + CsSpacing.lg position as Wishlist.
            flexibleSpace: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  CsSpacing.pageHorizontal,
                  CsSpacing.lg,
                  CsSpacing.pageHorizontal,
                  0,
                ),
                child: Align(
                  alignment: Alignment.topLeft,
                  child: Text(
                    'Rankings',
                    style: CsTypography.screenTitle.copyWith(
                      color: AppColors.ivory,
                    ),
                  ),
                ),
              ),
            ),
            pinned: true,
            backgroundColor: AppColors.deepGreen,
            foregroundColor: AppColors.textOnDark,
            toolbarHeight: 64,
          ),
        ],
        body: PersonalRankingsTab(userId: uid),
      ),
    );
  }
}
