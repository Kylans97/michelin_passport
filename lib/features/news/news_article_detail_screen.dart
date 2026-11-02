import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/analytics/analytics_event.dart';
import '../../core/analytics/analytics_properties.dart';
import '../../core/analytics/analytics_service.dart';
import '../../core/analytics/supabase_analytics_service.dart';
import '../../core/constants/app_colors.dart';
import '../../core/theme/cs_spacing.dart';
import '../../core/theme/cs_typography.dart';
import '../../core/widgets/editorial_back_button.dart';
import '../../core/widgets/linked_venue_row.dart';
import '../../data/repositories/news_repository.dart';
import '../../models/hotel.dart';
import '../../models/news_article.dart';
import '../../models/private_chef.dart';
import '../../models/restaurant.dart';
import '../hotels/hotel_detail_screen.dart';
import '../private_chefs/private_chef_detail_screen.dart';
import '../restaurants/restaurant_detail_screen.dart';
import 'news_screen.dart' show formatNewsDate;
import '../../core/widgets/app_network_image.dart';

/// Takes an already-loaded [NewsArticle] — no second fetch-by-id round
/// trip, matching Restaurant/Hotel Detail's "caller already has the
/// model" convention rather than Event Detail's id-only one. News V1 is
/// one simple table with nothing else to resolve, so a second query
/// would only add latency for no benefit.
///
/// Fires [AnalyticsEvent.newsArticleOpened] exactly once, on genuinely
/// opening this screen (initState) — not on the outbound link tap below,
/// which is a separate, unmeasured action per the News V1 spec ("meet
/// openen, niet leestijd of scrolldiepte").
class NewsArticleDetailScreen extends StatefulWidget {
  final NewsArticle article;

  // Optional DI seams, matching this app's established convention —
  // default to the real SupabaseAnalyticsService/NewsRepository so a test
  // can supply fakes without needing a live Supabase session.
  final AnalyticsService? analytics;
  final Future<NewsArticleVenues> Function()? loadVenues;
  final Future<List<NewsArticlePhoto>> Function()? loadPhotos;

  const NewsArticleDetailScreen({
    super.key,
    required this.article,
    this.analytics,
    this.loadVenues,
    this.loadPhotos,
  });

  @override
  State<NewsArticleDetailScreen> createState() =>
      _NewsArticleDetailScreenState();
}

class _NewsArticleDetailScreenState extends State<NewsArticleDetailScreen> {
  late final Future<NewsArticleVenues> _venuesFuture;
  late final Future<List<NewsArticlePhoto>> _photosFuture;

