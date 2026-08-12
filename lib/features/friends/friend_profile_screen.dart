import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants/app_colors.dart';
import '../../core/theme/cs_spacing.dart';
import '../../core/theme/cs_typography.dart';
import '../../core/widgets/cs_primary_button.dart';
import '../../core/widgets/editorial_back_button.dart';
import '../../data/repositories/friendship_repository.dart';
import '../../models/profile_identity.dart';

/// One screen for both a friend's profile and a non-friend's — the
/// difference is entirely in which action [relationshipStatus] resolves
/// to (§34-35 of the task). Identity only: avatar, name, @username, and a
/// relationship action. Deliberately renders NOTHING beyond that — no
/// visits, ratings, photos, wishlist, or trips. Those require Step 2's
/// friends-visibility rules on visits/photos, which this step does not
/// build; showing them here would leak whatever profiles.is_public
/// currently allows, exactly what this step is designed to avoid.
class FriendProfileScreen extends StatefulWidget {
  final String userId;
  const FriendProfileScreen({super.key, required this.userId});

  @override
  State<FriendProfileScreen> createState() => _FriendProfileScreenState();
}

class _FriendProfileScreenState extends State<FriendProfileScreen> {
  late final _repo = FriendshipRepository(Supabase.instance.client);
  late Future<ProfileIdentity?> _future;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    setState(() => _future = _repo.getProfileIdentity(widget.userId));
  }

  void _showSnack(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: CsTypography.metadata.copyWith(
            color: isError ? AppColors.textOnDark : Colors.black,
          ),
        ),
        backgroundColor: isError ? AppColors.error : AppColors.gold,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _sendRequest() async {
    try {
      await _repo.sendRequest(widget.userId);
      _load();
    } on PostgrestException catch (e) {
      _showSnack(e.message, isError: true);
    }
  }

  Future<void> _accept(String friendshipId) async {
    try {
      await _repo.acceptRequest(friendshipId);
      _load();
    } on PostgrestException catch (e) {
      _showSnack(e.message, isError: true);
    }
  }

  Future<void> _decline(String friendshipId) async {
    try {
      await _repo.declineRequest(friendshipId);
      _load();
    } on PostgrestException catch (e) {
      _showSnack(e.message, isError: true);
    }
  }

  Future<void> _removeFriend() async {
    // Needs the friendship id, which get_profile_identity doesn't
    // return — the outgoing/incoming id isn't relevant once accepted, so
    // resolve it via the friends list rather than adding a new RPC solely
    // to look up one id (getFriends() is already cheap and cached-free).
    final friends = await _repo.getFriends();
    final match = friends.where((f) => f.friendId == widget.userId);
    if (match.isEmpty) return;
    if (!mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.brandGreenLight,
        title: Text(
          'Remove friend?',
          style: CsTypography.placeTitle.copyWith(
            color: AppColors.textOnDark,
            fontSize: 20,
          ),
        ),
        content: Text(
          'You will no longer be friends. Either of you can send a new '
          'request later.',
          style: CsTypography.body.copyWith(color: AppColors.secondaryOnDark),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancel',
              style: CsTypography.bodyMedium.copyWith(
                color: AppColors.secondaryOnDark,
              ),
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
      await _repo.removeFriendship(match.first.friendshipId);
      _load();
    } catch (_) {
      _showSnack('Could not remove. Please try again.', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.deepGreen,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(
                CsSpacing.base,
                CsSpacing.sm,
                CsSpacing.base,
                0,
              ),
              child: Align(
                alignment: Alignment.centerLeft,
                child: EditorialBackButton(),
              ),
            ),
            Expanded(
              child: FutureBuilder<ProfileIdentity?>(
                future: _future,
                builder: (context, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(
                        color: AppColors.gold,
                        strokeWidth: 1.5,
                      ),
                    );
                  }
                  final identity = snap.data;
                  if (snap.hasError || identity == null) {
                    return Center(
                      child: Text(
                        'Could not load this profile',
                        style: CsTypography.body.copyWith(
                          color: AppColors.secondaryOnDark,
                        ),
                      ),
                    );
                  }
                  return _ProfileBody(
                    identity: identity,
                    onSendRequest: _sendRequest,
                    onAccept: () async {
                      final friendshipId = await _incomingFriendshipId(
                        identity.id,
                      );
                      if (friendshipId != null) _accept(friendshipId);
                    },
                    onDecline: () async {
                      final friendshipId = await _incomingFriendshipId(
                        identity.id,
                      );
                      if (friendshipId != null) _decline(friendshipId);
                    },
                    onRemove: _removeFriend,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<String?> _incomingFriendshipId(String requesterId) async {
    final incoming = await _repo.getIncomingRequests();
    final match = incoming.where((r) => r.otherUserId == requesterId);
    return match.isEmpty ? null : match.first.friendshipId;
  }
}

class _ProfileBody extends StatelessWidget {
  final ProfileIdentity identity;
  final VoidCallback onSendRequest;
  final VoidCallback onAccept;
  final VoidCallback onDecline;
  final VoidCallback onRemove;

  const _ProfileBody({
    required this.identity,
    required this.onSendRequest,
    required this.onAccept,
    required this.onDecline,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final words = identity.label.trim().split(' ').where((w) => w.isNotEmpty);
    final initials = words.isEmpty
        ? '?'
        : words.map((w) => w[0]).take(2).join().toUpperCase();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: CsSpacing.pageHorizontal),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: CsSpacing.xl),
          Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.brandGreenLight,
              border: Border.all(color: AppColors.gold.withValues(alpha: 0.5)),
            ),
            alignment: Alignment.center,
            child:
                (identity.avatarUrl != null && identity.avatarUrl!.isNotEmpty)
                ? ClipOval(
                    child: Image.network(
                      identity.avatarUrl!,
                      width: 96,
                      height: 96,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => Text(
                        initials,
                        style: CsTypography.screenTitle.copyWith(
                          color: AppColors.gold,
                        ),
                      ),
                    ),
                  )
                : Text(
                    initials,
                    style: CsTypography.screenTitle.copyWith(
                      color: AppColors.gold,
                    ),
                  ),
          ),
          const SizedBox(height: CsSpacing.lg),
          Text(
            identity.displayName?.trim().isNotEmpty == true
                ? identity.displayName!
                : identity.label,
            textAlign: TextAlign.center,
            style: CsTypography.screenTitle.copyWith(
              color: AppColors.textOnDark,
            ),
          ),
          if (identity.username != null) ...[
            const SizedBox(height: 4),
            Text(
              '@${identity.username}',
              style: CsTypography.body.copyWith(
                color: AppColors.secondaryOnDark,
              ),
            ),
          ],
          const SizedBox(height: CsSpacing.xxl),
          _RelationshipAction(
            status: identity.relationshipStatus,
            onSendRequest: onSendRequest,
            onAccept: onAccept,
            onDecline: onDecline,
            onRemove: onRemove,
          ),
        ],
      ),
    );
  }
}

