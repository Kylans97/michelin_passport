import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/cs_spacing.dart';
import '../../../core/theme/cs_typography.dart';
import '../../../core/widgets/cs_content_sheet.dart';
import '../../../core/widgets/cs_friends_stack.dart';
import '../../../data/repositories/friendship_repository.dart';
import '../../../data/repositories/planned_trips_repository.dart';
import '../../../models/friendship.dart';
import '../../../models/trip_member.dart';
import '../../friends/widgets/identity_row.dart';
import 'trip_chrome.dart';

String _initials(String label) {
  final source = label.startsWith('@') ? label.substring(1) : label;
  final words = source.trim().split(' ').where((w) => w.isNotEmpty);
  return words.isEmpty
      ? '?'
      : words.map((w) => w[0]).take(2).join().toUpperCase();
}

/// "Travelling with" on Trip Detail: the accepted members' avatars and a
/// short line, tappable to open [showTripMembersSheet]. Pending invitees
/// are counted separately so the line never implies they've said yes.
class TripCompanionsRow extends StatelessWidget {
  final List<TripMember> members;
  final String currentUserId;
  final VoidCallback onTap;

  const TripCompanionsRow({
    super.key,
    required this.members,
    required this.currentUserId,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final others = [
      for (final m in members)
        if (m.userId != currentUserId && m.status != TripMemberStatus.pending)
          m,
    ];
    final pending = members
        .where((m) => m.status == TripMemberStatus.pending)
        .length;
    final names = others.map((m) => m.label).toList();
    final line = switch (names.length) {
      0 => 'Just you so far',
      1 => 'With ${names[0]}',
      2 => 'With ${names[0]} and ${names[1]}',
      _ => 'With ${names[0]} and ${names.length - 1} others',
    };
    final pendingLine = pending == 0 ? '' : ' · $pending invited';

    return Semantics(
      button: true,
      label: 'Travelling with. $line$pendingLine',
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(CsRadius.small),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: CsSpacing.xs),
          child: Row(
            children: [
              if (others.isNotEmpty) ...[
                FriendsStack(
                  friends: [
                    for (final m in others)
                      CsFriendAvatar(
                        id: m.userId,
                        initials: _initials(m.label),
                        photoUrl: m.avatarUrl,
                      ),
                  ],
                  label: '',
                ),
                const SizedBox(width: CsSpacing.sm),
              ],
              Expanded(
                child: Text(
                  '$line$pendingLine',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: CsTypography.metadata.copyWith(
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
}

/// Everyone on a trip, with the actions the current user may take: the
/// owner removes anyone; whoever sent a still-pending invitation may
/// withdraw it; any member invites their own friends (decision 4). The
/// server enforces each of these again — this only decides what to offer.
/// Returns true when anything changed.
Future<bool> showTripMembersSheet(
  BuildContext context, {
  required String tripId,
  required String ownerId,
  required String currentUserId,
  required PlannedTripsRepository repo,
  required FriendshipRepository friendsRepo,
}) async {
  final changed = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _TripMembersSheet(
      tripId: tripId,
      ownerId: ownerId,
      currentUserId: currentUserId,
      repo: repo,
      friendsRepo: friendsRepo,
    ),
  );
  return changed == true;
}

class _TripMembersSheet extends StatefulWidget {
  final String tripId;
  final String ownerId;
  final String currentUserId;
  final PlannedTripsRepository repo;
  final FriendshipRepository friendsRepo;

  const _TripMembersSheet({
    required this.tripId,
    required this.ownerId,
    required this.currentUserId,
    required this.repo,
    required this.friendsRepo,
  });

  @override
  State<_TripMembersSheet> createState() => _TripMembersSheetState();
}

class _TripMembersSheetState extends State<_TripMembersSheet> {
  late Future<List<TripMember>> _members = widget.repo.loadTripMembers(
    widget.tripId,
  );
  bool _changed = false;
  bool _picking = false;
  String? _error;

  bool get _isOwner => widget.currentUserId == widget.ownerId;

  void _reload() => setState(() {
    _changed = true;
    _members = widget.repo.loadTripMembers(widget.tripId);
  });

  Future<void> _run(Future<void> Function() action, String failure) async {
    setState(() => _error = null);
    try {
      await action();
      _reload();
    } catch (_) {
      if (mounted) setState(() => _error = failure);
    }
  }

  Future<void> _remove(TripMember member) async {
    final withdraw = member.status == TripMemberStatus.pending;
    final confirmed = await showTripConfirmDialog(
      context,
      title: withdraw ? 'Withdraw the invitation?' : 'Remove from the trip?',
      message: withdraw
          ? '${member.label} won\'t be able to join unless invited again.'
          : '${member.label} leaves this trip. Their own plans stay theirs, '
                'no longer part of the trip.',
      confirmLabel: withdraw ? 'Withdraw' : 'Remove',
    );
    if (!confirmed || member.memberId == null) return;
    await _run(
      () => widget.repo.removeTripMember(member.memberId!),
      'Could not update the trip. Please try again.',
    );
  }

  Future<void> _invite(List<TripMember> current) async {
    setState(() => _picking = true);
    final onTrip = {for (final m in current) m.userId};
    final friend = await _pickFriend(onTrip);
    if (mounted) setState(() => _picking = false);
    if (friend == null) return;
    await _run(
      () => widget.repo.inviteToTrip(
        tripId: widget.tripId,
        friendId: friend.friendId,
      ),
      'Could not send the invitation. Please try again.',
    );
  }

  Future<Friendship?> _pickFriend(Set<String> exclude) =>
      showModalBottomSheet<Friendship>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => _FriendPickerSheet(
          friends: widget.friendsRepo.getFriends(),
          exclude: exclude,
        ),
      );

  bool _canRemove(TripMember m) {
    if (m.memberId == null || m.userId == widget.currentUserId) return false;
    if (_isOwner) return true;
    return m.status == TripMemberStatus.pending &&
        m.invitedBy == widget.currentUserId;
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: false,
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop) Navigator.pop(context, _changed);
    },
    child: CsContentSheet(
      maxHeightFraction: 0.85,
      child: FutureBuilder<List<TripMember>>(
        future: _members,
        builder: (context, snap) {
          final members = snap.data ?? const <TripMember>[];
          return ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(
              CsSpacing.pageHorizontal,
              CsSpacing.md,
              CsSpacing.pageHorizontal,
              CsSpacing.xl,
            ),
            children: [
              Text('Travelling with', style: CsTypography.sectionTitle),
              const SizedBox(height: 2),
              Text(
                'Everyone on the trip sees its plans. Invite your own '
                'friends; they join once they accept.',
                style: CsTypography.metadata,
              ),
              const SizedBox(height: CsSpacing.lg),
              if (snap.connectionState == ConnectionState.waiting)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: CsSpacing.xl),
                  child: Center(
                    child: CircularProgressIndicator(
                      color: AppColors.forestGreen,
                      strokeWidth: 1.5,
                    ),
                  ),
                )
              else if (snap.hasError)
                Text(
                  'Could not load who\'s on this trip.',
                  style: CsTypography.metadata,
                )
              else
                for (final m in members)
                  Padding(
                    padding: const EdgeInsets.only(bottom: CsSpacing.md),
                    child: IdentityRow(
                      label: m.userId == widget.currentUserId
                          ? '${m.label} (you)'
                          : m.label,
                      username: m.username,
                      avatarUrl: m.avatarUrl,
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            switch (m.status) {
                              TripMemberStatus.owner => 'Planner',
                              TripMemberStatus.pending => 'Invited',
                              TripMemberStatus.accepted => '',
                            },
                            style: CsTypography.smallLabel.copyWith(
                              color: AppColors.taupe,
                            ),
                          ),
                          if (_canRemove(m))
                            IconButton(
                              onPressed: () => _remove(m),
                              tooltip: m.status == TripMemberStatus.pending
                                  ? 'Withdraw invitation'
                                  : 'Remove from trip',
                              icon: const Icon(
                                Icons.close_rounded,
                                color: AppColors.taupe,
                                size: 18,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
              if (_error != null) ...[
                const SizedBox(height: CsSpacing.sm),
                Text(
                  _error!,
                  style: CsTypography.metadata.copyWith(color: AppColors.error),
                ),
              ],
              const SizedBox(height: CsSpacing.md),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: _picking || !snap.hasData
                      ? null
                      : () => _invite(members),
                  icon: const Icon(Icons.person_add_alt_1_outlined, size: 18),
                  label: Text(
                    'Invite a friend',
                    style: CsTypography.bodyMedium.copyWith(fontSize: 14),
                  ),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.forestGreen,
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(0, 44),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    ),
  );
}

class _FriendPickerSheet extends StatefulWidget {
  final Future<List<Friendship>> friends;
  final Set<String> exclude;
  const _FriendPickerSheet({required this.friends, required this.exclude});

  @override
  State<_FriendPickerSheet> createState() => _FriendPickerSheetState();
}

class _FriendPickerSheetState extends State<_FriendPickerSheet> {
  @override
  Widget build(BuildContext context) => CsContentSheet(
    maxHeightFraction: 0.8,
    child: FutureBuilder<List<Friendship>>(
      future: widget.friends,
      builder: (context, snap) {
        final friends = [
          for (final f in snap.data ?? const <Friendship>[])
            if (!widget.exclude.contains(f.friendId)) f,
        ];
        return ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(
            CsSpacing.pageHorizontal,
            CsSpacing.md,
            CsSpacing.pageHorizontal,
            CsSpacing.xl,
          ),
          children: [
            Text('Invite a friend', style: CsTypography.sectionTitle),
            const SizedBox(height: CsSpacing.lg),
            if (snap.connectionState == ConnectionState.waiting)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: CsSpacing.xl),
                child: Center(
                  child: CircularProgressIndicator(
                    color: AppColors.forestGreen,
                    strokeWidth: 1.5,
                  ),
                ),
              )
            else if (friends.isEmpty)
              Text(
                snap.hasError
                    ? 'Could not load your friends.'
                    : 'Every friend of yours is already on this trip — or '
                          'add friends from Community first.',
                style: CsTypography.metadata,
              )
            else
              for (final f in friends)
                Padding(
                  padding: const EdgeInsets.only(bottom: CsSpacing.md),
                  child: IdentityRow(
                    label: f.label,
                    username: f.username,
                    avatarUrl: f.avatarUrl,
                    onTap: () => Navigator.pop(context, f),
                  ),
                ),
          ],
        );
      },
    ),
  );
}
