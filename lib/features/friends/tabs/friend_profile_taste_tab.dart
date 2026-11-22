import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/cs_spacing.dart';
import '../../../core/theme/cs_typography.dart';
import '../../../data/repositories/visit_wine_repository.dart' show CellarWine;
import '../../../models/visit.dart' show formatOverall;
import '../../../models/visit_wine.dart';
import '../friend_profile_all_visits_screen.dart';
import '../friend_profile_data.dart';
import '../friend_profile_screen.dart' show openFriendVenue, openVisitDetail;
import '../friends_together_data.dart';
import '../widgets/friend_event_row.dart' show FriendSectionLabel;

const _sharedPreviewCount = 5;
const _cityCount = 6;
const _winePreviewCount = 6;

/// Tab 4, Taste (Friends round one, 2026-11-22, idea 3): where the friend
/// eats most, the places you've both been with each one's score, their
/// cities, and the wines they shared. Built only from what a friend may
/// already see: shared visits, and wines on shared visits or kept without
/// one (verdict and note included, product owner 2026-11-21).
///
/// Compared per place only. No overall "taste match" figure and no
/// ranking of friends against each other.
class FriendProfileTasteTab extends StatelessWidget {
  final FriendProfileLayoutData data;

  const FriendProfileTasteTab({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final shared = data.sharedScores;
    final cities = data.cities;
    final wines = [...data.wines]
      ..sort((a, b) => _verdictRank(a).compareTo(_verdictRank(b)));
    final countries = [
      for (final code in topCountryCodes(data.visits))
        countryInSentence(code, data.countryNameByCode[code] ?? code),
    ];

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        CsSpacing.pageHorizontal,
        CsSpacing.lg,
        CsSpacing.pageHorizontal,
        CsSpacing.xxl,
      ),
      children: [
        if (countries.isNotEmpty) ...[
          Text(
            'Most often in ${countries.join(' and ')}.',
            style: CsTypography.editorialTitle(
              size: 21,
              italic: true,
            ).copyWith(color: AppColors.textOnDark),
          ),
          const SizedBox(height: CsSpacing.xl),
        ],
        if (shared.isNotEmpty) ...[
          const FriendSectionLabel('Where your tastes meet'),
          const SizedBox(height: CsSpacing.xs),
          _ScoreHeader(friendName: data.friendName.split(' ').first),
          for (final s in shared.take(_sharedPreviewCount))
            _SharedScoreRow(
              scores: s,
              onTap: () => openFriendVenue(context, s.venue),
            ),
          if (shared.length > _sharedPreviewCount)
            Padding(
              padding: const EdgeInsets.only(top: CsSpacing.sm),
              child: Text(
                "You've both been to ${shared.length} places",
                style: CsTypography.editorialBody.copyWith(
                  color: AppColors.secondaryOnDark,
                  fontSize: 13,
                ),
              ),
            ),
          const SizedBox(height: CsSpacing.xl),
        ],
        if (cities.isNotEmpty) ...[
          FriendSectionLabel("${data.friendName}'s cities"),
          const SizedBox(height: CsSpacing.sm),
          Wrap(
            spacing: CsSpacing.sm,
            runSpacing: CsSpacing.sm,
            children: [
              for (final city in cities.take(_cityCount))
                _CityChip(
                  city: city,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => FriendProfileAllVisitsScreen(
                        friendName: data.friendName,
                        title: "${data.friendName}'s ${city.cityName}",
                        visits: city.visits,
                        coverPhotoByVisitId: data.coverPhotoByVisitId,
                        onTapVisit: (context, fv) =>
                            openVisitDetail(context, fv),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: CsSpacing.xl),
        ],
        if (wines.isNotEmpty) ...[
          FriendSectionLabel("In ${data.friendName}'s glass"),
          for (final w in wines.take(_winePreviewCount)) _WineRow(wine: w),
        ],
        if (countries.isEmpty && shared.isEmpty && wines.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: CsSpacing.lg),
            child: Text(
              'This fills in as ${data.friendName} shares visits and wines.',
              style: CsTypography.editorialLead().copyWith(
                color: AppColors.secondaryOnDark,
              ),
            ),
          ),
      ],
    );
  }
}

/// Wines they'd drink again first, then the rest, each group newest first
/// (the order they arrive in).
int _verdictRank(CellarWine w) => switch (w.wine.verdict) {
  WineVerdict.again => 0,
  null => 1,
  WineVerdict.fine => 2,
  WineVerdict.notForMe => 3,
};

class _ScoreHeader extends StatelessWidget {
  final String friendName;
  const _ScoreHeader({required this.friendName});

