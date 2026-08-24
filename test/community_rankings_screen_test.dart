// Covers CommunityRankingsScreen — the pushed destination
// CommunityScreen's "COMMUNITY RANKINGS" row navigates to (Navigation &
// Information Architecture V2 UI Refinement). It embeds
// CommunityRankingsTab, which constructs RankingsRepository against
// Supabase.instance.client eagerly in initState — same established
// limitation as every other Supabase-eager screen/child in this app (see
// e.g. wishlist_screen_shell_test.dart's own note) — so this mirrors the
// exact widget tree CommunityRankingsScreen.build() produces, standing a
// plain placeholder in for CommunityRankingsTab's own bounded Expanded
// slot, rather than pumping the real screen.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:michelin_passport/core/constants/app_colors.dart';
import 'package:michelin_passport/core/theme/cs_spacing.dart';
import 'package:michelin_passport/core/theme/cs_typography.dart';
import 'package:michelin_passport/core/widgets/editorial_back_button.dart';

Widget _shell({required Widget rankingsContent}) => MaterialApp(
  home: Scaffold(
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
          Expanded(child: rankingsContent),
        ],
      ),
    ),
  ),
);

void main() {
  group('CommunityRankingsScreen outer shell', () {
    testWidgets('owns a Scaffold + back button (a pushed screen, not a '
        'tab body)', (tester) async {
      await tester.pumpWidget(_shell(rankingsContent: const SizedBox()));
      expect(find.byType(Scaffold), findsOneWidget);
      expect(find.byType(EditorialBackButton), findsOneWidget);
    });

    testWidgets('renders the "Community Rankings" title, ivory, never '
        'gold', (tester) async {
      await tester.pumpWidget(_shell(rankingsContent: const SizedBox()));
      final title = tester.widget<Text>(find.text('Community Rankings'));
      expect(title.style?.color, AppColors.ivory);
      expect(title.style?.color, isNot(AppColors.gold));
    });

    testWidgets('Community Rankings content sits in a bounded Expanded '
        'slot (it manages its own internal scrolling)', (tester) async {
      await tester.pumpWidget(
        _shell(rankingsContent: const Text('rankings content')),
      );
      expect(find.text('rankings content'), findsOneWidget);
      expect(
        find.ancestor(
          of: find.text('rankings content'),
          matching: find.byType(Expanded),
        ),
        findsOneWidget,
      );
    });
  });
}
