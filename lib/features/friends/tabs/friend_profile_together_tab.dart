import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/cs_spacing.dart';
import '../../../core/theme/cs_typography.dart';
import '../../../core/widgets/cs_editorial_glyphs.dart';
import '../../../data/repositories/wishlist_repository.dart';
import '../../../models/passport_venue.dart';
import '../friend_profile_data.dart';
import '../friend_profile_screen.dart' show openFriendVenue;
import '../widgets/friend_profile_widgets.dart';

/// Tab 3: shared wishlist items (each with its own "Plan" pill), then the
/// friend's own-only items (each with a "+" that saves it to the viewer's
/// wishlist and moves it up into the shared section), then a sticky
/// "Suggest going together" button pinned to the bottom of the tab — both
/// open the real venue-invite flow (`showPlanDinnerSheet`), not a preview.
///
/// Stateful (unlike the other two tabs) because the +/move interaction is
/// real, local, optimistic state — the shared/only-theirs split changes
/// live as the viewer adds items, not just once per screen load.
class FriendProfileTogetherTab extends StatefulWidget {
  final FriendProfileLayoutData data;
  final WishlistRepository wishlistRepo;
  final String viewerUserId;
  final void Function(PassportVenue? preselected) onPlanDinner;

  const FriendProfileTogetherTab({
    super.key,
    required this.data,
    required this.wishlistRepo,
    required this.viewerUserId,
    required this.onPlanDinner,
  });

  @override
  State<FriendProfileTogetherTab> createState() => _FriendProfileTogetherTabState();
}

class _FriendProfileTogetherTabState extends State<FriendProfileTogetherTab> {
  late List<PassportVenue> _shared = widget.data.sharedWishlistVenues;
  late List<PassportVenue> _onlyTheirs = widget.data.onlyTheirWishlistVenues;
  final _addingKeys = <String>{};

