import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/cs_spacing.dart';
import '../../../core/theme/cs_typography.dart';
import '../../../models/news_article.dart';
import '../news_screen.dart' show formatNewsDate;

/// "IN THE NEWS" on a private chef's page: the published articles that
/// link to the chef (news_article_chefs), the reverse of an article's own
/// "IN THIS INTERVIEW". Same calm, text-led row as [HostedEventsSection]
/// on the same page, and like it renders nothing when [articles] is empty.
class NewsMentionsSection extends StatelessWidget {
  final List<NewsArticle> articles;
  final ValueChanged<NewsArticle> onTapArticle;

  const NewsMentionsSection({
    super.key,
    required this.articles,
    required this.onTapArticle,
  });

  @override
  Widget build(BuildContext context) {
    if (articles.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'IN THE NEWS',
          style: CsTypography.eyebrow.copyWith(color: AppColors.taupe),
        ),
        const SizedBox(height: CsSpacing.md),
        for (var i = 0; i < articles.length; i++) ...[
          if (i > 0) const SizedBox(height: CsSpacing.sm),
          _NewsMentionRow(
            article: articles[i],
            onTap: () => onTapArticle(articles[i]),
          ),
        ],
      ],
    );
  }
}

class _NewsMentionRow extends StatelessWidget {
  final NewsArticle article;
  final VoidCallback onTap;

  const _NewsMentionRow({required this.article, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final date = formatNewsDate(article.publishedAt);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(CsRadius.medium),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(CsSpacing.base),
          decoration: BoxDecoration(
            color: AppColors.warmWhite,
            borderRadius: BorderRadius.circular(CsRadius.medium),
            border: Border.all(color: AppColors.subtleBorderLight),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      article.shortTitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: CsTypography.bodyMedium.copyWith(
                        color: AppColors.forestGreen,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      article.section == NewsSection.interview
                          ? 'Interview · $date'
                          : date,
                      style: CsTypography.metadata,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: CsSpacing.sm),
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
}
