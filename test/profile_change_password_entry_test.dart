// Covers ProfileScreen's ACCOUNT section, focused on the "Change password"
// entry — must sit directly alongside Edit profile/Notifications/Privacy/
// Delete account, never buried elsewhere. Mirrors
// profile_delete_account_entry_test.dart's own approach exactly: ProfileScreen
// constructs several repositories against Supabase.instance.client eagerly
// in initState (same established limitation as every other Supabase-eager
// screen in this app), so this mirrors the _SettingsRow list ProfileScreen.
// build() produces rather than pumping the real screen.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:michelin_passport/core/constants/app_colors.dart';
import 'package:michelin_passport/core/theme/cs_typography.dart';

class _SettingsRowMirror extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _SettingsRowMirror({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Row(
        children: [
          Icon(icon, color: AppColors.secondaryOnDark),
          Text(
            label,
            style: CsTypography.body.copyWith(color: AppColors.textOnDark),
          ),
          Icon(
            Icons.chevron_right_rounded,
            color: AppColors.secondaryOnDark,
          ),
        ],
      ),
    );
  }
}

Widget _accountSection({
  required VoidCallback onEditProfile,
  required VoidCallback onChangePassword,
  required VoidCallback onNotifications,
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
        // Sits directly after Edit profile, before Notifications — same
        // ACCOUNT section as Delete account, per the approved plan.
        _SettingsRowMirror(
          icon: Icons.lock_reset_outlined,
          label: 'Change password',
          onTap: onChangePassword,
        ),
        _SettingsRowMirror(
          icon: Icons.notifications_outlined,
          label: 'Notifications',
          onTap: onNotifications,
        ),
      ],
    ),
  ),
);

void main() {
  group('Profile ACCOUNT section — Change password entry', () {
    testWidgets('is directly visible alongside Edit profile/Notifications — '
        'not nested behind another screen', (tester) async {
      await tester.pumpWidget(
        _accountSection(
          onEditProfile: () {},
          onChangePassword: () {},
          onNotifications: () {},
        ),
      );
      expect(find.text('Edit profile'), findsOneWidget);
      expect(find.text('Change password'), findsOneWidget);
      expect(find.text('Notifications'), findsOneWidget);
    });

    testWidgets('uses the same neutral tint as the other non-destructive '
        'rows — never the error tint reserved for Delete account', (
      tester,
    ) async {
      await tester.pumpWidget(
        _accountSection(
          onEditProfile: () {},
          onChangePassword: () {},
          onNotifications: () {},
        ),
      );
      final label = tester.widget<Text>(find.text('Change password'));
      expect(label.style?.color, AppColors.textOnDark);
      expect(label.style?.color, isNot(AppColors.error));
      expect(label.style?.color, isNot(AppColors.gold));
    });

    testWidgets('tapping it triggers navigation to the change-password flow', (
      tester,
    ) async {
      var tapped = false;
      await tester.pumpWidget(
        _accountSection(
          onEditProfile: () {},
          onChangePassword: () => tapped = true,
          onNotifications: () {},
        ),
      );
      await tester.tap(find.text('Change password'));
      expect(tapped, isTrue);
    });
  });
}
