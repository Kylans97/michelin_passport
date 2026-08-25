import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/star_row.dart';
import '../../../data/repositories/rankings_repository.dart';
import '../../../data/repositories/restaurant_repository.dart';
import '../../../models/ranking_entry.dart';
import '../../../models/restaurant.dart';
import '../../restaurants/restaurant_detail_screen.dart';

/// Community Rankings: unrelated to "My Rankings" and deliberately kept
/// self-contained (its own star filter, its own data source) rather than
/// forced through the personal per-restaurant aggregation.
///
/// Community Rankings Backend V1: rows are now tappable — the same
/// resolve-full-Restaurant-then-push pattern Community's "Hottest Places"
/// hero already uses ([RestaurantRepository.getById], since
/// [CommunityRankingEntry] only carries summary fields, not enough for
/// [RestaurantDetailScreen]). [loadCommunityRankings] and
/// [getRestaurantById] are injectable — the same constructor-injection
/// seam used throughout this app's other Supabase-eager destructive/
/// data-loading widgets (`DeleteAccountScreen`, `CommunityScreen`) — so
/// the real widget can be pumped and exercised in tests without Supabase.
/// Both default to the real repositories against
/// `Supabase.instance.client` when omitted.
class CommunityRankingsTab extends StatefulWidget {
  final Future<List<CommunityRankingEntry>> Function({int? stars})?
  loadCommunityRankings;
  final Future<Restaurant?> Function(String id)? getRestaurantById;

  const CommunityRankingsTab({
    super.key,
    this.loadCommunityRankings,
    this.getRestaurantById,
  });

  @override
  State<CommunityRankingsTab> createState() => _CommunityRankingsTabState();
}

class _CommunityRankingsTabState extends State<CommunityRankingsTab> {
  int _starFilter = 0;
  late Future<List<CommunityRankingEntry>> _future;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    setState(() {
      final load =
          widget.loadCommunityRankings ??
          RankingsRepository(Supabase.instance.client).getCommunityRankings;
      _future = load(stars: _starFilter == 0 ? null : _starFilter);
    });
  }

  Future<void> _openRestaurant(String restaurantId) async {
    final getById =
        widget.getRestaurantById ??
        RestaurantRepository(Supabase.instance.client).getById;
    final restaurant = await getById(restaurantId);
    if (!mounted || restaurant == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RestaurantDetailScreen(restaurant: restaurant),
      ),
    );
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
                return const _RankingsMessage(
                  icon: Icons.wifi_off_rounded,
                  message: 'Could not load community rankings',
                );
              }
              final entries = snap.data ?? [];
              if (entries.isEmpty) {
                return const _RankingsMessage(
                  icon: Icons.emoji_events_outlined,
                  message: 'No community data yet',
                );
              }
              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
                itemCount: entries.length,
                itemBuilder: (_, i) => _CommunityRankCard(
                  entry: entries[i],
                  rank: i + 1,
                  onTap: () => _openRestaurant(entries[i].restaurantId),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

// ── Empty / error message ───────────────────────────────────────────────────

/// Primary Tabs UI Polish V1 bugfix + polish: the previous `Center` inside
/// the tab's `Expanded` region vertically centered the message in all
/// leftover space below the filter row — on a typical phone that reads as
/// floating oddly low, disconnected from the filters right above it. This
/// anchors it just below the filters instead, like the next natural
/// content block. It also fixes a real color-token bug: this file's
/// message text (and, elsewhere in this file, the name/city/visits text)
/// used `AppColors.textPrimary`/`textSecondary` — near-black/dark-brown
/// tokens meant for light surfaces — on `CommunityRankingsScreen`'s dark
/// green canvas, rendering as low-contrast dark-on-dark. `textOnDark`/
/// `secondaryOnDark` are the correct dark-surface counterparts.
class _RankingsMessage extends StatelessWidget {
  final IconData icon;
  final String message;
  const _RankingsMessage({required this.icon, required this.message});

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
        ],
      ),
    ),
  );
}

// ── Community rank card ───────────────────────────────────────────────────────

class _CommunityRankCard extends StatelessWidget {
  final CommunityRankingEntry entry;
  final int rank;
  final VoidCallback onTap;
  const _CommunityRankCard({
    required this.entry,
    required this.rank,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label:
          '#$rank, ${entry.name}, ${entry.city}. Community rating '
          '${entry.communityRating.toStringAsFixed(1)}.',
      excludeSemantics: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: _cardContent(),
        ),
      ),
    );
  }

  Widget _cardContent() {
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
                    // Responsiveness pass: this was a bare Text — with no
                    // Flexible/ellipsis, a 2-3 star restaurant with a
                    // flag+city combination could exceed the row's
                    // available width (confirmed via a 320px widget test:
                    // 2 stars + "🇫🇷  Paris" overflowed by 19px). Flexible
                    // + maxLines/overflow matches every other name/city
                    // row in this codebase (e.g. explore_discovery_cards
                    // .dart, community_screen.dart's Hottest Places card).
                    Flexible(
                      child: Text(
                        '${entry.countryFlag}  ${entry.city}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          color: AppColors.textSecondary,
                          fontSize: 11,
                        ),
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
