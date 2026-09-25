// Covers FloatingNavBar (lib/core/widgets/floating_nav_bar.dart) — the
// floating-pill redesign that replaced app.dart's previous docked, full-
// width Material NavigationBar (Bottom Navigation UI Consistency Step 1/
// 1A/1B + Green Token Consistency Migration, all superseded by this pass).
// Navigation & Information Architecture V2's five destinations (Explore,
// Passport, News, Community, Profile) are unchanged — only the chrome
// around them changed shape.
//
// This file pumps the real, public FloatingNavBar directly rather than a
// hand-mirrored copy of app.dart's construction, so drift between this
// suite and the shipped widget isn't possible the way it was when the old
// suite had to redeclare the NavigationBar construction by hand.
//
// app.dart's own five tab screens are Supabase-eager and can't be pumped
// directly (same established limitation as every other Supabase-eager
// screen in this app) — irrelevant here since FloatingNavBar itself has no
// such dependency.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:michelin_passport/core/constants/app_colors.dart';
import 'package:michelin_passport/core/theme/cs_spacing.dart';
import 'package:michelin_passport/core/theme/cs_theme.dart';
import 'package:michelin_passport/core/widgets/floating_nav_bar.dart';

const _labels = ['Explore', 'Passport', 'News', 'Community', 'Profile'];
const _destinations = [
  FloatingNavDestination(
    icon: Icons.explore_outlined,
    selectedIcon: Icons.explore_rounded,
    label: 'Explore',
  ),
  FloatingNavDestination(
    icon: Icons.menu_book_outlined,
    selectedIcon: Icons.menu_book_rounded,
    label: 'Passport',
  ),
  FloatingNavDestination(
    icon: Icons.article_outlined,
    selectedIcon: Icons.article_rounded,
    label: 'News',
  ),
  FloatingNavDestination(
    icon: Icons.groups_outlined,
    selectedIcon: Icons.groups_rounded,
    label: 'Community',
  ),
  FloatingNavDestination(
    icon: Icons.person_outline_rounded,
    selectedIcon: Icons.person_rounded,
    label: 'Profile',
  ),
];

// setSurfaceSize actually resizes the test's render viewport — the
// established convention in this repo (see community_screen_shell_test.dart)
// for width-dependent assertions. A plain MediaQuery override around the
// content only changes what descendants read via MediaQuery.of(context); it
// does not change the actual layout viewport, so a Row/SizedBox with no
// intrinsic width still lays out against flutter_test's own default surface
// size regardless of that override — confirmed the hard way (a "390px"
// test whose pill rect came back at x=784, the unrelated default surface
// width, not 390) while first writing this suite.
Future<void> _pumpNavBar(
  WidgetTester tester,
  Widget navBar, {
  double width = 390,
  double bottomInset = 34,
  double textScale = 1.0,
  Widget body = const SizedBox.shrink(),
}) async {
  final size = Size(width, 844);
  await tester.binding.setSurfaceSize(size);
  await tester.pumpWidget(
    MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(
          size: size,
          padding: EdgeInsets.only(bottom: bottomInset),
          textScaler: TextScaler.linear(textScale),
        ),
        child: Scaffold(
          body: Stack(
            children: [body, Align(alignment: Alignment.bottomCenter, child: navBar)],
          ),
        ),
      ),
    ),
  );
  addTearDown(() => tester.binding.setSurfaceSize(null));
}

FloatingNavBar _bar({required int selectedIndex, required ValueChanged<int> onSelect}) =>
    FloatingNavBar(
      selectedIndex: selectedIndex,
      onDestinationSelected: onSelect,
      destinations: _destinations,
    );

// The pill's own visual DecoratedBox (background/shape/border/shadow) —
// distinct from FloatingNavBar's outer Padding, whose own render bounds
// span the full available width regardless of the pill's visual inset
// (Padding reports child-size-plus-insets as its own size; with an
// unconstrained-width child that resolves back to full width), so
// find.byType(FloatingNavBar).getRect() is the wrong thing to measure for
// "is the pill actually inset" assertions — this is.
Finder _pillDecoratedBox() => find.byWidgetPredicate(
  (w) =>
      w is DecoratedBox &&
      w.decoration is BoxDecoration &&
      (w.decoration as BoxDecoration).color == AppColors.forestGreen,
);

