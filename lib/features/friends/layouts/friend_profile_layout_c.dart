import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/cs_spacing.dart';
import '../../../core/theme/cs_typography.dart';
import '../../../core/widgets/cs_editorial_glyphs.dart';
import '../../../models/passport_venue.dart';
import '../friend_profile_data.dart';
import '../friend_profile_screen.dart' show FriendVenueVisit, openFriendVenue;
import '../widgets/friend_profile_topbar.dart';
import '../widgets/friend_profile_widgets.dart';

const _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

/// Layout C — "De column." A full-page ivory magazine spread: a centred
/// masthead, recent visits as mini-reviews (quoting the friend's own
/// visit note when one exists — never fabricated), then a green wishlist
/// rail filling the rest of the screen.
class FriendProfileLayoutC extends StatelessWidget {
  final FriendProfileLayoutData data;
  final VoidCallback onBack;
  final VoidCallback onRemoveFriend;
  final VoidCallback onBlock;
  final VoidCallback onReport;

  const FriendProfileLayoutC({
    super.key,
    required this.data,
    required this.onBack,
    required this.onRemoveFriend,
    required this.onBlock,
    required this.onReport,
  });

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.background,
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            FriendProfileTopBar(
              onDark: false,
              showCenterLogo: true,
              onBack: onBack,
              onRemoveFriend: onRemoveFriend,
              onBlock: onBlock,
              onReport: onReport,
              showRemoveFriend: true,
            ),
            Expanded(
              child: CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(child: _Masthead(data: data)),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(
                      CsSpacing.pageHorizontal,
                      CsSpacing.xl,
                      CsSpacing.pageHorizontal,
                      0,
                    ),
                    sliver: SliverToBoxAdapter(
                      child: _LatelySection(friendName: data.friendName, data: data),
                    ),
                  ),
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: _WishlistRail(data: data),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Masthead extends StatelessWidget {
  final FriendProfileLayoutData data;
  const _Masthead({required this.data});

  @override
  Widget build(BuildContext context) {
    final parts = [
      if (data.identity.username != null) '@${data.identity.username}',
      '${data.stats.stamps} visits',
      '${data.wishlist.length} on the wishlist',
      'Friends',
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        CsSpacing.pageHorizontal,
        CsSpacing.xl,
        CsSpacing.pageHorizontal,
        CsSpacing.lg,
      ),
      child: Column(
        children: [
          Text(
            'THE TABLE OF',
            style: CsTypography.editorialLabel().copyWith(color: AppColors.gold700),
          ),
          const SizedBox(height: 6),
          Text(
            data.friendName,
            textAlign: TextAlign.center,
            style: CsTypography.editorialDisplay(size: 64).copyWith(
              color: AppColors.forestGreen,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            parts.join(' · '),
            textAlign: TextAlign.center,
            style: CsTypography.editorialBody.copyWith(color: AppColors.taupe, fontSize: 12.5),
          ),
          const SizedBox(height: CsSpacing.lg),
          Container(height: 1, color: AppColors.hairlineOnPaper),
        ],
      ),
    );
  }
}

class _LatelySection extends StatelessWidget {
  final String friendName;
  final FriendProfileLayoutData data;
  const _LatelySection({required this.friendName, required this.data});

  @override
  Widget build(BuildContext context) {
    final visits = data.visits;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'LATELY',
          style: CsTypography.editorialLabel().copyWith(color: AppColors.taupe),
        ),
        const SizedBox(height: CsSpacing.sm),
        if (visits.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: CsSpacing.lg),
            child: Text(
              "$friendName hasn't stamped anything yet.",
              style: CsTypography.editorialLead().copyWith(color: AppColors.taupe),
            ),
          )
        else
          for (final fv in visits)
            _ReviewRow(
              visit: fv,
              photoUrl: data.coverPhotoByVisitId[fv.visit.id],
              onTap: () => openFriendVenue(context, fv.venue),
            ),
      ],
    );
  }
}

class _ReviewRow extends StatelessWidget {
  final FriendVenueVisit visit;
  final String? photoUrl;
  final VoidCallback onTap;

  const _ReviewRow({required this.visit, required this.photoUrl, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final award = switch (visit.venue) {
      RestaurantVenue(:final restaurant) when restaurant.hasMichelinStar =>
        CsEditorialStarRow(count: restaurant.michelinStars!, size: 12),
      HotelVenue(:final hotel) when hotel.hasMichelinKeys =>
        CsEditorialKeyRow(count: hotel.michelinKeys!, size: 12),
      _ => null,
    };
    final date = visit.visit.visitedOn;
    final note = visit.visit.notes?.trim();
    final score = visit.score;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(height: 1, color: AppColors.hairlineOnPaper),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: CsSpacing.md),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  PhotoOrTile(
                    photoUrl: photoUrl,
                    venueName: visit.venue.name,
                    width: 96,
                    height: 112,
                  ),
                  const SizedBox(width: CsSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${visit.cityName.toUpperCase()} · '
                          '${date.day} ${_months[date.month - 1].toUpperCase()}',
                          style: CsTypography.editorialLabel().copyWith(color: AppColors.gold700),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                visit.venue.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: CsTypography.editorialTitle(size: 24).copyWith(
                                  color: AppColors.forestGreen,
                                ),
                              ),
                            ),
                            if (award != null) ...[const SizedBox(width: 6), award],
                          ],
                        ),
                        if (note != null && note.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(
                            '"$note"',
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: CsTypography.editorialTitle(
                              size: 15,
                              italic: true,
                            ).copyWith(color: AppColors.textSecondary),
                          ),
                        ],
                        const Spacer(),
                        if (score != null)
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.baseline,
                            textBaseline: TextBaseline.alphabetic,
                            children: [
                              Text(
                                '$score',
                                style: CsTypography.editorialTitle(size: 28).copyWith(
                                  color: AppColors.gold700,
                                ),
                              ),
                              Text(
                                '/10',
                                style: CsTypography.editorialLead(size: 14).copyWith(
                                  color: AppColors.taupe,
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WishlistRail extends StatelessWidget {
  final FriendProfileLayoutData data;
  const _WishlistRail({required this.data});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(color: AppColors.deepGreen),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: CsSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: CsSpacing.pageHorizontal),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'ON THE WISHLIST',
                    style: CsTypography.editorialLabel().copyWith(color: AppColors.secondaryOnDark),
                  ),
                  Text(
                    'All →',
                    style: CsTypography.editorialLabel().copyWith(color: AppColors.gold300),
                  ),
                ],
              ),
            ),
            const SizedBox(height: CsSpacing.md),
            if (data.wishlist.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: CsSpacing.pageHorizontal),
                child: Text(
                  "Nothing on ${data.friendName}'s wishlist yet.",
                  style: CsTypography.editorialLead().copyWith(color: AppColors.secondaryOnDark),
                ),
              )
            else
              SizedBox(
                height: 118,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: CsSpacing.pageHorizontal),
                  itemCount: data.wishlist.length,
                  separatorBuilder: (_, _) => const SizedBox(width: CsSpacing.md),
                  itemBuilder: (context, i) {
                    final venue = data.wishlist[i];
                    return GestureDetector(
                      onTap: () => openFriendVenue(context, venue),
                      child: SizedBox(
                        width: 90,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            PhotoOrTile(
                              photoUrl: null,
                              venueName: venue.name,
                              width: 90,
                              height: 78,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              venue.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: CsTypography.editorialTitle(size: 16).copyWith(
                                color: AppColors.textOnDark,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}
