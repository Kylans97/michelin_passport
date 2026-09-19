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
import 'news_screen.dart' show formatNewsDate;
import '../../models/news_article.dart';

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

  // Optional DI seam, matching this app's established convention —
  // defaults to the real SupabaseAnalyticsService so a test can supply a
  // fake without needing a live Supabase session.
  final AnalyticsService? analytics;

  const NewsArticleDetailScreen({
    super.key,
    required this.article,
    this.analytics,
  });

  @override
  State<NewsArticleDetailScreen> createState() =>
      _NewsArticleDetailScreenState();
}

class _NewsArticleDetailScreenState extends State<NewsArticleDetailScreen> {
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
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

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
