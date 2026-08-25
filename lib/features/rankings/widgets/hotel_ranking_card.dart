import 'package:flutter/material.dart';
import '../../../core/widgets/key_row.dart';
import '../../../models/hotel.dart';
import '../../../models/ranking_entry.dart';
import '../../hotels/hotel_detail_screen.dart';
import 'ranking_editorial_card.dart';

// "City 🇬🇧" — the same city + flag pairing this card has always shown.
String _locationLabel(Hotel hotel) =>
    '${hotel.cityName} ${hotel.flagEmoji}'.trim();

/// One unique hotel's row in "My Rankings": rank, identity, current
/// Michelin Keys (context only — never part of computing the ranking, just
/// like current Stars on [PersonalRankingCard]), and the selected
/// dimension's average with how many stays contributed to it. Tapping
/// opens the existing HotelDetailScreen — no separate ranking-detail
/// screen. [onReturn] fires once that screen is popped, so a stay saved
/// there is reflected in the ranking immediately.
///
/// PASSPORT — RANKING UI REDESIGN V1: visual presentation now delegates to
/// [RankingEditorialCard] — same shell as [PersonalRankingCard], with
/// Keys (never Stars) as this card's recognition, matching hotels
/// everywhere else in the app.
class HotelRankingCard extends StatelessWidget {
  final Hotel hotel;
  final PersonalRankingEntry entry;
  final int rank;
  final VoidCallback onReturn;

  const HotelRankingCard({
    super.key,
    required this.hotel,
    required this.entry,
    required this.rank,
    required this.onReturn,
  });

  @override
  Widget build(BuildContext context) {
    return RankingEditorialCard(
      rank: rank,
      imageUrl: null,
      title: hotel.name,
      subtitle: _locationLabel(hotel),
      recognition: hotel.hasMichelinKeys
          ? KeyRow(count: hotel.michelinKeys!, size: 12)
          : null,
      scoreText: entry.averageScore.toStringAsFixed(1),
      visitText: entry.ratedVisitCount == 1
          ? '1 stay'
          : '${entry.ratedVisitCount} stays',
      onTap: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => HotelDetailScreen(hotel: hotel)),
        );
        onReturn();
      },
    );
  }
}
