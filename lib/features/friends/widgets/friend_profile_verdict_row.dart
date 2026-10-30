import 'package:flutter/material.dart';
import '../../../core/widgets/key_row.dart';
import '../../../core/widgets/star_row.dart';
import '../../../models/passport_venue.dart';
import '../../../models/photo_framing.dart';
import '../../rankings/widgets/ranking_editorial_card.dart';
import '../friend_profile_data.dart';
import '../friend_profile_screen.dart' show FriendVenueVisit;

const _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

/// One friend verdict — the Overview tab's "{NAME}'S VERDICTS" preview and
/// its own "All →" full list share this exact widget, so the two can never
/// drift out of visual sync.
///
/// The same ivory editorial card as My Rankings ([RankingEditorialCard],
/// without a rank) on the deep-green canvas: photo flush left, name, stars
/// or Keys (the only gold), city, then "8/10 · Visited 23 Sep" in forest
/// green and taupe. Replaces the earlier dark tile with a gold border and
/// a 40pt score numeral (2026-10-30), which read unlike the rest of the
/// app.
class FriendVerdictRow extends StatelessWidget {
  final FriendVenueVisit visit;
  final String? photoUrl;
  final VoidCallback onTap;

  const FriendVerdictRow({
    super.key,
    required this.visit,
    required this.photoUrl,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isHotel = visit.venue is HotelVenue;
    final date = visit.visit.visitedOn;
    // Year only when it isn't this year — the line has to fit next to
    // the score on a phone.
    final dateLabel = date.year == DateTime.now().year
        ? '${date.day} ${_months[date.month - 1]}'
        : '${date.day} ${_months[date.month - 1]} ${date.year}';
    final stars = visit.stars ?? 0;
    final keys = visit.keys ?? 0;

    return RankingEditorialCard(
      imageUrl: photoUrl ?? visit.venue.cardImageUrl,
      imageFraming: photoUrl == null
          ? visit.venue.cardFraming
          : PhotoFraming.center,
      title: visit.venue.name,
      subtitle: visit.cityName,
      recognition: !isHotel && stars > 0
          ? StarRow(count: stars, size: 12)
          : isHotel && keys > 0
          ? KeyRow(count: keys, size: 12)
          : null,
      scoreText: visit.score == null ? null : '${visit.score}/10',
      visitText: isHotel ? 'Stayed $dateLabel' : 'Visited $dateLabel',
      onTap: onTap,
    );
  }
}
