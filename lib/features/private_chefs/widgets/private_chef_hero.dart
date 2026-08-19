import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/cs_spacing.dart';
import '../../../core/theme/cs_typography.dart';
import '../../../core/widgets/editorial_back_button.dart';
import '../../../models/private_chef_photo.dart';

/// Chef Detail's hero — a parallel, trimmed sibling of [VenueDetailHero],
/// not a reuse of it: that widget hard-requires wishlist state
/// ([isWishlisted]/[wishlistSaving]/[onTapWishlist]), which has no
/// equivalent concept here (Private Chefs is not on Wishlist — see
/// PRIVATE_CHEFS.md §33). Building a small parallel component for a
/// genuinely different screen is this codebase's own established pattern
/// — [VenueDetailHero] itself exists for exactly this reason rather than
/// modifying the older shared `DetailHero`.
///
/// Deliberately shows NO score, rating, review count, "Chasing Stars
/// Selected" badge, Michelin stars, or price badge — the chef's page
/// existing at all is the selection signal (PRIVATE_CHEFS.md §14). The one
/// permitted editorial context label is the small "PRIVATE CHEF" eyebrow,
/// never worded as a badge/credential.
///
/// Step 2B — PHOTO GALLERY: background image resolution, in order:
///   1. [photos] (up to 5, [PrivateChefPhoto.displayOrder] ascending) —
///      1 photo renders as a static image; 2–5 render as a swipeable
///      [PageView] with a small dot indicator (no autoplay, no
///      thumbnail rail — see the class's own gallery widgets below).
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

  const PrivateChefHero({
    super.key,
    required this.displayName,
    this.businessName,
    this.location,
    this.photos = const [],
    this.profileImageUrl,
    this.expandedHeight = 320,
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

  @override
  Widget build(BuildContext context) {
    final photos = widget.photos;
    final hasGallery = photos.isNotEmpty;
    final hasFallbackPhoto =
        !hasGallery && (widget.profileImageUrl ?? '').isNotEmpty;
    final hasAnyPhoto = hasGallery || hasFallbackPhoto;

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
                  reverse: true,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (photos.length > 1) ...[
                        _PhotoPageIndicator(
                          count: photos.length,
                          index: _pageIndex,
                        ),
                        const SizedBox(height: CsSpacing.sm),
                      ],
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

/// A restrained dot indicator — ivory for the active page,
/// [AppColors.secondaryOnDark] (at reduced opacity) for the rest. No
/// gold, no numbers, no large pill controls. Purely decorative — excluded
/// from the accessibility tree so it doesn't add noisy, uninformative
/// stops; swipe/page semantics are already carried by the [PageView]
/// itself.
class _PhotoPageIndicator extends StatelessWidget {
  final int count;
  final int index;

  const _PhotoPageIndicator({required this.count, required this.index});

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < count; i++) ...[
          if (i > 0) const SizedBox(width: 6),
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: i == index
                  ? AppColors.ivory
                  : AppColors.secondaryOnDark.withValues(alpha: 0.5),
            ),
          ),
        ],
      ],
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
          Color(0xFF0E211C),
        ],
      ),
    ),
  );
}
