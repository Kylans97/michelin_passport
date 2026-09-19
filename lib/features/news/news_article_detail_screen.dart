import 'package:flutter/material.dart';
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

  const NewsArticleDetailScreen({
    super.key,
    required this.article,
    this.analytics,
    this.loadVenues,
  });

  @override
  State<NewsArticleDetailScreen> createState() =>
      _NewsArticleDetailScreenState();
}

class _NewsArticleDetailScreenState extends State<NewsArticleDetailScreen> {
  late final Future<NewsArticleVenues> _venuesFuture;

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
      builder: (_) => RestaurantDetailScreen(restaurant: restaurant),
    ),
  );

  void _openHotel(Hotel hotel) => Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => HotelDetailScreen(hotel: hotel)),
  );

  void _openChef(PrivateChef chef) => Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => PrivateChefDetailScreen(chefId: chef.id),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final article = widget.article;
    final hasImage = (article.imageUrl ?? '').isNotEmpty;
    final hasLink = (article.linkUrl ?? '').isNotEmpty;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            backgroundColor: AppColors.deepGreen,
            foregroundColor: AppColors.textOnDark,
            pinned: true,
            leadingWidth: 56,
            leading: const Padding(
              padding: EdgeInsets.only(left: CsSpacing.sm),
              child: EditorialBackButton(),
            ),
            expandedHeight: hasImage ? 240 : kToolbarHeight,
            flexibleSpace: hasImage
                ? FlexibleSpaceBar(
                    background: Image.network(
                      article.imageUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) =>
                          const ColoredBox(color: AppColors.deepGreen),
                    ),
                  )
                : null,
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                CsSpacing.pageHorizontal,
                CsSpacing.lg,
                CsSpacing.pageHorizontal,
                CsSpacing.section,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    formatNewsDate(article.publishedAt),
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
                  for (final paragraph in article.paragraphs) ...[
                    Text(
                      paragraph,
                      style: CsTypography.body.copyWith(
                        color: AppColors.textPrimary,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: CsSpacing.md),
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
              ),
            ),
          ),
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
  final NewsArticleVenues venues;
  final ValueChanged<Restaurant> onTapRestaurant;
  final ValueChanged<Hotel> onTapHotel;
  final ValueChanged<PrivateChef> onTapChef;

  const _MentionedVenuesSection({
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
        LinkedVenueRow(
          name: chef.displayName,
          onTap: () => onTapChef(chef),
        ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'MENTIONED IN THIS ARTICLE',
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
