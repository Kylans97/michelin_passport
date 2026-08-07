import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/navigation/route_observer.dart';
import '../../../core/utils/visit_years.dart';
import '../../../core/widgets/year_filter_bar.dart';
import '../../../data/repositories/rankings_repository.dart';
import '../../../models/passport_entry.dart';
import '../../../models/ranking_dimension.dart';
import '../../../models/ranking_entry.dart';
import '../../../models/visit.dart';
import '../../restaurants/widgets/detail_section.dart';
import '../rankings_view_model.dart';
import 'dimension_filter_bar.dart';
import 'personal_ranking_card.dart';

/// "My Rankings": the user's own visited restaurants ranked by one rating
/// dimension over one period.
///
/// This tab stays mounted for the whole app session — it lives inside the
/// bottom-tab IndexedStack (see `_MainNavigation` in app.dart), which never
/// disposes its children on tab switch. A one-time fetch would go stale the
/// moment a visit is saved elsewhere, so the source data is reloaded
/// explicitly instead: on first mount, on pull-to-refresh, and via
/// [RouteAware.didPopNext] whenever a pushed screen (RestaurantDetailScreen,
/// reached from a ranking card or from Explore) is popped back to the tab
/// shell. Changing dimension or year never refetches — both just re-run
/// [buildPersonalRankings] against the source already held in memory.
class PersonalRankingsTab extends StatefulWidget {
  final String userId;

  const PersonalRankingsTab({super.key, required this.userId});

  @override
  State<PersonalRankingsTab> createState() => _PersonalRankingsTabState();
}

class _PersonalRankingsTabState extends State<PersonalRankingsTab>
    with RouteAware {
  late final RankingsRepository _repo = RankingsRepository(
    Supabase.instance.client,
  );

  List<PassportEntry>? _entries; // null until the first load completes.
  bool _loading = true; // true only for the very first, blocking load.
  bool _loadError = false;
  bool _refreshing = false; // guards overlapping refresh calls.

  RankingDimension _dimension = RankingDimension.overall;
  int? _selectedYear; // null = "All time", the default.

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route is PageRoute) {
      appRouteObserver.subscribe(this, route);
    }
  }

  @override
  void dispose() {
    appRouteObserver.unsubscribe(this);
    super.dispose();
  }

  // Fires when a screen pushed on top of the tab shell is popped and this
  // (permanently mounted) tab becomes current again — covers a visit saved
  // from Explore just as much as one saved from a ranking card here.
  @override
  void didPopNext() => _load();

  Future<void> _load() async {
    if (_refreshing) return;
    _refreshing = true;
    try {
      final entries = await _repo.getPersonalRankingSource(widget.userId);
      if (!mounted) return;
      final years = availableVisitYears(
        entries.expand((entry) => entry.visits),
      );
      setState(() {
        _entries = entries;
        _loading = false;
        _loadError = false;
        // Preserve the selected year only if it's still represented in the
        // freshly loaded data; otherwise fall back to "All time".
        if (_selectedYear != null && !years.contains(_selectedYear)) {
          _selectedYear = null;
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        // Only surface an error screen when there's nothing to show yet —
        // a failed background refresh should leave existing content as-is.
        _loadError = _entries == null;
      });
    } finally {
      _refreshing = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(
          color: AppColors.gold,
          strokeWidth: 1.5,
        ),
      );
    }
    if (_loadError) {
      return Center(
        child: Text(
          'Could not load rankings',
          style: GoogleFonts.inter(color: AppColors.textSecondary),
        ),
      );
    }

    final allEntries = _entries ?? [];
    final allVisits = allEntries.expand((entry) => entry.visits);
    final years = availableVisitYears(allVisits);
    final rankings = buildPersonalRankings(
      allEntries,
      dimension: _dimension,
      year: _selectedYear,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(20, 16, 20, 12),
          child: SectionLabel('MY RANKINGS'),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: DimensionFilterBar(
            selected: _dimension,
            onSelect: (d) => setState(() => _dimension = d),
          ),
        ),
        if (years.isNotEmpty) ...[
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: YearFilterBar(
              years: years,
              selectedYear: _selectedYear,
              onSelect: (year) => setState(() => _selectedYear = year),
            ),
          ),
        ],
        const SizedBox(height: 16),
        Expanded(
          child: _RankingsList(
            rankings: rankings,
            emptyMessage: _emptyMessage(allVisits, rankings),
            onRefresh: _load,
          ),
        ),
      ],
    );
  }

  String _emptyMessage(
    Iterable<Visit> allVisits,
    List<PersonalRankingEntry> rankings,
  ) {
    final hasAnyRatedVisit = allVisits.any(
      (v) =>
          v.rating != null ||
          v.foodRating != null ||
          v.serviceRating != null ||
          v.wineRating != null ||
          v.valueRating != null,
    );
    if (!hasAnyRatedVisit) return 'No rated restaurant visits yet.';
    if (_selectedYear == null) return 'No ${_dimension.label} ratings yet.';
    return 'No ${_dimension.label} ratings in $_selectedYear.';
  }
}

class _RankingsList extends StatelessWidget {
  final List<PersonalRankingEntry> rankings;
  final String emptyMessage;
  final Future<void> Function() onRefresh;

  const _RankingsList({
    required this.rankings,
    required this.emptyMessage,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      color: AppColors.gold,
      backgroundColor: AppColors.card,
      onRefresh: onRefresh,
      child: rankings.isEmpty
          ? ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 80,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.leaderboard_outlined,
                        color: AppColors.textSecondary,
                        size: 48,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        emptyMessage,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.playfairDisplay(
                          color: AppColors.textSecondary,
                          fontSize: 17,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            )
          : ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
              itemCount: rankings.length,
              itemBuilder: (_, i) => PersonalRankingCard(
                entry: rankings[i],
                rank: i + 1,
                onReturn: onRefresh,
              ),
            ),
    );
  }
}