  @override
  void initState() {
    super.initState();
    final analytics =
        widget.analytics ?? SupabaseAnalyticsService(Supabase.instance.client);
    analytics.track(
      AnalyticsEvent.newsArticleOpened,
      AnalyticsProperties(
        entityType: AnalyticsEntityType.newsArticle,
        entityId: widget.article.id,
      ),
    );

    final loadVenues =
        widget.loadVenues ??
        () => NewsRepository(
          Supabase.instance.client,
        ).loadLinkedVenues(widget.article.id);
    _venuesFuture = loadVenues();

    final loadPhotos =
        widget.loadPhotos ??
        () => NewsRepository(
          Supabase.instance.client,
        ).loadPhotos(widget.article.id);
    // A failed lookup shows the article without its inline photos, never
    // an error over the text itself.
    _photosFuture = loadPhotos().catchError(
      (Object _) => const <NewsArticlePhoto>[],
    );
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  // Same "already-fetched model, never re-fetch on tap" shape as
  // EventDetailScreen._openRestaurant/_openHotel — the full model came
  // out of _venuesFuture's own batched lookup. PrivateChefDetailScreen is
  // the one exception (id-only, matching its own established convention
  // of always re-resolving a chef as currently published — see that
  // screen's own doc comment).
  void _openRestaurant(Restaurant restaurant) => Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => RestaurantDetailScreen(
        restaurant: restaurant,
        openSource: AnalyticsOpenSource.news,
        openSourceId: widget.article.id,
      ),
    ),
  );

  void _openHotel(Hotel hotel) => Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => HotelDetailScreen(
        hotel: hotel,
        openSource: AnalyticsOpenSource.news,
        openSourceId: widget.article.id,
      ),
    ),
  );

  void _openChef(PrivateChef chef) => Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => PrivateChefDetailScreen(
        chefId: chef.id,
        openSource: AnalyticsOpenSource.news,
        openSourceId: widget.article.id,
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final article = widget.article;
    final hasImage = (article.imageUrl ?? '').isNotEmpty;
    final hasLink = (article.linkUrl ?? '').isNotEmpty;
    final isInterview = article.section == NewsSection.interview;
    final blocks = article.blocks;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          if (hasImage)
            SliverPersistentHeader(
              pinned: true,
              delegate: _PhotoBandHeader(
                article: article,
                topPadding: MediaQuery.paddingOf(context).top,
              ),
            )
          else
            const SliverAppBar(
              backgroundColor: AppColors.deepGreen,
              foregroundColor: AppColors.textOnDark,
              pinned: true,
              leadingWidth: 56,
              leading: Padding(
                padding: EdgeInsets.only(left: CsSpacing.sm),
                child: EditorialBackButton(),
              ),
            ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                CsSpacing.pageHorizontal,
                CsSpacing.lg,
                CsSpacing.pageHorizontal,
                CsSpacing.section,
              ),
              child: FutureBuilder<List<NewsArticlePhoto>>(
                future: _photosFuture,
                builder: (context, snap) {
                  final photos = groupNewsPhotos(
                    snap.data ?? const [],
                    blocks.length,
                  );
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isInterview
                            ? 'INTERVIEW · ${formatNewsDate(article.publishedAt).toUpperCase()}'
                            : formatNewsDate(article.publishedAt),
                        style: CsTypography.eyebrow.copyWith(
                          color: AppColors.taupe,
                        ),
                      ),
                      const SizedBox(height: CsSpacing.sm),
                      Text(
                        article.title,
                        style: CsTypography.placeTitle.copyWith(
                          fontSize: 26,
                          color: AppColors.forestGreen,
                        ),
                      ),
                      const SizedBox(height: CsSpacing.lg),
                      if (photos[0] != null) _NewsPhotos(photos: photos[0]!),
                      for (var i = 0; i < blocks.length; i++) ...[
                        _NewsBlockView(
                          block: blocks[i],
                          // An interview opens with its introduction, set
                          // larger than the conversation that follows.
                          isLead: isInterview && i == 0,
                        ),
                        if (photos[i + 1] != null)
                          _NewsPhotos(photos: photos[i + 1]!),
                      ],
                      FutureBuilder<NewsArticleVenues>(
                        future: _venuesFuture,
                        builder: (context, snap) {
                          final venues = snap.data;
                          // Silent while loading and on error — mentioned
                          // venues are enhancement content, same convention
                          // as HostedEventsSection: never block or clutter
                          // the article itself over a lookup that failed.
                          if (venues == null || venues.isEmpty) {
                            return const SizedBox.shrink();
                          }
                          return Padding(
                            padding: const EdgeInsets.only(top: CsSpacing.md),
                            child: _MentionedVenuesSection(
                              title: isInterview
                                  ? 'IN THIS INTERVIEW'
                                  : 'MENTIONED IN THIS ARTICLE',
                              venues: venues,
                              onTapRestaurant: _openRestaurant,
                              onTapHotel: _openHotel,
                              onTapChef: _openChef,
                            ),
                          );
                        },
                      ),
                      if (hasLink) ...[
                        const SizedBox(height: CsSpacing.md),
                        _NewsLinkRow(
                          url: article.linkUrl!,
                          onTap: () => _openUrl(article.linkUrl!),
                        ),
                      ],
                    ],
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The article's photo, pinned: full height at the top, and as the reader
/// scrolls it shrinks to a band under the status bar instead of scrolling
/// away, with the title fading in beside the back button. Painted by hand
/// rather than with [FlexibleSpaceBar], which fades its background out as
/// it collapses — the opposite of what this is for.
class _PhotoBandHeader extends SliverPersistentHeaderDelegate {
  _PhotoBandHeader({required this.article, required this.topPadding});

  final NewsArticle article;
  final double topPadding;

  static const double _expanded = 320;
  static const double _band = 64;

  @override
  double get maxExtent => topPadding + _expanded;

  @override
  double get minExtent => topPadding + _band;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlaps) {
    final range = maxExtent - minExtent;
    final t = range <= 0 ? 1.0 : (shrinkOffset / range).clamp(0.0, 1.0);
    // The title only once the photo is nearly a band, so the two never
    // overlap the article's own title below.
    final titleOpacity = ((t - 0.75) / 0.25).clamp(0.0, 1.0);
    // Light status bar over the photo, whatever the rest of the app sets.
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: _photoBand(titleOpacity, t),
    );
  }

  Widget _photoBand(double titleOpacity, double t) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const ColoredBox(color: AppColors.deepGreen),
        AppNetworkImage(
          article.imageUrl!,
          fit: BoxFit.cover,
          // Per-article crop focus (news_articles.focus_x/focus_y), so the
          // band keeps the subject rather than a centre strip of it.
          alignment: Alignment(article.alignmentX, article.alignmentY),
          errorBuilder: (_, _, _) => const SizedBox.shrink(),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                AppColors.heroGradientEnd.withValues(alpha: 0.55),
                AppColors.heroGradientEnd.withValues(alpha: 0.05 + 0.6 * t),
              ],
            ),
          ),
        ),
        Positioned(
          top: topPadding,
          left: 0,
          right: 0,
          height: _band,
          child: Row(
            children: [
              const Padding(
                padding: EdgeInsets.only(left: CsSpacing.sm),
                child: EditorialBackButton(),
              ),
              const SizedBox(width: CsSpacing.sm),
              Expanded(
                child: Opacity(
                  opacity: titleOpacity,
                  child: Text(
                    article.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: CsTypography.placeTitle.copyWith(
                      fontSize: 18,
                      color: AppColors.ivory,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: CsSpacing.pageHorizontal),
            ],
          ),
        ),
      ],
    );
  }

  @override
  bool shouldRebuild(_PhotoBandHeader old) =>
      old.article != article || old.topPadding != topPadding;
}

