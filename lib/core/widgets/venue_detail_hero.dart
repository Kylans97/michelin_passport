import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../theme/cs_spacing.dart';
import '../theme/cs_typography.dart';
import 'editorial_back_button.dart';
import 'follow_toggle_button.dart';
import 'hero_photo_chevron.dart';

/// The current-generation hero for Restaurant/Hotel Detail (UI Consistency
/// Step 1) — a fresh, Cs-token-based primitive, deliberately NOT a
/// modification of [DetailHero] (`detail_hero.dart`), which stays exactly
/// as it is: that widget is shared with Event Detail, both Award History
/// screens, and other screens explicitly out of scope for this redesign,
/// and editing it would risk changing their appearance too. This is a
/// parallel component for the two screens that are actually being
/// redesigned, following the exact same "one small primitive genuinely
/// reused twice" reasoning as everywhere else in this pass.
///
/// [imageUrls] is the venue's published photos, in display_order — resolved
/// by the caller (see RestaurantHero/HotelHero, whose own [photoUrls]
/// param falls back to the venue's single restaurants_full/hotels_full.
/// cover_photo_url while the Detail screen's independent full-set load is
/// still in flight) and passed down as plain URLs, not pre-built widgets,
/// so this class owns Image.network/BoxFit.cover/the error fallback in
/// exactly one place. Zero or one photo renders exactly as a single-image
/// hero always has — no PageView, no indicator, no gesture change — that
/// stays the overwhelmingly common case. Two or more enables a horizontal
/// swipe between them (a plain [PageView.builder], loading at most the
/// current photo plus the next via [precacheImage] — never all of them at
/// once) with a small chevron at each edge — no separate dot/count
/// indicator, since the chevrons alone already carry position (no left
/// chevron means the first photo, no right means the last).
/// The no-photo (and failed-load) state is a considered deep-green tonal
/// gradient, not a placeholder pretending to be a photo — the
/// scrim/legibility treatment already accounts for a photo being there
/// either way.
class VenueDetailHero extends StatefulWidget {
  final String title;

  /// The single primary recognition signal (Michelin stars for a
  /// restaurant, Keys for a hotel) — rendered large and alone, never
  /// competing with secondary badges. Omit entirely (pass null) rather
  /// than an empty row when there is no current recognition to show.
  final Widget? primaryRecognition;

  /// Secondary context chips — "World's 50 Best · #12", "Inside Aman
  /// Venice" — visually quieter than [primaryRecognition] by design.
  final List<Widget> secondaryBadges;

  final double expandedHeight;
  final List<String> imageUrls;

  final bool isWishlisted;
  final bool wishlistSaving;
  final VoidCallback onTapWishlist;

  /// Events V2 Step 6. [onTapFollow] is deliberately nullable and defaults
  /// to null — when omitted, no Follow control renders at all, so every
  /// existing call site (and every existing test) that predates Follow
  /// keeps its exact prior rendering with zero changes required. Only
  /// Restaurant/Hotel Detail (the two screens that wire a real callback)
  /// show the second hero icon.
  final bool isFollowing;
  final bool followBusy;
  final VoidCallback? onTapFollow;

  /// True for a `permanently_closed` venue — DATA_UPDATE_PROCESS.md §7's
  /// "renders greyed". No catalogue table carries a restaurant/hotel
  /// photo today (see this class's own doc comment), so there is nothing
  /// to desaturate with a ColorFilter yet — a real photo pipeline should
  /// apply one to [imageUrls] specifically when it lands. Until then this
  /// swaps the no-photo gradient for a neutral grey one and mutes the
  /// title, which is the entire visible hero surface today.
  final bool isClosed;

  const VenueDetailHero({
    super.key,
    required this.title,
    this.primaryRecognition,
    this.secondaryBadges = const [],
    // Generous enough for the realistic worst case — a long, wrapped
    // 2-line title alongside 3-star/3-Key primary recognition and two
    // wrapped secondary badges — to fit without clipping even at 1.6x
    // text scale (§18). The SingleChildScrollView below is a defensive
    // second layer, not the primary fix: it guarantees no RenderFlex
    // overflow ever throws, but sizing this generously means it's never
    // actually needed for realistic content.
    this.expandedHeight = 300,
    this.imageUrls = const [],
    required this.isWishlisted,
    required this.wishlistSaving,
    required this.onTapWishlist,
    this.isFollowing = false,
    this.followBusy = false,
    this.onTapFollow,
    this.isClosed = false,
  });

  @override
  State<VenueDetailHero> createState() => _VenueDetailHeroState();
}

