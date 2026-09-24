import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/cs_spacing.dart';
import '../../../core/theme/cs_typography.dart';
import '../../../core/widgets/cs_editorial_glyphs.dart';
import '../../../core/widgets/cs_invitation_card.dart';
import '../../../data/repositories/wishlist_repository.dart';
import '../../../models/passport_venue.dart';
import '../friend_activity_list_screen.dart';
import '../friend_profile_data.dart';
import '../friend_profile_screen.dart' show FriendVenueVisit, openFriendVenue;
import '../widgets/friend_profile_topbar.dart';
import '../widgets/friend_profile_widgets.dart';

/// Layout B — "Samen dineren." A shared-wishlist (or their-favourite)
/// invitation, then their verdicts as a scored list, then a wishlist
/// footer that hands off to the same [FriendWishlistListScreen] every
/// other entry point into a friend's wishlist already uses.
class FriendProfileLayoutB extends StatelessWidget {
  final FriendProfileLayoutData data;
  final WishlistRepository wishlistRepo;
  final String viewerUserId;
  final VoidCallback onBack;
  final VoidCallback onRemoveFriend;
  final VoidCallback onBlock;
  final VoidCallback onReport;

  const FriendProfileLayoutB({
    super.key,
    required this.data,
    required this.wishlistRepo,
    required this.viewerUserId,
    required this.onBack,
    required this.onRemoveFriend,
    required this.onBlock,
    required this.onReport,
  });

  @override
  Widget build(BuildContext context) {
    final sharedVenues = data.wishlist
        .where((v) => data.sharedKeys.contains(wishlistVenueKey(v)))
        .toList();

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
                CsSpacing.xl,
                CsSpacing.pageHorizontal,
                0,
              ),
              child: Column(
                children: [
                  _OverlappingAvatars(
                    friendPhoto: data.identity.avatarUrl,
                    friendLabel: data.friendName,
                    myPhoto: data.myIdentity?.avatarUrl,
                    myLabel: data.myIdentity?.label ?? 'You',
                  ),
                  const SizedBox(height: CsSpacing.md),
                  Text(
                    data.friendName,
                    textAlign: TextAlign.center,
                    style: CsTypography.editorialTitle(size: 36).copyWith(
                      color: AppColors.textOnDark,
                    ),
                  ),
                  if (data.identity.username != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      '@${data.identity.username!.toUpperCase()} · FRIENDS',
                      style: CsTypography.editorialLabel().copyWith(
                        color: AppColors.secondaryOnDark,
                      ),
                    ),
                  ],
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
              child: Center(
                child: sharedVenues.isNotEmpty
                    ? _SharedWishlistCard(venue: sharedVenues.first)
                    : _FavouriteCard(
                        visit: highestRatedVisit(data.visits),
                        wishlistRepo: wishlistRepo,
                        viewerUserId: viewerUserId,
                      ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                CsSpacing.pageHorizontal,
                CsSpacing.xxl,
                CsSpacing.pageHorizontal,
                0,
              ),
              child: _VerdictsSection(friendName: data.friendName, visits: data.visits),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                CsSpacing.pageHorizontal,
                CsSpacing.xl,
                CsSpacing.pageHorizontal,
                0,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Wishlist · ${data.wishlist.length} places',
                    style: CsTypography.editorialBody.copyWith(
                      color: AppColors.secondaryOnDark,
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => FriendWishlistListScreen(
                          userId: data.identity.id,
                          friendLabel: data.friendName,
                        ),
                      ),
                    ),
                    child: Text(
                      'View all →',
                      style: CsTypography.editorialLabel().copyWith(color: AppColors.gold300),
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

  static const _size = 62.0;
  static const _overlap = 14.0;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: SizedBox(
      width: _size * 2 - _overlap,
      height: _size,
      child: Stack(
        children: [
          Positioned(
            left: 0,
            child: _Ring(
              child: FriendProfileAvatar(
                photoUrl: friendPhoto,
                label: friendLabel,
                size: _size,
                doubleRing: false,
              ),
            ),
          ),
          Positioned(
            left: _size - _overlap,
            child: _Ring(
              child: FriendProfileAvatar(
                photoUrl: myPhoto,
                label: myLabel,
                size: _size,
                doubleRing: false,
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

class _SharedWishlistCard extends StatelessWidget {
  final PassportVenue venue;
  const _SharedWishlistCard({required this.venue});

  @override
  Widget build(BuildContext context) {
    final (cityName, award) = switch (venue) {
      RestaurantVenue(:final restaurant) => (
        restaurant.cityName,
        restaurant.hasMichelinStar
            ? CsEditorialStarRow(count: restaurant.michelinStars!)
            : null,
      ),
      HotelVenue(:final hotel) => (
        hotel.cityName,
        hotel.hasMichelinKeys ? CsEditorialKeyRow(count: hotel.michelinKeys!) : null,
      ),
    };

    return CsInvitationCard(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'ON BOTH YOUR WISHLISTS',
            style: CsTypography.editorialLabel().copyWith(color: AppColors.taupe),
          ),
          const SizedBox(height: 14),
          Text(
            venue.name,
            textAlign: TextAlign.center,
            style: CsTypography.editorialTitle(size: 38).copyWith(
              color: AppColors.forestGreen,
            ),
          ),
          const SizedBox(height: 6),
          CsCountryLabel(
            cityName: cityName,
            countryCode: venue.countryCode,
            style: CsTypography.editorialBody.copyWith(color: AppColors.taupe),
          ),
          if (award != null) ...[const SizedBox(height: 8), award],
          const SizedBox(height: 18),
          _PlanTableButton(),
        ],
      ),
    );
  }
}

class _FavouriteCard extends StatelessWidget {
  final FriendVenueVisit? visit;
  final WishlistRepository wishlistRepo;
  final String viewerUserId;

  const _FavouriteCard({
    required this.visit,
    required this.wishlistRepo,
    required this.viewerUserId,
  });

  @override
  Widget build(BuildContext context) {
    final fv = visit;
    if (fv == null) return const SizedBox.shrink();
    final (cityName, award) = switch (fv.venue) {
      RestaurantVenue(:final restaurant) => (
        restaurant.cityName,
        restaurant.hasMichelinStar
            ? CsEditorialStarRow(count: restaurant.michelinStars!)
            : null,
      ),
      HotelVenue(:final hotel) => (
        hotel.cityName,
        hotel.hasMichelinKeys ? CsEditorialKeyRow(count: hotel.michelinKeys!) : null,
      ),
    };

    return CsInvitationCard(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'THEIR FAVOURITE',
            style: CsTypography.editorialLabel().copyWith(color: AppColors.taupe),
          ),
          const SizedBox(height: 14),
          Text(
            fv.venue.name,
            textAlign: TextAlign.center,
            style: CsTypography.editorialTitle(size: 38).copyWith(
              color: AppColors.forestGreen,
            ),
          ),
          const SizedBox(height: 6),
          CsCountryLabel(
            cityName: cityName,
            countryCode: fv.venue.countryCode,
            style: CsTypography.editorialBody.copyWith(color: AppColors.taupe),
          ),
          if (award != null) ...[const SizedBox(height: 8), award],
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: _SaveToWishlistButton(
              venue: fv.venue,
              wishlistRepo: wishlistRepo,
              viewerUserId: viewerUserId,
            ),
          ),
        ],
      ),
    );
  }
}

// TODO(friend-profile-b): wire this to the real share/invite flow once
// one exists — a prefilled invitation via the platform share sheet, or
// in-app chat if that ships first (see the task brief's own note). For
// now this surfaces the intent without pretending the flow is built.
class _PlanTableButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    child: ElevatedButton(
      onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Planning together is coming soon.')),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.forestGreen,
        foregroundColor: AppColors.textOnDark,
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: const StadiumBorder(),
      ),
      child: const Text('Plan a table together'),
    ),
  );
}

