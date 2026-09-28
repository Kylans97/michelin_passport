// Covers ProfileScreen's redesigned states. ProfileScreen constructs
// repositories against Supabase.instance.client eagerly in initState (same
// established limitation as every other screen in this app that touches
// Supabase there), so it can't be pumped directly — this reconstructs the
// exact widgets/copy from lib/features/profile/profile_screen.dart,
// mirroring this codebase's established "test the presentation seam"
// precedent.
//
// PROFILE UI REDESIGN V1: ACCOUNT holds only Edit profile/Notifications/
// Privacy. Friends sits under a "SOCIAL" section. The avatar mirror is
// gone — MemberAvatar is a real, Supabase-free widget now, covered
// directly in member_avatar_test.dart.
//
// FINAL VISUAL REFINEMENT: Sign out/Delete account no longer sit under an
// "ACCOUNT ACTIONS" eyebrow (see profile_delete_account_entry_test.dart
// for that pairing's own coverage) — generous spacing plus Delete
// account's own destructive tint read as a group without a label.
//
// JOURNEY CARD REFINEMENT: Your Journey is no longer mirrored here at
// all — it's now a single `JourneyCard` (lib/features/profile/
// journey_card.dart), a real, Supabase-free widget pumped DIRECTLY in
// journey_card_test.dart (metric semantics/calculation logic itself
// stays covered, unchanged, by journey_metrics_test.dart). The same pass
// also moved "Member since …" out of the identity hero and into
// JourneyCard's own stamp — the hero mirror below no longer renders or
// asserts a Member since line.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:michelin_passport/core/constants/app_colors.dart';
import 'package:michelin_passport/core/theme/cs_spacing.dart';
import 'package:michelin_passport/core/theme/cs_typography.dart';
import 'package:michelin_passport/core/widgets/member_avatar.dart';
import 'package:michelin_passport/models/managed_venue.dart';
import 'package:michelin_passport/models/restaurant.dart';

// ── Reconstructed from ProfileScreen's own _SettingsRow + section split ──

Widget _accountSection({VoidCallback? onOpenPrivacy}) => Column(
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
  ],
);