class _VenueDetailHeroState extends State<VenueDetailHero> {
  // Only meaningful once widget.imageUrls.length > 1 — the chevrons read
  // this to decide which edge (if either) to show; a single-or-zero-photo
  // hero never touches it, so that case stays
  // pixel-for-pixel identical to before this feature existed.
  int _currentPage = 0;

  // Owned here (not by a separate gallery widget) so the chevrons — a
  // sibling of the PageView in the same Stack, not a descendant of it —
  // can drive the exact same controller a swipe does, through the exact
  // same onPageChanged path (no duplicated page-tracking logic).
  final _pageController = PageController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _precacheNext(0));
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _precacheNext(int currentIndex) {
    final nextIndex = currentIndex + 1;
    if (!mounted || nextIndex >= widget.imageUrls.length) return;
    // onError is required here: a failed precache (offline, a bad URL) must
    // never surface as an uncaught exception — the swipe/chevron still
    // works, that photo's own Image.network just falls back to the
    // gradient via errorBuilder when its page is actually built.
    precacheImage(
      NetworkImage(widget.imageUrls[nextIndex]),
      context,
      onError: (_, _) {},
    );
  }

  void _onGalleryPageChanged(int index) {
    setState(() => _currentPage = index);
    _precacheNext(index);
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
    final imageUrls = widget.imageUrls;
    final hasPhoto = imageUrls.isNotEmpty;
    final isGallery = imageUrls.length > 1;
    final title = widget.title;
    final isClosed = widget.isClosed;

    return SliverAppBar(
      expandedHeight: widget.expandedHeight,
      pinned: true,
      backgroundColor: AppColors.deepGreen,
      foregroundColor: AppColors.textOnDark,
      leadingWidth: 56,
      leading: Padding(
        padding: const EdgeInsets.only(left: CsSpacing.sm),
        child: EditorialBackButton(),
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: CsSpacing.sm),
          child: _HeroToggleButton(
            icon: widget.isWishlisted
                ? Icons.favorite_rounded
                : Icons.favorite_border_rounded,
            active: widget.isWishlisted,
            onTap: widget.wishlistSaving ? null : widget.onTapWishlist,
          ),
        ),
        if (widget.onTapFollow != null)
          Padding(
            padding: const EdgeInsets.only(right: CsSpacing.sm),
            child: FollowToggleButton(
              isFollowing: widget.isFollowing,
              busy: widget.followBusy,
              onTap: widget.onTapFollow,
              entityName: title,
            ),
          ),
      ],
      title: Text(
        title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: CsTypography.bodyMedium.copyWith(color: AppColors.textOnDark),
      ),
      flexibleSpace: FlexibleSpaceBar(
        collapseMode: CollapseMode.parallax,
        background: Stack(
          fit: StackFit.expand,
          children: [
            if (isGallery)
              // Two or more photos: a swipeable set, built inline (not a
              // separate widget) so the chevrons below can drive the exact
              // same PageController a swipe does.
              PageView.builder(
                controller: _pageController,
                itemCount: imageUrls.length,
                onPageChanged: _onGalleryPageChanged,
                itemBuilder: (context, index) => Image.network(
                  imageUrls[index],
                  fit: BoxFit.cover,
                  loadingBuilder: (_, child, progress) =>
                      progress == null ? child : _FallbackGradient(isClosed: isClosed),
                  errorBuilder: (_, _, _) => _FallbackGradient(isClosed: isClosed),
                ),
              )
            else if (hasPhoto)
              Image.network(
                imageUrls.first,
                fit: BoxFit.cover,
                // While it loads, the same gradient the no-photo state
                // uses — never a spinner or a blank frame.
                loadingBuilder: (_, child, progress) =>
                    progress == null ? child : _FallbackGradient(isClosed: isClosed),
                // A failed load falls back to the exact same gradient the
                // no-photo state uses — never a broken-image icon, and
                // never a different treatment than "no photo yet".
                errorBuilder: (_, _, _) => _FallbackGradient(isClosed: isClosed),
              )
            else
              _FallbackGradient(isClosed: isClosed),
            // Bottom-weighted vignette so the title/badges stay legible
            // regardless of whether there's a photo underneath.
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    AppColors.deepGreen.withValues(alpha: hasPhoto ? 0.55 : 0),
                    AppColors.deepGreen.withValues(alpha: hasPhoto ? 0.9 : 1),
                  ],
                  stops: const [0.0, 0.55, 1.0],
                ),
              ),
            ),
            if (isGallery && _currentPage > 0)
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
            if (isGallery && _currentPage < imageUrls.length - 1)
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
                // A defensive second layer against overflow, not the
                // primary fix (see [expandedHeight]'s doc comment): giving
                // the column unconstrained height means even a pathological
                // combination of a very long title and several long badge
                // labels clips gracefully at the bottom rather than
                // throwing a RenderFlex overflow error.
                child: SingleChildScrollView(
                  physics: const NeverScrollableScrollPhysics(),
                  // Mechanism: this box is stretched to the FULL hero area
                  // by the parent Stack's StackFit.expand (not just the
                  // bottom strip where its text visually sits), and
                  // Scrollable's own hit-test behaviour defaults to
                  // HitTestBehavior.opaque. Stack hit-testing
                  // (RenderBox.defaultHitTestChildren) walks children
                  // topmost-first and STOPS at the first one that reports a
                  // hit — so this box, being the last/topmost Stack child,
                  // was silently absorbing every pointer down across the
                  // whole photo (including over the gallery beneath it)
                  // before the PageView ever saw it, even though
                  // NeverScrollableScrollPhysics means it has zero
                  // registered drag recognizers of its own to actually do
                  // anything with that pointer. translucent still lets
                  // this box report itself as hit (so it stays part of the
                  // tree normally) without stopping the Stack from also
                  // testing the sibling behind it.
                  hitTestBehavior: HitTestBehavior.translucent,
                  reverse: true,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (widget.primaryRecognition != null) ...[
                        Opacity(
                          opacity: isClosed ? 0.5 : 1,
                          child: widget.primaryRecognition,
                        ),
                        const SizedBox(height: CsSpacing.sm),
                      ],
                      Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: CsTypography.displayHero.copyWith(
                          color: AppColors.textOnDark.withValues(
                            alpha: isClosed ? 0.7 : 1,
                          ),
                          fontSize: 30,
                          height: 1.1,
                        ),
                      ),
                      if (widget.secondaryBadges.isNotEmpty) ...[
                        const SizedBox(height: CsSpacing.sm),
                        Wrap(
                          spacing: CsSpacing.sm,
                          runSpacing: CsSpacing.sm,
                          children: widget.secondaryBadges,
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

/// The two gradient washes VenueDetailHero falls back to — factored out
/// once so a failed Image.network load (see [VenueDetailHero.build]'s own
/// errorBuilder) renders identically to the no-photo state, rather than
/// duplicating either gradient's colors a second time.
class _FallbackGradient extends StatelessWidget {
  final bool isClosed;
  const _FallbackGradient({required this.isClosed});

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      gradient: isClosed
          ? const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF5A564D),
                Color(0xFF3E3B35),
                Color(0xFF26241F),
              ],
            )
          : const LinearGradient(
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

/// The overlay wishlist toggle — same "translucent disc over the hero"
/// visual idea the previous generation used, rebuilt as independent code
/// rather than reusing `HeroIconButton` from `detail_hero.dart` (kept
/// fully untouched — see this file's own class doc).
class _HeroToggleButton extends StatelessWidget {
  final IconData icon;
  final bool active;
  final VoidCallback? onTap;

  const _HeroToggleButton({
    required this.icon,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.black.withValues(alpha: 0.24),
    shape: const CircleBorder(),
    child: InkWell(
      customBorder: const CircleBorder(),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(9),
        child: Icon(
          icon,
          // Step 1B color rule: gold is reserved for Michelin stars/Keys
          // only. Wishlist state reads through the filled-vs-outline icon
          // shape alone (favorite_rounded vs favorite_border_rounded), not
          // color — both states stay ivory-on-dark.
          color: AppColors.textOnDark,
          size: 19,
        ),
      ),
    ),
  );
}

/// A small translucent secondary badge for hero-overlaid context —
/// "World's 50 Best · #12", "Inside Aman Venice". The Cs-token twin of
/// `HeroBadge` (`detail_hero.dart`), rebuilt independently for the same
/// "don't touch the shared component" reason as the rest of this file.
class VenueHeroBadge extends StatelessWidget {
  final IconData icon;
  final String label;
  const VenueHeroBadge({super.key, required this.icon, required this.label});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(CsRadius.pill),
      border: Border.all(
        color: AppColors.textOnDark.withValues(alpha: 0.25),
        width: 0.5,
      ),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: AppColors.textOnDark),
        const SizedBox(width: 5),
        Text(
          label,
          style: CsTypography.smallLabel.copyWith(color: AppColors.textOnDark),
        ),
      ],
    ),
  );
}