  Future<void> _addToMyWishlist(PassportVenue venue) async {
    final key = wishlistVenueKey(venue);
    if (_addingKeys.contains(key)) return;
    setState(() => _addingKeys.add(key));
    try {
      switch (venue) {
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
      if (!mounted) return;
      HapticFeedback.lightImpact();
      setState(() {
        _onlyTheirs = _onlyTheirs.where((v) => wishlistVenueKey(v) != key).toList();
        _shared = [..._shared, venue];
        _addingKeys.remove(key);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _addingKeys.remove(key));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not save. Please try again.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasAnything = _shared.isNotEmpty || _onlyTheirs.isNotEmpty;

    return Stack(
      children: [
        Positioned.fill(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              CsSpacing.pageHorizontal,
              CsSpacing.lg,
              CsSpacing.pageHorizontal,
              96,
            ),
            children: [
              Text(
                'Where you’d both go',
                style: CsTypography.editorialTitle(size: 20, italic: true).copyWith(
                  color: AppColors.textOnDark,
                ),
              ),
              const SizedBox(height: CsSpacing.lg),
              if (!hasAnything)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: CsSpacing.lg),
                  child: Text(
                    'Nothing in common yet',
                    style: CsTypography.editorialLead().copyWith(
                      color: AppColors.secondaryOnDark,
                    ),
                  ),
                ),
              AnimatedSize(
                duration: const Duration(milliseconds: 260),
                curve: Curves.easeOut,
                alignment: Alignment.topCenter,
                child: Column(
                  children: [
                    for (final venue in _shared)
                      KeyedSubtree(
                        key: ValueKey(wishlistVenueKey(venue)),
                        child: TweenAnimationBuilder<double>(
                          tween: Tween(begin: 0, end: 1),
                          duration: const Duration(milliseconds: 260),
                          curve: Curves.easeOut,
                          builder: (context, t, child) =>
                              Opacity(opacity: t, child: child),
                          child: _SharedRow(
                            venue: venue,
                            onPlan: () => widget.onPlanDinner(venue),
                            onTap: () => openFriendVenue(context, venue),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              if (_onlyTheirs.isNotEmpty) ...[
                const SizedBox(height: CsSpacing.xl),
                Text(
                  "ONLY ON ${widget.data.friendName.toUpperCase()}'S LIST",
                  style: CsTypography.editorialLabel().copyWith(
                    color: AppColors.secondaryOnDark,
                  ),
                ),
              ],
              AnimatedSize(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOut,
                alignment: Alignment.topCenter,
                child: Column(
                  children: [
                    for (final venue in _onlyTheirs)
                      KeyedSubtree(
                        key: ValueKey(wishlistVenueKey(venue)),
                        child: _DimmedRow(
                          venue: venue,
                          adding: _addingKeys.contains(wishlistVenueKey(venue)),
                          onAdd: () => _addToMyWishlist(venue),
                          onTap: () => openFriendVenue(context, venue),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                CsSpacing.pageHorizontal,
                CsSpacing.sm,
                CsSpacing.pageHorizontal,
                CsSpacing.sm,
              ),
              child: SizedBox(
                height: 52,
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => widget.onPlanDinner(null),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.gold600,
                    foregroundColor: AppColors.textPrimary,
                    shape: const StadiumBorder(),
                    textStyle: CsTypography.editorialBody.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  child: const Text('Suggest going together'),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _SharedRow extends StatelessWidget {
  final PassportVenue venue;
  final VoidCallback onPlan;
  final VoidCallback onTap;

  const _SharedRow({required this.venue, required this.onPlan, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final (cityName, award) = switch (venue) {
      RestaurantVenue(:final restaurant) => (
        restaurant.cityName,
        restaurant.hasMichelinStar
            ? CsEditorialStarRow(count: restaurant.michelinStars!, size: 12)
            : null,
      ),
      HotelVenue(:final hotel) => (
        hotel.cityName,
        hotel.hasMichelinKeys
            ? CsEditorialKeyRow(count: hotel.michelinKeys!, size: 12)
            : null,
      ),
    };

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
                  PhotoOrTile(photoUrl: null, venueName: venue.name, width: 72, height: 72),
                  const SizedBox(width: CsSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          venue.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: CsTypography.editorialTitle(size: 19).copyWith(
                            color: AppColors.textOnDark,
                          ),
                        ),
                        if (award != null) ...[const SizedBox(height: 3), award],
                        const SizedBox(height: 3),
                        CsCountryLabel(
                          cityName: cityName,
                          countryCode: venue.countryCode,
                          style: CsTypography.editorialBody.copyWith(
                            color: AppColors.secondaryOnDark,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: CsSpacing.sm),
                  _PlanPill(onTap: onPlan),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlanPill extends StatelessWidget {
  final VoidCallback onTap;
  const _PlanPill({required this.onTap});

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.transparent,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(17),
      child: Container(
        height: 34,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.gold600, width: 1),
          borderRadius: BorderRadius.circular(17),
        ),
        child: Text(
          'Suggest',
          style: CsTypography.editorialLabel().copyWith(color: AppColors.textOnDark),
        ),
      ),
    ),
  );
}

class _DimmedRow extends StatelessWidget {
  final PassportVenue venue;
  final bool adding;
  final VoidCallback onAdd;
  final VoidCallback onTap;

  const _DimmedRow({
    required this.venue,
    required this.adding,
    required this.onAdd,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cityName = switch (venue) {
      RestaurantVenue(:final restaurant) => restaurant.cityName,
      HotelVenue(:final hotel) => hotel.cityName,
    };

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
                        Text(
                          venue.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: CsTypography.editorialTitle(size: 18).copyWith(
                            color: AppColors.secondaryOnDark,
                          ),
                        ),
                        const SizedBox(height: 3),
                        CsCountryLabel(
                          cityName: cityName,
                          countryCode: venue.countryCode,
                          style: CsTypography.editorialBody.copyWith(
                            color: AppColors.secondaryOnDark.withValues(alpha: 0.7),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: CsSpacing.sm),
                  _AddButton(busy: adding, onTap: onAdd),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AddButton extends StatelessWidget {
  final bool busy;
  final VoidCallback onTap;
  const _AddButton({required this.busy, required this.onTap});

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: 'Add to my wishlist',
    child: Material(
      color: Colors.transparent,
      shape: const CircleBorder(),
      child: InkWell(
        onTap: busy ? null : onTap,
        customBorder: const CircleBorder(),
        child: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.hairlineOnGreen.withValues(alpha: 1)),
          ),
          alignment: Alignment.center,
          child: busy
              ? const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 1.5,
                    color: AppColors.textOnDark,
                  ),
                )
              : const Icon(Icons.add_rounded, color: AppColors.textOnDark, size: 18),
        ),
      ),
    ),
  );
}
