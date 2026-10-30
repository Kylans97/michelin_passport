import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/cs_spacing.dart';
import '../../../core/theme/cs_typography.dart';
import '../../../core/widgets/cs_filter_chip.dart';
import '../../../core/widgets/cs_primary_button.dart';
import '../../../core/theme/cs_surface_context.dart';
import '../../../core/widgets/key_row.dart';
import '../../../core/widgets/star_row.dart';
import '../../../core/widgets/venue_thumbnail.dart';
import '../../../data/repositories/country_lookup.dart';
import '../../../data/repositories/hotel_repository.dart';
import '../../../data/repositories/rankings_repository.dart';
import '../../../data/repositories/restaurant_repository.dart';
import '../../../models/hotel.dart';
import '../../../models/ranking_entry.dart';
import '../../../models/restaurant.dart';
import '../../events/event_detail_screen.dart';
import '../../hotels/hotel_detail_screen.dart';
import '../../restaurants/restaurant_detail_screen.dart';

/// Community Rankings: what members score highest, across restaurants,
/// hotels and events — unrelated to "My Rankings" and its own data source.
///
/// Layout "B" (product owner, 2026-10-30), following CLAUDE.md's UI
/// principle: one Filters affordance → a quiet summary of what's active →
/// the ranked list. No permanent chips on the page; type, country and
/// recognition (MICHELIN stars or Keys, or The World's 50 Best) live in an
/// ivory sheet. Each row is a calm editorial line — serif rank, a small
/// photo, name, city with stars/Keys (the only gold), the community score
/// and how many members it rests on — separated by hairlines rather than
/// boxed in cards.
///
/// Scores are the overall score members give a visit, stay or confirmed
/// event, each member's latest per venue, averaged in the
/// restaurant_rankings / hotel_rankings / event_rankings views, which
/// return only aggregates and only from 3 members.
///
/// [loadRanking], [loadCountryNames], [getRestaurantById] and
/// [getHotelById] are injectable so the real widget can be pumped in tests
/// without Supabase; each defaults to the real repository.
class CommunityRankingsTab extends StatefulWidget {
  final Future<List<CommunityRankedVenue>> Function(CommunityRankingKind kind)?
  loadRanking;
  final Future<Map<String, String>> Function()? loadCountryNames;
  final Future<Restaurant?> Function(String id)? getRestaurantById;
  final Future<Hotel?> Function(String id)? getHotelById;

  const CommunityRankingsTab({
    super.key,
    this.loadRanking,
    this.loadCountryNames,
    this.getRestaurantById,
    this.getHotelById,
  });

  @override
  State<CommunityRankingsTab> createState() => _CommunityRankingsTabState();
}

/// The recognition choice's label for [kind] — stars for restaurants, Keys
/// for hotels.
String recognitionFilterLabel(
  CommunityRankingKind kind,
  CommunityRecognitionFilter filter,
) => switch ((kind, filter)) {
  (_, CommunityRecognitionFilter.all) => 'Any',
  (_, CommunityRecognitionFilter.worlds50Best) => "World's 50 Best",
  (CommunityRankingKind.hotels, CommunityRecognitionFilter.one) => '1 Key',
  (CommunityRankingKind.hotels, CommunityRecognitionFilter.two) => '2 Keys',
  (CommunityRankingKind.hotels, CommunityRecognitionFilter.three) => '3 Keys',
  (_, CommunityRecognitionFilter.one) => '★',
  (_, CommunityRecognitionFilter.two) => '★★',
  (_, CommunityRecognitionFilter.three) => '★★★',
};

/// The one-line summary beside the Filters button: "Restaurants · Italy ·
/// ★★". Only what is actually narrowing the list is named.
String communityFiltersSummary(
  CommunityRankingFilters filters,
  Map<String, String> countryNames,
) {
  final country = filters.countryCode;
  return [
    filters.kind.label,
    if (country != null) countryNames[country] ?? country,
    if (filters.recognition != CommunityRecognitionFilter.all &&
        filters.kind != CommunityRankingKind.events)
      recognitionFilterLabel(filters.kind, filters.recognition),
  ].join(' · ');
}

class _CommunityRankingsTabState extends State<CommunityRankingsTab> {
  CommunityRankingFilters _filters = const CommunityRankingFilters();
  final _cache = <CommunityRankingKind, Future<List<CommunityRankedVenue>>>{};
  Map<String, String> _countryNames = const {};

  @override
  void initState() {
    super.initState();
    _loadCountryNames();
  }

