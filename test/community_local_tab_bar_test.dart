// COMMUNITY TAB SPACING refinement: CommunityLocalTabBar previously used
// mainAxisAlignment.spaceBetween with Flexible tabs, which pushed FRIENDS
// toward the far right edge of a wide screen — reading as two separate
// navigation destinations rather than two closely related views. This
// covers the compact, left-aligned replacement: both labels sit at the
// same left content margin as the page, with a small fixed gap between
// them (never stretched across most of the available row), and the
// active indicator tracks its own label's width rather than a wide,
// evenly split column.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:michelin_passport/core/theme/cs_spacing.dart';
import 'package:michelin_passport/features/community/widgets/community_local_tab_bar.dart';

Widget _wrap(CommunityTopTab selected, {double width = 390}) => MaterialApp(
  home: MediaQuery(
    data: MediaQueryData(size: Size(width, 844)),
    child: Scaffold(
      body: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: CsSpacing.pageHorizontal,
        ),
        child: CommunityLocalTabBar(selected: selected, onSelect: (_) {}),
      ),
    ),
  ),
);

void main() {
  group('CommunityLocalTabBar — compact, left-aligned layout', () {
    testWidgets('COMMUNITY starts at the page content margin, and FRIENDS '
        'sits a small fixed gap after it — never spaceBetween-style '
        'distribution across the row', (tester) async {
      const width = 390.0;
      await tester.pumpWidget(_wrap(CommunityTopTab.community, width: width));
      await tester.pump();

      final communityRect = tester.getRect(find.text('COMMUNITY'));
      final friendsRect = tester.getRect(find.text('FRIENDS'));

      // Left-aligned: COMMUNITY starts at the page's own left content
      // margin, same as the header/content below it — not centered, not
      // indented further.
      expect(communityRect.left, CsSpacing.pageHorizontal);

      // A small, fixed gap (CsSpacing.xl) — this is a SizedBox, so it's
      // exact regardless of font metrics.
      final gap = friendsRect.left - communityRect.right;
      expect(gap, closeTo(CsSpacing.xl, 0.5));

      // The whole tab group is well clear of the available content
      // width's right edge — the old spaceBetween layout pushed FRIENDS'
      // right edge to within a few points of it.
      final availableWidth = width - 2 * CsSpacing.pageHorizontal;
      expect(friendsRect.right, lessThan(availableWidth * 0.75));
    });

    testWidgets('the same compact, fixed gap holds at a much wider width '
        'too — the tab group never stretches to fill the available row', (
      tester,
    ) async {
      const width = 800.0;
      await tester.pumpWidget(_wrap(CommunityTopTab.community, width: width));
      await tester.pump();

      final communityRect = tester.getRect(find.text('COMMUNITY'));
      final friendsRect = tester.getRect(find.text('FRIENDS'));
      final gap = friendsRect.left - communityRect.right;
      expect(gap, closeTo(CsSpacing.xl, 0.5));

      // At 800pt wide, a spaceBetween layout would put FRIENDS' right
      // edge near 780 — the compact layout keeps it far short of that,
      // near the left-aligned content column instead.
      expect(friendsRect.right, lessThan(width * 0.4));
    });
  });

  group('CommunityLocalTabBar — active indicator', () {
    testWidgets('the tab group as a whole is compact — COMMUNITY-to-'
        'FRIENDS span is a fraction of the screen, not stretched full '
        'width', (tester) async {
      await tester.pumpWidget(_wrap(CommunityTopTab.community));
      await tester.pump();

      final communityRect = tester.getRect(find.text('COMMUNITY'));
      final friendsRect = tester.getRect(find.text('FRIENDS'));

      expect(friendsRect.right - communityRect.left, lessThan(280));
    });

    testWidgets('switching the selected tab keeps the same compact, '
        'left-aligned gap (only which label is bold/ivory changes)', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap(CommunityTopTab.friends));
      await tester.pump();

      final communityRect = tester.getRect(find.text('COMMUNITY'));
      final friendsRect = tester.getRect(find.text('FRIENDS'));
      expect(communityRect.left, CsSpacing.pageHorizontal);
      final gap = friendsRect.left - communityRect.right;
      expect(gap, closeTo(CsSpacing.xl, 0.5));
    });
  });
}
