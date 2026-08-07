import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/star_row.dart';
import '../../../data/repositories/rankings_repository.dart';
import '../../../models/ranking_entry.dart';

/// Community Rankings: unrelated to "My Rankings" and deliberately kept
/// self-contained (its own star filter, its own data source) rather than
/// forced through the personal per-restaurant aggregation.
class CommunityRankingsTab extends StatefulWidget {
  const CommunityRankingsTab({super.key});

  @override
  State<CommunityRankingsTab> createState() => _CommunityRankingsTabState();
}

class _CommunityRankingsTabState extends State<CommunityRankingsTab> {
  late final RankingsRepository _repo = RankingsRepository(
    Supabase.instance.client,
  );

  int _starFilter = 0;
  late Future<List<CommunityRankingEntry>> _future;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    setState(() {
      _future = _repo.getCommunityRankings(
        stars: _starFilter == 0 ? null : _starFilter,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _StarFilterChip(
                  label: 'All ★',
                  selected: _starFilter == 0,
                  onTap: () {
                    setState(() => _starFilter = 0);
                    _load();
                  },
                ),
                const SizedBox(width: 8),
                _StarFilterChip(
                  label: '★',
                  selected: _starFilter == 1,
                  onTap: () {
                    setState(() => _starFilter = 1);
                    _load();
                  },
                ),
                const SizedBox(width: 8),
                _StarFilterChip(
                  label: '★★',
                  selected: _starFilter == 2,
                  onTap: () {
                    setState(() => _starFilter = 2);
                    _load();
                  },
                ),
                const SizedBox(width: 8),
                _StarFilterChip(
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
        Expanded(
          child: FutureBuilder<List<CommunityRankingEntry>>(
            future: _future,
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
        ),
      ],
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

class _StarFilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _StarFilterChip({
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
