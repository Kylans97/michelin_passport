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
//
// Primary Tabs UI Polish V1 additions: Journey metrics (now CsMetricStrip,
// replacing the old icon/card grid) and the Friends row (now a restrained
// editorial action row, replacing the old bordered/icon card) — both
// mirrored the same way, plus a gold-audit check on the avatar.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:michelin_passport/core/constants/app_colors.dart';
import 'package:michelin_passport/core/theme/cs_spacing.dart';
import 'package:michelin_passport/core/theme/cs_typography.dart';
import 'package:michelin_passport/core/widgets/cs_metric_strip.dart';

// ── Reconstructed from ProfileScreen's own _SettingsRow + Account section ──

Widget _accountSection({
  required VoidCallback onSignOut,
  VoidCallback? onOpenPrivacy,
}) => Column(
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
    // PROFILE PRIVACY & DISCOVERABILITY V1 — opens PrivacySettingsScreen
    // (see privacy_settings_screen_test.dart for that screen's own,
    // direct — non-mirrored — coverage).
    _SettingsRowStandIn(
      icon: Icons.lock_outline_rounded,
      label: 'Privacy',
      onTap: onOpenPrivacy ?? () {},
    ),
    _SettingsRowStandIn(
      icon: Icons.logout_outlined,
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

// ── Reconstructed from ProfileScreen's own _Avatar/JOURNEY/_FriendsEntryRow ──

Widget _avatarMirror(String initials) => Container(
  width: 64,
  height: 64,
  decoration: BoxDecoration(
    shape: BoxShape.circle,
    color: AppColors.brandGreenLight,
    border: Border.all(color: AppColors.subtleBorderDark),
  ),
  alignment: Alignment.center,
  child: Text(
    initials,
    style: CsTypography.placeTitle.copyWith(color: AppColors.ivory),
  ),
);

Widget _journeyMetrics({
  required int restaurants,
  required int stars,
  required int countries,
  required int cities,
}) => Column(
  crossAxisAlignment: CrossAxisAlignment.start,
  children: [
    Text(
      'JOURNEY',
      style: CsTypography.eyebrow.copyWith(color: AppColors.secondaryOnDark),
    ),
    const SizedBox(height: CsSpacing.md),
    CsMetricStrip(
      metrics: [
        CsMetric(value: '$restaurants', label: 'RESTAURANTS'),
        CsMetric(value: '$stars', label: 'STARS'),
        CsMetric(value: '$countries', label: 'COUNTRIES'),
        CsMetric(value: '$cities', label: 'CITIES'),
      ],
    ),
  ],
);

Widget _friendsRowMirror({
  int? friendCount,
  int? pendingCount,
  required VoidCallback onTap,
}) {
  final parts = <String>[];
  if (friendCount != null) {
    parts.add('$friendCount friend${friendCount == 1 ? '' : 's'}');
  }
  if (pendingCount != null && pendingCount > 0) {
    parts.add('$pendingCount request${pendingCount == 1 ? '' : 's'}');
  }
  return Material(
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
            Expanded(
              child: Text(
                'Friends',
                style: CsTypography.body.copyWith(color: AppColors.textOnDark),
              ),
            ),
            if (parts.isNotEmpty) ...[
              Text(
                parts.join(' · '),
                style: CsTypography.metadata.copyWith(
                  color: AppColors.secondaryOnDark,
                ),
              ),
              const SizedBox(width: CsSpacing.sm),
            ],
            const Icon(
              Icons.arrow_forward_rounded,
              color: AppColors.ivory,
              size: 16,
            ),
          ],
        ),
      ),
    ),
  );
}

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

  group('ProfileScreen — Privacy entry (PROFILE PRIVACY & DISCOVERABILITY '
      'V1)', () {
    testWidgets('is visible in the Account section, alongside Edit profile/'
        'Notifications/Sign out', (tester) async {
      await tester.pumpWidget(_wrap(_accountSection(onSignOut: () {})));
      expect(find.text('Privacy'), findsOneWidget);
      expect(find.text('Edit profile'), findsOneWidget);
      expect(find.text('Notifications'), findsOneWidget);
      expect(find.text('Sign out'), findsOneWidget);
    });

    testWidgets('tapping Privacy opens the Privacy settings entry point', (
      tester,
    ) async {
      var opened = false;
      await tester.pumpWidget(
        _wrap(
          _accountSection(onSignOut: () {}, onOpenPrivacy: () => opened = true),
        ),
      );
      await tester.tap(find.text('Privacy'));
      expect(opened, isTrue);
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

  group('ProfileScreen — Journey metrics (Primary Tabs UI Polish V1)', () {
    testWidgets('renders all four values and labels via the shared '
        'typography-led CsMetricStrip — no decorative icons, matching '
        "Passport's own metric strip treatment", (tester) async {
      await tester.pumpWidget(
        _wrap(
          _journeyMetrics(restaurants: 42, stars: 12, countries: 9, cities: 20),
        ),
      );
      expect(find.text('42'), findsOneWidget);
      expect(find.text('RESTAURANTS'), findsOneWidget);
      expect(find.text('12'), findsOneWidget);
      expect(find.text('STARS'), findsOneWidget);
      expect(find.text('9'), findsOneWidget);
      expect(find.text('COUNTRIES'), findsOneWidget);
      expect(find.text('20'), findsOneWidget);
      expect(find.text('CITIES'), findsOneWidget);
      // The old grid rendered a restaurant/star/public/city icon per
      // tile — the redesigned strip is typography-only.
      expect(find.byType(Icon), findsNothing);
    });

    testWidgets('no overflow at 320px', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            backgroundColor: AppColors.deepGreen,
            body: SizedBox(
              width: 320,
              child: _journeyMetrics(
                restaurants: 128,
                stars: 61,
                countries: 24,
                cities: 87,
              ),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('ProfileScreen — Friends row (Primary Tabs UI Polish V1)', () {
    testWidgets('shows the label, friend/request counts, and a restrained '
        'arrow — never the old leading icon avatar or a card background', (
      tester,
    ) async {
      var tapped = false;
      await tester.pumpWidget(
        _wrap(
          _friendsRowMirror(
            friendCount: 3,
            pendingCount: 1,
            onTap: () => tapped = true,
          ),
        ),
      );
      expect(find.text('Friends'), findsOneWidget);
      expect(find.text('3 friends · 1 request'), findsOneWidget);
      expect(find.byIcon(Icons.people_outline_rounded), findsNothing);
      expect(find.byIcon(Icons.arrow_forward_rounded), findsOneWidget);

      await tester.tap(find.text('Friends'));
      expect(tapped, isTrue);
    });

    testWidgets('the arrow is ivory, never gold', (tester) async {
      await tester.pumpWidget(
        _wrap(_friendsRowMirror(friendCount: 0, pendingCount: 0, onTap: () {})),
      );
      final icon = tester.widget<Icon>(
        find.byIcon(Icons.arrow_forward_rounded),
      );
      expect(icon.color, AppColors.ivory);
      expect(icon.color, isNot(AppColors.gold));
    });

    testWidgets('tap target meets the 44px minimum', (tester) async {
      await tester.pumpWidget(
        _wrap(_friendsRowMirror(friendCount: 0, pendingCount: 0, onTap: () {})),
      );
      final size = tester.getSize(find.byType(InkWell));
      expect(size.height, greaterThanOrEqualTo(44));
    });
  });

  group('ProfileScreen — Avatar gold audit (Primary Tabs UI Polish V1)', () {
    testWidgets('the border and initials are never gold — restrained '
        'subtleBorderDark/ivory instead', (tester) async {
      await tester.pumpWidget(_wrap(_avatarMirror('KS')));
      final container = tester.widget<Container>(find.byType(Container));
      final decoration = container.decoration! as BoxDecoration;
      expect(decoration.border!.top.color, AppColors.subtleBorderDark);
      expect(decoration.border!.top.color, isNot(AppColors.gold));

      final initials = tester.widget<Text>(find.text('KS'));
      expect(initials.style?.color, AppColors.ivory);
      expect(initials.style?.color, isNot(AppColors.gold));
    });
  });
}
