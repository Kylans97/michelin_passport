// Covers Primary Tab Header Consistency Step 1 — the five bottom-
// navigation tab titles (Passport, Explore, Rankings, Wishlist, Profile)
// now share the same Title Case labels, the same CsTypography.screenTitle
// role, the same ivory-on-deepGreen color, and — the actual physical-
// device complaint — the same rendered vertical starting position,
// derived from Wishlist as the reference.
//
// All five tab screens construct repositories against
// Supabase.instance.client eagerly in initState, so none can be pumped
// directly (same established limitation as every other Supabase-eager
// screen in this app). This mirrors each screen's exact header widget
// tree — Passport/Explore/Wishlist/Profile's plain SafeArea+Padding
// headers, and Rankings' SliverAppBar+flexibleSpace — under an identical
// MediaQuery (fixed screen size, fixed status-bar inset) so their
// rendered title positions are directly, meaningfully comparable.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:michelin_passport/core/constants/app_colors.dart';
import 'package:michelin_passport/core/theme/cs_spacing.dart';
import 'package:michelin_passport/core/theme/cs_typography.dart';

// A realistic iPhone status-bar inset — fixed across every mirror below
// so a direct Y-position comparison between screens is meaningful.
const _statusBarInset = 47.0;

Widget _wrap(Widget child, {double width = 390, double textScale = 1.0}) =>
    MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(
          size: Size(width, 844),
          padding: const EdgeInsets.only(top: _statusBarInset),
          textScaler: TextScaler.linear(textScale),
        ),
        child: child,
      ),
    );

// Mirrors WishlistScreen's header exactly (wishlist_screen.dart) — the
// physical-device reference position: SafeArea + CsSpacing.lg before the
// title, CsSpacing.pageHorizontal as the only horizontal inset.
Widget _wishlistHeader() => ColoredBox(
  color: AppColors.deepGreen,
  child: SafeArea(
    bottom: false,
    child: Padding(
      padding: const EdgeInsets.fromLTRB(
        CsSpacing.pageHorizontal,
        CsSpacing.lg,
        CsSpacing.pageHorizontal,
        CsSpacing.lg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Wishlist',
            style: CsTypography.screenTitle.copyWith(color: AppColors.ivory),
          ),
          const SizedBox(height: CsSpacing.xs),
          Text(
            "Places you're saving for later.",
            style: CsTypography.body.copyWith(color: AppColors.secondaryOnDark),
          ),
        ],
      ),
    ),
  ),
);

// Mirrors _ExploreHeader (explore_screen.dart).
Widget _exploreHeader() => ColoredBox(
  color: AppColors.deepGreen,
  child: SafeArea(
    bottom: false,
    child: Padding(
      padding: const EdgeInsets.fromLTRB(
        CsSpacing.pageHorizontal,
        CsSpacing.lg,
        CsSpacing.pageHorizontal,
        CsSpacing.lg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Explore',
            style: CsTypography.screenTitle.copyWith(color: AppColors.ivory),
          ),
          const SizedBox(height: CsSpacing.xs),
          Text(
            'Places worth travelling for.',
            style: CsTypography.body.copyWith(color: AppColors.secondaryOnDark),
          ),
        ],
      ),
    ),
  ),
);

// Mirrors _PassportHeader (passport_screen.dart) — title/subtitle Column
// and the map IconButton share one Row so the icon never pushes the
// title down.
Widget _passportHeader() => ColoredBox(
  color: AppColors.deepGreen,
  child: SafeArea(
    bottom: false,
    child: Padding(
      padding: const EdgeInsets.fromLTRB(
        CsSpacing.pageHorizontal,
        CsSpacing.lg,
        CsSpacing.pageHorizontal,
        CsSpacing.section,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Passport',
                  style: CsTypography.screenTitle.copyWith(
                    color: AppColors.ivory,
                  ),
                ),
                const SizedBox(height: CsSpacing.xs),
                Text(
                  'Your collection of remarkable places.',
                  style: CsTypography.body.copyWith(
                    color: AppColors.secondaryOnDark,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.map_outlined, color: AppColors.textOnDark),
            tooltip: 'My Map',
            onPressed: () {},
          ),
        ],
      ),
    ),
  ),
);

// Mirrors ProfileScreen's header Row (profile_screen.dart) inside its own
// ListView.
Widget _profileHeader() => ColoredBox(
  color: AppColors.deepGreen,
  child: SafeArea(
    child: ListView(
      padding: const EdgeInsets.fromLTRB(
        CsSpacing.pageHorizontal,
        CsSpacing.lg,
        CsSpacing.pageHorizontal,
        CsSpacing.section,
      ),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Profile',
              style: CsTypography.screenTitle.copyWith(color: AppColors.ivory),
            ),
            const Icon(
              Icons.notifications_outlined,
              color: AppColors.secondaryOnDark,
            ),
          ],
        ),
      ],
    ),
  ),
);

