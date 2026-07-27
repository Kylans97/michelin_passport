import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants/app_colors.dart';
import '../../core/widgets/star_row.dart';
import '../../data/repositories/rankings_repository.dart';
import '../../models/ranking_entry.dart';

class RankingsScreen extends StatefulWidget {
  const RankingsScreen({super.key});

  @override
  State<RankingsScreen> createState() => _RankingsScreenState();
}

class _RankingsScreenState extends State<RankingsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabCtrl;
  late final RankingsRepository _repo;
  final String _uid = Supabase.instance.client.auth.currentUser?.id ?? '';

  int _starFilter = 0;

  late Future<List<PersonalRankingEntry>> _personalFuture;
  late Future<List<CommunityRankingEntry>> _communityFuture;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _repo = RankingsRepository(Supabase.instance.client);
    _load();
  }

  void _load() {
    setState(() {
      _personalFuture = _repo.getPersonalRankings(
        _uid,
        stars: _starFilter == 0 ? null : _starFilter,
      );
      _communityFuture = _repo.getCommunityRankings(
        stars: _starFilter == 0 ? null : _starFilter,
      );
    });
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: NestedScrollView(
        headerSliverBuilder: (_, _) => [
          SliverAppBar(
            title: const Text('Rankings'),
            pinned: true,
            backgroundColor: AppColors.background,
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(96),
              child: Column(
                children: [
                  // Star filter chips
                  Container(
                    color: AppColors.background,
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _FilterChip(
                            label: 'All ★',
                            selected: _starFilter == 0,
                            onTap: () {
                              setState(() => _starFilter = 0);
                              _load();
                            },
                          ),
                          const SizedBox(width: 8),
                          _FilterChip(
                            label: '★',
                            selected: _starFilter == 1,
                            onTap: () {
                              setState(() => _starFilter = 1);
                              _load();
                            },
                          ),
                          const SizedBox(width: 8),
                          _FilterChip(
                            label: '★★',
                            selected: _starFilter == 2,
                            onTap: () {
                              setState(() => _starFilter = 2);
                              _load();
                            },
                          ),
                          const SizedBox(width: 8),
                          _FilterChip(
                            label: '★★★',
                            selected: _starFilter == 3,
                            onTap: () {
                              setState(() => _starFilter = 3);
                              _load();
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Tabs
                  TabBar(
                    controller: _tabCtrl,
                    labelColor: AppColors.gold,
                    unselectedLabelColor: AppColors.textSecondary,
                    indicatorColor: AppColors.gold,
                    indicatorSize: TabBarIndicatorSize.label,
                    labelStyle: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                    unselectedLabelStyle: GoogleFonts.inter(fontSize: 13),
                    tabs: const [
                      Tab(text: 'My Rankings'),
                      Tab(text: 'Community'),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
        body: TabBarView(
          controller: _tabCtrl,
          children: [
            // ── Personal rankings ───────────────────────────────────────
            FutureBuilder<List<PersonalRankingEntry>>(
              future: _personalFuture,
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(
                      color: AppColors.gold,
                      strokeWidth: 1.5,
                    ),
                  );
                }
                if (snap.hasError) {
                  return Center(
                    child: Text(
                      'Could not load rankings',
                      style: GoogleFonts.inter(color: AppColors.textSecondary),
                    ),
                  );
                }
                final entries = snap.data ?? [];
                if (entries.isEmpty) {
                  return Center(
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
                          'No ratings yet',
                          style: GoogleFonts.playfairDisplay(
                            color: AppColors.textSecondary,
                            fontSize: 18,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Rate restaurants when logging visits\nto build your personal rankings.',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(
                            color: AppColors.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
                  itemCount: entries.length,
                  itemBuilder: (_, i) =>
                      _PersonalRankCard(entry: entries[i], rank: i + 1),
                );
              },
            ),

            // ── Community rankings ──────────────────────────────────────
            FutureBuilder<List<CommunityRankingEntry>>(
              future: _communityFuture,
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(
                      color: AppColors.gold,
                      strokeWidth: 1.5,
                    ),
                  );
                }
                if (snap.hasError) {
                  return Center(
                    child: Text(
                      'Could not load community rankings',
                      style: GoogleFonts.inter(color: AppColors.textSecondary),
                    ),
                  );
                }
                final entries = snap.data ?? [];
                if (entries.isEmpty) {
                  return Center(
                    child: Text(
                      'No community data yet',
                      style: GoogleFonts.inter(color: AppColors.textSecondary),
                    ),
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
                  itemCount: entries.length,
                  itemBuilder: (_, i) =>
                      _CommunityRankCard(entry: entries[i], rank: i + 1),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ── Personal rank card ────────────────────────────────────────────────────────

class _PersonalRankCard extends StatelessWidget {
  final PersonalRankingEntry entry;
  final int rank;
  const _PersonalRankCard({required this.entry, required this.rank});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorder, width: 0.5),
      ),
      child: Row(
        children: [
          // Rank number
          SizedBox(
            width: 32,
            child: Text(
              '#$rank',
              style: GoogleFonts.inter(
                color: AppColors.gold,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 10),
          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.restaurant.name,
                  style: GoogleFonts.playfairDisplay(
                    color: AppColors.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    StarRow(count: entry.restaurant.michelinStars, size: 11),
                    const SizedBox(width: 8),
                    Text(
                      '${entry.restaurant.countryFlag}  ${entry.restaurant.city}',
                      style: GoogleFonts.inter(
                        color: AppColors.textSecondary,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Personal rating badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.goldMuted,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.goldBorder40, width: 0.5),
            ),
            child: Text(
              entry.personalRating.toStringAsFixed(1),
              style: GoogleFonts.playfairDisplay(
                color: AppColors.gold,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Community rank card ───────────────────────────────────────────────────────

class _CommunityRankCard extends StatelessWidget {
  final CommunityRankingEntry entry;
  final int rank;
  const _CommunityRankCard({required this.entry, required this.rank});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorder, width: 0.5),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 32,
            child: Text(
              '#$rank',
              style: GoogleFonts.inter(
                color: AppColors.gold,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.name,
                  style: GoogleFonts.playfairDisplay(
                    color: AppColors.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    StarRow(count: entry.michelinStars, size: 11),
                    const SizedBox(width: 8),
                    Text(
                      '${entry.countryFlag}  ${entry.city}',
                      style: GoogleFonts.inter(
                        color: AppColors.textSecondary,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                entry.communityRating.toStringAsFixed(1),
                style: GoogleFonts.playfairDisplay(
                  color: AppColors.gold,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                '${entry.totalVisits} visits',
                style: GoogleFonts.inter(
                  color: AppColors.textSecondary,
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Filter chip ───────────────────────────────────────────────────────────────

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: selected ? AppColors.goldMuted : AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: selected ? AppColors.goldBorder60 : AppColors.cardBorder,
          width: selected ? 1.0 : 0.5,
        ),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          color: selected ? AppColors.gold : AppColors.textSecondary,
          fontSize: 12,
          fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
        ),
      ),
    ),
  );
}
