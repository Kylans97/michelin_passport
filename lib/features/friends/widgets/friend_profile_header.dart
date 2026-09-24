import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/cs_spacing.dart';
import '../../../core/theme/cs_typography.dart';
import 'friend_profile_widgets.dart';

/// The scrolls-away top of the friend-profile header: topbar (back
/// chevron, "⋯" menu), the friend's + viewer's overlapping avatars, name,
/// and the `@HANDLE · N STAMPS · N STARS` line. The tab row itself is a
/// separate, PINNED sliver (see [FriendProfileTabBarDelegate]) — this
/// widget is only ever the part that scrolls out of view.
class FriendProfileHeaderTop extends StatelessWidget {
  final String? friendPhoto;
  final String friendLabel;
  final String? myPhoto;
  final String myLabel;
  final String name;
  final String? username;
  final int stamps;
  final int stars;
  final VoidCallback onBack;
  final VoidCallback onRemoveFriend;
  final VoidCallback onBlock;
  final VoidCallback onReport;

  const FriendProfileHeaderTop({
    super.key,
    required this.friendPhoto,
    required this.friendLabel,
    required this.myPhoto,
    required this.myLabel,
    required this.name,
    required this.username,
    required this.stamps,
    required this.stars,
    required this.onBack,
    required this.onRemoveFriend,
    required this.onBlock,
    required this.onReport,
  });

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            CsSpacing.pageHorizontal,
            CsSpacing.sm,
            CsSpacing.pageHorizontal,
            0,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _RoundOutlineButton(
                icon: Icons.arrow_back_ios_new_rounded,
                iconSize: 16,
                semanticLabel: 'Back',
                onTap: onBack,
              ),
              _OverflowButton(
                onRemoveFriend: onRemoveFriend,
                onBlock: onBlock,
                onReport: onReport,
              ),
            ],
          ),
        ),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(
          CsSpacing.pageHorizontal,
          CsSpacing.md,
          CsSpacing.pageHorizontal,
          CsSpacing.lg,
        ),
        child: Column(
          children: [
            _OverlappingAvatars(
              friendPhoto: friendPhoto,
              friendLabel: friendLabel,
              myPhoto: myPhoto,
              myLabel: myLabel,
            ),
            const SizedBox(height: CsSpacing.md),
            Text(
              name,
              textAlign: TextAlign.center,
              style: CsTypography.editorialTitle(size: 34).copyWith(
                color: AppColors.textOnDark,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              [
                if (username != null) '@${username!.toUpperCase()}',
                '$stamps STAMPS',
                '$stars STARS',
              ].join(' · '),
              style: CsTypography.editorialLabel().copyWith(
                color: AppColors.secondaryOnDark,
              ),
            ),
          ],
        ),
      ),
    ],
  );
}

class _OverlappingAvatars extends StatelessWidget {
  final String? friendPhoto;
  final String friendLabel;
  final String? myPhoto;
  final String myLabel;

  const _OverlappingAvatars({
    required this.friendPhoto,
    required this.friendLabel,
    required this.myPhoto,
    required this.myLabel,
  });

  static const _size = 54.0;
  static const _overlap = 12.0;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: SizedBox(
      width: _size * 2 - _overlap,
      height: _size,
      child: Stack(
        children: [
          // The viewer sits BEHIND the friend — drawn first, offset right.
          Positioned(
            left: _size - _overlap,
            child: _Ring(
              child: FriendProfileAvatar(
                photoUrl: myPhoto,
                label: myLabel,
                size: _size,
                ringColor: Colors.transparent,
                fallbackBackground: AppColors.accent700,
                fallbackTextColor: AppColors.textOnDark,
              ),
            ),
          ),
          Positioned(
            left: 0,
            child: _Ring(
              child: FriendProfileAvatar(
                photoUrl: friendPhoto,
                label: friendLabel,
                size: _size,
                ringColor: Colors.transparent,
                fallbackBackground: AppColors.ivory,
                fallbackTextColor: AppColors.forestGreen,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _Ring extends StatelessWidget {
  final Widget child;
  const _Ring({required this.child});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(3),
    decoration: const BoxDecoration(shape: BoxShape.circle, color: AppColors.deepGreen),
    child: child,
  );
}

class _RoundOutlineButton extends StatelessWidget {
  final IconData icon;
  final double iconSize;
  final String semanticLabel;
  final VoidCallback onTap;

  const _RoundOutlineButton({
    required this.icon,
    required this.iconSize,
    required this.semanticLabel,
    required this.onTap,
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
            border: Border.all(color: AppColors.hairlineOnGreen),
          ),
          alignment: Alignment.center,
          child: ExcludeSemantics(
            child: Icon(icon, color: AppColors.textOnDark, size: iconSize),
          ),
        ),
      ),
    ),
  );
}

class _OverflowButton extends StatelessWidget {
  final VoidCallback onRemoveFriend;
  final VoidCallback onBlock;
  final VoidCallback onReport;

  const _OverflowButton({
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
    itemBuilder: (context) => const [
      PopupMenuItem(
        value: 'remove',
        child: Row(
          children: [
            Icon(Icons.person_remove_outlined, color: AppColors.textPrimary, size: 18),
            SizedBox(width: 10),
            Text('Remove friend'),
          ],
        ),
      ),
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
      child: const Icon(Icons.more_horiz_rounded, color: AppColors.textOnDark, size: 20),
    ),
  );
}

/// The PINNED tab row: `OVERVIEW · PASSPORT · TOGETHER`, 28pt gaps, a
/// 1px gold underline on the active tab, a hairline beneath the whole
/// row. Sticks to the top once the scrolling header above it is gone —
/// [SliverPersistentHeaderDelegate] is the standard Flutter mechanism for
/// exactly this ("de tabrij wordt sticky zodra hij de bovenkant raakt").
class FriendProfileTabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabController controller;
  static const _labels = ['OVERVIEW', 'PASSPORT', 'TOGETHER'];

  const FriendProfileTabBarDelegate({required this.controller});

  static const double _height = 52;

  @override
  double get minExtent => _height;
  @override
  double get maxExtent => _height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return ColoredBox(
      color: AppColors.deepGreen,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          TabBar(
            controller: controller,
            isScrollable: true,
            tabAlignment: TabAlignment.center,
            labelPadding: const EdgeInsets.symmetric(horizontal: 14),
            indicatorSize: TabBarIndicatorSize.label,
            indicatorColor: AppColors.gold600,
            indicatorWeight: 1,
            dividerColor: Colors.transparent,
            labelColor: AppColors.textOnDark,
            unselectedLabelColor: AppColors.stone600OnGreen,
            labelStyle: CsTypography.editorialLabel(),
            unselectedLabelStyle: CsTypography.editorialLabel(),
            splashFactory: NoSplash.splashFactory,
            overlayColor: const WidgetStatePropertyAll(Colors.transparent),
            tabs: [for (final label in _labels) Tab(text: label)],
          ),
          Container(height: 1, color: AppColors.hairlineOnGreen),
        ],
      ),
    );
  }

  @override
  bool shouldRebuild(covariant FriendProfileTabBarDelegate oldDelegate) =>
      oldDelegate.controller != controller;
}
