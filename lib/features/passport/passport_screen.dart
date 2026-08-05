import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants/app_colors.dart';
import '../../core/widgets/star_row.dart';
import '../../data/repositories/visited_repository.dart';
import '../../models/restaurant.dart';
import 'widgets/stat_card.dart';

class PassportScreen extends StatefulWidget {
  const PassportScreen({super.key});

  @override
  State<PassportScreen> createState() => _PassportScreenState();
}

class _PassportScreenState extends State<PassportScreen> {
  late final VisitedRepository _repo = VisitedRepository(
    Supabase.instance.client,
  );

  late Future<List<Restaurant>> _future;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    final uid = Supabase.instance.client.auth.currentUser?.id ?? '';
    _future = _repo.getVisited(uid);
  }

  void _refresh() => setState(_load);

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Restaurant>>(
      future: _future,
      builder: (context, snap) {
        final visited = snap.data ?? [];
        final countries = visited.map((r) => r.countryName).toSet().length;
        final cities = visited.map((r) => r.cityName).toSet().length;

        return RefreshIndicator(
          color: AppColors.gold,
          backgroundColor: AppColors.card,
          onRefresh: () async => _refresh(),
          child: CustomScrollView(
            slivers: [
              _PassportHeader(),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                  child: Row(
                    children: [
                      StatCard(
                        value: '${visited.length}',
                        label: 'RESTAURANTS',
                        icon: Icons.restaurant_rounded,
                      ),
                      const SizedBox(width: 10),
                      StatCard(
                        value: '$countries',
                        label: 'COUNTRIES',
                        icon: Icons.public_rounded,
                      ),
                      const SizedBox(width: 10),
                      StatCard(
                        value: '$cities',
                        label: 'CITIES',
                        icon: Icons.location_city_rounded,
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
                        'My Stamps',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(width: 10),
                      if (snap.connectionState == ConnectionState.waiting)
                        const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            color: AppColors.gold,
                            strokeWidth: 1.5,
                          ),
                        )
                      else
                        _CountBadge('${visited.length}'),
                    ],
                  ),
                ),
              ),
              if (snap.hasError)
                SliverFillRemaining(child: _ErrorState(onRetry: _refresh))
              else if (snap.connectionState == ConnectionState.waiting)
                const SliverFillRemaining(
                  child: Center(
                    child: CircularProgressIndicator(
                      color: AppColors.gold,
                      strokeWidth: 1.5,
                    ),
                  ),
                )
              else if (visited.isEmpty)
                const SliverFillRemaining(child: _EmptyStamps())
              else
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, i) => Padding(
                      padding: EdgeInsets.fromLTRB(
                        20,
                        0,
                        20,
                        i == visited.length - 1 ? 100 : 12,
                      ),
                      child: _StampCard(
                        restaurant: visited[i],
                        stampNumber: i + 1,
                      ),
                    ),
                    childCount: visited.length,
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
                        'TABLE PASSPORT',
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

// ── Stamp card ────────────────────────────────────────────────────────────────

class _StampCard extends StatelessWidget {
  final Restaurant restaurant;
  final int stampNumber;
  const _StampCard({required this.restaurant, required this.stampNumber});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorder, width: 0.5),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.goldBorder50, width: 1),
            ),
            alignment: Alignment.center,
            child: Text(
              '#$stampNumber',
              style: GoogleFonts.inter(
                color: AppColors.gold,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  restaurant.name,
                  style: GoogleFonts.playfairDisplay(
                    color: AppColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                if (restaurant.hasMichelinStar)
                  StarRow(count: restaurant.michelinStars!),
                const SizedBox(height: 4),
                Text(
                  '${restaurant.flagEmoji}  ${restaurant.cityName}, ${restaurant.countryName}',
                  style: GoogleFonts.inter(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: AppColors.goldAlpha10,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.goldAlpha30, width: 0.5),
            ),
            child: Text(
              'VISITED',
              style: GoogleFonts.inter(
                color: AppColors.gold,
                fontSize: 9,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
              ),
            ),
          ),
        ],
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

class _EmptyStamps extends StatelessWidget {
  const _EmptyStamps();

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(
          Icons.menu_book_outlined,
          color: AppColors.textSecondary,
          size: 48,
        ),
        const SizedBox(height: 16),
        Text(
          'No stamps yet',
          style: GoogleFonts.playfairDisplay(
            color: AppColors.textSecondary,
            fontSize: 18,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Explore restaurants and mark them as visited',
          style: GoogleFonts.inter(
            color: AppColors.textSecondary,
            fontSize: 13,
          ),
        ),
      ],
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
