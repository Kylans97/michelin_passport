import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/cs_spacing.dart';
import '../../../core/theme/cs_typography.dart';
import '../../../core/widgets/cs_filter_chip.dart';
import '../../../core/widgets/key_row.dart';
import '../../../core/widgets/star_row.dart';
import '../../../data/repositories/hotel_repository.dart';
import '../../../data/repositories/rankings_repository.dart';
import '../../../data/repositories/restaurant_repository.dart';
import '../../../models/hotel.dart';
import '../../../models/ranking_entry.dart';
import '../../../models/restaurant.dart';
import '../../events/event_detail_screen.dart';
import '../../hotels/hotel_detail_screen.dart';
import '../../restaurants/restaurant_detail_screen.dart';
import 'ranking_editorial_card.dart';

/// Community Rankings: what members score highest, across restaurants,
/// hotels and events — unrelated to "My Rankings" and its own data source.
///
/// Redesigned 2026-10-30 (product owner): it used to cover restaurants
/// only, filtered by star count. Now one row of kinds (Restaurants · Hotels
/// · Events) and, for restaurants and hotels, one recognition filter — the
/// MICHELIN stars or Keys, or The World's 50 Best — so a venue ranked
/// beyond stars is reachable too. Each row is the ivory
/// [RankingEditorialCard] My Rankings uses; gold appears only in the stars
/// and Keys themselves.
///
/// Scores are the overall score members give a visit, stay or confirmed
/// event — each member's latest per venue — averaged in the
/// restaurant_rankings / hotel_rankings / event_rankings views, which
/// return only aggregates and only from 3 members.
///
/// [loadRanking], [getRestaurantById] and [getHotelById] are injectable so
/// the real widget can be pumped in tests without Supabase; each defaults
/// to the real repository against `Supabase.instance.client`.
class CommunityRankingsTab extends StatefulWidget {
  final Future<List<CommunityRankedVenue>> Function(
    CommunityRankingKind kind,
    CommunityRecognitionFilter filter,
  )?
  loadRanking;
  final Future<Restaurant?> Function(String id)? getRestaurantById;
  final Future<Hotel?> Function(String id)? getHotelById;

  const CommunityRankingsTab({
    super.key,
    this.loadRanking,
    this.getRestaurantById,
    this.getHotelById,
  });

  @override
  State<CommunityRankingsTab> createState() => _CommunityRankingsTabState();
}

/// The recognition filter's chip label for [kind] — stars for restaurants,
/// Keys for hotels.
String recognitionFilterLabel(
  CommunityRankingKind kind,
  CommunityRecognitionFilter filter,
) => switch ((kind, filter)) {
  (_, CommunityRecognitionFilter.all) => 'All',
  (_, CommunityRecognitionFilter.worlds50Best) => "World's 50 Best",
  (CommunityRankingKind.hotels, CommunityRecognitionFilter.one) => '1 Key',
  (CommunityRankingKind.hotels, CommunityRecognitionFilter.two) => '2 Keys',
  (CommunityRankingKind.hotels, CommunityRecognitionFilter.three) => '3 Keys',
  (_, CommunityRecognitionFilter.one) => '★',
  (_, CommunityRecognitionFilter.two) => '★★',
  (_, CommunityRecognitionFilter.three) => '★★★',
};

