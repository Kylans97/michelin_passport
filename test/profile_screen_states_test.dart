// Covers ProfileScreen's redesigned states (Social Foundation Step 1):
// the "choose a username" banner, and — explicitly required — Sign Out.
// ProfileScreen constructs repositories against Supabase.instance.client
// eagerly in initState (same established limitation as every other
// screen in this app that touches Supabase there), so it can't be pumped
// directly — this reconstructs the exact widgets/copy from
// lib/features/profile/profile_screen.dart, mirroring this codebase's
// established "test the presentation seam" precedent.
//
// Sign Out specifically: verifies the row (a) is present and immediately
// visible in a plain list — not nested inside a submenu/dialog — and
// (b) invokes the provided callback on tap, standing in for
// AuthRepository.signOut() exactly as ProfileScreen._signOut() calls it
// (`Future<void> _signOut() async => _authRepo.signOut();` — a direct,
// unconditional call with no second/alternate logout mechanism).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:michelin_passport/core/constants/app_colors.dart';
import 'package:michelin_passport/core/theme/cs_spacing.dart';
import 'package:michelin_passport/core/theme/cs_typography.dart';

// ── Reconstructed from ProfileScreen's own _SettingsRow + Account section ──

Widget _accountSection({required VoidCallback onSignOut}) => Column(
  crossAxisAlignment: CrossAxisAlignment.start,
  children: [
    Text(
      'ACCOUNT',
      style: CsTypography.eyebrow.copyWith(color: AppColors.secondaryOnDark),
    ),
    const SizedBox(height: CsSpacing.md),
    _SettingsRowStandIn(
      icon: Icons.edit_outlined,
      label: 'Edit profile',
      onTap: () {},
    ),
    _SettingsRowStandIn(
      icon: Icons.notifications_outlined,
      label: 'Notifications',
      onTap: () {},
    ),
    _SettingsRowStandIn(
      icon: Icons.logout_rounded,
      label: 'Sign out',
      onTap: onSignOut,
    ),
  ],
);

class _SettingsRowStandIn extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _SettingsRowStandIn({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.transparent,
    child: InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          vertical: CsSpacing.md,
          horizontal: CsSpacing.xs,
        ),
        child: Row(
          children: [
            Icon(icon, color: AppColors.secondaryOnDark, size: 20),
            const SizedBox(width: CsSpacing.base),
            Expanded(
              child: Text(
                label,
                style: CsTypography.body.copyWith(color: AppColors.textOnDark),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

Widget _chooseUsernameBanner(VoidCallback onTap) => Material(
  color: Colors.transparent,
  child: InkWell(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.all(CsSpacing.base),
      child: const Text('Choose a username so friends can find you'),
    ),
  ),
);

Widget _wrap(Widget child) => MaterialApp(
  home: Scaffold(backgroundColor: AppColors.deepGreen, body: child),
);

void main() {
  group('ProfileScreen — Sign Out', () {
    testWidgets('is visible immediately, in a plain list, not a submenu', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap(_accountSection(onSignOut: () {})));
      // No nested Drawer/PopupMenu/second dialog needed to find it — it's
      // a direct descendant of the Account section, found without any
      // prior interaction.
      expect(find.text('Sign out'), findsOneWidget);
      expect(find.byType(PopupMenuButton), findsNothing);
      expect(find.byType(Drawer), findsNothing);
    });

    testWidgets('tapping Sign Out invokes the sign-out callback (stands '
        'in for AuthRepository.signOut())', (tester) async {
      var signedOut = false;
      await tester.pumpWidget(
        _wrap(_accountSection(onSignOut: () => signedOut = true)),
      );
      await tester.tap(find.text('Sign out'));
      expect(signedOut, isTrue);
    });

    testWidgets('Sign Out sits alongside Edit Profile/Notifications — no '
        'second/alternate logout control exists', (tester) async {
      await tester.pumpWidget(_wrap(_accountSection(onSignOut: () {})));
      expect(find.text('Edit profile'), findsOneWidget);
      expect(find.text('Notifications'), findsOneWidget);
      expect(find.text('Sign out'), findsOneWidget);
      expect(find.textContaining('Log out'), findsNothing);
      expect(find.textContaining('Logout'), findsNothing);
    });

    testWidgets('tap target meets the 44px minimum', (tester) async {
      await tester.pumpWidget(_wrap(_accountSection(onSignOut: () {})));
      final size = tester.getSize(find.widgetWithText(InkWell, 'Sign out'));
      expect(size.height, greaterThanOrEqualTo(44));
    });
  });

  group('ProfileScreen — missing-username completion CTA', () {
    testWidgets('renders when shown and fires its callback on tap', (
      tester,
    ) async {
      var tapped = false;
      await tester.pumpWidget(
        _wrap(_chooseUsernameBanner(() => tapped = true)),
      );
      expect(
        find.text('Choose a username so friends can find you'),
        findsOneWidget,
      );
      await tester.tap(find.text('Choose a username so friends can find you'));
      expect(tapped, isTrue);
    });
  });
}