// FINAL VISUAL REFINEMENT — no "ACCOUNT ACTIONS" eyebrow above these rows
// (see ProfileScreen.build's own comment for why it was removed).
Widget _accountActionsSection({required VoidCallback onSignOut}) => Column(
  crossAxisAlignment: CrossAxisAlignment.start,
  children: [
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

// Mirrors profile_screen.dart's own FutureBuilder-gated "My venues" row
// exactly — hidden (SizedBox.shrink) on null/empty, shown otherwise. The
// gating is the entire point of this row (§2 of the task that built it:
// "invisible to users who manage nothing"), so it's tested here as its
// own reconstructed unit rather than only implied by the rest of the
// section rendering.
Widget _myVenuesRow(Future<List<ManagedVenue>> future, {required VoidCallback onTap}) =>
    FutureBuilder<List<ManagedVenue>>(
      future: future,
      builder: (context, snap) {
        final venues = snap.data;
        if (venues == null || venues.isEmpty) return const SizedBox.shrink();
        return _SettingsRowStandIn(icon: Icons.dashboard_outlined, label: 'My venues', onTap: onTap);
      },
    );

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

// ── Reconstructed from ProfileScreen's own _IdentityHero ────────────────
//
// FINAL VISUAL REFINEMENT — the standalone trailing pencil IconButton
// this hero used to render is gone; [MemberAvatar]'s own `onEdit` pencil
// badge is now the ONLY edit affordance. Uses the REAL [MemberAvatar]
// widget (no Supabase dependency, so no mirror needed for it), matching
// _IdentityHero's own composition exactly.
//
// JOURNEY CARD REFINEMENT — no `memberSince` parameter/line anymore: that
// fact moved to JourneyCard's own stamp (see journey_card_test.dart) so
// it appears in exactly one place, never duplicated.
Widget _identityHero({
  required String name,
  String? username,
  required VoidCallback onEditAvatar,
}) => Row(
  crossAxisAlignment: CrossAxisAlignment.center,
  children: [
    MemberAvatar(
      avatarUrl: null,
      displayName: name,
      size: 76,
      onEdit: onEditAvatar,
    ),
    const SizedBox(width: CsSpacing.base),
    Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: CsTypography.placeTitle.copyWith(color: AppColors.textOnDark),
          ),
          if (username != null) ...[
            const SizedBox(height: 2),
            Text(
              '@$username',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: CsTypography.metadata.copyWith(
                color: AppColors.secondaryOnDark,
              ),
            ),
          ],
        ],
      ),
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
  group('ProfileScreen — Sign Out (no ACCOUNT ACTIONS heading)', () {
    testWidgets('is visible immediately, in a plain list, not a submenu', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(_accountActionsSection(onSignOut: () {})),
      );
      // No nested Drawer/PopupMenu/second dialog needed to find it — it's
      // found directly, without any prior interaction, and without an
      // "ACCOUNT ACTIONS" eyebrow above it (removed for a calmer
      // composition — generous spacing plus Delete account's own
      // destructive tint read as a group without a label).
      expect(find.text('Sign out'), findsOneWidget);
      expect(find.text('ACCOUNT ACTIONS'), findsNothing);
      expect(find.byType(PopupMenuButton), findsNothing);
      expect(find.byType(Drawer), findsNothing);
    });

    testWidgets('tapping Sign Out invokes the sign-out callback (stands '
        'in for AuthRepository.signOut())', (tester) async {
      var signedOut = false;
      await tester.pumpWidget(
        _wrap(_accountActionsSection(onSignOut: () => signedOut = true)),
      );
      await tester.tap(find.text('Sign out'));
      expect(signedOut, isTrue);
    });

    testWidgets('no second/alternate logout control exists', (tester) async {
      await tester.pumpWidget(
        _wrap(_accountActionsSection(onSignOut: () {})),
      );
      expect(find.text('Sign out'), findsOneWidget);
      expect(find.textContaining('Log out'), findsNothing);
      expect(find.textContaining('Logout'), findsNothing);
    });

    testWidgets('tap target meets the 44px minimum', (tester) async {
      await tester.pumpWidget(
        _wrap(_accountActionsSection(onSignOut: () {})),
      );
      final size = tester.getSize(find.widgetWithText(InkWell, 'Sign out'));
      expect(size.height, greaterThanOrEqualTo(44));
    });
  });

  group('ProfileScreen — Privacy entry (PROFILE PRIVACY & DISCOVERABILITY '
      'V1)', () {
    testWidgets('is visible in the Account section, alongside Edit profile/'
        'Notifications', (tester) async {
      await tester.pumpWidget(_wrap(_accountSection()));
      expect(find.text('Privacy'), findsOneWidget);
      expect(find.text('Edit profile'), findsOneWidget);
      expect(find.text('Notifications'), findsOneWidget);
    });

    testWidgets('tapping Privacy opens the Privacy settings entry point', (
      tester,
    ) async {
      var opened = false;
      await tester.pumpWidget(
        _wrap(_accountSection(onOpenPrivacy: () => opened = true)),
      );
      await tester.tap(find.text('Privacy'));
      expect(opened, isTrue);
    });
  });

  group('ProfileScreen — Identity hero (FINAL VISUAL REFINEMENT: single '
      'edit affordance)', () {
    testWidgets('shows exactly one edit affordance — the avatar\'s own '
        'pencil badge — never a second standalone pencil', (tester) async {
      await tester.pumpWidget(
        _wrap(
          _identityHero(
            name: 'Kylan Scheepstra',
            username: 'admin',
            onEditAvatar: () {},
          ),
        ),
      );
      expect(find.byIcon(Icons.edit_outlined), findsOneWidget);
      expect(find.byType(IconButton), findsNothing);
    });

    testWidgets('tapping the avatar\'s edit badge invokes onEditAvatar', (
      tester,
    ) async {
      var tapped = false;
      await tester.pumpWidget(
        _wrap(
          _identityHero(
            name: 'Kylan Scheepstra',
            username: 'admin',
            onEditAvatar: () => tapped = true,
          ),
        ),
      );
      await tester.tap(find.byType(InkWell));
      expect(tapped, isTrue);
    });

    testWidgets('name and @username render — no "Member since" line (moved '
        'to JourneyCard\'s own stamp, never duplicated here)', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          _identityHero(
            name: 'Kylan Scheepstra',
            username: 'admin',
            onEditAvatar: () {},
          ),
        ),
      );
      expect(find.text('Kylan Scheepstra'), findsOneWidget);
      expect(find.text('@admin'), findsOneWidget);
      expect(find.textContaining('Member since'), findsNothing);
      expect(find.byType(Chip), findsNothing);
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

  group('ProfileScreen — Friends row (now under SOCIAL)', () {
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

  group('ProfileScreen — "My venues" entry (read-only manager entry point)', () {
    testWidgets('a user who manages nothing sees no trace of the row — '
        'not even a placeholder or a zero state', (tester) async {
      await tester.pumpWidget(
        _wrap(_myVenuesRow(Future.value(const []), onTap: () {})),
      );
      await tester.pumpAndSettle();
      expect(find.text('My venues'), findsNothing);
      expect(find.byIcon(Icons.dashboard_outlined), findsNothing);
    });

    testWidgets('still loading (future not yet resolved) also shows '
        'nothing — never a flash of the row before it can be hidden', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(_myVenuesRow(Completer<List<ManagedVenue>>().future, onTap: () {})),
      );
      expect(find.text('My venues'), findsNothing);
    });

    testWidgets('a failed load is treated the same as managing nothing — '
        'hidden, not an error row', (tester) async {
      // A Completer, completed with an error only AFTER pumpWidget —
      // FutureBuilder's own listener is already attached by then, so
      // there's no race with Dart's zone-level "unhandled Future error"
      // check (which a pre-rejected future created before pumpWidget can
      // lose, since argument evaluation happens before pumpWidget's own
      // guarded zone is entered). Standard pattern for testing
      // FutureBuilder's error branch deterministically.
      final completer = Completer<List<ManagedVenue>>();
      await tester.pumpWidget(_wrap(_myVenuesRow(completer.future, onTap: () {})));
      completer.completeError(Exception('boom'));
      await tester.pumpAndSettle();
      expect(find.text('My venues'), findsNothing);
    });

    testWidgets('a manager of at least one venue sees the row, and can tap '
        'it', (tester) async {
      var tapped = false;
      final restaurant = Restaurant.fromJson({
        'id': 'r1',
        'name': 'Flore Amsterdam',
        'city_name': 'Amsterdam',
      });
      await tester.pumpWidget(
        _wrap(
          _myVenuesRow(
            Future.value([ManagedRestaurant(restaurant)]),
            onTap: () => tapped = true,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('My venues'), findsOneWidget);
      await tester.tap(find.text('My venues'));
      expect(tapped, isTrue);
    });
  });
}
