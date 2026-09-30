import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/cs_spacing.dart';
import '../../../core/theme/cs_typography.dart';
import '../../../core/widgets/editorial_back_button.dart';
import '../../../core/widgets/follow_toggle_button.dart';
import '../../../core/widgets/hero_photo_chevron.dart';
import '../../../models/content_report.dart';
import '../../../models/private_chef_photo.dart';
import '../../reports/widgets/report_content_sheet.dart';

/// Chef Detail's hero — a parallel, trimmed sibling of [VenueDetailHero],
/// not a reuse of it: that widget hard-requires wishlist state
/// ([isWishlisted]/[wishlistSaving]/[onTapWishlist]), which has no
/// equivalent concept here (Private Chefs is not on Wishlist — see
/// PRIVATE_CHEFS.md §33). Building a small parallel component for a
/// genuinely different screen is this codebase's own established pattern
/// — [VenueDetailHero] itself exists for exactly this reason rather than
/// modifying the older shared `DetailHero`.
///
/// Deliberately shows NO score, rating, review count, "Mantelier
/// Selected" badge, Michelin stars, or price badge — the chef's page
/// existing at all is the selection signal (PRIVATE_CHEFS.md §14). The one
/// permitted editorial context label is the small "PRIVATE CHEF" eyebrow,
/// never worded as a badge/credential.
///
/// Step 2B — PHOTO GALLERY: background image resolution, in order:
///   1. [photos] (up to 5, [PrivateChefPhoto.displayOrder] ascending) —
///      1 photo renders as a static image; 2–5 render as a swipeable
///      [PageView] with a chevron at each edge (no dot/count indicator —
///      the chevrons alone carry position; no autoplay, no thumbnail
///      rail — see the class's own gallery widgets below).
///   2. [profileImageUrl] — a single static fallback image when no
///      gallery photo exists yet, matching the schema's own documented
///      profile_image_url (avatar/fallback) vs. private_chef_photos
///      (curated gallery) split.
///   3. the existing branded gradient placeholder, unchanged.
class PrivateChefHero extends StatefulWidget {
  final String displayName;
  final String? businessName;

  /// Pre-formatted "City, Country" (or just city, or just the country) —
  /// the hero doesn't know about PrivateChef, only about strings already
  /// assembled by the caller (see `formatChefLocation`), matching
  /// [PrivateChefDiscoveryCard]'s own location-join approach.
  final String? location;

  final List<PrivateChefPhoto> photos;
  final String? profileImageUrl;
  final double expandedHeight;

  /// Events V2 Step 6. Nullable and defaults to null — see
  /// VenueDetailHero's own doc comment for why: when omitted, no Follow
  /// control renders, so every pre-Step-6 call site (and test) keeps its
  /// exact prior rendering.
  final bool isFollowing;
  final bool followBusy;
  final VoidCallback? onTapFollow;

  const PrivateChefHero({
    super.key,
    required this.displayName,
    this.businessName,
    this.location,
    this.photos = const [],
    this.profileImageUrl,
    this.expandedHeight = 320,
    this.isFollowing = false,
    this.followBusy = false,
    this.onTapFollow,
  });

  @override
  State<PrivateChefHero> createState() => _PrivateChefHeroState();
}

class _PrivateChefHeroState extends State<PrivateChefHero> {
  late final PageController _pageController;
  int _pageIndex = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _goToNextPhoto() {
    _pageController.nextPage(
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
    );
  }

