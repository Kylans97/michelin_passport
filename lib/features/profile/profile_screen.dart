import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/constants/app_colors.dart';
import '../../core/theme/cs_spacing.dart';
import '../../core/theme/cs_typography.dart';
import '../../core/utils/username_rules.dart';
import '../../core/widgets/country_picker_sheet.dart';
import '../../core/widgets/cs_primary_button.dart';
import '../../core/widgets/cs_text_field.dart';
import '../../core/widgets/floating_nav_bar.dart';
import '../../core/widgets/member_avatar.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/repositories/event_confirmed_attendance_repository.dart';
import '../../data/repositories/friendship_repository.dart';
import '../../data/repositories/notifications_repository.dart';
import '../../data/repositories/profile_repository.dart';
import '../../data/repositories/visited_repository.dart';
import '../../models/user_profile.dart';
import '../../models/venue_country.dart';
import '../../models/venue_entry.dart';
import '../friends/friends_screen.dart';
import '../notifications/notifications_screen.dart';
import 'change_avatar_sheet.dart';
import 'change_password_screen.dart';
import 'delete_account_screen.dart';
import 'journey_card.dart';
import 'journey_metrics.dart';
import 'privacy_settings_screen.dart';

/// My Profile — PROFILE UI REDESIGN V1.
///
/// Profile answers "who am I and what is the shape of my overall
/// journey" — deliberately distinct from Passport's own "what have I
/// collected/visited/rated/planned" AND from Passport's own per-category
/// Restaurants/Hotels/Events filtering — so Your Journey below is a
/// compact TOTAL summary (Places/Countries only; see
/// `journey_metrics.dart` for the exact, audited definition of each),
/// never a restatement of anything Passport already shows in detail.
///
/// Dark editorial canvas, matching Explore/Guides/Trips/Auth. Root tab
/// screen (reached via bottom navigation) — no back button, matching
/// Passport/Explore/Rankings/Wishlist's own root-tab treatment.
///
/// The previous version of this screen also rendered a tier badge,
/// "Community Stats" (tier distribution), and "Trophies" — all three
/// depended on database views/tables (`user_tiers`, `tier_stats`,
/// `trophies`, `user_trophies`) that were dropped when the production
/// schema was rebuilt and never recreated; those sections were removed
/// (not hidden) in an earlier pass and stay removed here.
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
  late final _notificationsRepo = NotificationsRepository(
    Supabase.instance.client,
  );
  late final _eventAttendanceRepo = EventConfirmedAttendanceRepository(
    Supabase.instance.client,
  );

  late Future<UserProfile> _profileFuture;
  late Future<String?> _avatarUrlFuture;
  late Future<JourneyMetrics> _journeyFuture;
  late Future<_FriendsSummary> _friendsSummaryFuture;
  late Future<int> _unreadNotificationCountFuture;

  // Loaded once, not re-fetched on pull-to-refresh (_load) — the running
  // build's own version/build number can't change at runtime.
  late final Future<PackageInfo> _packageInfoFuture = PackageInfo.fromPlatform();

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

      // Chained off the profile load — avatarPath is only known once the
      // profile row itself has loaded. resolveAvatarUrl returns null
      // (no network call) when there's nothing to resolve, so this stays
      // cheap for every member who hasn't set a photo yet.
      _avatarUrlFuture = _profileFuture.then(
        (profile) => _profileRepo.resolveAvatarUrl(profile.avatarPath),
      );

      // Places = restaurants + hotels + confirmed-attendance events
      // combined (see journey_metrics.dart) — just these same two lists,
      // no Trips query needed anymore now the card no longer shows one.
      _journeyFuture = Future.wait([
        _visitedRepo.loadPassportVenues(_uid),
        _eventAttendanceRepo.loadPassportEventAttendance(_uid),
      ]).then(
        (results) => computeJourneyMetrics(
          passportVenues: results[0] as List<VenueEntry>,
          confirmedEventAttendance: results[1] as List<EventAttendanceEntry>,
        ),
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

      _unreadNotificationCountFuture = _notificationsRepo.getUnreadCount();
    });
  }

  Future<void> _signOut() async => _authRepo.signOut();

  void _openDeleteAccount() => Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => const DeleteAccountScreen()),
  );

  void _openChangePassword() => Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => const ChangePasswordScreen()),
  );

  void _openPrivacySettings() => Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => const PrivacySettingsScreen()),
  );

  // Same external-browser pattern RestaurantDetailScreen/HotelDetailScreen
  // already use for venue links — never an in-app webview. Apple requires
  // the privacy policy be reachable from inside the app itself, not only
  // from the App Store listing; this is that requirement's entry point.
  Future<void> _openExternal(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _openEditProfile(UserProfile profile) async {
    // Awaited (not passed as a Future) so the sheet can show the member's
    // actual current photo immediately rather than always starting on the
    // initials fallback — cheap since resolveAvatarUrl is already loaded
    // or loading by the time any entry point can reach this method.
    final avatarUrl = await _avatarUrlFuture;
    if (!mounted) return;
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _EditProfileSheet(
        userId: _uid,
        profileRepo: _profileRepo,
        initialDisplayName: profile.name,
        initialUsername: profile.username,
        currentAvatarPath: profile.avatarPath,
        currentAvatarUrl: avatarUrl,
        initialHomeCountryCode: profile.homeCountryCode,
      ),
    );
    if (saved == true) _load();
  }

  Future<void> _openChangeAvatar(UserProfile profile) async {
    final changed = await ChangeAvatarSheet.show(
      context,
      userId: _uid,
      currentAvatarPath: profile.avatarPath,
    );
    if (changed == true) _load();
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
              // position. bottom: false, matching every other top-level
              // tab screen — the floating nav pill isn't part of Scaffold's
              // own layout anymore (see app.dart), so this list's own
              // bottom padding is the only thing keeping Sign out/Delete
              // account clear of it; floatingNavClearance() already folds
              // in the device's own safe-area inset, so SafeArea handling
              // it too would double-count that inset.
              bottom: false,
              child: ListView(
                padding: EdgeInsets.fromLTRB(
                  CsSpacing.pageHorizontal,
                  CsSpacing.lg,
                  CsSpacing.pageHorizontal,
                  floatingNavClearance(context),
                ),
                children: [
                  Text(
                    'Profile',
                    style: CsTypography.screenTitle.copyWith(
                      color: AppColors.ivory,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Your place in Mantelier.',
                    style: CsTypography.metadata.copyWith(
                      color: AppColors.secondaryOnDark,
                    ),
                  ),
                  const SizedBox(height: CsSpacing.xxl),

                  FutureBuilder<String?>(
                    future: _avatarUrlFuture,
                    builder: (context, avatarSnap) => _IdentityHero(
                      user: user,
                      avatarUrl: avatarSnap.data,
                      onEditAvatar: () => _openChangeAvatar(user),
                    ),
                  ),

                  if (user.username == null) ...[
                    const SizedBox(height: CsSpacing.lg),
                    _ChooseUsernameBanner(onTap: () => _openEditProfile(user)),
                  ],

                  const SizedBox(height: CsSpacing.xxl),
                  FutureBuilder<JourneyMetrics>(
                    future: _journeyFuture,
                    builder: (context, journeySnap) {
                      final journey = journeySnap.data;
                      if (journey == null) {
                        return const SizedBox(
                          height: 140,
                          child: Center(
                            child: SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 1.5,
                                color: AppColors.secondaryOnDark,
                              ),
                            ),
                          ),
                        );
                      }
                      return JourneyCard(
                        journey: journey,
                        memberSince: user.memberSince,
                      );
                    },
                  ),

                  const SizedBox(height: CsSpacing.xxl),
                  const TripSectionLabelStandIn('SOCIAL'),
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

                  const SizedBox(height: CsSpacing.xxl),
                  const TripSectionLabelStandIn('ACCOUNT'),
                  const SizedBox(height: CsSpacing.md),
                  _SettingsRow(
                    icon: Icons.edit_outlined,
                    label: 'Edit profile',
                    onTap: () => _openEditProfile(user),
                  ),
                  _SettingsRow(
                    icon: Icons.lock_reset_outlined,
                    label: 'Change password',
                    onTap: _openChangePassword,
                  ),
                  FutureBuilder<int>(
                    future: _unreadNotificationCountFuture,
                    builder: (context, unreadSnap) => _SettingsRow(
                      icon: Icons.notifications_outlined,
                      label: 'Notifications',
                      badgeCount: unreadSnap.data,
                      onTap: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const NotificationsScreen(),
                          ),
                        );
                        // NotificationsScreen marks everything read on
                        // open — refresh so the badge reflects that
                        // immediately on return, not on the next full
                        // profile reload.
                        if (mounted) {
                          setState(() {
                            _unreadNotificationCountFuture =
                                _notificationsRepo.getUnreadCount();
                          });
                        }
                      },
                    ),
                  ),
                  _SettingsRow(
                    icon: Icons.lock_outline_rounded,
                    label: 'Privacy',
                    onTap: _openPrivacySettings,
                  ),

                  // FINAL VISUAL REFINEMENT — no "ACCOUNT ACTIONS" eyebrow:
                  // Sign out/Delete account read clearly as their own
                  // group from generous spacing alone (and Delete
                  // account's own destructive tint), matching this pass's
                  // "calmer composition" preference over a label that
                  // added little beyond what the spacing and color already
                  // communicate.
                  const SizedBox(height: CsSpacing.xxl),
                  _SettingsRow(
                    // Icon audit: was logout_rounded (solid), the only
                    // filled icon among this list's otherwise
                    // outline-stroke icons — normalized to match.
                    icon: Icons.logout_outlined,
                    label: 'Sign out',
                    onTap: _signOut,
                  ),
                  // App Store readiness — real, findable, not buried
                  // behind Privacy/Terms/About/support email. Error-tinted
                  // (not gold, not the neutral secondaryOnDark other rows
                  // use) purely as a destructive-action clarity signal —
                  // not a dark pattern; the row is exactly as large and
                  // easy to tap as every other row above it.
                  _SettingsRow(
                    icon: Icons.delete_outline_rounded,
                    label: 'Delete account',
                    color: AppColors.error,
                    onTap: _openDeleteAccount,
                  ),

                  // Legal/info footer — deliberately separated from the
                  // ACCOUNT actions above by extra space rather than its
                  // own eyebrow label, matching this screen's existing
                  // "spacing alone signals a new group" convention. The
                  // open-in-new (not chevron) trailing icon marks these as
                  // leaving the app, not pushing a route.
                  const SizedBox(height: CsSpacing.xxl),
                  _SettingsRow(
                    icon: Icons.public_rounded,
                    label: 'Website',
                    trailingIcon: Icons.open_in_new_rounded,
                    onTap: () => _openExternal('https://mantelier.app'),
                  ),
                  _SettingsRow(
                    icon: Icons.privacy_tip_outlined,
                    label: 'Privacy policy',
                    trailingIcon: Icons.open_in_new_rounded,
                    onTap: () =>
                        _openExternal('https://mantelier.app/privacy'),
                  ),
                  const SizedBox(height: CsSpacing.lg),
                  FutureBuilder<PackageInfo>(
                    future: _packageInfoFuture,
                    builder: (context, infoSnap) {
                      final info = infoSnap.data;
                      if (info == null) return const SizedBox.shrink();
                      return Center(
                        child: Text(
                          'Mantelier ${info.version} (${info.buildNumber})',
                          style: CsTypography.metadata.copyWith(
                            color: AppColors.secondaryOnDark.withValues(
                              alpha: 0.6,
                            ),
                          ),
                        ),
                      );
                    },
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

// ── Identity hero: avatar, name, @username, edit ────────────────────────

/// PROFILE UI REDESIGN V1 — replaces the previous compact `_ProfileHeader`
/// row. Still a header, not a dashboard card: no background fill, no
/// border, no gold — an ivory serif identity block on the bare deep-green
/// canvas, exactly like Explore/Passport's own editorial headers.
///
/// FINAL VISUAL REFINEMENT — the standalone trailing pencil this hero
/// used to show (a second, redundant edit affordance alongside the
/// avatar's own) is gone. [MemberAvatar]'s own `onEdit` pencil badge is
/// now the ONLY edit affordance in this hero, and its semantic meaning is
/// narrowed to exactly what it visually points at: change/add/remove the
/// photo. General profile editing (name/username) is reached from the
/// existing "Edit profile" row in the ACCOUNT section below — unchanged
/// by this pass.
///
/// JOURNEY CARD REFINEMENT — the "Member since …" line that used to sit
/// under @username is gone too: that same date now appears exactly once,
/// as the join-date stamp on [JourneyCard] below (see
/// `journey_card.dart`'s `journeyStampLabel`). Judged not to harm this
/// hero's hierarchy — Name/@username alone is still a complete, clean
/// identity block, and removing the third line is a genuine declutter,
/// not a loss.
class _IdentityHero extends StatelessWidget {
  final UserProfile user;
  final String? avatarUrl;
  final VoidCallback onEditAvatar;
  const _IdentityHero({
    required this.user,
    required this.avatarUrl,
    required this.onEditAvatar,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        MemberAvatar(
          avatarUrl: avatarUrl,
          displayName: user.name,
          size: 76,
          onEdit: onEditAvatar,
        ),
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
      ],
    );
  }
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

/// A restrained editorial action row — the same "label … detail →"
/// language as Community's `_CommunityActionLink` (no card background, no
/// leading icon avatar) — so Friends reads as part of Profile's content
/// rather than a dashboard tile.
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
  // Defaults to the in-app-navigation chevron every existing row uses.
  // The Website/Privacy policy rows pass open_in_new instead, since
  // those leave the app rather than push a route.
  final IconData trailingIcon;
  // A small count pill between the label and the chevron — currently
  // only the Notifications row uses this (unread count). Null/zero
  // renders nothing, so every other existing row is unaffected.
  final int? badgeCount;
  const _SettingsRow({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
    this.trailingIcon = Icons.chevron_right_rounded,
    this.badgeCount,
  });

  @override
  Widget build(BuildContext context) {
    final tint = color ?? AppColors.secondaryOnDark;
    final count = badgeCount;
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
              // Never gold — Step 1B's color rule reserves gold for
              // Michelin stars/Keys only; an unread count is an
              // attention signal, matching the same AppColors.error
              // register Delete account already uses for that purpose.
              if (count != null && count > 0) ...[
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.error,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    count > 9 ? '9+' : '$count',
                    style: CsTypography.smallLabel.copyWith(
                      color: AppColors.textOnDark,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: CsSpacing.sm),
              ],
              Icon(trailingIcon, color: tint, size: 20),
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
  final String? currentAvatarPath;
  final String? currentAvatarUrl;
  final String? initialHomeCountryCode;
  const _EditProfileSheet({
    required this.userId,
    required this.profileRepo,
    required this.initialDisplayName,
    required this.initialUsername,
    required this.currentAvatarPath,
    required this.currentAvatarUrl,
    required this.initialHomeCountryCode,
  });

  @override
  State<_EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends State<_EditProfileSheet> {
  late final _nameCtrl = TextEditingController(text: widget.initialDisplayName);
  late final _usernameCtrl = TextEditingController(
    text: widget.initialUsername ?? '',
  );
  // Internal-only field (see UserProfile.homeCountryCode's own doc comment)
  // — never shown to other users, so this sheet is the only place it's
  // ever read back after being set.
  VenueCountry? _country;
  // True once the initial code (if any) has been resolved against the
  // full country list — distinguishes "still loading the flag/name for an
  // existing selection" from "genuinely not set" so the field never
  // flashes "Not set" before correcting itself.
  bool _countryResolved = false;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final code = widget.initialHomeCountryCode;
    if (code == null) {
      _countryResolved = true;
      return;
    }
    widget.profileRepo.getAllCountries().then((all) {
      if (!mounted) return;
      setState(() {
        _country = all.where((c) => c.code == code).firstOrNull;
        _countryResolved = true;
      });
    });
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _usernameCtrl.dispose();
    super.dispose();
  }

  // Opens the same canonical photo-edit sheet the identity hero's avatar
  // tap uses (§26 of this feature's own spec: one mechanism, reached from
  // two places) — closes THIS sheet with `true` if the photo actually
  // changed, since the caller (ProfileScreen) reloads on any `true` pop
  // regardless of which field changed.
  Future<void> _changePhoto() async {
    final changed = await ChangeAvatarSheet.show(
      context,
      userId: widget.userId,
      currentAvatarPath: widget.currentAvatarPath,
    );
    if (changed == true && mounted) Navigator.pop(context, true);
  }

  // Never passes allowAll to showCountryPickerSheet: that reuses `null`
  // for both "an All/None option was tapped" and "the sheet was dismissed
  // without choosing anything" — indistinguishable at this call site, and
  // conflating them would silently clear a person's country if they just
  // swiped the sheet away. A null result here always means "no change";
  // clearing has its own explicit, separate affordance below.
  Future<void> _pickCountry() async {
    final all = await widget.profileRepo.getAllCountries();
    if (!mounted) return;
    final picked = await showCountryPickerSheet(context, countries: all);
    if (picked != null) setState(() => _country = picked);
  }

  void _clearCountry() => setState(() => _country = null);

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
      // Its own call, only when actually changed — updateProfile's
      // null-means-untouched convention can't express "clear this field",
      // which is exactly why updateHomeCountryCode is separate (see its
      // own doc comment).
      if (_country?.code != widget.initialHomeCountryCode) {
        await widget.profileRepo.updateHomeCountryCode(
          userId: widget.userId,
          homeCountryCode: _country?.code,
        );
      }
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
            // MT001 — check_username_not_blocked() trigger (username
            // blocklist migration).
            : e.code == 'MT001'
            ? 'That username is not allowed.'
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
              Center(
                child: Semantics(
                  button: true,
                  label: 'Change profile photo',
                  child: GestureDetector(
                    onTap: _changePhoto,
                    child: MemberAvatar(
                      avatarUrl: widget.currentAvatarUrl,
                      displayName: widget.initialDisplayName,
                      size: 64,
                      onEdit: _changePhoto,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: CsSpacing.lg),
              CsTextField(label: 'Name', controller: _nameCtrl),
              const SizedBox(height: CsSpacing.lg),
              CsTextField(label: 'Username', controller: _usernameCtrl),
              const SizedBox(height: CsSpacing.lg),
              _CountryField(
                country: _country,
                resolved: _countryResolved,
                onTap: _saving ? null : _pickCountry,
                onClear: _saving ? null : _clearCountry,
              ),
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

/// The tappable "Country" row in Edit Profile — visually matches
/// [CsTextField]'s own label/field shape (eyebrow label, ivory rounded
/// container) so it reads as one more field in the same form, not a
/// bolted-on control. A plain tap opens the picker; a separate "×" only
/// renders once a country is set, so clearing is its own explicit action
/// distinct from dismissing the picker without choosing (see
/// _EditProfileSheetState._pickCountry's own doc comment for why that
/// distinction matters).
class _CountryField extends StatelessWidget {
  final VenueCountry? country;
  final bool resolved;
  final VoidCallback? onTap;
  final VoidCallback? onClear;

  const _CountryField({
    required this.country,
    required this.resolved,
    required this.onTap,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final label = !resolved ? 'Loading…' : country?.name ?? 'Not set';
    final labelColor = country != null ? AppColors.charcoal : AppColors.taupe;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Country',
          style: CsTypography.eyebrow.copyWith(
            color: AppColors.secondaryOnDark,
          ),
        ),
        const SizedBox(height: CsSpacing.sm),
        Material(
          color: AppColors.ivory,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: CsSpacing.base,
                vertical: 16,
              ),
              child: Row(
                children: [
                  if (country != null && country!.flag.isNotEmpty) ...[
                    Text(country!.flag, style: const TextStyle(fontSize: 18)),
                    const SizedBox(width: CsSpacing.sm),
                  ],
                  Expanded(
                    child: Text(
                      label,
                      style: CsTypography.body.copyWith(color: labelColor),
                    ),
                  ),
                  if (country != null && onClear != null)
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: onClear,
                        borderRadius: BorderRadius.circular(12),
                        child: const Padding(
                          padding: EdgeInsets.all(4),
                          child: Icon(
                            Icons.close_rounded,
                            size: 18,
                            color: AppColors.taupe,
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(width: 2),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: AppColors.taupe,
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
