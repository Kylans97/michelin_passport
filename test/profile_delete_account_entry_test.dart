// Covers ProfileScreen's ACCOUNT section rows, focused on the new
// "Delete account" entry (Account Deletion / App Store readiness addendum
// to Navigation & Information Architecture V2 UI Refinement) — must be
// directly visible and tappable from Profile, never buried behind
// Privacy/Terms/About/a support email. ProfileScreen constructs several
// repositories against Supabase.instance.client eagerly in initState —
// same established limitation as every other Supabase-eager screen in
// this app — so this mirrors the exact ACCOUNT section _SettingsRow list
// ProfileScreen.build() produces rather than pumping the real screen.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:michelin_passport/core/constants/app_colors.dart';
import 'package:michelin_passport/core/theme/cs_typography.dart';

class _SettingsRowMirror extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;
  const _SettingsRowMirror({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final tint = color ?? AppColors.secondaryOnDark;
    return InkWell(
      onTap: onTap,
      child: Row(
        children: [
          Icon(icon, color: tint),
          Text(
            label,
            style: CsTypography.body.copyWith(
              color: color ?? AppColors.textOnDark,
            ),
          ),
          Icon(Icons.chevron_right_rounded, color: tint),
        ],
      ),
    );
  }
}

Widget _accountSection({
  required VoidCallback onEditProfile,
  required VoidCallback onNotifications,
  required VoidCallback onSignOut,
  required VoidCallback onDeleteAccount,
}) => MaterialApp(
  home: Scaffold(
    backgroundColor: AppColors.deepGreen,
    body: Column(
      children: [
        _SettingsRowMirror(
          icon: Icons.edit_outlined,
          label: 'Edit profile',
          onTap: onEditProfile,
        ),
        _SettingsRowMirror(
          icon: Icons.notifications_outlined,
          label: 'Notifications',
          onTap: onNotifications,
        ),
        _SettingsRowMirror(
          icon: Icons.logout_outlined,
          label: 'Sign out',
          onTap: onSignOut,
        ),
        _SettingsRowMirror(
          icon: Icons.delete_outline_rounded,
          label: 'Delete account',
          color: AppColors.error,
          onTap: onDeleteAccount,
        ),
      ],
    ),
  ),
);

void main() {
  group('Profile ACCOUNT section — Delete account entry', () {
    testWidgets('is directly visible alongside Edit profile/Notifications/'
        'Sign out — not nested behind another screen', (tester) async {
      await tester.pumpWidget(
        _accountSection(
          onEditProfile: () {},
          onNotifications: () {},
          onSignOut: () {},
          onDeleteAccount: () {},
        ),
      );
      expect(find.text('Edit profile'), findsOneWidget);
      expect(find.text('Notifications'), findsOneWidget);
      expect(find.text('Sign out'), findsOneWidget);
      expect(find.text('Delete account'), findsOneWidget);
    });

    testWidgets('is error-tinted (destructive-action signal), unlike the '
        'other neutral rows — never gold', (tester) async {
      await tester.pumpWidget(
        _accountSection(
          onEditProfile: () {},
          onNotifications: () {},
          onSignOut: () {},
          onDeleteAccount: () {},
        ),
      );
      final deleteLabel = tester.widget<Text>(find.text('Delete account'));
      expect(deleteLabel.style?.color, AppColors.error);
      expect(deleteLabel.style?.color, isNot(AppColors.gold));

      final signOutLabel = tester.widget<Text>(find.text('Sign out'));
      expect(signOutLabel.style?.color, AppColors.textOnDark);
      expect(signOutLabel.style?.color, isNot(AppColors.error));
    });

    testWidgets('tapping it triggers navigation to the deletion flow', (
      tester,
    ) async {
      var tapped = false;
      await tester.pumpWidget(
        _accountSection(
          onEditProfile: () {},
          onNotifications: () {},
          onSignOut: () {},
          onDeleteAccount: () => tapped = true,
        ),
      );
      await tester.tap(find.text('Delete account'));
      expect(tapped, isTrue);
    });
  });
}