// Mirrors RankingsScreen's SliverAppBar (rankings_screen.dart) —
// flexibleSpace positions the title manually (Material's title: slot
// always vertically centers within toolbarHeight, which cannot be made
// to match the other four screens' fixed-offset headers). Navigation &
// Information Architecture V2 UI Refinement: RankingsScreen is no longer
// a TabBar/TabController screen — its former "Community" tab moved to
// CommunityScreen, so this mirror no longer wraps a
// DefaultTabController/TabBar either.
Widget _rankingsHeader() => Scaffold(
  backgroundColor: AppColors.background,
  body: NestedScrollView(
    headerSliverBuilder: (_, _) => [
      SliverAppBar(
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
    body: const SizedBox.shrink(),
  ),
);

const _headers = {
  'Passport': _passportHeader,
  'Explore': _exploreHeader,
  'Rankings': _rankingsHeader,
  'Wishlist': _wishlistHeader,
  'Profile': _profileHeader,
};

const _oldUppercaseLabels = ['PASSPORT', 'EXPLORE', 'WISHLIST'];

void main() {
  group('Primary tab headers — Title Case', () {
    for (final entry in _headers.entries) {
      testWidgets('${entry.key}: exact Title Case label renders', (
        tester,
      ) async {
        await tester.pumpWidget(_wrap(entry.value()));
        await tester.pump();
        expect(find.text(entry.key), findsOneWidget);
      });
    }

    testWidgets('none of the five headers render the old uppercase labels', (
      tester,
    ) async {
      for (final header in _headers.values) {
        await tester.pumpWidget(_wrap(header()));
        await tester.pump();
        for (final old in _oldUppercaseLabels) {
          expect(find.text(old), findsNothing);
        }
      }
    });

    testWidgets('Rankings label is unchanged — "Rankings", never touched', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap(_rankingsHeader()));
      await tester.pump();
      expect(find.text('Rankings'), findsOneWidget);
    });
  });

  group('Primary tab headers — typography consistency', () {
    testWidgets('all five titles share the same CsTypography.screenTitle '
        'font size, weight, and family', (tester) async {
      for (final entry in _headers.entries) {
        await tester.pumpWidget(_wrap(entry.value()));
        await tester.pump();
        final text = tester.widget<Text>(find.text(entry.key));
        expect(
          text.style?.fontSize,
          CsTypography.screenTitle.fontSize,
          reason: '${entry.key} font size',
        );
        expect(
          text.style?.fontWeight,
          CsTypography.screenTitle.fontWeight,
          reason: '${entry.key} font weight',
        );
        expect(
          text.style?.fontFamily,
          CsTypography.screenTitle.fontFamily,
          reason: '${entry.key} font family',
        );
      }
    });

    testWidgets('all five titles are ivory — never gold, never the raw '
        'textOnDark token', (tester) async {
      for (final entry in _headers.entries) {
        await tester.pumpWidget(_wrap(entry.value()));
        await tester.pump();
        final text = tester.widget<Text>(find.text(entry.key));
        expect(text.style?.color, AppColors.ivory, reason: entry.key);
        expect(text.style?.color, isNot(AppColors.gold), reason: entry.key);
      }
    });
  });

  group('Primary tab headers — rendered vertical position (Wishlist is '
      'the physical-device reference)', () {
    testWidgets('all five titles start within 1px of Wishlist\'s Y '
        'position', (tester) async {
      final positions = <String, double>{};
      for (final entry in _headers.entries) {
        await tester.pumpWidget(_wrap(entry.value()));
        await tester.pump();
        positions[entry.key] = tester.getTopLeft(find.text(entry.key)).dy;
      }
      final reference = positions['Wishlist']!;
      for (final entry in positions.entries) {
        expect(
          entry.value,
          closeTo(reference, 1.0),
          reason:
              '${entry.key} title Y=${entry.value}, Wishlist reference '
              'Y=$reference',
        );
      }
    });
  });

  group('Primary tab headers — horizontal alignment', () {
    testWidgets('all five titles share the same left edge '
        '(CsSpacing.pageHorizontal)', (tester) async {
      final positions = <String, double>{};
      for (final entry in _headers.entries) {
        await tester.pumpWidget(_wrap(entry.value()));
        await tester.pump();
        positions[entry.key] = tester.getTopLeft(find.text(entry.key)).dx;
      }
      for (final entry in positions.entries) {
        expect(
          entry.value,
          closeTo(CsSpacing.pageHorizontal, 0.5),
          reason: '${entry.key} title X=${entry.value}',
        );
      }
    });
  });

  group('Primary tab headers — responsive', () {
    for (final entry in _headers.entries) {
      testWidgets('${entry.key}: 320px — no overflow', (tester) async {
        await tester.pumpWidget(_wrap(entry.value(), width: 320));
        await tester.pump();
        expect(tester.takeException(), isNull);
      });

      testWidgets('${entry.key}: 390px — no overflow', (tester) async {
        await tester.pumpWidget(_wrap(entry.value(), width: 390));
        await tester.pump();
        expect(tester.takeException(), isNull);
      });

      testWidgets('${entry.key}: 1.6x text scale — no overflow', (
        tester,
      ) async {
        await tester.pumpWidget(
          _wrap(entry.value(), width: 320, textScale: 1.6),
        );
        await tester.pump();
        expect(tester.takeException(), isNull);
      });
    }
  });
}
