import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/cs_spacing.dart';
import '../../../core/theme/cs_typography.dart';
import '../../../models/visit.dart' show formatOverall;
import '../friend_profile_all_visits_screen.dart';
import '../friend_profile_data.dart';
import '../friend_profile_screen.dart' show openFriendVenue, openVisitDetail;
import '../friends_together_data.dart';
import '../widgets/friend_event_row.dart' show FriendSectionLabel;
import '../widgets/friend_profile_verdict_row.dart';

const _sharedPreviewCount = 5;
const _cityCount = 6;
const _favouritesPreviewCount = 3;

/// Tab 4, Palate: the friend's palate next to yours (product owner,
/// 2026-11-24, renamed from Taste when the wines moved to the Cellar tab).
/// Where they eat most, the places you've both been with each one's
/// score, their favourites at places you haven't been (moved here from
/// Overview), the cuisines they return to, and their cities. Built only
/// from their shared visits.
///
/// Compared per place only. No overall "taste match" figure and no
/// ranking of friends against each other.
class FriendProfilePalateTab extends StatelessWidget {
  final FriendProfileLayoutData data;

  const FriendProfilePalateTab({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final shared = data.sharedScores;
    final cities = data.cities;
    final favourites = data.recommended;
    final cuisines = topCuisines(data.visits);
    final firstName = data.friendName.split(' ').first;
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
        if (favourites.isNotEmpty) ...[
          FriendSectionLabel("$firstName's favourites"),
          const SizedBox(height: CsSpacing.xs),
          Text(
            "Their best scores at places you haven't been.",
            style: CsTypography.editorialBody.copyWith(
              color: AppColors.secondaryOnDark,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: CsSpacing.sm),
          for (final fv in favourites.take(_favouritesPreviewCount))
            FriendVerdictRow(
              visit: fv,
              photoUrl: null,
              onTap: () => openFriendVenue(context, fv.venue),
            ),
          const SizedBox(height: CsSpacing.xl),
        ],
        if (cuisines.isNotEmpty) ...[
          FriendSectionLabel('The cuisines $firstName returns to'),
          const SizedBox(height: CsSpacing.sm),
          Text(
            listInSentence(cuisines),
            style: CsTypography.editorialTitle(
              size: 19,
              italic: true,
            ).copyWith(color: AppColors.textOnDark),
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
        if (countries.isEmpty && shared.isEmpty && favourites.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: CsSpacing.lg),
            child: Text(
              'This fills in as ${data.friendName} shares visits.',
              style: CsTypography.editorialLead().copyWith(
                color: AppColors.secondaryOnDark,
              ),
            ),
          ),
      ],
    );
  }
}

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
