import 'package:flutter/material.dart';
import '../../../core/widgets/linked_venue_row.dart';
import '../../../core/widgets/star_row.dart';
import '../../../core/widgets/venue_visit_row.dart';
import '../../../models/restaurant.dart';
import '../../restaurants/restaurant_detail_screen.dart';

/// Restaurants linked to this hotel (resolved via
/// HotelRepository.getLinkedRestaurants, off restaurants_full's hotel_id).
/// Each row opens the existing RestaurantDetailScreen — no separate
/// hotel-restaurant detail screen. UI Consistency Step 1: reskinned onto
/// the shared [LinkedVenueRow] — same widget as Restaurant Detail's own
/// "AT THIS HOTEL" row, now used both directions.
class HotelRestaurantsCard extends StatelessWidget {
  final Future<List<Restaurant>> future;
  const HotelRestaurantsCard({super.key, required this.future});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Restaurant>>(
      future: future,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const VenueVisitStatusRow(
            icon: Icons.hourglass_empty_rounded,
            message: 'Loading restaurants…',
          );
        }
        final restaurants = snap.data ?? [];
        if (restaurants.isEmpty) {
          return const VenueVisitStatusRow(
            icon: Icons.info_outline_rounded,
            message: 'Could not load linked restaurants.',
          );
        }
        return Column(
          children: [
            for (var i = 0; i < restaurants.length; i++) ...[
              if (i > 0) const SizedBox(height: 10),
              LinkedVenueRow(
                name: restaurants[i].name,
                recognition: restaurants[i].hasMichelinStar
                    ? StarRow(count: restaurants[i].michelinStars!, size: 11)
                    : null,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        RestaurantDetailScreen(restaurant: restaurants[i]),
                  ),
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}
