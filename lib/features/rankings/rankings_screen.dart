import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants/app_colors.dart';
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
            title: const Text('Rankings'),
            pinned: true,
            backgroundColor: AppColors.background,
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(48),
              child: TabBar(
                controller: _tabCtrl,
                labelColor: AppColors.gold,
                unselectedLabelColor: AppColors.textSecondary,
                indicatorColor: AppColors.gold,
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
