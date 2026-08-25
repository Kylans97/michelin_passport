import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants/app_colors.dart';
import '../../core/theme/cs_spacing.dart';
import '../../core/theme/cs_typography.dart';
import '../../core/utils/username_rules.dart';
import '../../core/widgets/cs_metric_strip.dart';
import '../../core/widgets/cs_primary_button.dart';
import '../../core/widgets/cs_text_field.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/repositories/friendship_repository.dart';
import '../../data/repositories/profile_repository.dart';
import '../../data/repositories/visited_repository.dart';
import '../../models/user_profile.dart';
import '../friends/friends_screen.dart';
import '../notifications/notifications_screen.dart';
import 'delete_account_screen.dart';
import 'privacy_settings_screen.dart';

/// My Profile — identity, Journey Stats (existing Passport-derived data,
/// unchanged computation), Friends entry, and account actions. Dark
/// editorial canvas, matching Explore/Guides/Trips/Auth. Root tab screen
/// (reached via bottom navigation) — no back button, matching Passport/
/// Explore/Rankings/Wishlist's own root-tab treatment.
///
/// The previous version of this screen also rendered a tier badge,
/// "Community Stats" (tier distribution), and "Trophies" — all three
/// depended on database views/tables (`user_tiers`, `tier_stats`,
/// `trophies`, `user_trophies`) that were dropped when the production
/// schema was rebuilt and never recreated (confirmed via a live read-only
/// query against the linked project during this task's audit); every
/// load of this screen has been throwing "Could not load profile" for
/// every user, unconditionally, since before this task started. Fixing
/// `getProfile` to stop depending on those means those three sections no
/// longer have real data to show — they are removed here, not hidden;
/// rebuilding tiers/trophies against a real schema is out of this step's
/// scope. `TrophyRepository`/`models/trophy.dart` are untouched (still
/// used elsewhere — see `notifications_screen.dart`/`rating_dialog.dart`
/// — just no longer referenced from this screen).
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late final _authRepo = AuthRepository(Supabase.instance.client);
  late final _visitedRepo = VisitedRepository(Supabase.instance.client);
  late final _profileRepo = ProfileRepository(Supabase.instance.client);
  late final _friendshipRepo = FriendshipRepository(Supabase.instance.client);

  late Future<UserProfile> _profileFuture;
  late Future<_FriendsSummary> _friendsSummaryFuture;

  final String _uid = Supabase.instance.client.auth.currentUser?.id ?? '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    setState(() {
      _profileFuture = _visitedRepo
          .getVisited(_uid)
          .then(
            (visited) =>
                _profileRepo.getProfile(userId: _uid, visited: visited),
          );
      // Genuinely cheap and already-needed data (the Friends screen itself
      // fetches the same two lists) — not a new aggregate query invented
      // purely to decorate this row, just the lengths of lists this
      // screen already has a reason to know about.
      _friendsSummaryFuture =
          Future.wait([
            _friendshipRepo.getFriends(),
            _friendshipRepo.getIncomingRequests(),
          ]).then(
            (results) => _FriendsSummary(
              friendCount: results[0].length,
              pendingCount: results[1].length,
            ),
          );
    });
  }

  Future<void> _signOut() async => _authRepo.signOut();

  void _openDeleteAccount() => Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => const DeleteAccountScreen()),
  );

  void _openPrivacySettings() => Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => const PrivacySettingsScreen()),
  );

  Future<void> _openEditProfile(UserProfile profile) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _EditProfileSheet(
        userId: _uid,
        profileRepo: _profileRepo,
        initialDisplayName: profile.name,
        initialUsername: profile.username,
      ),
    );
    if (saved == true) _load();
  }

  void _openFriends() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const FriendsScreen()),
    );
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.deepGreen,
      body: FutureBuilder<UserProfile>(
        future: _profileFuture,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(
                color: AppColors.gold,
                strokeWidth: 1.5,
              ),
            );
          }
          if (snap.hasError) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Could not load profile',
                    style: CsTypography.body.copyWith(
                      color: AppColors.secondaryOnDark,
                    ),
                  ),
                  const SizedBox(height: CsSpacing.md),
                  TextButton(
                    onPressed: _load,
                    child: Text(
                      'Retry',
                      style: CsTypography.bodyMedium.copyWith(
                        color: AppColors.gold,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }

          final user = snap.data!;

          return RefreshIndicator(
            color: AppColors.gold,
            backgroundColor: AppColors.brandGreenLight,
            onRefresh: () async => _load(),
            child: SafeArea(
              // Primary Tab Header Consistency Step 1: top padding is
              // CsSpacing.lg, matching Wishlist's reference title
              // position — was CsSpacing.md, which started "Profile"
              // higher than the other primary tabs.
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  CsSpacing.pageHorizontal,
                  CsSpacing.lg,
                  CsSpacing.pageHorizontal,
                  CsSpacing.section,
                ),
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Profile',
                        style: CsTypography.screenTitle.copyWith(
                          color: AppColors.ivory,
                        ),
                      ),
                      Tooltip(
                        message: 'Notifications',
                        child: IconButton(
                          icon: const Icon(
                            Icons.notifications_outlined,
                            color: AppColors.secondaryOnDark,
                          ),
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const NotificationsScreen(),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: CsSpacing.xl),

                  _ProfileHeader(
                    user: user,
                    onEdit: () => _openEditProfile(user),
                  ),

                  if (user.username == null) ...[
                    const SizedBox(height: CsSpacing.lg),
                    _ChooseUsernameBanner(onTap: () => _openEditProfile(user)),
                  ],

                  const SizedBox(height: CsSpacing.section),
                  const TripSectionLabelStandIn('JOURNEY'),
                  const SizedBox(height: CsSpacing.md),
                  CsMetricStrip(
                    metrics: [
                      CsMetric(
                        value: '${user.restaurantsVisited}',
                        label: 'RESTAURANTS',
                      ),
                      CsMetric(
                        value: '${user.michelinStarsCollected}',
                        label: 'STARS',
                      ),
                      CsMetric(
                        value: '${user.countriesVisited}',
                        label: 'COUNTRIES',
                      ),
                      CsMetric(value: '${user.citiesVisited}', label: 'CITIES'),
                    ],
                  ),

                  const SizedBox(height: CsSpacing.section),
                  const TripSectionLabelStandIn('FRIENDS'),
                  const SizedBox(height: CsSpacing.md),
                  FutureBuilder<_FriendsSummary>(
                    future: _friendsSummaryFuture,
                    builder: (context, friendsSnap) {
                      final summary = friendsSnap.data;
                      return _FriendsEntryRow(
                        friendCount: summary?.friendCount,
                        pendingCount: summary?.pendingCount,
                        onTap: _openFriends,
                      );
                    },
                  ),

                  const SizedBox(height: CsSpacing.section),
                  const TripSectionLabelStandIn('ACCOUNT'),
                  const SizedBox(height: CsSpacing.md),
                  _SettingsRow(
                    icon: Icons.edit_outlined,
                    label: 'Edit profile',
                    onTap: () => _openEditProfile(user),
                  ),
                  _SettingsRow(
                    icon: Icons.notifications_outlined,
                    label: 'Notifications',
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const NotificationsScreen(),
                      ),
                    ),
                  ),
                  _SettingsRow(
                    icon: Icons.lock_outline_rounded,
                    label: 'Privacy',
                    onTap: _openPrivacySettings,
                  ),
                  _SettingsRow(
                    // Icon audit: was logout_rounded (solid), the only
                    // filled icon among this list's four otherwise
                    // outline-stroke icons — normalized to match.
                    icon: Icons.logout_outlined,
                    label: 'Sign out',
                    onTap: _signOut,
                  ),
                  // App Store readiness — real, findable, not buried
                  // behind Privacy/Terms/About/support email. Error-tinted
                  // (not gold, not the neutral secondaryOnDark other rows
                  // use) purely as a destructive-action clarity signal,
                  // matching AppColors.error's existing use elsewhere in
                  // this app — not a dark pattern; the row is exactly as
                  // large and easy to tap as every other row above it.
                  _SettingsRow(
                    icon: Icons.delete_outline_rounded,
                    label: 'Delete account',
                    color: AppColors.error,
                    onTap: _openDeleteAccount,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _FriendsSummary {
  final int friendCount;
  final int pendingCount;
  const _FriendsSummary({
    required this.friendCount,
    required this.pendingCount,
  });
}

/// A quiet eyebrow section label matching Guides/Trips' own established
/// treatment (`CsTypography.eyebrow` on `secondaryOnDark`) — not importing
/// Trips' own `TripSectionLabel` (a Trips-internal component per that
/// feature's own scope), just the identical, tiny, already-proven pattern
/// reused locally.
class TripSectionLabelStandIn extends StatelessWidget {
  final String text;
  const TripSectionLabelStandIn(this.text, {super.key});

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: CsTypography.eyebrow.copyWith(color: AppColors.secondaryOnDark),
  );
}

// ── Header: avatar, name, @username ─────────────────────────────────────

class _ProfileHeader extends StatelessWidget {
  final UserProfile user;
  final VoidCallback onEdit;
  const _ProfileHeader({required this.user, required this.onEdit});

  @override
  Widget build(BuildContext context) {
    final initials = user.name
        .split(' ')
        .where((w) => w.isNotEmpty)
        .map((w) => w[0])
        .take(2)
        .join()
        .toUpperCase();

    return Row(
      children: [
        _Avatar(initials: initials.isEmpty ? '?' : initials),
        const SizedBox(width: CsSpacing.base),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                user.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: CsTypography.placeTitle.copyWith(
                  color: AppColors.textOnDark,
                ),
              ),
              if (user.username != null) ...[
                const SizedBox(height: 2),
                Text(
                  '@${user.username}',
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
        Tooltip(
          message: 'Edit profile',
          child: IconButton(
            icon: const Icon(
              Icons.edit_outlined,
              color: AppColors.secondaryOnDark,
              size: 20,
            ),
            onPressed: onEdit,
          ),
        ),
      ],
    );
  }
}

/// Gold audit (Primary Tabs UI Polish V1): the border/initials were gold
/// purely decoratively — no Michelin-recognition meaning — inconsistent
/// with gold being reserved for stars/Keys. Now `subtleBorderDark`/`ivory`,
/// matching the restrained editorial-identity treatment used everywhere
/// else on this screen.
class _Avatar extends StatelessWidget {
  final String initials;
  const _Avatar({required this.initials});

  @override
  Widget build(BuildContext context) => Container(
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
}

class _ChooseUsernameBanner extends StatelessWidget {
  final VoidCallback onTap;
  const _ChooseUsernameBanner({required this.onTap});

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.transparent,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(CsRadius.medium),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(CsSpacing.base),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.subtleBorderDark),
          borderRadius: BorderRadius.circular(CsRadius.medium),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.alternate_email_rounded,
              color: AppColors.ivory,
              size: 18,
            ),
            const SizedBox(width: CsSpacing.sm),
            Expanded(
              child: Text(
                'Choose a username so friends can find you',
                style: CsTypography.bodyMedium.copyWith(
                  color: AppColors.textOnDark,
                ),
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: AppColors.secondaryOnDark,
              size: 20,
            ),
          ],
        ),
      ),
    ),
  );
}