class _CommunityRankingsTabState extends State<CommunityRankingsTab> {
  CommunityRankingKind _kind = CommunityRankingKind.restaurants;
  CommunityRecognitionFilter _filter = CommunityRecognitionFilter.all;
  late Future<List<CommunityRankedVenue>> _future;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    setState(() {
      final load =
          widget.loadRanking ??
          (kind, filter) => RankingsRepository(
            Supabase.instance.client,
          ).getCommunityRanking(kind: kind, filter: filter);
      _future = load(_kind, _filter);
    });
  }

  void _selectKind(CommunityRankingKind kind) {
    if (kind == _kind) return;
    _kind = kind;
    _filter = CommunityRecognitionFilter.all;
    _load();
  }

  void _selectFilter(CommunityRecognitionFilter filter) {
    if (filter == _filter) return;
    _filter = filter;
    _load();
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
  Widget build(BuildContext context) {
    final hasRecognition = _kind != CommunityRankingKind.events;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ChipRow(
          padding: const EdgeInsets.fromLTRB(
            CsSpacing.pageHorizontal,
            CsSpacing.base,
            CsSpacing.pageHorizontal,
            0,
          ),
          children: [
            for (final kind in CommunityRankingKind.values)
              CsFilterChip(
                label: kind.label,
                selected: _kind == kind,
                onTap: () => _selectKind(kind),
              ),
          ],
        ),
        if (hasRecognition)
          _ChipRow(
            padding: const EdgeInsets.fromLTRB(
              CsSpacing.pageHorizontal,
              CsSpacing.sm,
              CsSpacing.pageHorizontal,
              0,
            ),
            children: [
              for (final filter in CommunityRecognitionFilter.values)
                _RecognitionChip(
                  label: recognitionFilterLabel(_kind, filter),
                  selected: _filter == filter,
                  onTap: () => _selectFilter(filter),
                ),
            ],
          ),
        Expanded(
          child: FutureBuilder<List<CommunityRankedVenue>>(
            future: _future,
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(
                    color: AppColors.ivory,
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
                padding: const EdgeInsets.fromLTRB(
                  CsSpacing.pageHorizontal,
                  CsSpacing.base,
                  CsSpacing.pageHorizontal,
                  100,
                ),
                itemCount: entries.length,
                itemBuilder: (_, i) => _CommunityRankCard(
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
}

class _ChipRow extends StatelessWidget {
  final EdgeInsets padding;
  final List<Widget> children;
  const _ChipRow({required this.padding, required this.children});

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    padding: padding,
    child: Row(
      children: [
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0) const SizedBox(width: CsSpacing.sm),
          children[i],
        ],
      ],
    ),
  );
}

/// The quieter second row: text-only, ivory when selected, so the kind
/// chips above stay the primary choice.
class _RecognitionChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _RecognitionChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: selected,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(CsRadius.small),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
        child: Text(
          label,
          style: CsTypography.metadata.copyWith(
            color: selected ? AppColors.ivory : AppColors.secondaryOnDark,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            decoration: selected ? TextDecoration.underline : null,
            decorationColor: AppColors.ivory,
          ),
        ),
      ),
    ),
  );
}

// ── Empty / error message ───────────────────────────────────────────────────

/// Anchored just below the filters (not floating in the middle of the
/// leftover space), in `secondaryOnDark` — the dark-surface token, never
/// the light-surface `textSecondary`, on this deep-green canvas.
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

/// One ranked venue or event as the ivory [RankingEditorialCard]: rank on
/// the image, name, stars or Keys (the only gold) plus a World's 50 Best
/// rank when there is one, city (and an event's date), then the community
/// score and how many members it rests on.
class _CommunityRankCard extends StatelessWidget {
  final CommunityRankedVenue entry;
  final int rank;
  final VoidCallback onTap;
  const _CommunityRankCard({
    required this.entry,
    required this.rank,
    required this.onTap,
  });

  String get _subtitle {
    final place = [
      if (entry.countryFlag.isNotEmpty) entry.countryFlag,
      entry.city,
    ].where((s) => s.isNotEmpty).join('  ');
    final start = entry.startDate;
    if (start == null) return place;
    final date = '${start.day} ${_months[start.month - 1]} ${start.year}';
    return place.isEmpty ? date : '$place · $date';
  }

  Widget? get _recognition {
    final stars = entry.stars ?? 0;
    final keys = entry.keys ?? 0;
    final w50b = entry.worlds50BestRank;
    final parts = <Widget>[
      if (stars > 0) StarRow(count: stars, size: 12),
      if (keys > 0) KeyRow(count: keys, size: 12),
      if (w50b != null)
        Text(
          '50 Best #$w50b',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: CsTypography.metadata.copyWith(
            color: AppColors.taupe,
            fontSize: 12,
          ),
        ),
    ];
    if (parts.isEmpty) return null;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < parts.length; i++) ...[
          if (i > 0) const SizedBox(width: CsSpacing.xs),
          if (parts[i] is Text) Flexible(child: parts[i]) else parts[i],
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label:
        '#$rank, ${entry.name}, ${entry.city}. Community rating '
        '${entry.communityRating.toStringAsFixed(1)}.',
    excludeSemantics: true,
    child: RankingEditorialCard(
      rank: rank,
      imageUrl: entry.imageUrl,
      imageFraming: entry.imageFraming,
      title: entry.name,
      subtitle: _subtitle,
      recognition: _recognition,
      scoreText: entry.communityRating.toStringAsFixed(1),
      visitText: entry.memberCount == 1
          ? '1 member'
          : '${entry.memberCount} members',
      onTap: onTap,
    ),
  );
}
