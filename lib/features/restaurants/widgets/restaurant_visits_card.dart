import 'package:flutter/material.dart';
import '../../../core/widgets/venue_visit_row.dart';
import '../../../models/restaurant.dart';
import '../../../models/visit.dart';
import '../../visits/visit_detail_screen.dart';

/// Every logged visit to this restaurant, newest first, each independently
/// tappable into [VisitDetailScreen]. Repeat visits are never merged: a
/// restaurant visited three times shows three rows. UI Consistency Step 1:
/// reskinned onto the shared [VenueVisitRow]/[VenueVisitStatusRow] — same
/// behavior, no longer its own bespoke card styling.
class RestaurantVisitsCard extends StatelessWidget {
  final bool isAuthenticated;
  final bool loading;
  final List<Visit> visits;
  final Restaurant restaurant;
  final String signInMessage;

  // Called after returning from VisitDetailScreen, regardless of what
  // happened there — covers a deleted visit just as much as a no-op back
  // tap; a harmless extra refresh either way.
  final VoidCallback onReturn;

  const RestaurantVisitsCard({
    super.key,
    required this.isAuthenticated,
    required this.loading,
    required this.visits,
    required this.restaurant,
    required this.signInMessage,
    required this.onReturn,
  });

  @override
  Widget build(BuildContext context) {
    if (!isAuthenticated) {
      return VenueVisitStatusRow(
        icon: Icons.lock_outline_rounded,
        message: signInMessage,
      );
    }
    if (loading) {
      return const VenueVisitStatusRow(
        icon: Icons.hourglass_empty_rounded,
        message: 'Checking your visits…',
      );
    }
    if (visits.isEmpty) {
      return const VenueVisitStatusRow(
        icon: Icons.menu_book_outlined,
        message: "You haven't visited this restaurant yet.",
      );
    }

    return Column(
      children: [
        for (var i = 0; i < visits.length; i++) ...[
          if (i > 0) const SizedBox(height: 10),
          VenueVisitRow(
            date: visits[i].visitedOn,
            rating: visits[i].rating,
            subtitle: visits[i].menuType?.label,
            onTap: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => VisitDetailScreen(
                    restaurant: restaurant,
                    visit: visits[i],
                  ),
                ),
              );
              onReturn();
            },
          ),
        ],
      ],
    );
  }
}