/// One paragraph of the body, read for its prefix (NewsArticle.blocks).
class _NewsBlockView extends StatelessWidget {
  const _NewsBlockView({required this.block, this.isLead = false});

  final NewsBlock block;
  final bool isLead;

  @override
  Widget build(BuildContext context) {
    switch (block.kind) {
      case NewsBlockKind.question:
        return Padding(
          padding: const EdgeInsets.only(
            top: CsSpacing.sm,
            bottom: CsSpacing.sm,
          ),
          child: Text(
            block.text,
            style: CsTypography.editorialTitle(
              size: 19,
              italic: true,
            ).copyWith(color: AppColors.forestGreen, height: 1.35),
          ),
        );
      case NewsBlockKind.quote:
        return Container(
          margin: const EdgeInsets.symmetric(vertical: CsSpacing.lg),
          padding: const EdgeInsets.only(left: CsSpacing.md),
          decoration: const BoxDecoration(
            border: Border(
              left: BorderSide(color: AppColors.forestGreen, width: 2),
            ),
          ),
          child: Text(
            block.text,
            style: CsTypography.editorialDisplay(
              size: 26,
            ).copyWith(color: AppColors.forestGreen, height: 1.25),
          ),
        );
      case NewsBlockKind.text:
        return Padding(
          padding: const EdgeInsets.only(bottom: CsSpacing.md),
          child: Text(
            block.text,
            style: isLead
                ? CsTypography.editorialLead(
                    size: 19,
                  ).copyWith(color: AppColors.forestGreen, height: 1.45)
                : CsTypography.body.copyWith(
                    color: AppColors.textPrimary,
                    height: 1.5,
                  ),
          ),
        );
    }
  }
}

/// Photos at one place in the text: one full width, two or more as a
/// gallery to swipe through, its caption following the photo on show.
class _NewsPhotos extends StatefulWidget {
  const _NewsPhotos({required this.photos});

  final List<NewsArticlePhoto> photos;

  @override
  State<_NewsPhotos> createState() => _NewsPhotosState();
}

class _NewsPhotosState extends State<_NewsPhotos> {
  int _page = 0;

  Widget _image(NewsArticlePhoto photo) => ClipRRect(
    borderRadius: BorderRadius.circular(12),
    child: AppNetworkImage(
      photo.imageUrl,
      fit: BoxFit.cover,
      alignment: photo.alignment,
      errorBuilder: (_, _, _) => const ColoredBox(color: AppColors.cardBorder),
    ),
  );