void main() {
  group('FloatingNavBar — information architecture freeze', () {
    testWidgets('exactly 5 tappable destinations, correct icons in order', (
      tester,
    ) async {
      await _pumpNavBar(tester, _bar(selectedIndex: 0, onSelect: (_) {}));
      expect(find.byType(InkWell), findsNWidgets(5));
      const expectedIcons = [
        Icons.explore_rounded, // selected (index 0)
        Icons.menu_book_outlined,
        Icons.article_outlined,
        Icons.groups_outlined,
        Icons.person_outline_rounded,
      ];
      for (final icon in expectedIcons) {
        expect(find.byIcon(icon), findsOneWidget);
      }
    });
  });

  group('FloatingNavBar — fully icon-only, no label anywhere', () {
    // An earlier version kept a label under the active tab's icon as a
    // middle ground — corrected away from explicitly once seen rendered
    // (Passport was the only destination still carrying text, which read
    // as inconsistent, not as deliberate emphasis). No destination shows
    // a Text label now, selected or not.
    testWidgets('no destination ever renders its label as visible text, '
        'regardless of which one is selected', (tester) async {
      for (final selectedIndex in [0, 1, 2, 3, 4]) {
        await _pumpNavBar(tester, _bar(selectedIndex: selectedIndex, onSelect: (_) {}));
        for (final label in _labels) {
          expect(find.text(label), findsNothing, reason: 'selectedIndex=$selectedIndex');
        }
      }
    });

    testWidgets('the accessibility label is still present even though '
        'nothing is painted on screen for it', (tester) async {
      final handle = tester.ensureSemantics();
      await _pumpNavBar(tester, _bar(selectedIndex: 1, onSelect: (_) {}));
      expect(find.text('Passport'), findsNothing);
      expect(
        tester.getSemantics(find.byIcon(Icons.menu_book_rounded)),
        matchesSemantics(
          label: 'Passport',
          isSelected: true,
          isButton: true,
          hasEnabledState: true,
          isEnabled: true,
          isFocusable: true,
          hasSelectedState: true,
          hasFocusAction: true,
          hasTapAction: true,
        ),
      );
      handle.dispose();
    });
  });

  group('FloatingNavBar — icon alignment', () {
    testWidgets('every icon sits on the same horizontal centerline', (
      tester,
    ) async {
      await _pumpNavBar(tester, _bar(selectedIndex: 2, onSelect: (_) {}));
      const icons = [
        Icons.explore_outlined,
        Icons.menu_book_outlined,
        Icons.article_rounded, // selected
        Icons.groups_outlined,
        Icons.person_outline_rounded,
      ];
      final centerYs = [for (final icon in icons) tester.getCenter(find.byIcon(icon)).dy];
      for (final y in centerYs.skip(1)) {
        expect(y, closeTo(centerYs.first, 0.5));
      }
    });

    testWidgets('the five icons are evenly spaced across the pill\'s width '
        '(each owns an equal-width share)', (tester) async {
      await _pumpNavBar(tester, _bar(selectedIndex: 0, onSelect: (_) {}), width: 390);
      const icons = [
        Icons.explore_rounded, // selected
        Icons.menu_book_outlined,
        Icons.article_outlined,
        Icons.groups_outlined,
        Icons.person_outline_rounded,
      ];
      final centerXs = [for (final icon in icons) tester.getCenter(find.byIcon(icon)).dx];
      final gaps = [
        for (var i = 1; i < centerXs.length; i++) centerXs[i] - centerXs[i - 1],
      ];
      for (final gap in gaps.skip(1)) {
        expect(gap, closeTo(gaps.first, 0.5));
      }
    });
  });

  group('FloatingNavBar — visual tokens', () {
    testWidgets('pill surface is forestGreen — a panel on the canvas, not '
        'the canvas color itself (deepGreen), not ivory', (tester) async {
      await _pumpNavBar(tester, _bar(selectedIndex: 0, onSelect: (_) {}));
      final decorated = tester.widget<DecoratedBox>(_pillDecoratedBox());
      final decoration = decorated.decoration as BoxDecoration;
      expect(decoration.color, AppColors.forestGreen);
      expect(decoration.color, isNot(AppColors.deepGreen));
      expect(decoration.color, isNot(AppColors.ivory));
      expect(decoration.color, CsNavStyle.background);
    });

    testWidgets('pill has fully rounded ends and a soft shadow — the '
        'floating-panel treatment, not a flat docked bar', (tester) async {
      await _pumpNavBar(tester, _bar(selectedIndex: 0, onSelect: (_) {}));
      final decorated = tester.widget<DecoratedBox>(_pillDecoratedBox());
      final decoration = decorated.decoration as BoxDecoration;
      expect(decoration.borderRadius, BorderRadius.circular(CsRadius.pill));
      expect(decoration.boxShadow, isNotEmpty);
      expect(decoration.border, isNotNull);
    });

    testWidgets('selected icon is ivory, unselected icons are '
        'secondaryOnDark — never gold', (tester) async {
      await _pumpNavBar(tester, _bar(selectedIndex: 0, onSelect: (_) {}));
      final selectedIcon = tester.widget<Icon>(find.byIcon(Icons.explore_rounded));
      final unselectedIcon = tester.widget<Icon>(find.byIcon(Icons.menu_book_outlined));
      expect(selectedIcon.color, AppColors.ivory);
      expect(unselectedIcon.color, AppColors.secondaryOnDark);
      expect(selectedIcon.color, isNot(AppColors.gold));
      expect(unselectedIcon.color, isNot(AppColors.gold));
    });

    testWidgets('no filled selection capsule behind an item — selection '
        'reads through icon/label tone alone', (tester) async {
      await _pumpNavBar(tester, _bar(selectedIndex: 0, onSelect: (_) {}));
      // The InkWell/Material wrapping each item (inside FloatingNavBar
      // only — Scaffold/MaterialApp contribute their own unrelated
      // Material ancestors elsewhere in the tree) is transparent — no
      // per-item background fill distinguishing the active one.
      final materials = tester
          .widgetList<Material>(
            find.descendant(
              of: find.byType(FloatingNavBar),
              matching: find.byType(Material),
            ),
          )
          .toList();
      expect(materials, hasLength(5));
      for (final m in materials) {
        expect(m.color, Colors.transparent);
      }
    });
  });

  group('FloatingNavBar — footprint (the "lager dan nu" requirement)', () {
    testWidgets('pill content height is meaningfully shorter than the old '
        'docked bar\'s own 68pt fixed height', (tester) async {
      expect(kFloatingNavBarHeight, lessThan(68));
    });

    // Regression guard for a real bug this suite's own earlier version
    // missed entirely: switching the pill's fixed SizedBox height to a
    // ConstrainedBox(minHeight:) (to stop the active label clipping at
    // large text scale) silently let the pill inflate to fill its ENTIRE
    // available height inside app.dart's Align(bottom center) — a giant
    // oval, not a pill — while every other assertion in this group still
    // passed (they only checked the bottom edge and horizontal insets,
    // never an upper bound on height). Caught only by actually
    // screenshotting a preview harness; this test exists so it can never
    // silently regress again.
    testWidgets('the pill stays close to its target height even when its '
        'parent offers much more (e.g. Align inside a full-height Stack) '
        '— never inflates to fill the available space', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(390, 844),
              padding: EdgeInsets.only(bottom: 34),
            ),
            child: Scaffold(
              // The exact shape app.dart's own body uses: a Stack whose
              // Align(bottomCenter) child gets loose, effectively
              // unbounded height from the Stack — the precondition the
              // real bug needed to reproduce.
              body: Stack(
                children: [
                  const SizedBox.expand(),
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: _bar(selectedIndex: 0, onSelect: (_) {}),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      final pillRect = tester.getRect(_pillDecoratedBox());
      expect(pillRect.height, lessThan(kFloatingNavBarHeight + 20));
    });

    testWidgets('the pill is inset from both side edges — floating, not '
        'edge-to-edge', (tester) async {
      await _pumpNavBar(tester, _bar(selectedIndex: 0, onSelect: (_) {}), width: 390);
      final pillRect = tester.getRect(_pillDecoratedBox());
      expect(pillRect.left, greaterThan(0));
      expect(pillRect.right, lessThan(390));
    });

    testWidgets('the pill is inset from the bottom edge by more than the '
        'device safe-area alone — floating, not docked flush', (tester) async {
      await _pumpNavBar(tester, _bar(selectedIndex: 0, onSelect: (_) {}), bottomInset: 34);
      final pillRect = tester.getRect(_pillDecoratedBox());
      // Screen height 844; pill's bottom edge must sit above the 34pt
      // safe-area inset by at least kFloatingNavBarBottomMargin.
      expect(844 - pillRect.bottom, greaterThanOrEqualTo(34 + kFloatingNavBarBottomMargin));
    });
  });

  group('floatingNavClearance()', () {
    testWidgets('folds in the device safe-area inset, the pill\'s own '
        'margin/height, and breathing room above it', (tester) async {
      late double clearance;
      await _pumpNavBar(
        tester,
        Builder(builder: (context) {
          clearance = floatingNavClearance(context);
          return const SizedBox.shrink();
        }),
        bottomInset: 34,
      );
      expect(
        clearance,
        34 + kFloatingNavBarBottomMargin + kFloatingNavBarHeight + 16,
      );
    });

    testWidgets('is always taller than the pill\'s own on-screen footprint '
        '— a scroll body using it can never end flush behind the pill', (
      tester,
    ) async {
      const bottomInset = 34.0;
      late double clearance;
      await _pumpNavBar(
        tester,
        Column(
          children: [
            Expanded(
              child: Builder(builder: (context) {
                clearance = floatingNavClearance(context);
                return const SizedBox.shrink();
              }),
            ),
          ],
        ),
        bottomInset: bottomInset,
      );
      final pillTotalFootprint =
          bottomInset + kFloatingNavBarBottomMargin + kFloatingNavBarHeight;
      expect(clearance, greaterThan(pillTotalFootprint));
    });
  });

  group('FloatingNavBar — tap behavior', () {
    testWidgets('tapping each destination reports its own index', (tester) async {
      final tapped = <int>[];
      await _pumpNavBar(tester, _bar(selectedIndex: 0, onSelect: tapped.add));
      const icons = [
        Icons.explore_rounded, // selected
        Icons.menu_book_outlined,
        Icons.article_outlined,
        Icons.groups_outlined,
        Icons.person_outline_rounded,
      ];
      for (final icon in icons) {
        await tester.tap(find.byIcon(icon));
      }
      expect(tapped, [0, 1, 2, 3, 4]);
    });
  });

  group('FloatingNavBar — accessibility', () {
    testWidgets('an unselected destination is discoverable but not marked '
        'selected', (tester) async {
      final handle = tester.ensureSemantics();
      await _pumpNavBar(tester, _bar(selectedIndex: 1, onSelect: (_) {}));
      expect(
        tester.getSemantics(find.byIcon(Icons.explore_outlined)),
        matchesSemantics(
          label: 'Explore',
          isSelected: false,
          isButton: true,
          hasEnabledState: true,
          isEnabled: true,
          isFocusable: true,
          hasSelectedState: true,
          hasFocusAction: true,
          hasTapAction: true,
        ),
      );
      handle.dispose();
    });
  });

  group('FloatingNavBar — responsive', () {
    testWidgets('320px — all five destinations fit, no overflow', (tester) async {
      await _pumpNavBar(tester, _bar(selectedIndex: 0, onSelect: (_) {}), width: 320);
      expect(tester.takeException(), isNull);
      expect(find.byType(InkWell), findsNWidgets(5));
    });

    testWidgets('1.6x text scale — no overflow (icons don\'t scale with '
        'text, but this is a cheap regression guard to keep)', (tester) async {
      await _pumpNavBar(
        tester,
        _bar(selectedIndex: 0, onSelect: (_) {}),
        width: 320,
        textScale: 1.6,
      );
      expect(tester.takeException(), isNull);
      expect(find.byIcon(Icons.explore_rounded), findsOneWidget);
    });

    testWidgets('bar height clears the 44pt accessibility floor', (tester) async {
      await _pumpNavBar(tester, _bar(selectedIndex: 0, onSelect: (_) {}));
      final size = tester.getSize(find.byType(FloatingNavBar));
      expect(size.height, greaterThanOrEqualTo(44));
    });
  });

  group('Tab state preservation — the IndexedStack mechanism '
      '_MainNavigation relies on', () {
    // _MainNavigation's real tab screens can't be pumped (Supabase-eager
    // initState). This proves the underlying, unmodified Flutter mechanism
    // itself — IndexedStack keeps every child mounted and never disposes
    // or rebuilds an inactive one — using plain stateful counters standing
    // in for the real screens' own internal state.
    testWidgets('switching the active index does not reset a hidden tab\'s '
        'internal state', (tester) async {
      final keys = List.generate(3, (_) => GlobalKey<_CounterState>());
      var index = 0;
      await tester.pumpWidget(
        StatefulBuilder(
          builder: (context, setState) => MaterialApp(
            home: Scaffold(
              body: Stack(
                children: [
                  IndexedStack(
                    index: index,
                    children: [for (final key in keys) _Counter(key: key)],
                  ),
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (var i = 0; i < 3; i++)
                          TextButton(
                            onPressed: () => setState(() => index = i),
                            child: Text('Tab $i'),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      // Bump tab 0's counter, switch away, switch back — the same State
      // object (and its count) must still be there, not a fresh one.
      await tester.tap(find.text('Bump'));
      await tester.pump();
      expect(keys[0].currentState!.count, 1);

      await tester.tap(find.text('Tab 1'));
      await tester.pump();
      await tester.tap(find.text('Tab 0'));
      await tester.pump();

      expect(keys[0].currentState!.count, 1, reason: 'tab 0 kept its state');
    });
  });
}

class _Counter extends StatefulWidget {
  const _Counter({super.key});
  @override
  State<_Counter> createState() => _CounterState();
}

class _CounterState extends State<_Counter> {
  int count = 0;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Text('Count: $count'),
      TextButton(onPressed: () => setState(() => count++), child: const Text('Bump')),
    ],
  );
}
