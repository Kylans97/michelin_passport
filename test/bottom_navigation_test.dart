// Covers _MainNavigation's bottom navigation bar. Navigation & Information
// Architecture V2 replaced the previous 5-tab structure (Passport,
// Explore, Rankings, Wishlist, Profile) with the long-term product
// structure: Explore, Passport, News, Community, Profile — five
// destinations answering five different user questions (see
// docs/Architecture/NAVIGATION_INFORMATION_ARCHITECTURE_V2.md). Rankings
// and Wishlist are NOT gone — both are fully intact, just re-homed as
// screens pushed from Passport's own quick-access row (see
// passport_screen_test.dart / passport_screen.dart) rather than primary
// tabs of their own. This file otherwise keeps every pre-existing visual-
// token/accessibility/responsive/tap-behavior/tab-state-preservation
// assertion (Bottom Navigation UI Consistency Step 1 + Step 1A's dark-
// green surface direction change + Step 1B's exact-color regression
// coverage + the Green Token Consistency Migration) — those guarantees
// are unchanged by which five destinations they apply to.
//
// app.dart's _MainNavigation is a private class whose 5 tab children
// (ExploreScreen, PassportScreen, NewsScreen, CommunityScreen,
// ProfileScreen) all construct repositories against Supabase.instance
// .client eagerly, so it can't be pumped directly (same established
// limitation as every other Supabase-eager screen in this app). This
// mirrors app.dart's exact NavigationBar construction — same
// destinations, same styling parameters, same theme — with plain
// Container bodies standing in for the real tab screens.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:michelin_passport/core/constants/app_colors.dart';
import 'package:michelin_passport/core/theme/app_theme.dart';
import 'package:michelin_passport/core/theme/cs_theme.dart';
import 'package:michelin_passport/core/theme/cs_typography.dart';

const _labels = ['Explore', 'Passport', 'News', 'Community', 'Profile'];

// Mirrors _MainNavigationState.build's bottomNavigationBar exactly.
Widget _bottomNav({
  required int selectedIndex,
  required ValueChanged<int> onSelect,
}) => Container(
  decoration: const BoxDecoration(color: AppColors.deepGreen),
  child: NavigationBar(
    selectedIndex: selectedIndex,
    onDestinationSelected: onSelect,
    backgroundColor: AppColors.deepGreen,
    surfaceTintColor: Colors.transparent,
    shadowColor: Colors.transparent,
    elevation: 0,
    indicatorColor: Colors.transparent,
    height: 68,
    labelTextStyle: WidgetStateProperty.resolveWith((states) {
      final selected = states.contains(WidgetState.selected);
      return CsTypography.navigation.copyWith(
        color: selected ? AppColors.ivory : AppColors.secondaryOnDark,
        fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
      );
    }),
    destinations: const [
      NavigationDestination(
        icon: Icon(Icons.explore_outlined),
        selectedIcon: Icon(Icons.explore_rounded),
        label: 'Explore',
      ),
      NavigationDestination(
        icon: Icon(Icons.menu_book_outlined),
        selectedIcon: Icon(Icons.menu_book_rounded),
        label: 'Passport',
      ),
      NavigationDestination(
        icon: Icon(Icons.article_outlined),
        selectedIcon: Icon(Icons.article_rounded),
        label: 'News',
      ),
      NavigationDestination(
        icon: Icon(Icons.groups_outlined),
        selectedIcon: Icon(Icons.groups_rounded),
        label: 'Community',
      ),
      NavigationDestination(
        icon: Icon(Icons.person_outline_rounded),
        selectedIcon: Icon(Icons.person_rounded),
        label: 'Profile',
      ),
    ],
  ),
);

Widget _wrap(
  Widget navBar, {
  double width = 390,
  double textScale = 1.0,
  Widget body = const SizedBox.shrink(),
}) => MaterialApp(
  theme: AppTheme.chasingStars,
  home: MediaQuery(
    data: MediaQueryData(
      size: Size(width, 844),
      textScaler: TextScaler.linear(textScale),
    ),
    child: Scaffold(body: body, bottomNavigationBar: navBar),
  ),
);

