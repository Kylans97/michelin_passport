import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/cs_spacing.dart';
import '../../../core/widgets/cs_masthead_logo.dart';

/// The topbar shared by all three friend-profile layouts: a back chevron
/// left, a 40pt round outline "⋯" button right. [onDark] switches the
/// icon/outline color for the green-canvas layouts (A/B) vs. layout C's
/// ink-on-paper masthead, which also shows the small logo centred.
class FriendProfileTopBar extends StatelessWidget {
  final bool onDark;
  final bool showCenterLogo;
  final VoidCallback onBack;
  final VoidCallback onRemoveFriend;
  final VoidCallback onBlock;
  final VoidCallback onReport;
  final bool showRemoveFriend;

  const FriendProfileTopBar({
    super.key,
    required this.onDark,
    required this.onBack,
    required this.onRemoveFriend,
    required this.onBlock,
    required this.onReport,
    required this.showRemoveFriend,
    this.showCenterLogo = false,
  });

  @override
  Widget build(BuildContext context) {
    final iconColor = onDark ? AppColors.textOnDark : AppColors.forestGreen;
    final borderColor = onDark
        ? AppColors.hairlineOnGreen
        : AppColors.hairlineOnPaper;

    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          CsSpacing.pageHorizontal,
          CsSpacing.sm,
          CsSpacing.pageHorizontal,
          0,
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (showCenterLogo) const CsMastheadLogo(size: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _RoundOutlineButton(
                  icon: Icons.arrow_back_ios_new_rounded,
                  iconSize: 16,
                  color: iconColor,
                  borderColor: borderColor,
                  onTap: onBack,
                  semanticLabel: 'Back',
                ),
                _OverflowButton(
                  color: iconColor,
                  borderColor: borderColor,
                  showRemoveFriend: showRemoveFriend,
                  onRemoveFriend: onRemoveFriend,
                  onBlock: onBlock,
                  onReport: onReport,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _RoundOutlineButton extends StatelessWidget {
  final IconData icon;
  final double iconSize;
  final Color color;
  final Color borderColor;
  final VoidCallback onTap;
  final String semanticLabel;

  const _RoundOutlineButton({
    required this.icon,
    required this.iconSize,
    required this.color,
    required this.borderColor,
    required this.onTap,
    required this.semanticLabel,
  });

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: semanticLabel,
    child: Material(
      color: Colors.transparent,
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: borderColor),
          ),
          alignment: Alignment.center,
          child: ExcludeSemantics(child: Icon(icon, color: color, size: iconSize)),
        ),
      ),
    ),
  );
}

class _OverflowButton extends StatelessWidget {
  final Color color;
  final Color borderColor;
  final bool showRemoveFriend;
  final VoidCallback onRemoveFriend;
  final VoidCallback onBlock;
  final VoidCallback onReport;

  const _OverflowButton({
    required this.color,
    required this.borderColor,
    required this.showRemoveFriend,
    required this.onRemoveFriend,
    required this.onBlock,
    required this.onReport,
  });

  @override
  Widget build(BuildContext context) => PopupMenuButton<String>(
    color: AppColors.card,
    onSelected: (value) => switch (value) {
      'remove' => onRemoveFriend(),
      'block' => onBlock(),
      'report' => onReport(),
      _ => null,
    },
    itemBuilder: (context) => [
      if (showRemoveFriend)
        const PopupMenuItem(
          value: 'remove',
          child: Row(
            children: [
              Icon(Icons.person_remove_outlined, color: AppColors.textPrimary, size: 18),
              SizedBox(width: 10),
              Text('Remove friend'),
            ],
          ),
        ),
      const PopupMenuItem(
        value: 'report',
        child: Row(
          children: [
            Icon(Icons.flag_outlined, color: AppColors.textPrimary, size: 18),
            SizedBox(width: 10),
            Text('Report profile'),
          ],
        ),
      ),
      const PopupMenuItem(
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
        border: Border.all(color: borderColor),
      ),
      alignment: Alignment.center,
      child: Icon(Icons.more_horiz_rounded, color: color, size: 20),
    ),
  );
}