// ── Friends entry row ─────────────────────────────────────────────────

/// Simplified from a bordered/iconed card into a restrained editorial
/// action row — the same "label … detail →" language as Community's
/// `_CommunityActionLink` (no card background, no leading icon avatar) —
/// so Friends reads as part of Profile's content rather than a dashboard
/// tile. Tap target and semantics label are unchanged.
class _FriendsEntryRow extends StatelessWidget {
  final int? friendCount;
  final int? pendingCount;
  final VoidCallback onTap;
  const _FriendsEntryRow({
    required this.friendCount,
    required this.pendingCount,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final parts = <String>[];
    if (friendCount != null) {
      parts.add('$friendCount friend${friendCount == 1 ? '' : 's'}');
    }
    if (pendingCount != null && pendingCount! > 0) {
      parts.add('$pendingCount request${pendingCount == 1 ? '' : 's'}');
    }

    return Semantics(
      button: true,
      label: 'Friends. ${parts.join(', ')}',
      excludeSemantics: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(CsRadius.medium),
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
                    style: CsTypography.body.copyWith(
                      color: AppColors.textOnDark,
                    ),
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
      ),
    );
  }
}

// ── Account settings ──────────────────────────────────────────────────

class _SettingsRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  // Optional tint override — used only by the destructive "Delete
  // account" row (AppColors.error); every other row omits it and keeps
  // the original neutral secondaryOnDark/textOnDark styling unchanged.
  final Color? color;
  const _SettingsRow({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final tint = color ?? AppColors.secondaryOnDark;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(CsRadius.medium),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            vertical: CsSpacing.md,
            horizontal: CsSpacing.xs,
          ),
          child: Row(
            children: [
              Icon(icon, color: tint, size: 20),
              const SizedBox(width: CsSpacing.base),
              Expanded(
                child: Text(
                  label,
                  style: CsTypography.body.copyWith(
                    color: color ?? AppColors.textOnDark,
                  ),
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: tint, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Edit profile sheet ────────────────────────────────────────────────

class _EditProfileSheet extends StatefulWidget {
  final String userId;
  final ProfileRepository profileRepo;
  final String initialDisplayName;
  final String? initialUsername;
  const _EditProfileSheet({
    required this.userId,
    required this.profileRepo,
    required this.initialDisplayName,
    required this.initialUsername,
  });

  @override
  State<_EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends State<_EditProfileSheet> {
  late final _nameCtrl = TextEditingController(text: widget.initialDisplayName);
  late final _usernameCtrl = TextEditingController(
    text: widget.initialUsername ?? '',
  );
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _usernameCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    final username = UsernameRules.normalize(_usernameCtrl.text);
    if (name.isEmpty) {
      setState(() => _error = 'Enter a name');
      return;
    }
    final usernameError = UsernameRules.validate(username);
    if (usernameError != null) {
      setState(() => _error = usernameError);
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.profileRepo.updateProfile(
        userId: widget.userId,
        displayName: name,
        username: username,
      );
      if (!mounted) return;
      Navigator.pop(context, true);
    } on PostgrestException catch (e) {
      setState(() {
        _saving = false;
        _error = e.code == '23505'
            ? 'That username is already taken.'
            : e.code == '23514'
            ? 'Usernames are 3–30 characters: lowercase letters, numbers, '
                  '"_" or "." only.'
            : 'Could not save changes. Please try again.';
      });
    } catch (_) {
      setState(() {
        _saving = false;
        _error = 'Could not save changes. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SafeArea(
        top: false,
        child: Container(
          decoration: const BoxDecoration(
            color: AppColors.brandGreenLight,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: const EdgeInsets.fromLTRB(24, 14, 24, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.textOnDark.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: CsSpacing.xl),
              Text(
                'EDIT PROFILE',
                style: CsTypography.eyebrow.copyWith(
                  color: AppColors.secondaryOnDark,
                ),
              ),
              const SizedBox(height: CsSpacing.lg),
              CsTextField(label: 'Name', controller: _nameCtrl),
              const SizedBox(height: CsSpacing.lg),
              CsTextField(label: 'Username', controller: _usernameCtrl),
              if (_error != null) ...[
                const SizedBox(height: CsSpacing.base),
                Text(
                  _error!,
                  style: CsTypography.metadata.copyWith(color: AppColors.error),
                ),
              ],
              const SizedBox(height: CsSpacing.xl),
              SizedBox(
                width: double.infinity,
                child: CsPrimaryButton(
                  label: 'Save changes',
                  onTap: _save,
                  loading: _saving,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