void main() {
  group('Bottom navigation — information architecture freeze', () {
    testWidgets('exactly 5 destinations, exact order, exact labels', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(_bottomNav(selectedIndex: 0, onSelect: (_) {})),
      );
      expect(find.byType(NavigationDestination), findsNWidgets(5));
      for (final label in _labels) {
        expect(find.text(label), findsOneWidget);
      }
    });

    testWidgets('exact icon/selectedIcon pairs, unchanged from before this '
        'step', (tester) async {
      await tester.pumpWidget(
        _wrap(_bottomNav(selectedIndex: 0, onSelect: (_) {})),
      );
      final destinations = tester
          .widgetList<NavigationDestination>(find.byType(NavigationDestination))
          .toList();
      const expectedIcons = [
        (Icons.explore_outlined, Icons.explore_rounded),
        (Icons.menu_book_outlined, Icons.menu_book_rounded),
        (Icons.article_outlined, Icons.article_rounded),
        (Icons.groups_outlined, Icons.groups_rounded),
        (Icons.person_outline_rounded, Icons.person_rounded),
      ];
      for (var i = 0; i < 5; i++) {
        final icon = destinations[i].icon as Icon;
        final selectedIcon = destinations[i].selectedIcon! as Icon;
        expect(icon.icon, expectedIcons[i].$1);
        expect(selectedIcon.icon, expectedIcons[i].$2);
      }
    });
  });

  group('Bottom navigation — visual tokens', () {
    testWidgets('navigation surface is deep-green — not ivory, not the '
        'legacy surface token', (tester) async {
      await tester.pumpWidget(
        _wrap(_bottomNav(selectedIndex: 0, onSelect: (_) {})),
      );
      final bar = tester.widget<NavigationBar>(find.byType(NavigationBar));
      expect(bar.backgroundColor, AppColors.deepGreen);
      expect(bar.backgroundColor, isNot(AppColors.surface));
      expect(bar.backgroundColor, isNot(AppColors.ivory));
    });

    testWidgets('wrapper Container color is EXACTLY AppColors.deepGreen — '
        'not an approximation, the identical Color value', (tester) async {
      await tester.pumpWidget(
        _wrap(_bottomNav(selectedIndex: 0, onSelect: (_) {})),
      );
      final container = tester.widget<Container>(find.byType(Container).first);
      final decoration = container.decoration! as BoxDecoration;
      expect(decoration.color, equals(AppColors.deepGreen));
    });

    testWidgets('NavigationBar.backgroundColor is EXACTLY '
        'AppColors.deepGreen', (tester) async {
      await tester.pumpWidget(
        _wrap(_bottomNav(selectedIndex: 0, onSelect: (_) {})),
      );
      final bar = tester.widget<NavigationBar>(find.byType(NavigationBar));
      expect(bar.backgroundColor, equals(AppColors.deepGreen));
    });

    testWidgets('theme-level NavigationBarTheme.backgroundColor is EXACTLY '
        'AppColors.deepGreen — the same fallback source app.dart\'s own '
        'inline value must never drift from', (tester) async {
      final theme = AppTheme.chasingStars.navigationBarTheme;
      expect(theme.backgroundColor, equals(AppColors.deepGreen));
    });

    testWidgets('CsNavStyle.background is EXACTLY AppColors.deepGreen — '
        'the third, named-reference source stays in sync with the two '
        'live styling paths above', (tester) async {
      expect(CsNavStyle.background, equals(AppColors.deepGreen));
      expect(CsNavStyle.selectedColor, equals(AppColors.ivory));
      expect(CsNavStyle.unselectedColor, equals(AppColors.secondaryOnDark));
    });

    testWidgets('deepGreen and forestGreen are distinct, non-interchangeable '
        'colors — this bar uses the primary brand surface (deepGreen), '
        'never the secondary-elevated-panel token (forestGreen); Green '
        'Token Consistency Migration\'s canonical rule, asserted directly '
        'so the two are never conflated again', (tester) async {
      await tester.pumpWidget(
        _wrap(_bottomNav(selectedIndex: 0, onSelect: (_) {})),
      );
      final container = tester.widget<Container>(find.byType(Container).first);
      final decoration = container.decoration! as BoxDecoration;
      final bar = tester.widget<NavigationBar>(find.byType(NavigationBar));
      final theme = AppTheme.chasingStars.navigationBarTheme;
      expect(AppColors.deepGreen, isNot(equals(AppColors.forestGreen)));
      expect(decoration.color, isNot(equals(AppColors.forestGreen)));
      expect(bar.backgroundColor, isNot(equals(AppColors.forestGreen)));
      expect(theme.backgroundColor, isNot(equals(AppColors.forestGreen)));
      expect(CsNavStyle.background, isNot(equals(AppColors.forestGreen)));
    });

    testWidgets('no Material indicator pill — indicatorColor is transparent', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(_bottomNav(selectedIndex: 0, onSelect: (_) {})),
      );
      final bar = tester.widget<NavigationBar>(find.byType(NavigationBar));
      expect(bar.indicatorColor, Colors.transparent);
      expect(bar.indicatorColor, isNot(AppColors.goldMuted));
    });

    testWidgets('no visible elevation/shadow', (tester) async {
      await tester.pumpWidget(
        _wrap(_bottomNav(selectedIndex: 0, onSelect: (_) {})),
      );
      final bar = tester.widget<NavigationBar>(find.byType(NavigationBar));
      expect(bar.elevation, 0);
      expect(bar.shadowColor, Colors.transparent);
    });

    testWidgets('selected label is ivory, unselected is secondaryOnDark — '
        'never gold', (tester) async {
      await tester.pumpWidget(
        _wrap(_bottomNav(selectedIndex: 0, onSelect: (_) {})),
      );
      final bar = tester.widget<NavigationBar>(find.byType(NavigationBar));
      final selectedStyle = bar.labelTextStyle!.resolve({WidgetState.selected});
      final unselectedStyle = bar.labelTextStyle!.resolve({});
      expect(selectedStyle?.color, AppColors.ivory);
      expect(unselectedStyle?.color, AppColors.secondaryOnDark);
      expect(selectedStyle?.color, isNot(AppColors.gold));
      expect(unselectedStyle?.color, isNot(AppColors.gold));
    });

    testWidgets('selected label carries more weight than unselected — '
        'hierarchy through typography, not decoration', (tester) async {
      await tester.pumpWidget(
        _wrap(_bottomNav(selectedIndex: 0, onSelect: (_) {})),
      );
      final bar = tester.widget<NavigationBar>(find.byType(NavigationBar));
      final selectedStyle = bar.labelTextStyle!.resolve({WidgetState.selected});
      final unselectedStyle = bar.labelTextStyle!.resolve({});
      expect(
        selectedStyle!.fontWeight!.value,
        greaterThan(unselectedStyle!.fontWeight!.value),
      );
    });

    testWidgets('theme-level icon color: ivory selected, secondaryOnDark '
        'unselected — never gold', (tester) async {
      final theme = AppTheme.chasingStars.navigationBarTheme;
      final selectedIcon = theme.iconTheme!.resolve({WidgetState.selected});
      final unselectedIcon = theme.iconTheme!.resolve({});
      expect(selectedIcon?.color, AppColors.ivory);
      expect(unselectedIcon?.color, AppColors.secondaryOnDark);
      expect(selectedIcon?.color, isNot(AppColors.gold));
      expect(unselectedIcon?.color, isNot(AppColors.gold));
      expect(theme.indicatorColor, Colors.transparent);
    });

    testWidgets('no top hairline — the deep-green-to-ivory color-block '
        'boundary is the separator, same reasoning GuideCatalogueLayout '
        'already established for its own masthead-to-content transition', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(_bottomNav(selectedIndex: 0, onSelect: (_) {})),
      );
      final container = tester.widget<Container>(find.byType(Container).first);
      final decoration = container.decoration! as BoxDecoration;
      expect(decoration.color, AppColors.deepGreen);
      expect(decoration.border, isNull);
    });
  });

  group('Bottom navigation — tap behavior', () {
    testWidgets('tapping each destination reports its own index', (
      tester,
    ) async {
      final tapped = <int>[];
      await tester.pumpWidget(
        _wrap(_bottomNav(selectedIndex: 0, onSelect: tapped.add)),
      );
      for (var i = 0; i < _labels.length; i++) {
        await tester.tap(find.text(_labels[i]));
      }
      expect(tapped, [0, 1, 2, 3, 4]);
    });

    testWidgets('selectedIndex drives which destination Flutter marks '
        'selected', (tester) async {
      await tester.pumpWidget(
        _wrap(_bottomNav(selectedIndex: 3, onSelect: (_) {})),
      );
      final bar = tester.widget<NavigationBar>(find.byType(NavigationBar));
      expect(bar.selectedIndex, 3);
    });
  });

  group('Bottom navigation — accessibility', () {
    testWidgets('the selected destination is discoverable as selected via '
        'semantics', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _wrap(_bottomNav(selectedIndex: 1, onSelect: (_) {})),
      );
      expect(
        tester.getSemantics(find.text('Passport')),
        matchesSemantics(
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

    testWidgets('an unselected destination is not marked selected', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _wrap(_bottomNav(selectedIndex: 1, onSelect: (_) {})),
      );
      expect(
        tester.getSemantics(find.text('Explore')),
        matchesSemantics(
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

  group('Bottom navigation — responsive', () {
    testWidgets('320px — all five destinations fit, no overflow', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(_bottomNav(selectedIndex: 0, onSelect: (_) {}), width: 320),
      );
      expect(tester.takeException(), isNull);
      expect(find.byType(NavigationDestination), findsNWidgets(5));
    });

    testWidgets('390px — no overflow', (tester) async {
      await tester.pumpWidget(
        _wrap(_bottomNav(selectedIndex: 0, onSelect: (_) {}), width: 390),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('1.6x text scale — labels remain readable, no overflow', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          _bottomNav(selectedIndex: 0, onSelect: (_) {}),
          width: 320,
          textScale: 1.6,
        ),
      );
      expect(tester.takeException(), isNull);
      for (final label in _labels) {
        expect(find.text(label), findsOneWidget);
      }
    });

    testWidgets('bar height is compact but comfortable — clears the 44pt '
        'accessibility floor', (tester) async {
      await tester.pumpWidget(
        _wrap(_bottomNav(selectedIndex: 0, onSelect: (_) {})),
      );
      final size = tester.getSize(find.byType(NavigationBar));
      expect(size.height, greaterThanOrEqualTo(44));
    });
  });

  group('Tab state preservation — the IndexedStack mechanism '
      '_MainNavigation relies on', () {
    // _MainNavigation's real tab screens can't be pumped (Supabase-eager
    // initState). This proves the underlying, unmodified Flutter mechanism
    // itself — IndexedStack keeps every child mounted and never disposes
    // or rebuilds an inactive one — using plain stateful counters standing
    // in for the real screens' own internal state (Explore's filters,
    // Wishlist's Restaurants/Hotels selection, scroll position, etc.).
    testWidgets('switching the active index does not reset a hidden tab\'s '
        'internal state', (tester) async {
      final keys = List.generate(3, (_) => GlobalKey<_CounterState>());
      var index = 0;
      await tester.pumpWidget(
        StatefulBuilder(
          builder: (context, setState) => MaterialApp(
            home: Scaffold(
              body: IndexedStack(
                index: index,
                children: [for (final key in keys) _Counter(key: key)],
              ),
              bottomNavigationBar: Row(
                children: [
                  for (var i = 0; i < 3; i++)
                    TextButton(
                      onPressed: () => setState(() => index = i),
                      child: Text('Tab $i'),
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
      TextButton(
        onPressed: () => setState(() => count++),
        child: const Text('Bump'),
      ),
    ],
  );
}
