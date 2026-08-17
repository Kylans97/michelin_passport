import 'package:flutter/material.dart';
import 'core/constants/app_colors.dart';
import 'core/navigation/route_observer.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/cs_typography.dart';
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
      // Bottom Navigation UI Consistency Step 1A: physical-device direction
      // change — an explicit dark-green Container/NavigationBar (Step 1's
      // ivory surface tested clean but the approved direction is now a
      // deliberate green-top/ivory-middle/green-bottom frame, matching how
      // many primary screens already open on a dark-green hero). Never
      // relying on this Scaffold's own AppColors.background showing
      // through. No top hairline: a dark-green bar sitting directly
      // against an ivory tab body is already a full color-block boundary
      // — exactly the same reasoning GuideCatalogueLayout's own
      // green-masthead-to-ivory-content transition already established
      // ("a hand-drawn line would be redundant next to a full color-block
      // boundary already this strong"), so Step 1's taupe hairline (right
      // for an ivory-on-ivory transition) is removed rather than kept and
      // reworked for a surface it was never designed for.
      //
      // Green Token Consistency Migration (Step 1B follow-up): the canvas
      // color here is AppColors.deepGreen, not forestGreen — deepGreen is
      // the app's canonical PRIMARY brand dark surface (see app_colors.dart
      // and CsSurfaces.greenCanvas), the same one Explore/Passport/Event
      // Detail's hero already use. forestGreen remains reserved for
      // secondary elevated panels sitting ON a deepGreen canvas (see
      // CsSurfaces.greenElevated) — this nav bar isn't a panel on
      // something else, it IS a primary surface, so it takes the primary
      // token.
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(color: AppColors.deepGreen),
        child: NavigationBar(
          selectedIndex: _index,
          onDestinationSelected: (i) => setState(() => _index = i),
          backgroundColor: AppColors.deepGreen,
          surfaceTintColor: Colors.transparent,
          shadowColor: Colors.transparent,
          elevation: 0,
          // No Material indicator pill — selection reads through icon/
          // label color alone (ivory vs. secondaryOnDark below), never a
          // filled background, and never gold.
          indicatorColor: Colors.transparent,
          height: 68,
          // Icon color/size has no direct NavigationBar constructor
          // parameter (Material only exposes it via
          // NavigationBarThemeData.iconTheme) — supplied by
          // AppTheme.chasingStars.navigationBarTheme above instead;
          // labelTextStyle IS a direct parameter, set explicitly here to
          // match the same ivory/secondaryOnDark selected/unselected rule.
          labelTextStyle: WidgetStateProperty.resolveWith((states) {
            final selected = states.contains(WidgetState.selected);
            return CsTypography.navigation.copyWith(
              color: selected ? AppColors.ivory : AppColors.secondaryOnDark,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
            );
          }),
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
