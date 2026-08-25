import 'package:flutter/material.dart';
import '../../../core/widgets/star_row.dart';
import '../../../models/ranking_entry.dart';
import '../../../models/restaurant.dart';
import '../../restaurants/restaurant_detail_screen.dart';
import 'ranking_editorial_card.dart';

// "City 🇳🇱" — the same city + flag pairing this card has always shown
// (unchanged from before this visual pass), matching the reference's
// city-line, not Passport's own "City, Country" collection-card format.
String _locationLabel(Restaurant restaurant) =>
    '${restaurant.cityName} ${restaurant.flagEmoji}'.trim();

/// One unique restaurant's row in "My Rankings": rank, identity, current
/// Michelin stars (context only — never part of computing the ranking),
/// and the selected dimension's average with how many visits contributed
/// to it. Tapping opens the existing RestaurantDetailScreen — no separate
/// ranking-detail screen. [onReturn] fires once that screen is popped, so a
/// visit saved there (or a repeat visit added to the same restaurant) is
/// reflected in the ranking immediately, without leaving and reopening it.
///
/// PASSPORT — RANKING UI REDESIGN V1: visual presentation now delegates to
/// [RankingEditorialCard] (the reference's dark editorial row) — every
/// value shown (rank, name, city, stars, score, visit count) is still read
/// straight from [restaurant]/[entry]/[rank], unchanged from before this
/// pass.
class PersonalRankingCard extends StatelessWidget {
  final Restaurant restaurant;
  final PersonalRankingEntry entry;
  final int rank;
  final VoidCallback onReturn;

  const PersonalRankingCard({
    super.key,
    required this.restaurant,
    required this.entry,
    required this.rank,
    required this.onReturn,
  });

  @override
  Widget build(BuildContext context) {
    return RankingEditorialCard(
      rank: rank,
      imageUrl: null,
      title: restaurant.name,
      subtitle: _locationLabel(restaurant),
      recognition: restaurant.hasMichelinStar
          ? StarRow(count: restaurant.michelinStars!, size: 12)
          : null,
      scoreText: entry.averageScore.toStringAsFixed(1),
      visitText: entry.ratedVisitCount == 1
          ? '1 visit'
          : '${entry.ratedVisitCount} visits',
      onTap: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => RestaurantDetailScreen(restaurant: restaurant),
          ),
        );
        onReturn();
      },
    );
  }
}
