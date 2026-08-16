import 'package:flutter/material.dart';
import '../../../core/widgets/venue_visit_row.dart';
import '../../../models/hotel.dart';
import '../../../models/visit.dart';
import '../../stays/stay_detail_screen.dart';

/// Every logged stay at this hotel, newest first, each independently
/// tappable into [StayDetailScreen]. Repeat stays are never merged: a
/// hotel stayed at three times shows three rows. UI Consistency Step 1:
/// reskinned onto the shared [VenueVisitRow]/[VenueVisitStatusRow], mirrors
/// [RestaurantVisitsCard] (no menu-type subtitle — hotels have none).
class HotelStaysCard extends StatelessWidget {
  final bool isAuthenticated;
  final bool loading;
  final List<Visit> stays;
  final Hotel hotel;
  final String signInMessage;

  // Called after returning from StayDetailScreen, regardless of what
  // happened there — covers a deleted stay just as much as a no-op back
  // tap; a harmless extra refresh either way.
  final VoidCallback onReturn;

  const HotelStaysCard({
    super.key,
    required this.isAuthenticated,
    required this.loading,
    required this.stays,
    required this.hotel,
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
        message: 'Checking your stays…',
      );
    }
    if (stays.isEmpty) {
      return const VenueVisitStatusRow(
        icon: Icons.hotel_outlined,
        message: "You haven't stayed at this hotel yet.",
      );
    }

    return Column(
      children: [
        for (var i = 0; i < stays.length; i++) ...[
          if (i > 0) const SizedBox(height: 10),
          VenueVisitRow(
            date: stays[i].visitedOn,
            rating: stays[i].rating,
            onTap: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      StayDetailScreen(hotel: hotel, stay: stays[i]),
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