  @override
  Widget build(BuildContext context) {
    final style = CsTypography.editorialBody.copyWith(
      color: AppColors.secondaryOnDark,
      fontSize: 12,
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: CsSpacing.xs),
      child: Row(
        children: [
          const Spacer(),
          SizedBox(
            width: 64,
            child: Text(
              friendName,
              textAlign: TextAlign.right,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: style,
            ),
          ),
          SizedBox(
            width: 52,
            child: Text('You', textAlign: TextAlign.right, style: style),
          ),
        ],
      ),
    );
  }
}

class _SharedScoreRow extends StatelessWidget {
  final SharedVenueScores scores;
  final VoidCallback onTap;

  const _SharedScoreRow({required this.scores, required this.onTap});

  String _score(double? s) => s == null ? '·' : formatOverall(s);

  @override
  Widget build(BuildContext context) {
    final numberStyle = CsTypography.editorialTitle(
      size: 17,
    ).copyWith(color: AppColors.textOnDark);
    return Semantics(
      button: true,
      label: [
        scores.venue.name,
        if (scores.theirs != null) 'theirs ${_score(scores.theirs)}',
        if (scores.mine != null) 'yours ${_score(scores.mine)}',
      ].join(', '),
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        child: Column(
          children: [
            Container(height: 1, color: AppColors.hairlineOnGreen),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: CsSpacing.sm),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      scores.venue.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: CsTypography.editorialTitle(
                        size: 16.5,
                      ).copyWith(color: AppColors.textOnDark),
                    ),
                  ),
                  SizedBox(
                    width: 64,
                    child: Text(
                      _score(scores.theirs),
                      textAlign: TextAlign.right,
                      style: numberStyle,
                    ),
                  ),
                  SizedBox(
                    width: 52,
                    child: Text(
                      _score(scores.mine),
                      textAlign: TextAlign.right,
                      style: numberStyle,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CityChip extends StatelessWidget {
  final FriendCity city;
  final VoidCallback onTap;

  const _CityChip({required this.city, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final count = city.placeCount;
    return Semantics(
      button: true,
      label: '${city.cityName}, $count ${count == 1 ? 'place' : 'places'}',
      excludeSemantics: true,
      child: Material(
        color: AppColors.greenSurface,
        borderRadius: BorderRadius.circular(2),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(2),
          child: Container(
            constraints: const BoxConstraints(minHeight: 44, minWidth: 96),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  city.cityName,
                  style: CsTypography.editorialTitle(
                    size: 16,
                  ).copyWith(color: AppColors.textOnDark),
                ),
                const SizedBox(height: 2),
                Text(
                  '$count ${count == 1 ? 'place' : 'places'}',
                  style: CsTypography.editorialBody.copyWith(
                    color: AppColors.secondaryOnDark,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _WineRow extends StatelessWidget {
  final CellarWine wine;
  const _WineRow({required this.wine});

  @override
  Widget build(BuildContext context) {
    final w = wine.wine;
    final title = [w.title, ?w.yearLabel].join(' ');
    final verdict = switch (w.verdict) {
      WineVerdict.again => 'Again',
      WineVerdict.fine => 'Fine',
      WineVerdict.notForMe => 'Not for me',
      null => null,
    };
    final note = w.tastingNote?.trim();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(height: 1, color: AppColors.hairlineOnGreen),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: CsSpacing.sm),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: CsTypography.editorialTitle(
                        size: 16.5,
                      ).copyWith(color: AppColors.textOnDark),
                    ),
                  ),
                  if (verdict != null) ...[
                    const SizedBox(width: CsSpacing.sm),
                    Text(
                      verdict.toUpperCase(),
                      style: CsTypography.editorialLabel().copyWith(
                        color: w.verdict == WineVerdict.again
                            ? AppColors.ivory
                            : AppColors.secondaryOnDark,
                      ),
                    ),
                  ],
                ],
              ),
              if (w.subtitle case final sub?) ...[
                const SizedBox(height: 2),
                Text(
                  sub,
                  style: CsTypography.editorialBody.copyWith(
                    color: AppColors.secondaryOnDark,
                    fontSize: 12.5,
                  ),
                ),
              ],
              if (note != null && note.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  note,
                  style: CsTypography.editorialTitle(
                    size: 15,
                    italic: true,
                  ).copyWith(color: AppColors.secondaryOnDark),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
