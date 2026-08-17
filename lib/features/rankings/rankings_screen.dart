import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants/app_colors.dart';
import '../../core/theme/cs_spacing.dart';
import '../../core/theme/cs_typography.dart';
import 'widgets/community_rankings_tab.dart';
import 'widgets/personal_rankings_tab.dart';

/// Rankings: "My Rankings" (personal, per-unique-restaurant aggregation —
/// see rankings_view_model.dart) and "Community" (unrelated, its own data
/// source) as two independent tabs.
class RankingsScreen extends StatefulWidget {
  const RankingsScreen({super.key});

  @override
  State<RankingsScreen> createState() => _RankingsScreenState();
}

class _RankingsScreenState extends State<RankingsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabCtrl;
  final String _uid = Supabase.instance.client.auth.currentUser?.id ?? '';

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
            // the same SafeArea + CsSpacing.lg position as Wishlist while
            // keeping this screen's TabBar/NestedScrollView architecture
            // (pinned AppBar, tab controller, tab content) completely
            // unchanged. toolbarHeight (64) is unchanged from before —
            // it already fits CsSpacing.lg + one CsTypography.screenTitle
            // line + a little breathing room above the TabBar.
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
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(48),
              child: TabBar(
                controller: _tabCtrl,
                labelColor: AppColors.textOnDark,
                unselectedLabelColor: AppColors.textOnDark.withValues(
                  alpha: 0.55,
                ),
                indicatorColor: AppColors.textOnDark,
                indicatorSize: TabBarIndicatorSize.label,
                labelStyle: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
                unselectedLabelStyle: GoogleFonts.inter(fontSize: 13),
                tabs: const [
                  Tab(text: 'My Rankings'),
                  Tab(text: 'Community'),
                ],
              ),
            ),
          ),
        ],
        body: TabBarView(
          controller: _tabCtrl,
          children: [
            PersonalRankingsTab(userId: _uid),
            const CommunityRankingsTab(),
          ],
        ),
      ),
    );
  }
}
