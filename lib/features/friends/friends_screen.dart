import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants/app_colors.dart';
import '../../core/theme/cs_spacing.dart';
import '../../core/theme/cs_surface_context.dart';
import '../../core/theme/cs_typography.dart';
import '../../core/widgets/cs_primary_button.dart';
import '../../core/widgets/editorial_back_button.dart';
import '../../data/repositories/friendship_repository.dart';
import '../../models/friendship.dart';
import 'add_friend_screen.dart';
import 'friend_profile_screen.dart';
import 'widgets/identity_row.dart';

/// Friends — accepted friends plus incoming/outgoing requests. Deliberately
/// small: no follower/following counts, no "people you may know," no
/// public discovery feed, no friend-of-friend graph — just the three
/// things this screen actually builds (list, requests, add).
///
/// Community/Friends UX Step 1: forest-green header (back arrow, add-
/// friend action, "Friends" title, tab bar) over an ivory body — see
/// docs/Architecture/COMMUNITY_FRIENDS_UX.md for why "Friends" (not
/// "Community") stays the visible label this step, and for the broader
/// information-architecture direction this screen is one part of.
class FriendsScreen extends StatefulWidget {
  const FriendsScreen({super.key});

  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen> {
  late final _repo = FriendshipRepository(Supabase.instance.client);

  late Future<List<Friendship>> _friendsFuture;
  late Future<List<FriendRequest>> _incomingFuture;
  late Future<List<FriendRequest>> _outgoingFuture;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    setState(() {
      _friendsFuture = _repo.getFriends();
      _incomingFuture = _repo.getIncomingRequests();
      _outgoingFuture = _repo.getOutgoingRequests();
    });
  }

  void _showSnack(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: CsTypography.metadata.copyWith(color: AppColors.textOnDark),
        ),
        backgroundColor: isError ? AppColors.error : AppColors.forestGreen,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _accept(FriendRequest request) async {
    try {
      await _repo.acceptRequest(request.friendshipId);
      _load();
    } on PostgrestException catch (e) {
      _showSnack(e.message, isError: true);
    }
  }

  Future<void> _decline(FriendRequest request) async {
    try {
      await _repo.declineRequest(request.friendshipId);
      _load();
    } on PostgrestException catch (e) {
      _showSnack(e.message, isError: true);
    }
  }

  Future<void> _cancelOutgoing(FriendRequest request) async {
    try {
      await _repo.removeFriendship(request.friendshipId);
      _load();
    } catch (_) {
      _showSnack('Could not cancel. Please try again.', isError: true);
    }
  }

  Future<void> _removeFriend(Friendship friend) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.warmWhite,
        title: Text(
          'Remove ${friend.label}?',
          style: CsTypography.placeTitle.copyWith(
            color: AppColors.forestGreen,
            fontSize: 20,
          ),
        ),
        content: Text(
          'You will no longer be friends. Either of you can send a new '
          'request later.',
          style: CsTypography.body.copyWith(color: AppColors.taupe),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancel',
              style: CsTypography.bodyMedium.copyWith(color: AppColors.taupe),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              'Remove',
              style: CsTypography.bodyMedium.copyWith(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _repo.removeFriendship(friend.friendshipId);
      _load();
    } catch (_) {
      _showSnack('Could not remove. Please try again.', isError: true);
    }
  }