  // Small photos: a row of squares, four across, each opening full size
  // on a tap; the group's captions, each said once, under the row.
  Widget _smallRow(List<NewsArticlePhoto> photos) {
    final captions = <String>{
      for (final p in photos)
        if ((p.caption ?? '').trim().isNotEmpty) p.caption!.trim(),
    };
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: CsSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              const gap = CsSpacing.sm;
              final side = (constraints.maxWidth - gap * 3) / 4;
              return Wrap(
                spacing: gap,
                runSpacing: gap,
                children: [
                  for (final photo in photos)
                    SizedBox(
                      width: side,
                      height: side,
                      child: GestureDetector(
                        onTap: () => _openFull(photo),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: AppNetworkImage(
                            photo.imageUrl,
                            fit: BoxFit.cover,
                            alignment: photo.alignment,
                            errorBuilder: (_, _, _) =>
                                const ColoredBox(color: AppColors.cardBorder),
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
          for (final caption in captions) ...[
            const SizedBox(height: CsSpacing.sm),
            Text(
              caption,
              style: CsTypography.metadata.copyWith(color: AppColors.taupe),
            ),
          ],
        ],
      ),
    );
  }

  void _openFull(NewsArticlePhoto photo) => showDialog<void>(
    context: context,
    barrierColor: AppColors.darkGreen.withValues(alpha: 0.92),
    builder: (context) => GestureDetector(
      onTap: () => Navigator.pop(context),
      child: InteractiveViewer(
        child: Center(
          child: AppNetworkImage(photo.imageUrl, fit: BoxFit.contain),
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final photos = widget.photos;
    if (photos.every((p) => p.isSmall)) return _smallRow(photos);
    final shown = photos[_page.clamp(0, photos.length - 1)];
    final caption = shown.caption?.trim();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: CsSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 4 / 3,
            child: photos.length == 1
                ? _image(photos.single)
                : PageView.builder(
                    itemCount: photos.length,
                    onPageChanged: (i) => setState(() => _page = i),
                    itemBuilder: (context, i) => Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: _image(photos[i]),
                    ),
                  ),
          ),
          if (photos.length > 1) ...[
            const SizedBox(height: CsSpacing.sm),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < photos.length; i++)
                  Container(
                    width: 6,
                    height: 6,
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: i == _page
                          ? AppColors.forestGreen
                          : AppColors.subtleBorderLight,
                    ),
                  ),
              ],
            ),
          ],
          if (caption != null && caption.isNotEmpty) ...[
            const SizedBox(height: CsSpacing.sm),
            Text(
              caption,
              style: CsTypography.metadata.copyWith(color: AppColors.taupe),
            ),
          ],
        ],
      ),
    );
  }
}

/// News V1, part 2 — the restaurants/hotels/chefs an article links to, one
/// combined list (not split into per-type headings the way Event Detail's
/// "AT THIS EVENT"/"HOTELS" are) since a curator links venues here
/// deliberately, never in bulk. Deliberately no recognition filter either
/// (unlike [AtThisEventSection]'s Michelin/World's-50-Best/Hall-of-Fame
/// gate on restaurants) — a linked pop-up or otherwise-unrecognized venue
/// is exactly as valid a mention as a starred one.
class _MentionedVenuesSection extends StatelessWidget {
  final String title;
  final NewsArticleVenues venues;
  final ValueChanged<Restaurant> onTapRestaurant;
  final ValueChanged<Hotel> onTapHotel;
  final ValueChanged<PrivateChef> onTapChef;

  const _MentionedVenuesSection({
    required this.title,
    required this.venues,
    required this.onTapRestaurant,
    required this.onTapHotel,
    required this.onTapChef,
  });

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[
      for (final restaurant in venues.restaurants)
        LinkedVenueRow(
          name: restaurant.name,
          onTap: () => onTapRestaurant(restaurant),
        ),
      for (final hotel in venues.hotels)
        LinkedVenueRow(name: hotel.name, onTap: () => onTapHotel(hotel)),
      for (final chef in venues.chefs)
        LinkedVenueRow(name: chef.displayName, onTap: () => onTapChef(chef)),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: CsTypography.eyebrow.copyWith(color: AppColors.taupe),
        ),
        const SizedBox(height: CsSpacing.md),
        for (var i = 0; i < rows.length; i++) ...[
          if (i > 0) const SizedBox(height: CsSpacing.sm),
          rows[i],
        ],
      ],
    );
  }
}

/// The one optional outbound link — same 52px tappable-row shape as
/// [EventActionsRow]'s own Tickets/Official-website rows, opened the
/// same way (launchUrl, external browser, never an in-app webview).
class _NewsLinkRow extends StatelessWidget {
  final String url;
  final VoidCallback onTap;

  const _NewsLinkRow({required this.url, required this.onTap});

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.transparent,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: 52,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.cardBorder),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.open_in_new_rounded,
              size: 18,
              color: AppColors.forestGreen,
            ),
            const SizedBox(width: CsSpacing.sm),
            Expanded(
              child: Text(
                'Read more',
                style: CsTypography.bodyMedium.copyWith(
                  color: AppColors.forestGreen,
                ),
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: AppColors.taupe,
              size: 20,
            ),
          ],
        ),
      ),
    ),
  );
}