  void _goToPreviousPhoto() {
    _pageController.previousPage(
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final photos = widget.photos;
    final hasGallery = photos.isNotEmpty;
    final hasFallbackPhoto =
        !hasGallery && (widget.profileImageUrl ?? '').isNotEmpty;
    final hasAnyPhoto = hasGallery || hasFallbackPhoto;
    // A swipeable set only exists for 2+ photos — _PhotoGallery itself
    // renders a single photo as a plain static image (no PageView), same
    // "1 photo changes nothing" rule VenueDetailHero's gallery follows.
    final isGallery = photos.length > 1;

    return SliverAppBar(
      expandedHeight: widget.expandedHeight,
      pinned: true,
      backgroundColor: AppColors.deepGreen,
      foregroundColor: AppColors.textOnDark,
      leadingWidth: 56,
      leading: const Padding(
        padding: EdgeInsets.only(left: CsSpacing.sm),
        child: EditorialBackButton(),
      ),
      actions: [
        if (widget.onTapFollow != null)
          Padding(
            padding: const EdgeInsets.only(right: CsSpacing.sm),
            child: FollowToggleButton(
              isFollowing: widget.isFollowing,
              busy: widget.followBusy,
              onTap: widget.onTapFollow,
              entityName: widget.displayName,
            ),
          ),
      ],
      // Physical-device review (Step 2C): no top-center title here — it
      // sat directly over the photo, redundant with the large displayHero
      // name lower in this same hero, and competed with the iOS Dynamic
      // Island/status-bar region for the same top strip. Restaurant/Hotel/
      // Event Detail keep their own SliverAppBar title (VenueDetailHero,
      // EventDetailHero) — that convention isn't changed, only this
      // screen's, per the explicit device-review call to test back-arrow
      // -only top navigation here.
      flexibleSpace: FlexibleSpaceBar(
        collapseMode: CollapseMode.parallax,
        background: Stack(
          fit: StackFit.expand,
          children: [
            if (hasGallery)
              _PhotoGallery(
                photos: photos,
                controller: _pageController,
                onPageChanged: (index) => setState(() => _pageIndex = index),
              )
            else if (hasFallbackPhoto)
              _HeroImage(url: widget.profileImageUrl!)
            else
              const _NoPhotoBackground(),
            // Bottom-weighted vignette so identity text stays legible
            // regardless of whether there's a photo underneath — same
            // treatment as VenueDetailHero.
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    AppColors.deepGreen.withValues(
                      alpha: hasAnyPhoto ? 0.55 : 0,
                    ),
                    AppColors.deepGreen.withValues(
                      alpha: hasAnyPhoto ? 0.9 : 1,
                    ),
                  ],
                  stops: const [0.0, 0.55, 1.0],
                ),
              ),
            ),
            if (isGallery && _pageIndex > 0)
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                child: Center(
                  child: HeroPhotoChevron(
                    icon: Icons.chevron_left_rounded,
                    onTap: _goToPreviousPhoto,
                  ),
                ),
              ),
            if (isGallery && _pageIndex < photos.length - 1)
              Positioned(
                right: 0,
                top: 0,
                bottom: 0,
                child: Center(
                  child: HeroPhotoChevron(
                    icon: Icons.chevron_right_rounded,
                    onTap: _goToNextPhoto,
                  ),
                ),
              ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  CsSpacing.pageHorizontal,
                  CsSpacing.hero,
                  CsSpacing.pageHorizontal,
                  CsSpacing.lg,
                ),
                child: SingleChildScrollView(
                  physics: const NeverScrollableScrollPhysics(),
                  // Mechanism (confirmed identical to VenueDetailHero's own
                  // fix): this box is stretched to the FULL hero area by
                  // the parent Stack's StackFit.expand, and Scrollable's
                  // own hit-test behaviour defaults to
                  // HitTestBehavior.opaque regardless of
                  // NeverScrollableScrollPhysics (that only empties its
                  // drag-recognizer list, it doesn't change hit-testing).
                  // Stack hit-testing stops at the first child that
                  // reports a hit, walking topmost-first — so this box,
                  // sitting above the gallery in the Stack, was silently
                  // absorbing every pointer down across the whole photo
                  // before the PageView ever saw it. This is exactly the
                  // same reason _ReportPhotoButton below has to be the
                  // LAST Stack child (its own doc comment describes the
                  // identical mechanism) — that workaround fixes a small
                  // button by outranking this box in hit-test order, but
                  // doesn't help the PageView, which sits BENEATH this box
                  // and can't be reordered above the text/gradient it's a
                  // background for. translucent still lets this box
                  // report itself as hit without stopping the Stack from
                  // also testing the sibling behind it.
                  hitTestBehavior: HitTestBehavior.translucent,
                  reverse: true,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'PRIVATE CHEF',
                        style: CsTypography.eyebrow.copyWith(
                          color: AppColors.secondaryOnDark,
                        ),
                      ),
                      const SizedBox(height: CsSpacing.xs),
                      Text(
                        widget.displayName,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: CsTypography.displayHero.copyWith(
                          color: AppColors.textOnDark,
                          fontSize: 30,
                          height: 1.1,
                        ),
                      ),
                      if ((widget.businessName ?? '').isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          widget.businessName!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: CsTypography.bodyMedium.copyWith(
                            color: AppColors.secondaryOnDark,
                          ),
                        ),
                      ],
                      if ((widget.location ?? '').isNotEmpty) ...[
                        const SizedBox(height: CsSpacing.xs),
                        Text(
                          widget.location!,
                          style: CsTypography.metadata.copyWith(
                            color: AppColors.secondaryOnDark,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            // A generic "Report photo" — private_chef_photos has no
            // submitted_by/user_id (admin-curated, not tied to any end
            // user), so this reports the photo itself, not a person.
            // History: this used to have to be the LAST Stack child,
            // because the identity-text SafeArea above defaults its
            // Scrollable to HitTestBehavior.opaque and, filling the whole
            // StackFit.expand hero, claimed every tap before it reached an
            // earlier-declared sibling — this button included. That's
            // fixed at the source now: the SafeArea's SingleChildScrollView
            // carries hitTestBehavior: HitTestBehavior.translucent (see
            // its own comment), so z-order no longer decides whether this
            // button receives taps — it would work in any position in this
            // list. Left where it is because there's no reason to move a
            // working button, not because it still needs to be last.
            // Bottom-right, clear of the chevrons (vertically centred) and
            // the identity text (bottom-left).
            if (hasGallery)
              Positioned(
                right: CsSpacing.pageHorizontal,
                bottom: CsSpacing.lg,
                child: SafeArea(
                  top: false,
                  child: _ReportPhotoButton(
                    onTap: () => showReportSheet(
                      context,
                      contentType: ReportContentType.photo,
                      contentId: photos[_pageIndex].id,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// The 2–5 photo swipeable gallery. Deliberately small and hero-specific
/// rather than a generic reusable carousel primitive — nothing else in
/// this app needs a multi-image swipe gallery yet, and building one for
/// a single call site would be speculative infrastructure. No autoplay,
/// no thumbnail rail — a plain [PageView], matching a restrained,
/// editorial (not marketplace/Instagram-feed) gallery feel.
class _PhotoGallery extends StatelessWidget {
  final List<PrivateChefPhoto> photos;
  final PageController controller;
  final ValueChanged<int> onPageChanged;

  const _PhotoGallery({
    required this.photos,
    required this.controller,
    required this.onPageChanged,
  });

  @override
  Widget build(BuildContext context) {
    if (photos.length == 1) {
      return _HeroImage(
        url: photos.first.imageUrl,
        semanticLabel: photos.first.altText,
      );
    }
    return PageView.builder(
      controller: controller,
      onPageChanged: onPageChanged,
      itemCount: photos.length,
      itemBuilder: (context, index) => _HeroImage(
        url: photos[index].imageUrl,
        semanticLabel: photos[index].altText,
      ),
    );
  }
}

/// One hero background image, with a per-image fallback to the branded
/// gradient on load failure — so one broken photo among several never
/// takes down the whole gallery.
///
/// Physical-device review (Step 2C): this hero fills a wide, short,
/// full-bleed box (landscape-shaped) with photography that's usually
/// portrait-oriented (a person), which crops far more aggressively than
/// the discovery card's own near-square 4:5 crop does — center-cropping
/// (the previous default) put a chef's face right at the very top edge,
/// directly behind the iOS Dynamic Island/status bar on notch/island
/// devices. [_focalAlignment] biases the crop toward the TOP of the
/// source image instead — i.e. it keeps the headroom that's normally
/// *above* a person's head, pushing the face down away from that top
/// strip — without touching the source file or the discovery card's own,
/// separately-approved [Alignment(0, -0.3)] focal point (different box
/// shape, different crop math, deliberately not shared). Not a
/// device-model-specific pixel value — a general top-biased default for
/// any portrait hero photo in this landscape box.
class _HeroImage extends StatelessWidget {
  final String url;
  final String? semanticLabel;

  const _HeroImage({required this.url, this.semanticLabel});

  static const Alignment _focalAlignment = Alignment(0, -0.8);

  @override
  Widget build(BuildContext context) => Semantics(
    image: true,
    label: semanticLabel,
    child: Image.network(
      url,
      fit: BoxFit.cover,
      alignment: _focalAlignment,
      errorBuilder: (_, _, _) => const _NoPhotoBackground(),
    ),
  );
}

/// Same translucent-circle treatment as [FollowToggleButton]/the wishlist
/// toggle — a single tap opens the shared report sheet directly (one
/// action, not worth a menu of its own).
class _ReportPhotoButton extends StatelessWidget {
  final VoidCallback onTap;

  const _ReportPhotoButton({required this.onTap});

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: 'Report this photo',
    excludeSemantics: true,
    child: Material(
      color: Colors.black.withValues(alpha: 0.24),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: const Padding(
          padding: EdgeInsets.all(9),
          child: Icon(
            Icons.flag_outlined,
            color: AppColors.textOnDark,
            size: 19,
          ),
        ),
      ),
    ),
  );
}

class _NoPhotoBackground extends StatelessWidget {
  const _NoPhotoBackground();

  @override
  Widget build(BuildContext context) => const DecoratedBox(
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          AppColors.brandGreenLight,
          AppColors.deepGreen,
          AppColors.heroGradientEnd,
        ],
      ),
    ),
  );
}
