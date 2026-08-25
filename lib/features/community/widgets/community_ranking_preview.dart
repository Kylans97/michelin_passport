import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/cs_spacing.dart';
import '../../../core/theme/cs_typography.dart';
import '../../../core/widgets/star_row.dart';
import '../../../models/ranking_entry.dart';
import 'community_shared.dart';

/// COMMUNITY V1 UI REFINEMENT — Community Ranking is now the Community
/// tab's primary visual feature: a single restrained [CommunityIvoryCard]
/// (ivory content on the deep-green canvas, per this pass's own core
/// design principle) rather than loose text/rows directly on the page
/// background. Still reads the exact same existing Community Ranking
/// source ([entries] arrives already ordered by [restaurant_rankings]
/// `community_rating DESC`, the same data `CommunityRankingsTab`/
/// `CommunityScreen`'s "Hottest Places" already read via
/// `RankingsRepository.getCommunityRankings()`) — this widget never
/// queries, sorts, or recomputes anything, and never renders more than
/// the first three.
///
/// Zero qualifying restaurants keeps the card (never fabricates ranking
/// rows) with a compact "No restaurants have qualified yet." line — the
/// "See full ranking" link always renders either way, since the full
/// Community Ranking experience is a valid destination regardless of
/// today's data.
class CommunityRankingPreview extends StatelessWidget {
  final List<CommunityRankingEntry> entries;
  final ValueChanged<CommunityRankingEntry> onTapEntry;
  final VoidCallback onSeeFullRanking;

  const CommunityRankingPreview({
    super.key,
    required this.entries,
    required this.onTapEntry,
    required this.onSeeFullRanking,
  });

  @override
  Widget build(BuildContext context) {
    final preview = entries.take(3).toList();
    return CommunityIvoryCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (preview.isEmpty)
            Text(
              'No restaurants have qualified yet.',
              style: CsTypography.bodyMedium.copyWith(
                color: AppColors.forestGreen,
              ),
            )
          else
            for (var i = 0; i < preview.length; i++) ...[
              if (i > 0) const SizedBox(height: CsSpacing.sm),
              _RankingPreviewRow(
                rank: i + 1,
                entry: preview[i],
                onTap: () => onTapEntry(preview[i]),
              ),
            ],
          const SizedBox(height: CsSpacing.md),
          CommunityActionLink(
            label: 'See full ranking',
            onTap: onSeeFullRanking,
            light: true,
          ),
        ],
      ),
    );
  }
}

class _RankingPreviewRow extends StatelessWidget {
  final int rank;
  final CommunityRankingEntry entry;
  final VoidCallback onTap;

  const _RankingPreviewRow({
    required this.rank,
    required this.entry,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label:
        '#$rank. ${entry.name}, ${entry.city}. '
        '${entry.communityRating.toStringAsFixed(1)}.',
    excludeSemantics: true,
    child: Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(CsRadius.small),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: CsSpacing.xs),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(
                width: 22,
                child: Text(
                  '$rank',
                  style: CsTypography.bodyMedium.copyWith(
                    color: AppColors.taupe,
                  ),
                ),
              ),
              const SizedBox(width: CsSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: CsTypography.bodyMedium.copyWith(
                        color: AppColors.forestGreen,
                      ),
                    ),
                    Row(
                      children: [
                        if (entry.michelinStars > 0) ...[
                          StarRow(count: entry.michelinStars, size: 11),
                          const SizedBox(width: CsSpacing.xs),
                        ],
                        Flexible(
                          child: Text(
                            '${entry.countryFlag} ${entry.city}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: CsTypography.metadata.copyWith(
                              color: AppColors.taupe,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: CsSpacing.sm),
              Text(
                entry.communityRating.toStringAsFixed(1),
                style: CsTypography.bodyMedium.copyWith(
                  color: AppColors.forestGreen,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