  Future<List<CommunityRankedVenue>> _rows(CommunityRankingKind kind) =>
      _cache.putIfAbsent(kind, () {
        final load =
            widget.loadRanking ??
            RankingsRepository(Supabase.instance.client).getCommunityRanking;
        return load(kind);
      });

  Future<void> _loadCountryNames() async {
    try {
      final names = widget.loadCountryNames != null
          ? await widget.loadCountryNames!()
          : {
              for (final c in await getAllCountries(Supabase.instance.client))
                c.code: c.name,
            };
      if (mounted) setState(() => _countryNames = names);
    } catch (_) {
      // Names are cosmetic; the codes stand in.
    }
  }

  void _retry() => setState(() => _cache.remove(_filters.kind));

  Future<void> _openFilters() async {
    final chosen = await showModalBottomSheet<CommunityRankingFilters>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.ivory,
      showDragHandle: true,
      builder: (_) => _FiltersSheet(
        initial: _filters,
        rowsFor: _rows,
        countryNames: _countryNames,
      ),
    );
    if (chosen != null && mounted) setState(() => _filters = chosen);
  }

  Future<void> _open(CommunityRankedVenue venue) async {
    switch (venue.kind) {
      case CommunityRankingKind.restaurants:
        final getById =
            widget.getRestaurantById ??
            RestaurantRepository(Supabase.instance.client).getById;
        final restaurant = await getById(venue.id);
        if (!mounted || restaurant == null) return;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => RestaurantDetailScreen(restaurant: restaurant),
          ),
        );
      case CommunityRankingKind.hotels:
        final getById =
            widget.getHotelById ??
            HotelRepository(Supabase.instance.client).getById;
        final hotel = await getById(venue.id);
        if (!mounted || hotel == null) return;
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => HotelDetailScreen(hotel: hotel)),
        );
      case CommunityRankingKind.events:
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => EventDetailScreen(eventId: venue.id),
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(
          CsSpacing.pageHorizontal,
          CsSpacing.md,
          CsSpacing.pageHorizontal,
          CsSpacing.sm,
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                communityFiltersSummary(_filters, _countryNames),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: CsTypography.metadata.copyWith(
                  color: AppColors.secondaryOnDark,
                ),
              ),
            ),
            const SizedBox(width: CsSpacing.sm),
            _FiltersButton(
              activeCount: _filters.activeCount,
              onTap: _openFilters,
            ),
          ],
        ),
      ),
      Expanded(
        child: FutureBuilder<List<CommunityRankedVenue>>(
          future: _rows(_filters.kind),
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const Center(
                child: CircularProgressIndicator(
                  color: AppColors.ivory,
                  strokeWidth: 1.5,
                ),
              );
            }
            if (snap.hasError) {
              return _RankingsMessage(
                icon: Icons.wifi_off_rounded,
                message: 'Could not load community rankings',
                onRetry: _retry,
              );
            }
            final entries = applyCommunityFilters(
              snap.data ?? const [],
              _filters,
            );
            if (entries.isEmpty) {
              return _RankingsMessage(
                icon: Icons.emoji_events_outlined,
                message: _filters.activeCount > 0
                    ? 'Nothing matches these filters yet'
                    : 'No community data yet',
              );
            }
            return ListView.builder(
              padding: const EdgeInsets.fromLTRB(
                CsSpacing.pageHorizontal,
                0,
                CsSpacing.pageHorizontal,
                100,
              ),
              itemCount: entries.length,
              itemBuilder: (_, i) => _RankRow(
                entry: entries[i],
                rank: i + 1,
                onTap: () => _open(entries[i]),
              ),
            );
          },
        ),
      ),
    ],
  );
}