class _RelationshipAction extends StatelessWidget {
  final RelationshipStatus status;
  final VoidCallback onSendRequest;
  final VoidCallback onAccept;
  final VoidCallback onDecline;
  final VoidCallback onRemove;

  const _RelationshipAction({
    required this.status,
    required this.onSendRequest,
    required this.onAccept,
    required this.onDecline,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    switch (status) {
      case RelationshipStatus.none:
        return SizedBox(
          width: double.infinity,
          child: CsPrimaryButton(
            label: 'Add friend',
            icon: Icons.person_add_alt_1_rounded,
            onTap: onSendRequest,
          ),
        );
      case RelationshipStatus.pendingSent:
        return Text(
          'Request sent',
          style: CsTypography.bodyMedium.copyWith(
            color: AppColors.secondaryOnDark,
          ),
        );
      case RelationshipStatus.pendingReceived:
        return Row(
          children: [
            Expanded(
              child: CsSecondaryButton(label: 'Decline', onTap: onDecline),
            ),
            const SizedBox(width: CsSpacing.md),
            Expanded(
              child: CsPrimaryButton(label: 'Accept', onTap: onAccept),
            ),
          ],
        );
      case RelationshipStatus.accepted:
        return Column(
          children: [
            Text(
              'Friends',
              style: CsTypography.bodyMedium.copyWith(color: AppColors.gold),
            ),
            const SizedBox(height: CsSpacing.md),
            TextButton(
              onPressed: onRemove,
              child: Text(
                'Remove friend',
                style: CsTypography.metadata.copyWith(
                  color: AppColors.secondaryOnDark,
                ),
              ),
            ),
          ],
        );
      case RelationshipStatus.declined:
        return Text(
          'Unavailable',
          style: CsTypography.bodyMedium.copyWith(
            color: AppColors.secondaryOnDark,
          ),
        );
    }
  }
}
