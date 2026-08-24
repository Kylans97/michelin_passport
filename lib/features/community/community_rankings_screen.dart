import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/theme/cs_spacing.dart';
import '../../core/theme/cs_typography.dart';
import '../../core/widgets/editorial_back_button.dart';
import '../rankings/widgets/community_rankings_tab.dart';

/// Navigation & Information Architecture V2 UI Refinement — Community
/// Rankings is now one subsection of Community's own landing page (see
/// community_screen.dart's "COMMUNITY RANKINGS" link), not the entire
/// Community destination. [CommunityRankingsTab] itself has zero changes
/// — reused verbatim (its own internal Expanded needs a bounded ancestor,
/// which a pushed Scaffold provides just as well as the old RankingsScreen
/// tab did) — only where it's hosted changed, again.
class CommunityRankingsScreen extends StatelessWidget {
  const CommunityRankingsScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.deepGreen,
    body: SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              CsSpacing.base,
              CsSpacing.sm,
              CsSpacing.base,
              0,
            ),
            child: Align(
              alignment: Alignment.centerLeft,
              child: EditorialBackButton(),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              CsSpacing.pageHorizontal,
              CsSpacing.sm,
              CsSpacing.pageHorizontal,
              0,
            ),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Community Rankings',
                style: CsTypography.screenTitle.copyWith(
                  color: AppColors.ivory,
                ),
              ),
            ),
          ),
          const Expanded(child: CommunityRankingsTab()),
        ],
      ),
    ),
  );
}