/// The one Filters affordance: a quiet outlined pill, "Filters" or
/// "Filters · 2" when anything narrows the list.
class _FiltersButton extends StatelessWidget {
  final int activeCount;
  final VoidCallback onTap;
  const _FiltersButton({required this.activeCount, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final label = activeCount == 0 ? 'Filters' : 'Filters · $activeCount';
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: Material(
        color: Colors.transparent,
        shape: const StadiumBorder(),
        child: InkWell(
          onTap: onTap,
          customBorder: const StadiumBorder(),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: ShapeDecoration(
              shape: StadiumBorder(
                side: BorderSide(
                  color: activeCount == 0
                      ? AppColors.hairlineOnGreen
                      : AppColors.ivory,
                ),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.tune_rounded,
                  size: 16,
                  color: AppColors.ivory,
                ),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: CsTypography.metadata.copyWith(
                    color: AppColors.ivory,
                    fontWeight: FontWeight.w600,
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

/// The ivory Filters sheet: TYPE, COUNTRY, RECOGNITION, then "Show N
/// places". Works on a draft and returns it only on that button, so
/// closing the sheet changes nothing. Countries offered are the ones the
/// chosen type's list actually contains — never a choice that can only
/// lead to an empty list.
class _FiltersSheet extends StatefulWidget {
  final CommunityRankingFilters initial;
  final Future<List<CommunityRankedVenue>> Function(CommunityRankingKind)
  rowsFor;
  final Map<String, String> countryNames;

  const _FiltersSheet({
    required this.initial,
    required this.rowsFor,
    required this.countryNames,
  });

  @override
  State<_FiltersSheet> createState() => _FiltersSheetState();
}

class _FiltersSheetState extends State<_FiltersSheet> {
  late CommunityRankingFilters _draft = widget.initial;

  String _countryName(String code) => widget.countryNames[code] ?? code;

  Widget _label(String text) => Padding(
    padding: const EdgeInsets.only(top: CsSpacing.lg, bottom: CsSpacing.sm),
    child: Text(
      text,
      style: CsTypography.eyebrow.copyWith(color: AppColors.taupe),
    ),
  );

  Widget _chips(List<Widget> chips) =>
      Wrap(spacing: CsSpacing.sm, runSpacing: CsSpacing.sm, children: chips);

  @override
  Widget build(BuildContext context) => SafeArea(
    child: Padding(
      padding: const EdgeInsets.fromLTRB(
        CsSpacing.pageHorizontal,
        0,
        CsSpacing.pageHorizontal,
        CsSpacing.lg,
      ),
      child: FutureBuilder<List<CommunityRankedVenue>>(
        future: widget.rowsFor(_draft.kind),
        builder: (context, snap) {
          final rows = snap.data ?? const <CommunityRankedVenue>[];
          final countries =
              {
                  for (final r in rows)
                    if (r.countryCode.isNotEmpty) r.countryCode.toUpperCase(),
                }.toList()
                ..sort((a, b) => _countryName(a).compareTo(_countryName(b)));
          final matches = applyCommunityFilters(rows, _draft).length;
          final loaded = snap.connectionState == ConnectionState.done;

          return SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Filters',
                        style: CsTypography.placeTitle.copyWith(
                          color: AppColors.forestGreen,
                        ),
                      ),
                    ),
                    if (_draft.activeCount > 0)
                      TextButton(
                        onPressed: () => setState(
                          () => _draft = CommunityRankingFilters(
                            kind: _draft.kind,
                          ),
                        ),
                        child: Text(
                          'Reset',
                          style: CsTypography.bodyMedium.copyWith(
                            color: AppColors.forestGreen,
                          ),
                        ),
                      ),
                  ],
                ),
                _label('TYPE'),
                _chips([
                  for (final kind in CommunityRankingKind.values)
                    CsFilterChip(
                      label: kind.label,
                      selected: _draft.kind == kind,
                      surface: CsSurface.light,
                      // A new type starts clean: its countries and
                      // recognition differ.
                      onTap: () => setState(
                        () => _draft = CommunityRankingFilters(kind: kind),
                      ),
                    ),
                ]),
                if (countries.isNotEmpty) ...[
                  _label('COUNTRY'),
                  _chips([
                    CsFilterChip(
                      label: 'Any',
                      selected: _draft.countryCode == null,
                      surface: CsSurface.light,
                      onTap: () => setState(
                        () => _draft = _draft.copyWith(countryCode: () => null),
                      ),
                    ),
                    for (final code in countries)
                      CsFilterChip(
                        label: _countryName(code),
                        selected: _draft.countryCode == code,
                        surface: CsSurface.light,
                        onTap: () => setState(
                          () =>
                              _draft = _draft.copyWith(countryCode: () => code),
                        ),
                      ),
                  ]),
                ],
                if (_draft.kind != CommunityRankingKind.events) ...[
                  _label('RECOGNITION'),
                  _chips([
                    for (final r in CommunityRecognitionFilter.values)
                      CsFilterChip(
                        label: recognitionFilterLabel(_draft.kind, r),
                        selected: _draft.recognition == r,
                        surface: CsSurface.light,
                        onTap: () => setState(
                          () => _draft = _draft.copyWith(recognition: r),
                        ),
                      ),
                  ]),
                ],
                const SizedBox(height: CsSpacing.xl),
                SizedBox(
                  width: double.infinity,
                  child: CsPrimaryButton(
                    label: !loaded
                        ? 'Show results'
                        : matches == 0
                        ? 'No places match yet'
                        : matches == 1
                        ? 'Show 1 place'
                        : 'Show $matches places',
                    surface: CsSurface.light,
                    onTap: () => Navigator.pop(context, _draft),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    ),
  );
}

// ── Empty / error message ───────────────────────────────────────────────────

/// Anchored just below the summary line, in `secondaryOnDark` — the
/// dark-surface token, never `textSecondary`, on this deep-green canvas.
class _RankingsMessage extends StatelessWidget {
  final IconData icon;
  final String message;
  final VoidCallback? onRetry;
  const _RankingsMessage({
    required this.icon,
    required this.message,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.topCenter,
    child: Padding(
      padding: const EdgeInsets.only(top: 56),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: AppColors.secondaryOnDark, size: 28),
          const SizedBox(height: 12),
          Text(
            message,
            style: GoogleFonts.inter(color: AppColors.secondaryOnDark),
          ),
          if (onRetry != null)
            TextButton(
              onPressed: onRetry,
              child: Text(
                'Retry',
                style: CsTypography.bodyMedium.copyWith(color: AppColors.ivory),
              ),
            ),
        ],
      ),
    ),
  );
}

// ── Ranked row ────────────────────────────────────────────────────────────────

const _months = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

/// One ranked venue or event: serif rank, small photo, name, city (or an
/// event's date) with stars/Keys and any World's 50 Best rank, then the
/// community score over its member count. A hairline above each row.
class _RankRow extends StatelessWidget {
  final CommunityRankedVenue entry;
  final int rank;
  final VoidCallback onTap;
  const _RankRow({
    required this.entry,
    required this.rank,
    required this.onTap,
  });

  String get _place {
    final start = entry.startDate;
    if (start == null) return entry.city;
    final date = '${start.day} ${_months[start.month - 1]} ${start.year}';
    return entry.city.isEmpty ? date : '${entry.city} · $date';
  }

  @override
  Widget build(BuildContext context) {
    final stars = entry.stars ?? 0;
    final keys = entry.keys ?? 0;
    final w50b = entry.worlds50BestRank;
    final meta = CsTypography.metadata.copyWith(
      color: AppColors.secondaryOnDark,
    );
    final score = entry.communityRating.toStringAsFixed(1);
    final members = entry.memberCount == 1
        ? '1 member'
        : '${entry.memberCount} members';

    return Semantics(
      button: true,
      label:
          '#$rank, ${entry.name}, ${entry.city}. Community rating $score, '
          '$members.',
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        child: Container(
          decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: AppColors.hairlineOnGreen)),
          ),
          padding: const EdgeInsets.symmetric(vertical: CsSpacing.md),
          child: Row(
            children: [
              SizedBox(
                width: 28,
                child: Text(
                  '$rank',
                  style: CsTypography.editorialTitle(
                    size: 24,
                  ).copyWith(color: AppColors.ivory),
                ),
              ),
              const SizedBox(width: CsSpacing.sm),
              // A framed tile, so a venue without a photo still reads as
              // a quiet square here rather than a loose monogram on the
              // same green as the page.
              Container(
                width: 48,
                height: 48,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: AppColors.greenSurface,
                  borderRadius: BorderRadius.circular(CsRadius.small),
                  border: Border.all(color: AppColors.hairlineOnGreen),
                ),
                child: VenueThumbnail(
                  imageUrl: entry.imageUrl,
                  framing: entry.imageFraming,
                  size: 48,
                ),
              ),
              const SizedBox(width: CsSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: CsTypography.placeTitle.copyWith(
                        color: AppColors.ivory,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            _place,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: meta,
                          ),
                        ),
                        if (stars > 0) ...[
                          const SizedBox(width: CsSpacing.xs),
                          StarRow(count: stars, size: 11),
                        ],
                        if (keys > 0) ...[
                          const SizedBox(width: CsSpacing.xs),
                          KeyRow(count: keys, size: 11),
                        ],
                      ],
                    ),
                    if (w50b != null)
                      Text("World's 50 Best #$w50b", style: meta),
                  ],
                ),
              ),
              const SizedBox(width: CsSpacing.sm),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    score,
                    style: CsTypography.editorialTitle(
                      size: 22,
                    ).copyWith(color: AppColors.ivory),
                  ),
                  Text(members, style: meta.copyWith(fontSize: 11)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