class _SaveToWishlistButton extends StatefulWidget {
  final PassportVenue venue;
  final WishlistRepository wishlistRepo;
  final String viewerUserId;

  const _SaveToWishlistButton({
    required this.venue,
    required this.wishlistRepo,
    required this.viewerUserId,
  });

  @override
  State<_SaveToWishlistButton> createState() => _SaveToWishlistButtonState();
}

class _SaveToWishlistButtonState extends State<_SaveToWishlistButton> {
  bool _saved = false;
  bool _busy = false;

  Future<void> _save() async {
    if (_busy || _saved) return;
    setState(() => _busy = true);
    try {
      switch (widget.venue) {
        case RestaurantVenue(:final restaurant):
          await widget.wishlistRepo.toggleWishlist(
            userId: widget.viewerUserId,
            restaurantId: restaurant.id,
          );
        case HotelVenue(:final hotel):
          await widget.wishlistRepo.toggleHotelWishlist(
            userId: widget.viewerUserId,
            hotelId: hotel.id,
          );
      }
      if (mounted) setState(() => _saved = true);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not save. Please try again.')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => ElevatedButton(
    onPressed: _saved ? null : _save,
    style: ElevatedButton.styleFrom(
      backgroundColor: AppColors.forestGreen,
      foregroundColor: AppColors.textOnDark,
      padding: const EdgeInsets.symmetric(vertical: 14),
      shape: const StadiumBorder(),
    ),
    child: Text(_saved ? 'Saved' : 'Save to my wishlist'),
  );
}

class _VerdictsSection extends StatelessWidget {
  final String friendName;
  final List<FriendVenueVisit> visits;

  const _VerdictsSection({required this.friendName, required this.visits});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "${friendName.toUpperCase()}'S VERDICTS",
          style: CsTypography.editorialLabel().copyWith(color: AppColors.secondaryOnDark),
        ),
        const SizedBox(height: CsSpacing.sm),
        if (visits.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: CsSpacing.lg),
            child: Text(
              "$friendName hasn't stamped anything yet.",
              style: CsTypography.editorialLead().copyWith(color: AppColors.secondaryOnDark),
            ),
          )
        else
          for (final fv in visits) _VerdictRow(visit: fv, onTap: () => openFriendVenue(context, fv.venue)),
      ],
    );
  }
}

class _VerdictRow extends StatelessWidget {
  final FriendVenueVisit visit;
  final VoidCallback onTap;
  const _VerdictRow({required this.visit, required this.onTap});

  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

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
    final score = visit.score;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(height: 1, color: AppColors.hairlineOnGreen),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: CsSpacing.sm),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                visit.venue.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: CsTypography.editorialTitle(size: 22).copyWith(
                                  color: AppColors.textOnDark,
                                ),
                              ),
                            ),
                            if (award != null) ...[const SizedBox(width: 6), award],
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${visit.cityName} · ${date.day} ${_months[date.month - 1]}',
                          style: CsTypography.editorialBody.copyWith(
                            color: AppColors.secondaryOnDark,
                            fontSize: 12.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (score != null)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          '$score',
                          style: CsTypography.editorialTitle(size: 36).copyWith(
                            color: AppColors.gold300,
                          ),
                        ),
                        Text(
                          '/10',
                          style: CsTypography.editorialLead(size: 16).copyWith(
                            color: AppColors.secondaryOnDark,
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
    );
  }
}
