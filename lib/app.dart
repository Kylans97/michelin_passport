import 'package:flutter/material.dart';
import 'core/constants/app_colors.dart';
import 'core/navigation/route_observer.dart';
import 'core/theme/app_theme.dart';
import 'core/widgets/floating_nav_bar.dart';
import 'features/auth/auth_gate.dart';
import 'features/community/community_screen.dart';
import 'features/explore/explore_screen.dart';
import 'features/news/news_screen.dart';
import 'features/passport/passport_screen.dart';
import 'features/profile/profile_screen.dart';

class TablePassportApp extends StatelessWidget {
  const TablePassportApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Mantelier',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.mantelier,
      navigatorObservers: [appRouteObserver],
      // AuthGate shows LoginScreen when there is no session,
      // and the tab scaffold when the user is authenticated.
      home: const AuthGate(child: _MainNavigation()),
    );
  }
}

// ── Tab scaffold ──────────────────────────────────────────────────────────────

class _MainNavigation extends StatefulWidget {
  const _MainNavigation();

  @override
  State<_MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<_MainNavigation> {
  int _index = 0;

  // Navigation & Information Architecture V2 — the long-term product
  // structure: five destinations answering five different user questions
  // (Explore "where can I go", Passport "where have I been/want to go",
  // News "what's happening", Community "what are other people doing",
  // Profile "my identity and settings"). Rankings and Wishlist are no
  // longer their own tabs — both are still fully intact, just re-homed as
  // pushed screens reachable from Passport's own quick-access row (see
  // passport_screen.dart). See docs/Architecture/
  // NAVIGATION_INFORMATION_ARCHITECTURE_V2.md for the full rationale and
  // migration map.
  static const _screens = [
    ExploreScreen(),
    PassportScreen(),
    NewsScreen(),
    CommunityScreen(),
    ProfileScreen(),
  ];

  static const _destinations = [
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      // The floating pill (FloatingNavBar) sits in a Stack on top of the
      // tab body, not in Scaffold's own bottomNavigationBar slot — that
      // slot always reserves its own full-width layout band, which is
      // exactly the "docked block" shape this replaced. Stacking it over
      // the body instead means the body renders full-height behind it, and
      // every tab's own scrolling content is responsible for its own
      // bottom clearance via floatingNavClearance() (see
      // floating_nav_bar.dart) — audited across all ten scroll bodies this
      // pill can float over.
      body: Stack(
        children: [
          IndexedStack(index: _index, children: _screens),
          Align(
            alignment: Alignment.bottomCenter,
            child: FloatingNavBar(
              selectedIndex: _index,
              onDestinationSelected: (i) => setState(() => _index = i),
              destinations: _destinations,
            ),
          ),
        ],
      ),
    );
  }
}
