import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/cs_spacing.dart';
import '../../../core/theme/cs_typography.dart';
import '../../../models/passport_venue.dart';
import '../friend_profile_data.dart';
import '../friend_profile_screen.dart' show openFriendVenue;
import '../widgets/friend_profile_stamp_page.dart';
import '../widgets/friend_profile_topbar.dart';
import '../widgets/friend_profile_widgets.dart';

/// Layout A — "Hun paspoort" (default). Identity + stats on the green
/// canvas, then the read-only stamped passport page, then the wishlist
/// as a ledger with shared items surfaced first.
class FriendProfileLayoutA extends StatelessWidget {
  final FriendProfileLayoutData data;
  final VoidCallback onBack;
  final VoidCallback onRemoveFriend;
  final VoidCallback onBlock;
  final VoidCallback onReport;

  const FriendProfileLayoutA({
    super.key,
    required this.data,
    required this.onBack,
    required this.onRemoveFriend,
    required this.onBlock,
    required this.onReport,
  });

  @override
  Widget build(BuildContext context) {
    final sharedCount = data.sharedKeys.length;
    final wishlist = [...data.wishlist]
      ..sort((a, b) {
        final aShared = data.sharedKeys.contains(wishlistVenueKey(a));
        final bShared = data.sharedKeys.contains(wishlistVenueKey(b));
        if (aShared != bShared) return aShared ? -1 : 1;
        return 0;
      });

    return ColoredBox(
      color: AppColors.deepGreen,
      child: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.only(bottom: CsSpacing.xxl),
          children: [
            FriendProfileTopBar(
              onDark: true,
              onBack: onBack,
              onRemoveFriend: onRemoveFriend,
              onBlock: onBlock,
              onReport: onReport,
              showRemoveFriend: true,
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                CsSpacing.pageHorizontal,
                CsSpacing.lg,
                CsSpacing.pageHorizontal,
                0,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  FriendProfileAvatar(photoUrl: data.identity.avatarUrl, label: data.friendName),
                  const SizedBox(width: 18),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          data.friendName,
                          style: CsTypography.editorialTitle(size: 40).copyWith(
                            color: AppColors.textOnDark,
                            height: 0.95,
                          ),
                        ),
                        if (data.identity.username != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            '@${data.identity.username}',
                            style: CsTypography.editorialBody.copyWith(
                              color: AppColors.secondaryOnDark,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                CsSpacing.pageHorizontal,
                CsSpacing.lg,
                CsSpacing.pageHorizontal,
                0,
              ),
              child: FriendProfileStatsRow(
                stats: [
                  FriendProfileStat(value: '${data.stats.stamps}', label: 'STAMPS'),
                  FriendProfileStat(value: '${data.stats.countries}', label: 'COUNTRIES'),
                  FriendProfileStat(value: '${data.stats.stars}', label: 'STARS', gold: true),
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
              child: FriendProfileStampPage(
                visits: data.visits,
                ownerName: data.friendName,
                onTapStamp: (fv) => openFriendVenue(context, fv.venue),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                CsSpacing.pageHorizontal,
                CsSpacing.xxl,
                CsSpacing.pageHorizontal,
                0,
              ),
              child: _WishlistSection(
                friendName: data.friendName,
                wishlist: wishlist,
                sharedCount: sharedCount,
                sharedKeys: data.sharedKeys,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WishlistSection extends StatelessWidget {
  final String friendName;
  final List<PassportVenue> wishlist;
  final int sharedCount;
  final Set<String> sharedKeys;

  const _WishlistSection({
    required this.friendName,
    required this.wishlist,
    required this.sharedCount,
    required this.sharedKeys,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'WISHLIST',
              style: CsTypography.editorialLabel().copyWith(color: AppColors.secondaryOnDark),
            ),
            if (sharedCount > 0)
              Text(
                '$sharedCount in common with you',
                style: CsTypography.editorialLabel().copyWith(color: AppColors.gold300),
              ),
          ],
        ),
        const SizedBox(height: CsSpacing.sm),
        if (wishlist.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: CsSpacing.lg),
            child: Text(
              "Nothing on $friendName's wishlist yet.",
              style: CsTypography.editorialLead().copyWith(color: AppColors.secondaryOnDark),
            ),
          )
        else
          DecoratedBox(
            decoration: const BoxDecoration(color: AppColors.background),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: CsSpacing.md),
              child: Column(
                children: [
                  for (final venue in wishlist)
                    WishlistRow(
                      venue: venue,
                      sharedWithViewer: sharedKeys.contains(wishlistVenueKey(venue)),
                      onTap: () => openFriendVenue(context, venue),
                    ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
