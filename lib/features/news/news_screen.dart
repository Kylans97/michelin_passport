import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants/app_colors.dart';
import '../../core/theme/cs_spacing.dart';
import '../../core/theme/cs_typography.dart';
import '../../core/widgets/floating_nav_bar.dart';
import '../../data/repositories/news_repository.dart';
import '../../models/news_article.dart';
import 'news_article_detail_screen.dart';
import '../../core/widgets/app_network_image.dart';

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

/// News, in three parts (20261101270000): the "Why Mantelier" article on
/// top, then Interviews as a horizontal row, then Stories as a list, each
/// newest first and each left out when empty. Before the sections, News
/// V1 was a plain list, newest first (`published_at desc`, not
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
              final about = articles
                  .where((a) => a.section == NewsSection.about)
                  .firstOrNull;
              final interviews = articles
                  .where((a) => a.section == NewsSection.interview)
                  .toList();
              final stories = articles
                  .where((a) => a.section == NewsSection.story)
                  .toList();
              void open(NewsArticle article) => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => NewsArticleDetailScreen(article: article),
                ),
              );
              return ListView(
                padding: EdgeInsets.only(bottom: floatingNavClearance(context)),
                children: [
                  if (about != null)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        CsSpacing.pageHorizontal,
                        0,
                        CsSpacing.pageHorizontal,
                        CsSpacing.section,
                      ),
                      child: _WhyMantelierCard(
                        article: about,
                        onTap: () => open(about),
                      ),
                    ),
                  if (interviews.isNotEmpty) ...[
                    const _NewsSectionLabel('Interviews'),
                    SizedBox(
                      height: _InterviewCard.height,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(
                          horizontal: CsSpacing.pageHorizontal,
                        ),
                        itemCount: interviews.length,
                        separatorBuilder: (_, _) =>
                            const SizedBox(width: CsSpacing.md),
                        itemBuilder: (context, i) => _InterviewCard(
                          article: interviews[i],
                          onTap: () => open(interviews[i]),
                        ),
                      ),
                    ),
                    const SizedBox(height: CsSpacing.section),
                  ],
                  if (stories.isNotEmpty) ...[
                    const _NewsSectionLabel('Stories'),
                    for (final story in stories)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(
                          CsSpacing.pageHorizontal,
                          0,
                          CsSpacing.pageHorizontal,
                          CsSpacing.md,
                        ),
                        child: _NewsArticleCard(
                          article: story,
                          onTap: () => open(story),
                        ),
                      ),
                  ],
                ],
              );
            },
          ),
        ),
      ],
    ),
  );
}

/// The tab's opening: the one [NewsSection.about] article, quietly — a
/// label, its title and the start of its first paragraph, no photo, so
/// it introduces the tab rather than competing with what's new.
class _WhyMantelierCard extends StatelessWidget {
  final NewsArticle article;
  final VoidCallback onTap;

  const _WhyMantelierCard({required this.article, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final intro = article.paragraphs.firstOrNull;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(CsSpacing.lg),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.subtleBorderDark, width: 0.5),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'WHY MANTELIER',
                style: CsTypography.eyebrow.copyWith(
                  color: AppColors.secondaryOnDark,
                ),
              ),
              const SizedBox(height: CsSpacing.sm),
              Text(
                article.shortTitle,
                style: CsTypography.placeTitle.copyWith(
                  fontSize: 22,
                  color: AppColors.ivory,
                ),
              ),
              if (intro != null) ...[
                const SizedBox(height: CsSpacing.sm),
                Text(
                  intro,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: CsTypography.body.copyWith(
                    color: AppColors.secondaryOnDark,
                    height: 1.5,
                  ),
                ),
              ],
              const SizedBox(height: CsSpacing.md),
              Text(
                'Read',
                style: CsTypography.bodyMedium.copyWith(
                  color: AppColors.ivory,
                  decoration: TextDecoration.underline,
                  decorationColor: AppColors.secondaryOnDark,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NewsSectionLabel extends StatelessWidget {
  final String text;

  const _NewsSectionLabel(this.text);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(
      CsSpacing.pageHorizontal,
      0,
      CsSpacing.pageHorizontal,
      CsSpacing.md,
    ),
    child: Text(
      text.toUpperCase(),
      style: CsTypography.eyebrow.copyWith(color: AppColors.secondaryOnDark),
    ),
  );
}

/// An interview in the horizontal row: a portrait photo with the title
/// over its foot. Without a photo, the same card in deep green, title only.
class _InterviewCard extends StatelessWidget {
  final NewsArticle article;
  final VoidCallback onTap;

  static const double width = 172;
  static const double height = 240;

  const _InterviewCard({required this.article, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final hasImage = (article.imageUrl ?? '').isNotEmpty;
    return SizedBox(
      width: width,
      child: Material(
        color: AppColors.forestGreen,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (hasImage)
                AppNetworkImage(
                  article.imageUrl!,
                  fit: BoxFit.cover,
                  alignment: Alignment(article.alignmentX, article.alignmentY),
                  errorBuilder: (_, _, _) => const SizedBox.shrink(),
                ),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: [0.45, 1],
                    colors: [Colors.transparent, AppColors.heroGradientEnd],
                  ),
                ),
              ),
              Positioned(
                left: 12,
                right: 12,
                bottom: 12,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      article.shortTitle,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: CsTypography.placeTitle.copyWith(
                        fontSize: 17,
                        color: AppColors.ivory,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      formatNewsDate(article.publishedAt),
                      style: CsTypography.metadata.copyWith(
                        color: AppColors.secondaryOnDark,
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
                  child: AppNetworkImage(
                    article.imageUrl!,
                    fit: BoxFit.cover,
                    // Same per-article crop focus as the detail screen's
                    // own hero — the same source image, same reason a
                    // plain center crop can cut through a face.
                    alignment: Alignment(
                      article.alignmentX,
                      article.alignmentY,
                    ),
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
                      article.shortTitle,
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
