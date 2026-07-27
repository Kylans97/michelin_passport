import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants/app_colors.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/repositories/friendship_repository.dart';
import '../../data/repositories/profile_repository.dart';
import '../../data/repositories/trophy_repository.dart';
import '../../data/repositories/visited_repository.dart';
import '../../models/friendship.dart';
import '../../models/trophy.dart';
import '../../models/user_profile.dart';
import '../notifications/notifications_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late final _authRepo = AuthRepository(Supabase.instance.client);
  late final _visitedRepo = VisitedRepository(Supabase.instance.client);
  late final _profileRepo = ProfileRepository(Supabase.instance.client);
  late final _trophyRepo = TrophyRepository(Supabase.instance.client);
  late final _friendshipRepo = FriendshipRepository(Supabase.instance.client);

  late Future<UserProfile> _profileFuture;
  late Future<List<Trophy>> _trophyFuture;
  late Future<List<Friendship>> _friendsFuture;
  late Future<List<Map<String, dynamic>>> _communityFuture;

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
      _trophyFuture = _trophyRepo.getAllTrophies(_uid);
      _friendsFuture = _friendshipRepo.getFriends(_uid);
      _communityFuture = _profileRepo.getCommunityStats();
    });
  }

  Future<void> _signOut() async => _authRepo.signOut();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<UserProfile>(
      future: _profileFuture,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: AppColors.background,
            body: Center(
              child: CircularProgressIndicator(
                color: AppColors.gold,
                strokeWidth: 1.5,
              ),
            ),
          );
        }
        if (snap.hasError) {
          return Scaffold(
            backgroundColor: AppColors.background,
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Could not load profile',
                    style: GoogleFonts.inter(color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: _load,
                    child: Text(
                      'Retry',
                      style: GoogleFonts.inter(color: AppColors.gold),
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        final user = snap.data!;
        final initials = user.name
            .split(' ')
            .map((w) => w.isNotEmpty ? w[0] : '')
            .take(2)
            .join()
            .toUpperCase();

        return RefreshIndicator(
          color: AppColors.gold,
          backgroundColor: AppColors.card,
          onRefresh: () async => _load(),
          child: CustomScrollView(
            slivers: [
              // ── App bar with notifications bell ──────────────────────────
              SliverAppBar(
                title: const Text('Profile'),
                pinned: true,
                backgroundColor: AppColors.background,
                actions: [
                  IconButton(
                    icon: const Icon(
                      Icons.notifications_outlined,
                      color: AppColors.textSecondary,
                    ),
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const NotificationsScreen(),
                      ),
                    ),
                  ),
                ],
              ),

              SliverToBoxAdapter(
                child: Column(
                  children: [
                    // ── Avatar & name ─────────────────────────────────────
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 28, 24, 0),
                      child: Column(
                        children: [
                          Container(
                            width: 88,
                            height: 88,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppColors.goldMuted,
                              border: Border.all(
                                color: AppColors.goldBorder60,
                                width: 1.5,
                              ),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              initials,
                              style: GoogleFonts.playfairDisplay(
                                color: AppColors.gold,
                                fontSize: 30,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            user.name,
                            style: Theme.of(context).textTheme.headlineMedium,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            user.email,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          const SizedBox(height: 12),
                          // Tier badge
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.goldMuted,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: AppColors.goldBorder50,
                                width: 0.5,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.workspace_premium_rounded,
                                  color: AppColors.gold,
                                  size: 14,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  user.tier,
                                  style: GoogleFonts.inter(
                                    color: AppColors.gold,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    // ── Journey stats ─────────────────────────────────────
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 32, 20, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Journey Stats',
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              _StatTile(
                                value: '${user.restaurantsVisited}',
                                label: 'Restaurants',
                                icon: Icons.restaurant_rounded,
                              ),
                              const SizedBox(width: 10),
                              _StatTile(
                                value: '${user.michelinStarsCollected}',
                                label: 'Stars Earned',
                                icon: Icons.star_rounded,
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              _StatTile(
                                value: '${user.countriesVisited}',
                                label: 'Countries',
                                icon: Icons.public_rounded,
                              ),
                              const SizedBox(width: 10),
                              _StatTile(
                                value: '${user.citiesVisited}',
                                label: 'Cities',
                                icon: Icons.location_city_rounded,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // ── Star breakdown ────────────────────────────────────
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 32, 20, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Star Breakdown',
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                          const SizedBox(height: 16),
                          _StarBar(
                            stars: '★★★',
                            count: user.threeStarCount,
                            total: user.restaurantsVisited,
                          ),
                          const SizedBox(height: 10),
                          _StarBar(
                            stars: '★★',
                            count: user.twoStarCount,
                            total: user.restaurantsVisited,
                          ),
                          const SizedBox(height: 10),
                          _StarBar(
                            stars: '★',
                            count: user.oneStarCount,
                            total: user.restaurantsVisited,
                          ),
                        ],
                      ),
                    ),

                    // ── Community stats (tier distribution) ───────────────
                    _CommunityStatsSection(future: _communityFuture),

                    // ── Friends ───────────────────────────────────────────
                    _FriendsSection(
                      future: _friendsFuture,
                      currentUserId: _uid,
                      onChanged: _load,
                    ),

                    // ── Trophies ──────────────────────────────────────────
                    _TrophiesSection(future: _trophyFuture),

                    // ── Account settings ──────────────────────────────────
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 32, 20, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Account',
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                          const SizedBox(height: 12),
                          _SettingsRow(
                            icon: Icons.edit_outlined,
                            label: 'Edit Profile',
                            onTap: () {},
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
                            icon: Icons.language_outlined,
                            label: 'Language & Region',
                            onTap: () {},
                          ),
                          _SettingsRow(
                            icon: Icons.info_outline_rounded,
                            label: 'About Table Passport',
                            onTap: () {},
                          ),
                          _SettingsRow(
                            icon: Icons.logout_rounded,
                            label: 'Sign Out',
                            onTap: _signOut,
                            isDestructive: true,
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 100),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ── Community stats section ───────────────────────────────────────────────────

class _CommunityStatsSection extends StatelessWidget {
  final Future<List<Map<String, dynamic>>> future;
  const _CommunityStatsSection({required this.future});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 32, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Community Stats',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 16),
          FutureBuilder<List<Map<String, dynamic>>>(
            future: future,
            builder: (_, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(
                    color: AppColors.gold,
                    strokeWidth: 1.5,
                  ),
                );
              }
              final rows = snap.data ?? [];
              if (rows.isEmpty) {
                return Text(
                  'No community data yet.',
                  style: GoogleFonts.inter(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                  ),
                );
              }
              return Column(
                children: rows.map((r) {
                  final tier = (r['tier'] as String?) ?? '';
                  final count = (r['user_count'] as int?) ?? 0;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 120,
                          child: Text(
                            tier,
                            style: GoogleFonts.inter(
                              color: AppColors.textSecondary,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: count > 0
                                  ? (count /
                                        (rows
                                            .map(
                                              (e) =>
                                                  (e['user_count'] as int?) ??
                                                  0,
                                            )
                                            .reduce((a, b) => a > b ? a : b)))
                                  : 0,
                              minHeight: 5,
                              backgroundColor: AppColors.surface,
                              valueColor: const AlwaysStoppedAnimation<Color>(
                                AppColors.gold,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        SizedBox(
                          width: 32,
                          child: Text(
                            '$count',
                            textAlign: TextAlign.end,
                            style: GoogleFonts.inter(
                              color: AppColors.textSecondary,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}

// ── Friends section ───────────────────────────────────────────────────────────

class _FriendsSection extends StatefulWidget {
  final Future<List<Friendship>> future;
  final String currentUserId;
  final VoidCallback onChanged;
  const _FriendsSection({
    required this.future,
    required this.currentUserId,
    required this.onChanged,
  });

  @override
  State<_FriendsSection> createState() => _FriendsSectionState();
}

class _FriendsSectionState extends State<_FriendsSection> {
  final _searchCtrl = TextEditingController();
  final _friendRepo = FriendshipRepository(Supabase.instance.client);
  List<Map<String, dynamic>> _searchResults = [];
  bool _searching = false;

  Future<void> _search(String q) async {
    if (q.trim().isEmpty) {
      setState(() => _searchResults = []);
      return;
    }
    setState(() => _searching = true);
    final results = await _friendRepo.searchUsers(q, widget.currentUserId);
    if (mounted) {
      setState(() {
        _searchResults = results;
        _searching = false;
      });
    }
  }

  Future<void> _sendRequest(String addresseeId) async {
    await _friendRepo.sendRequest(
      requesterId: widget.currentUserId,
      addresseeId: addresseeId,
    );
    if (mounted) {
      setState(() => _searchResults = []);
      _searchCtrl.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Friend request sent!',
            style: GoogleFonts.inter(color: Colors.black),
          ),
          backgroundColor: AppColors.gold,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 32, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Friends', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 16),

          // Friend search
          TextField(
            controller: _searchCtrl,
            onChanged: _search,
            style: GoogleFonts.inter(
              color: AppColors.textPrimary,
              fontSize: 14,
            ),
            decoration: const InputDecoration(
              hintText: 'Find friends by name…',
              prefixIcon: Icon(Icons.person_search_rounded),
            ),
          ),
          if (_searching)
            const Padding(
              padding: EdgeInsets.only(top: 12),
              child: Center(
                child: CircularProgressIndicator(
                  color: AppColors.gold,
                  strokeWidth: 1.5,
                ),
              ),
            ),
          if (_searchResults.isNotEmpty) ...[
            const SizedBox(height: 8),
            ..._searchResults.map(
              (u) => ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  backgroundColor: AppColors.surface,
                  child: Text(
                    (u['display_name'] as String? ?? '?')[0].toUpperCase(),
                    style: GoogleFonts.inter(color: AppColors.gold),
                  ),
                ),
                title: Text(
                  (u['display_name'] as String?) ?? '',
                  style: GoogleFonts.inter(
                    color: AppColors.textPrimary,
                    fontSize: 14,
                  ),
                ),
                subtitle: Text(
                  (u['tier'] as String?) ?? '',
                  style: GoogleFonts.inter(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
                trailing: TextButton(
                  onPressed: () => _sendRequest(u['id'] as String),
                  child: Text(
                    'Add',
                    style: GoogleFonts.inter(color: AppColors.gold),
                  ),
                ),
              ),
            ),
          ],

          const SizedBox(height: 16),

          // Friends list
          FutureBuilder<List<Friendship>>(
            future: widget.future,
            builder: (_, snap) {
              final friends = snap.data ?? [];
              if (friends.isEmpty) {
                return Text(
                  'No friends yet. Search above to find people!',
                  style: GoogleFonts.inter(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                  ),
                );
              }
              return Column(
                children: friends
                    .map(
                      (f) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 20,
                              backgroundColor: AppColors.surface,
                              child: Text(
                                f.friendDisplayName.isNotEmpty
                                    ? f.friendDisplayName[0].toUpperCase()
                                    : '?',
                                style: GoogleFonts.inter(color: AppColors.gold),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    f.friendDisplayName,
                                    style: GoogleFonts.inter(
                                      color: AppColors.textPrimary,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  if (f.friendTier != null)
                                    Text(
                                      f.friendTier!,
                                      style: GoogleFonts.inter(
                                        color: AppColors.textSecondary,
                                        fontSize: 12,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                    .toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}

// ── Trophies section ──────────────────────────────────────────────────────────

class _TrophiesSection extends StatelessWidget {
  final Future<List<Trophy>> future;
  const _TrophiesSection({required this.future});

  static const _categoryOrder = ['milestone', 'travel', 'country', 'social'];
  static const _categoryLabels = {
    'milestone': 'Milestone',
    'travel': 'Travel',
    'country': 'Country',
    'social': 'Social',
  };

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 32, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Trophies', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 16),
          FutureBuilder<List<Trophy>>(
            future: future,
            builder: (_, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(
                    color: AppColors.gold,
                    strokeWidth: 1.5,
                  ),
                );
              }
              final all = snap.data ?? [];
              if (all.isEmpty) {
                return Text(
                  'No trophies defined yet.',
                  style: GoogleFonts.inter(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                  ),
                );
              }

              final grouped = <String, List<Trophy>>{};
              for (final t in all) {
                grouped.putIfAbsent(t.category, () => []).add(t);
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: _categoryOrder
                    .where((c) => grouped.containsKey(c))
                    .expand((cat) {
                      final trophies = grouped[cat]!;
                      return [
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10, top: 8),
                          child: Text(
                            _categoryLabels[cat] ?? cat,
                            style: GoogleFonts.inter(
                              color: AppColors.textSecondary,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: trophies
                              .map((t) => _TrophyChip(trophy: t))
                              .toList(),
                        ),
                      ];
                    })
                    .toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _TrophyChip extends StatelessWidget {
  final Trophy trophy;
  const _TrophyChip({required this.trophy});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => showDialog(
        context: context,
        builder: (_) => AlertDialog(
          backgroundColor: AppColors.card,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              Icon(
                Icons.emoji_events_rounded,
                color: trophy.isEarned
                    ? AppColors.gold
                    : AppColors.textSecondary,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  trophy.name,
                  style: GoogleFonts.playfairDisplay(
                    color: AppColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          content: Text(
            trophy.description,
            style: GoogleFonts.inter(
              color: AppColors.textSecondary,
              fontSize: 13,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'OK',
                style: GoogleFonts.inter(color: AppColors.gold),
              ),
            ),
          ],
        ),
      ),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: trophy.isEarned ? AppColors.goldMuted : AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: trophy.isEarned
                ? AppColors.goldBorder60
                : AppColors.cardBorder,
            width: trophy.isEarned ? 1.0 : 0.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.emoji_events_rounded,
              color: trophy.isEarned
                  ? AppColors.gold
                  : AppColors.textSecondary.withValues(alpha: 0.4),
              size: 14,
            ),
            const SizedBox(width: 6),
            Text(
              trophy.name,
              style: GoogleFonts.inter(
                color: trophy.isEarned
                    ? AppColors.gold
                    : AppColors.textSecondary.withValues(alpha: 0.4),
                fontSize: 12,
                fontWeight: trophy.isEarned ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Shared sub-widgets ────────────────────────────────────────────────────────

class _StatTile extends StatelessWidget {
  final String value;
  final String label;
  final IconData icon;
  const _StatTile({
    required this.value,
    required this.label,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorder, width: 0.5),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.gold, size: 20),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: GoogleFonts.playfairDisplay(
                  color: AppColors.textPrimary,
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                label,
                style: GoogleFonts.inter(
                  color: AppColors.textSecondary,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

class _StarBar extends StatelessWidget {
  final String stars;
  final int count;
  final int total;
  const _StarBar({
    required this.stars,
    required this.count,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    final fraction = total > 0 ? count / total : 0.0;
    return Row(
      children: [
        SizedBox(
          width: 40,
          child: Text(
            stars,
            style: GoogleFonts.inter(color: AppColors.starFilled, fontSize: 12),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: fraction,
              minHeight: 6,
              backgroundColor: AppColors.surface,
              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.gold),
            ),
          ),
        ),
        const SizedBox(width: 12),
        SizedBox(
          width: 24,
          child: Text(
            '$count',
            textAlign: TextAlign.end,
            style: GoogleFonts.inter(
              color: AppColors.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}

class _SettingsRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isDestructive;
  const _SettingsRow({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = isDestructive ? AppColors.error : AppColors.textPrimary;
    return Column(
      children: [
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
            child: Row(
              children: [
                Icon(icon, color: color, size: 20),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    label,
                    style: GoogleFonts.inter(color: color, fontSize: 15),
                  ),
                ),
                if (!isDestructive)
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: AppColors.textSecondary,
                    size: 20,
                  ),
              ],
            ),
          ),
        ),
        if (!isDestructive) const Divider(height: 1),
      ],
    );
  }
}
