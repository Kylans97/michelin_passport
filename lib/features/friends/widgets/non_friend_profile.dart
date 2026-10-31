import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/cs_spacing.dart';
import '../../../core/theme/cs_typography.dart';
import '../../../core/widgets/cs_primary_button.dart';
import '../../../core/widgets/editorial_back_button.dart';
import '../../../models/profile_identity.dart';
import 'friend_profile_widgets.dart';

/// The profile of someone who is not (yet) a friend — reached from Find
/// friends, a request or a notification. Redesigned 2026-10-31 (product
/// owner: the old half-green, half-ivory screen with the name pushed left
/// read as unfinished): one deep-green page, everything centred — the
/// member's photo, name and @username, a short warm line about what
/// becomes possible together, and one calm friendship action.
///
/// Shows only the minimal identity a non-friend can already see (photo,
/// name, username — FRIENDS_PRIVACY_COMMUNITY_INTELLIGENCE.md §4.2): no
/// stamps, stars, visits or wishlist, which stay behind an accepted
/// friendship. The copy describes what friends share in general, never
/// anything about this member.
class NonFriendProfile extends StatelessWidget {
  final ProfileIdentity identity;

  /// The viewer's own profile: no overflow menu and no action.
  final bool isSelf;
  final VoidCallback onSendRequest;
  final VoidCallback onAccept;
  final VoidCallback onDecline;
  final VoidCallback onBlock;
  final VoidCallback onReport;

  const NonFriendProfile({
    super.key,
    required this.identity,
    required this.isSelf,
    required this.onSendRequest,
    required this.onAccept,
    required this.onDecline,
    required this.onBlock,
    required this.onReport,
  });

  String get _name => identity.displayName?.trim().isNotEmpty == true
      ? identity.displayName!.trim()
      : identity.label;

  String get _firstName => _name.split(' ').first;

  /// (headline, supporting line) for the invitation, by relationship.
  (String, String)? get _invitation => switch (identity.relationshipStatus) {
    RelationshipStatus.none => (
      'Start enjoying the Mantelier journey together.',
      'Friends see the stamps and verdicts the other chooses to share, '
          'and each other\'s wishlists.',
    ),
    RelationshipStatus.pendingSent => (
      'Your invitation is on its way.',
      'Once $_firstName accepts, you\'ll see each other\'s shared journey.',
    ),
    RelationshipStatus.pendingReceived => (
      '$_firstName would like to share the journey with you.',
      'Accept to see each other\'s shared stamps, verdicts and wishlists.',
    ),
    RelationshipStatus.accepted || RelationshipStatus.declined => null,
  };

