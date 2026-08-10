import 'package:flutter/material.dart';
import 'core/constants/app_colors.dart';
import 'core/navigation/route_observer.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/auth_gate.dart';
import 'features/explore/explore_screen.dart';
import 'features/passport/passport_screen.dart';
import 'features/profile/profile_screen.dart';
import 'features/rankings/rankings_screen.dart';
import 'features/wishlist/wishlist_screen.dart';

class TablePassportApp extends StatelessWidget {
  const TablePassportApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Chasing Stars',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.chasingStars,
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

  static const _screens = [
    PassportScreen(),
    ExploreScreen(),
    RankingsScreen(),
    WishlistScreen(),
    ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: IndexedStack(index: _index, children: _screens),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: AppColors.divider, width: 0.5)),
        ),
        child: NavigationBar(
          selectedIndex: _index,
          onDestinationSelected: (i) => setState(() => _index = i),
          backgroundColor: AppColors.surface,
          surfaceTintColor: Colors.transparent,
          indicatorColor: AppColors.goldMuted,
          height: 68,
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.menu_book_outlined),
              selectedIcon: Icon(Icons.menu_book_rounded),
              label: 'Passport',
            ),
            NavigationDestination(
              icon: Icon(Icons.explore_outlined),
              selectedIcon: Icon(Icons.explore_rounded),
              label: 'Explore',
            ),
            NavigationDestination(
              icon: Icon(Icons.leaderboard_outlined),
              selectedIcon: Icon(Icons.leaderboard_rounded),
              label: 'Rankings',
            ),
            NavigationDestination(
              icon: Icon(Icons.favorite_border_rounded),
              selectedIcon: Icon(Icons.favorite_rounded),
              label: 'Wishlist',
            ),
            NavigationDestination(
              icon: Icon(Icons.person_outline_rounded),
              selectedIcon: Icon(Icons.person_rounded),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }
}