  void _openAddFriend() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AddFriendScreen()),
    );
    _load();
  }

  void _openProfile(String userId) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => FriendProfileScreen(userId: userId)),
    );
    _load();
  }

  @override
  Widget build(BuildContext context) {
    // UI Polish pass: Scaffold.backgroundColor is deep-green (not
    // ivory) so the iOS status-bar area continues the header seamlessly
    // instead of showing an ivory strip above it — same root cause and
    // fix as GuideCatalogueLayout/FriendProfileScreen (see their own doc
    // comments): the previous single SafeArea rendered its top inset
    // against the Scaffold's own (then-ivory) background before the
    // deep-green header's ColoredBox ever got to paint it. AnnotatedRegion
    // forces light status-bar icons for exactly this screen.
    //
    // Green Token Consistency Migration: AppColors.deepGreen, not
    // forestGreen — the canonical primary brand dark surface.
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: DefaultTabController(
        length: 2,
        child: Scaffold(
          backgroundColor: AppColors.deepGreen,
          body: Column(
            children: [
              SafeArea(
                bottom: false,
                child: ColoredBox(
                  color: AppColors.deepGreen,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(
                          CsSpacing.base,
                          CsSpacing.sm,
                          CsSpacing.base,
                          0,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            EditorialBackButton(color: AppColors.ivory),
                            Tooltip(
                              message: 'Add friend',
                              child: _HeroIconButtonStandIn(
                                icon: Icons.person_add_alt_1_rounded,
                                onTap: _openAddFriend,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(
                          CsSpacing.pageHorizontal,
                          CsSpacing.xl,
                          CsSpacing.pageHorizontal,
                          0,
                        ),
                        child: Text(
                          'Friends',
                          style: CsTypography.screenTitle.copyWith(
                            color: AppColors.ivory,
                          ),
                        ),
                      ),
                      const SizedBox(height: CsSpacing.lg),
                      TabBar(
                        labelColor: AppColors.ivory,
                        unselectedLabelColor: AppColors.secondaryOnDark,
                        indicatorColor: AppColors.ivory,
                        labelStyle: CsTypography.bodyMedium,
                        unselectedLabelStyle: CsTypography.bodyMedium,
                        tabs: const [
                          Tab(text: 'Friends'),
                          Tab(text: 'Requests'),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: ColoredBox(
                  color: AppColors.ivory,
                  child: SafeArea(
                    top: false,
                    child: TabBarView(
                      children: [
                        _FriendsTab(
                          future: _friendsFuture,
                          onTapFriend: (f) => _openProfile(f.friendId),
                          onRemove: _removeFriend,
                          onFindFriends: _openAddFriend,
                        ),
                        _RequestsTab(
                          incomingFuture: _incomingFuture,
                          outgoingFuture: _outgoingFuture,
                          onAccept: _accept,
                          onDecline: _decline,
                          onCancelOutgoing: _cancelOutgoing,
                          onTapRequester: (r) => _openProfile(r.otherUserId),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A small translucent-circle icon button matching [EditorialBackButton]'s
/// own visual weight for a non-back action (the add-friend "+") — the
/// exact same "quiet on a dark canvas" reasoning as [HeroIconButton],
/// reused locally rather than importing a Detail-internal component.
class _HeroIconButtonStandIn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _HeroIconButtonStandIn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.black.withValues(alpha: 0.24),
    shape: const CircleBorder(),
    child: InkWell(
      customBorder: const CircleBorder(),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(13),
        child: Icon(icon, color: AppColors.ivory, size: 18),
      ),
    ),
  );
}

class _FriendsTab extends StatelessWidget {
  final Future<List<Friendship>> future;
  final ValueChanged<Friendship> onTapFriend;
  final ValueChanged<Friendship> onRemove;
  final VoidCallback onFindFriends;
  const _FriendsTab({
    required this.future,
    required this.onTapFriend,
    required this.onRemove,
    required this.onFindFriends,
  });

  @override
  Widget build(BuildContext context) => FutureBuilder<List<Friendship>>(
    future: future,
    builder: (context, snap) {
      if (snap.connectionState == ConnectionState.waiting) {
        return const Center(
          child: CircularProgressIndicator(
            color: AppColors.forestGreen,
            strokeWidth: 1.5,
          ),
        );
      }
      if (snap.hasError) {
        return Center(
          child: Text(
            'Could not load friends',
            style: CsTypography.body.copyWith(color: AppColors.taupe),
          ),
        );
      }
      final friends = snap.data ?? [];
      if (friends.isEmpty) {
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(CsSpacing.xxl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Find friends and discover the places they loved',
                  textAlign: TextAlign.center,
                  style: CsTypography.placeTitle.copyWith(
                    color: AppColors.forestGreen,
                    fontSize: 20,
                  ),
                ),
                const SizedBox(height: CsSpacing.sm),
                Text(
                  'Search for people you know by username.',
                  textAlign: TextAlign.center,
                  style: CsTypography.body.copyWith(color: AppColors.taupe),
                ),
                const SizedBox(height: CsSpacing.xl),
                CsPrimaryButton(
                  label: 'Find friends',
                  icon: Icons.person_add_alt_1_rounded,
                  onTap: onFindFriends,
                  surface: CsSurface.light,
                ),
              ],
            ),
          ),
        );
      }
      return ListView.builder(
        padding: const EdgeInsets.fromLTRB(
          CsSpacing.pageHorizontal,
          CsSpacing.md,
          CsSpacing.pageHorizontal,
          CsSpacing.section,
        ),
        itemCount: friends.length,
        itemBuilder: (context, i) {
          final friend = friends[i];
          return IdentityRow(
            label: friend.label,
            username: friend.username,
            avatarUrl: friend.avatarUrl,
            onTap: () => onTapFriend(friend),
            trailing: IconButton(
              icon: const Icon(
                Icons.more_horiz_rounded,
                color: AppColors.taupe,
                size: 20,
              ),
              tooltip: 'Remove friend',
              onPressed: () => onRemove(friend),
            ),
          );
        },
      );
    },
  );
}

class _RequestsTab extends StatelessWidget {
  final Future<List<FriendRequest>> incomingFuture;
  final Future<List<FriendRequest>> outgoingFuture;
  final ValueChanged<FriendRequest> onAccept;
  final ValueChanged<FriendRequest> onDecline;
  final ValueChanged<FriendRequest> onCancelOutgoing;
  final ValueChanged<FriendRequest> onTapRequester;

  const _RequestsTab({
    required this.incomingFuture,
    required this.outgoingFuture,
    required this.onAccept,
    required this.onDecline,
    required this.onCancelOutgoing,
    required this.onTapRequester,
  });

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(
      CsSpacing.pageHorizontal,
      CsSpacing.md,
      CsSpacing.pageHorizontal,
      CsSpacing.section,
    ),
    children: [
      Text(
        'INCOMING',
        style: CsTypography.eyebrow.copyWith(color: AppColors.taupe),
      ),
      const SizedBox(height: CsSpacing.md),
      FutureBuilder<List<FriendRequest>>(
        future: incomingFuture,
        builder: (context, snap) {
          final requests = snap.data ?? [];
          if (snap.connectionState == ConnectionState.waiting) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: CsSpacing.md),
              child: Center(
                child: CircularProgressIndicator(
                  color: AppColors.forestGreen,
                  strokeWidth: 1.5,
                ),
              ),
            );
          }
          if (requests.isEmpty) {
            return Text(
              'No pending requests',
              style: CsTypography.body.copyWith(color: AppColors.taupe),
            );
          }
          return Column(
            children: requests
                .map(
                  (r) => IdentityRow(
                    label: r.label,
                    username: r.username,
                    avatarUrl: r.avatarUrl,
                    onTap: () => onTapRequester(r),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextButton(
                          onPressed: () => onDecline(r),
                          child: Text(
                            'Decline',
                            style: CsTypography.metadata.copyWith(
                              color: AppColors.taupe,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: () => onAccept(r),
                          child: Text(
                            'Accept',
                            style: CsTypography.metadata.copyWith(
                              color: AppColors.forestGreen,
                              fontWeight: FontWeight.w600,
                            ),
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
      const SizedBox(height: CsSpacing.section),
      Text(
        'SENT',
        style: CsTypography.eyebrow.copyWith(color: AppColors.taupe),
      ),
      const SizedBox(height: CsSpacing.md),
      FutureBuilder<List<FriendRequest>>(
        future: outgoingFuture,
        builder: (context, snap) {
          final requests = snap.data ?? [];
          if (snap.connectionState == ConnectionState.waiting) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: CsSpacing.md),
              child: Center(
                child: CircularProgressIndicator(
                  color: AppColors.forestGreen,
                  strokeWidth: 1.5,
                ),
              ),
            );
          }
          if (requests.isEmpty) {
            return Text(
              'No requests sent',
              style: CsTypography.body.copyWith(color: AppColors.taupe),
            );
          }
          return Column(
            children: requests
                .map(
                  (r) => IdentityRow(
                    label: r.label,
                    username: r.username,
                    avatarUrl: r.avatarUrl,
                    onTap: () => onTapRequester(r),
                    trailing: TextButton(
                      onPressed: () => onCancelOutgoing(r),
                      child: Text(
                        'Cancel',
                        style: CsTypography.metadata.copyWith(
                          color: AppColors.taupe,
                        ),
                      ),
                    ),
                  ),
                )
                .toList(),
          );
        },
      ),
    ],
  );
}
