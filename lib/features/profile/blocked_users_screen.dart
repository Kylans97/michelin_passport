import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants/app_colors.dart';
import '../../core/theme/cs_spacing.dart';
import '../../core/theme/cs_typography.dart';
import '../../core/widgets/editorial_back_button.dart';
import '../../data/repositories/friendship_repository.dart';
import '../../models/blocked_user.dart';

/// Privacy → Blocked users — the other half of blocking (Apple's own
/// requirement: a block affordance must not ship without this list, or
/// blocking becomes one-way). Lists only blocks *you* created — see
/// [FriendshipRepository.getBlockedUsers]/`unblock_user`'s own "only the
/// blocker may unblock" rule.
///
/// [loadBlockedUsers]/[unblockUser] are optional, zero-argument DI seams —
/// same convention as [PrivacySettingsScreen]'s own
/// [loadDiscoverable]/[setDiscoverable] — so this screen's real
/// load/unblock behavior can be tested without a live Supabase session.
class BlockedUsersScreen extends StatefulWidget {
  final Future<List<BlockedUser>> Function()? loadBlockedUsers;
  final Future<void> Function(String userId)? unblockUser;

  const BlockedUsersScreen({
    super.key,
    this.loadBlockedUsers,
    this.unblockUser,
  });

  @override
  State<BlockedUsersScreen> createState() => _BlockedUsersScreenState();
}

class _BlockedUsersScreenState extends State<BlockedUsersScreen> {
  List<BlockedUser>? _users;
  bool _loadError = false;
  final Set<String> _unblocking = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _users = null;
      _loadError = false;
    });
    try {
      final load =
          widget.loadBlockedUsers ??
          () => FriendshipRepository(Supabase.instance.client)
              .getBlockedUsers();
      final users = await load();
      if (!mounted) return;
      setState(() => _users = users);
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadError = true);
    }
  }

  Future<void> _unblock(BlockedUser user) async {
    if (_unblocking.contains(user.userId)) return;
    setState(() => _unblocking.add(user.userId));
    try {
      final unblock =
          widget.unblockUser ??
          (userId) => FriendshipRepository(
            Supabase.instance.client,
          ).unblockUser(userId);
      await unblock(user.userId);
      if (!mounted) return;
      setState(() {
        _users = _users?.where((u) => u.userId != user.userId).toList();
        _unblocking.remove(user.userId);
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Unblocked ${user.label}.',
            style: CsTypography.metadata.copyWith(color: AppColors.textOnDark),
          ),
          backgroundColor: AppColors.forestGreen,
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _unblocking.remove(user.userId));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Could not unblock. Please try again.',
            style: CsTypography.metadata.copyWith(color: AppColors.textOnDark),
          ),
          backgroundColor: AppColors.error,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.deepGreen,
    body: SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
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
          Padding(
            padding: const EdgeInsets.fromLTRB(
              CsSpacing.pageHorizontal,
              CsSpacing.lg,
              CsSpacing.pageHorizontal,
              CsSpacing.xl,
            ),
            child: Text(
              'Blocked users',
              style: CsTypography.screenTitle.copyWith(color: AppColors.ivory),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: CsSpacing.pageHorizontal,
              ),
              child: _users == null && !_loadError
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: AppColors.textOnDark,
                        strokeWidth: 1.5,
                      ),
                    )
                  : _loadError
                  ? _BlockedUsersLoadError(onRetry: _load)
                  : _users!.isEmpty
                  ? Text(
                      "You haven't blocked anyone.",
                      style: CsTypography.body.copyWith(
                        color: AppColors.secondaryOnDark,
                      ),
                    )
                  : ListView.separated(
                      itemCount: _users!.length,
                      separatorBuilder: (_, _) =>
                          const SizedBox(height: CsSpacing.sm),
                      itemBuilder: (context, i) {
                        final user = _users![i];
                        return _BlockedUserRow(
                          user: user,
                          busy: _unblocking.contains(user.userId),
                          onUnblock: () => _unblock(user),
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _BlockedUsersLoadError extends StatelessWidget {
  final VoidCallback onRetry;
  const _BlockedUsersLoadError({required this.onRetry});

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(
          Icons.wifi_off_rounded,
          color: AppColors.secondaryOnDark,
          size: 32,
        ),
        const SizedBox(height: CsSpacing.base),
        Text(
          'Could not load your blocked users',
          style: CsTypography.body.copyWith(color: AppColors.secondaryOnDark),
        ),
        const SizedBox(height: CsSpacing.md),
        TextButton(
          onPressed: onRetry,
          child: Text(
            'Retry',
            style: CsTypography.bodyMedium.copyWith(color: AppColors.ivory),
          ),
        ),
      ],
    ),
  );
}

class _BlockedUserRow extends StatelessWidget {
  final BlockedUser user;
  final bool busy;
  final VoidCallback onUnblock;

  const _BlockedUserRow({
    required this.user,
    required this.busy,
    required this.onUnblock,
  });

  @override
  Widget build(BuildContext context) => Row(
    children: [
      CircleAvatar(
        radius: 20,
        backgroundColor: AppColors.ivory,
        backgroundImage:
            (user.avatarUrl != null && user.avatarUrl!.isNotEmpty)
            ? NetworkImage(user.avatarUrl!)
            : null,
        child: (user.avatarUrl == null || user.avatarUrl!.isEmpty)
            ? Text(
                user.label.isNotEmpty ? user.label[0].toUpperCase() : '?',
                style: CsTypography.bodyMedium.copyWith(
                  color: AppColors.forestGreen,
                ),
              )
            : null,
      ),
      const SizedBox(width: CsSpacing.md),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              user.label,
              style: CsTypography.bodyMedium.copyWith(
                color: AppColors.textOnDark,
              ),
            ),
            if (user.username != null)
              Text(
                '@${user.username}',
                style: CsTypography.metadata.copyWith(
                  color: AppColors.secondaryOnDark,
                ),
              ),
          ],
        ),
      ),
      TextButton(
        onPressed: busy ? null : onUnblock,
        child: busy
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.ivory,
                ),
              )
            : Text(
                'Unblock',
                style: CsTypography.bodyMedium.copyWith(
                  color: AppColors.ivory,
                ),
              ),
      ),
    ],
  );
}