  @override
  Widget build(BuildContext context) {
    final invitation = isSelf ? null : _invitation;
    return SafeArea(
      child: Column(
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
                const EditorialBackButton(color: AppColors.ivory),
                if (!isSelf)
                  _OverflowMenu(onBlock: onBlock, onReport: onReport),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(
                CsSpacing.pageHorizontal,
                CsSpacing.xl,
                CsSpacing.pageHorizontal,
                CsSpacing.xxl,
              ),
              child: Column(
                children: [
                  _Portrait(photoUrl: identity.avatarUrl, label: _name),
                  const SizedBox(height: CsSpacing.lg),
                  Text(
                    _name,
                    textAlign: TextAlign.center,
                    style: CsTypography.editorialTitle(
                      size: 34,
                    ).copyWith(color: AppColors.textOnDark),
                  ),
                  if (identity.username case final username?) ...[
                    const SizedBox(height: 6),
                    Text(
                      '@${username.toUpperCase()}',
                      textAlign: TextAlign.center,
                      style: CsTypography.editorialLabel().copyWith(
                        color: AppColors.secondaryOnDark,
                      ),
                    ),
                  ],
                  const SizedBox(height: CsSpacing.xl),
                  Container(
                    width: 32,
                    height: 1,
                    color: AppColors.hairlineOnGreen,
                  ),
                  if (invitation != null) ...[
                    const SizedBox(height: CsSpacing.xl),
                    Text(
                      invitation.$1,
                      textAlign: TextAlign.center,
                      style: CsTypography.editorialTitle(
                        size: 24,
                        italic: true,
                      ).copyWith(color: AppColors.textOnDark),
                    ),
                    const SizedBox(height: CsSpacing.sm),
                    Text(
                      invitation.$2,
                      textAlign: TextAlign.center,
                      style: CsTypography.body.copyWith(
                        color: AppColors.secondaryOnDark,
                      ),
                    ),
                  ],
                  const SizedBox(height: CsSpacing.xl),
                  if (!isSelf)
                    NonFriendAction(
                      status: identity.relationshipStatus,
                      onSendRequest: onSendRequest,
                      onAccept: onAccept,
                      onDecline: onDecline,
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The member's photo (or initial) in a hairline ivory ring.
class _Portrait extends StatelessWidget {
  final String? photoUrl;
  final String label;
  const _Portrait({required this.photoUrl, required this.label});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(5),
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      border: Border.all(color: AppColors.hairlineOnGreen),
    ),
    child: FriendProfileAvatar(
      photoUrl: photoUrl,
      label: label,
      size: 112,
      ringColor: Colors.transparent,
      fallbackBackground: AppColors.ivory,
      fallbackTextColor: AppColors.forestGreen,
    ),
  );
}

/// The one friendship action, by relationship: "Add friend", a quiet
/// "Request sent", or Accept with a quieter Decline beneath.
class NonFriendAction extends StatelessWidget {
  final RelationshipStatus status;
  final VoidCallback onSendRequest;
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  const NonFriendAction({
    super.key,
    required this.status,
    required this.onSendRequest,
    required this.onAccept,
    required this.onDecline,
  });

  @override
  Widget build(BuildContext context) => switch (status) {
    RelationshipStatus.none => SizedBox(
      width: double.infinity,
      child: CsPrimaryButton(
        label: 'Add friend',
        icon: Icons.person_add_alt_1_rounded,
        onTap: onSendRequest,
      ),
    ),
    RelationshipStatus.pendingSent => Container(
      padding: const EdgeInsets.symmetric(
        horizontal: CsSpacing.lg,
        vertical: CsSpacing.sm,
      ),
      decoration: ShapeDecoration(
        shape: StadiumBorder(
          side: BorderSide(color: AppColors.hairlineOnGreen),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.check_rounded,
            size: 16,
            color: AppColors.secondaryOnDark,
          ),
          const SizedBox(width: 6),
          Text(
            'Request sent',
            style: CsTypography.bodyMedium.copyWith(
              color: AppColors.secondaryOnDark,
            ),
          ),
        ],
      ),
    ),
    RelationshipStatus.pendingReceived => Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: CsPrimaryButton(label: 'Accept', onTap: onAccept),
        ),
        const SizedBox(height: CsSpacing.sm),
        TextButton(
          onPressed: onDecline,
          child: Text(
            'Decline',
            style: CsTypography.bodyMedium.copyWith(
              color: AppColors.secondaryOnDark,
            ),
          ),
        ),
      ],
    ),
    RelationshipStatus.accepted => const SizedBox.shrink(),
    RelationshipStatus.declined => Text(
      'Unavailable',
      style: CsTypography.bodyMedium.copyWith(color: AppColors.secondaryOnDark),
    ),
  };
}

class _OverflowMenu extends StatelessWidget {
  final VoidCallback onBlock;
  final VoidCallback onReport;
  const _OverflowMenu({required this.onBlock, required this.onReport});

  @override
  Widget build(BuildContext context) => PopupMenuButton<String>(
    color: AppColors.card,
    tooltip: 'More',
    onSelected: (value) {
      if (value == 'block') onBlock();
      if (value == 'report') onReport();
    },
    itemBuilder: (context) => const [
      PopupMenuItem(
        value: 'report',
        child: Row(
          children: [
            Icon(Icons.flag_outlined, color: AppColors.textPrimary, size: 18),
            SizedBox(width: 10),
            Text('Report profile'),
          ],
        ),
      ),
      PopupMenuItem(
        value: 'block',
        child: Row(
          children: [
            Icon(Icons.block_rounded, color: AppColors.error, size: 18),
            SizedBox(width: 10),
            Text('Block', style: TextStyle(color: AppColors.error)),
          ],
        ),
      ),
    ],
    child: Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.hairlineOnGreen),
      ),
      alignment: Alignment.center,
      child: const Icon(
        Icons.more_horiz_rounded,
        color: AppColors.textOnDark,
        size: 20,
      ),
    ),
  );
}
