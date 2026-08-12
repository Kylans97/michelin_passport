import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/cs_spacing.dart';
import '../../../core/theme/cs_typography.dart';

/// A small avatar+name+@username row — the one visual shape shared by the
/// Friends list, incoming/outgoing requests, search results, and the
/// Friend/Non-Friend Profile header. Never renders anything beyond
/// identity (no visit counts, no activity) — [trailing] is the only slot
/// for anything else, so a caller can never accidentally grow this into
/// showing activity data by adding a field here.
class IdentityRow extends StatelessWidget {
  final String label;
  final String? username;
  final String? avatarUrl;
  final Widget? trailing;
  final VoidCallback? onTap;

  const IdentityRow({
    super.key,
    required this.label,
    this.username,
    this.avatarUrl,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // label may be a "@username" fallback (see Friendship/FriendRequest/
    // ProfileIdentity.label) — strip the leading "@" so the avatar shows
    // a real initial rather than "@".
    final source = label.startsWith('@') ? label.substring(1) : label;
    final words = source.trim().split(' ').where((w) => w.isNotEmpty);
    final initials = words.isEmpty
        ? '?'
        : words.map((w) => w[0]).take(2).join().toUpperCase();

    final row = Row(
      children: [
        _RowAvatar(initials: initials, avatarUrl: avatarUrl),
        const SizedBox(width: CsSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: CsTypography.bodyMedium.copyWith(
                  color: AppColors.textOnDark,
                ),
              ),
              if (username != null && username!.isNotEmpty) ...[
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
        if (trailing != null) ...[
          const SizedBox(width: CsSpacing.sm),
          trailing!,
        ],
      ],
    );

    if (onTap == null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: CsSpacing.sm),
        child: row,
      );
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(CsRadius.medium),
        splashColor: AppColors.textOnDark.withValues(alpha: 0.06),
        highlightColor: AppColors.textOnDark.withValues(alpha: 0.04),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            vertical: CsSpacing.sm,
            horizontal: CsSpacing.xs,
          ),
          child: row,
        ),
      ),
    );
  }
}

class _RowAvatar extends StatelessWidget {
  final String initials;
  final String? avatarUrl;
  const _RowAvatar({required this.initials, required this.avatarUrl});

  @override
  Widget build(BuildContext context) {
    final url = avatarUrl;
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.brandGreenLight,
        border: Border.all(color: AppColors.subtleBorderDark),
      ),
      alignment: Alignment.center,
      child: (url != null && url.isNotEmpty)
          ? ClipOval(
              child: Image.network(
                url,
                width: 44,
                height: 44,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => _InitialsText(initials),
              ),
            )
          : _InitialsText(initials),
    );
  }
}

class _InitialsText extends StatelessWidget {
  final String initials;
  const _InitialsText(this.initials);

  @override
  Widget build(BuildContext context) => Text(
    initials,
    style: CsTypography.bodyMedium.copyWith(color: AppColors.gold),
  );
}
