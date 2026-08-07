import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/visit_years.dart';
import '../../core/widgets/year_filter_bar.dart';
import '../../data/repositories/visited_repository.dart';
import '../../models/passport_entry.dart';
import 'passport_view_model.dart';
import 'widgets/passport_empty_state.dart';
import 'widgets/passport_restaurant_card.dart';
import 'widgets/stat_card.dart';

/// My Passport: the user's personal collection of visited restaurants.
/// VISITS are individual historical records (see VisitedRepository /
/// Restaurant Detail's Visit History); PASSPORT shows each unique venue
/// once, however many times it's actually been visited. All aggregation
/// (grouping by restaurant, year filtering, averages, totals) happens in
/// [PassportFilterResult] — this screen only lays out what that produces.
class PassportScreen extends StatefulWidget {
  const PassportScreen({super.key});

  @override
  State<PassportScreen> createState() => _PassportScreenState();
}

class _PassportScreenState extends State<PassportScreen> {
  late final VisitedRepository _repo = VisitedRepository(
    Supabase.instance.client,
  );

  late Future<List<PassportEntry>> _future;
  int? _selectedYear; // null = "All time", the default.

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    final uid = Supabase.instance.client.auth.currentUser?.id ?? '';
    _future = _repo.loadPassportRestaurants(uid);
  }

  void _refresh() => setState(_load);

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<PassportEntry>>(
      future: _future,
      builder: (context, snap) {
        final allEntries = snap.data ?? [];
        final years = availableVisitYears(
          allEntries.expand((entry) => entry.visits),
        );
        final result = PassportFilterResult.of(allEntries, _selectedYear);
        final loading = snap.connectionState == ConnectionState.waiting;

        return RefreshIndicator(
          color: AppColors.gold,
          backgroundColor: AppColors.card,
          onRefresh: () async => _refresh(),
          child: CustomScrollView(
            slivers: [
              _PassportHeader(),
              if (years.isNotEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                    child: YearFilterBar(
                      years: years,
                      selectedYear: _selectedYear,
                      onSelect: (year) => setState(() => _selectedYear = year),
                    ),
                  ),
                ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                  child: Row(
                    children: [
                      StatCard(
                        value: '${result.summary.restaurantsVisited}',
                        label: 'RESTAURANTS',
                        icon: Icons.restaurant_rounded,
                      ),
                      const SizedBox(width: 10),
                      StatCard(
                        value: '${result.summary.michelinStarsExperienced}',
                        label: 'STARS',
                        icon: Icons.star_rounded,
                      ),
                      const SizedBox(width: 10),
                      StatCard(
                        value: '${result.summary.countriesVisited}',
                        label: 'COUNTRIES',
                        icon: Icons.public_rounded,
                      ),
                    ],
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 32, 20, 12),
                  child: Row(
                    children: [
                      Text(
                        'Restaurants',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(width: 10),
                      if (loading)
                        const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            color: AppColors.gold,
                            strokeWidth: 1.5,
                          ),
                        )
                      else
                        _CountBadge('${result.entries.length}'),
                    ],
                  ),
                ),
              ),
              if (snap.hasError)
                SliverFillRemaining(child: _ErrorState(onRetry: _refresh))
              else if (loading)
                const SliverFillRemaining(
                  child: Center(
                    child: CircularProgressIndicator(
                      color: AppColors.gold,
                      strokeWidth: 1.5,
                    ),
                  ),
                )
              else if (allEntries.isEmpty)
                const SliverFillRemaining(
                  child: PassportEmptyState(
                    message: 'Your passport is waiting for its first stamp.',
                  ),
                )
              else if (result.entries.isEmpty)
                SliverFillRemaining(
                  child: PassportEmptyState(
                    message: 'No restaurant visits in $_selectedYear.',
                  ),
                )
              else
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, i) => Padding(
                      padding: EdgeInsets.fromLTRB(
                        20,
                        0,
                        20,
                        i == result.entries.length - 1 ? 100 : 12,
                      ),
                      child: PassportRestaurantCard(stats: result.entries[i]),
                    ),
                    childCount: result.entries.length,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

// ── Collapsible header ────────────────────────────────────────────────────────

class _PassportHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final name =
        Supabase.instance.client.auth.currentUser?.userMetadata?['display_name']
            as String? ??
        'Passport';

    return SliverAppBar(
      expandedHeight: 200,
      pinned: true,
      backgroundColor: AppColors.background,
      flexibleSpace: FlexibleSpaceBar(
        collapseMode: CollapseMode.parallax,
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF1C1400),
                Color(0xFF110E00),
                AppColors.background,
              ],
              stops: [0.0, 0.5, 1.0],
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.menu_book_rounded,
                        color: AppColors.gold,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'CHASING STARS',
                        style: GoogleFonts.inter(
                          color: AppColors.gold,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 2.0,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Text(
                    name,
                    style: GoogleFonts.playfairDisplay(
                      color: AppColors.textPrimary,
                      fontSize: 30,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        titlePadding: const EdgeInsets.fromLTRB(20, 0, 0, 16),
        title: Text(
          'My Passport',
          style: GoogleFonts.playfairDisplay(
            color: AppColors.textPrimary,
            fontSize: 22,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

// ── Small helpers ─────────────────────────────────────────────────────────────

class _CountBadge extends StatelessWidget {
  final String value;
  const _CountBadge(this.value);

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
    decoration: BoxDecoration(
      color: AppColors.goldMuted,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: AppColors.goldBorder40, width: 0.5),
    ),
    child: Text(
      value,
      style: GoogleFonts.inter(
        color: AppColors.gold,
        fontSize: 12,
        fontWeight: FontWeight.w600,
      ),
    ),
  );
}

class _ErrorState extends StatelessWidget {
  final VoidCallback onRetry;
  const _ErrorState({required this.onRetry});

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(
          Icons.wifi_off_rounded,
          color: AppColors.textSecondary,
          size: 40,
        ),
        const SizedBox(height: 16),
        Text(
          'Could not load data',
          style: GoogleFonts.inter(color: AppColors.textSecondary),
        ),
        const SizedBox(height: 12),
        TextButton(
          onPressed: onRetry,
          child: Text('Retry', style: GoogleFonts.inter(color: AppColors.gold)),
        ),
      ],
    ),
  );
}
