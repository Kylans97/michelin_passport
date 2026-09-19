import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants/app_colors.dart';
import '../../core/theme/cs_spacing.dart';
import '../../core/theme/cs_typography.dart';
import '../../data/repositories/news_repository.dart';
import '../../models/news_article.dart';
import 'news_article_detail_screen.dart';

const _monthNames = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

String formatNewsDate(DateTime date) =>
    '${date.day} ${_monthNames[date.month - 1]} ${date.year}';

/// News V1 — a plain list, newest first (`published_at desc`, not
/// `created_at`, so an article can be scheduled ahead of its actual
/// authoring date). No categories, tags, comments, or read state —
/// deliberately out of scope for V1. A bottom-tab body (no own
/// [Scaffold], matching [ExploreScreen]/[PassportScreen]'s established
/// convention — the shared tab shell in `app.dart` already provides
/// one).
///
/// [loadArticles] is an optional, zero-argument DI seam — same
/// convention as [PrivacySettingsScreen]'s own
/// [loadDiscoverable]/[setDiscoverable] — so this screen's real
/// load/render behavior can be tested without a live Supabase session.
class NewsScreen extends StatefulWidget {
  final Future<List<NewsArticle>> Function()? loadArticles;

  const NewsScreen({super.key, this.loadArticles});

  @override
  State<NewsScreen> createState() => _NewsScreenState();
}

class _NewsScreenState extends State<NewsScreen> {
  late Future<List<NewsArticle>> _future;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    final load =
        widget.loadArticles ??
        () => NewsRepository(Supabase.instance.client).getPublishedArticles();
    setState(() {
      _future = load();
    });
  }

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: AppColors.deepGreen,
    child: Column(
      children: [
        SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              CsSpacing.pageHorizontal,
              CsSpacing.lg,
              CsSpacing.pageHorizontal,
              CsSpacing.lg,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'News',
                  style: CsTypography.screenTitle.copyWith(
                    color: AppColors.ivory,
                  ),
                ),
                const SizedBox(height: CsSpacing.xs),
                Text(
                  'Stories, interviews and the world of Mantelier.',
                  style: CsTypography.body.copyWith(
                    color: AppColors.secondaryOnDark,
                  ),
                ),
              ],
            ),
          ),
        ),
        Expanded(
          child: FutureBuilder<List<NewsArticle>>(
            future: _future,
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(
                    color: AppColors.secondaryOnDark,
                    strokeWidth: 1.5,
                  ),
                );
              }
              if (snap.hasError) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Could not load News',
                        style: CsTypography.body.copyWith(
                          color: AppColors.secondaryOnDark,
                        ),
                      ),
                      const SizedBox(height: CsSpacing.md),
                      TextButton(
                        onPressed: _load,
                        child: Text(
                          'Retry',
                          style: CsTypography.bodyMedium.copyWith(
                            color: AppColors.ivory,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }
              final articles = snap.data ?? const [];
              if (articles.isEmpty) {
                return Center(
                  child: Text(
                    'No stories yet.',
                    style: CsTypography.body.copyWith(
                      color: AppColors.secondaryOnDark,
                    ),
                  ),
                );
              }
              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(
                  CsSpacing.pageHorizontal,
                  0,
                  CsSpacing.pageHorizontal,
                  CsSpacing.section,
                ),
                itemCount: articles.length,
                separatorBuilder: (_, _) =>
                    const SizedBox(height: CsSpacing.md),
                itemBuilder: (context, i) => _NewsArticleCard(
                  article: articles[i],
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          NewsArticleDetailScreen(article: articles[i]),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    ),
  );
}

/// One article row. [NewsArticle.imageUrl] is genuinely optional —
/// deliberately NOT falling back to a branded placeholder box the way
/// [EventCard]'s own gallery does: a missing image here just means no
/// image slot at all, title+date alone, never a half-empty card.
class _NewsArticleCard extends StatelessWidget {
  final NewsArticle article;
  final VoidCallback onTap;

  const _NewsArticleCard({required this.article, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final hasImage = (article.imageUrl ?? '').isNotEmpty;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppColors.cardBorder.withValues(alpha: 0.55),
              width: 0.5,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (hasImage)
                AspectRatio(
                  aspectRatio: 16 / 9,
                  child: Image.network(
                    article.imageUrl!,
                    fit: BoxFit.cover,
                    // A failed load still shouldn't produce a half-card —
                    // collapse to zero height rather than a broken-image
                    // icon or a branded placeholder standing in for a
                    // photo that was supposed to be real.
                    errorBuilder: (_, _, _) => const SizedBox.shrink(),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      article.title,
                      style: CsTypography.placeTitle.copyWith(
                        fontSize: 17,
                        color: AppColors.forestGreen,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      formatNewsDate(article.publishedAt),
                      style: CsTypography.metadata.copyWith(
                        color: AppColors.taupe,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
