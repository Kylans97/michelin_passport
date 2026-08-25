import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/theme/cs_spacing.dart';
import '../../core/theme/cs_typography.dart';
import '../../core/widgets/editorial_back_button.dart';
import '../../models/planned_trip.dart';
import 'trip_detail_screen.dart';
import 'widgets/trip_card.dart';

/// One upcoming trip plus its already-resolved venue counts — precomputed
/// by [TripsBody] (which already groups [ResolvedPlannedVenue] by trip)
/// rather than making this screen re-derive them or re-query anything of
/// its own.
typedef UpcomingTripSummary = ({
  PlannedTrip trip,
  int restaurantCount,
  int hotelCount,
});

/// TRIPS HERO REDESIGN — a simple, full list of every upcoming trip,
/// reached only via the "N more trips →" link on the Trips subsection's
/// featured [TripHeroCard]. A normal pushed screen with its own back
/// arrow, exactly like [TripDetailScreen] — the "same page" rule applies
/// only to Passport's own four local subsections, never to deeper
/// navigation reached from within one of them.
///
/// Reuses [TripCard] unchanged — the same row shape the Trips subsection
/// itself used for every upcoming trip before this pass — since this
/// screen exists purely to hold the trips the featured hero card doesn't
/// have room to show individually, not a new card design of its own.
class AllUpcomingTripsScreen extends StatelessWidget {
  final List<UpcomingTripSummary> trips;

  const AllUpcomingTripsScreen({super.key, required this.trips});

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.deepGreen,
    body: Column(
      children: [
        SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              CsSpacing.base,
              CsSpacing.sm,
              CsSpacing.base,
              CsSpacing.lg,
            ),
            child: Row(
              children: [
                const EditorialBackButton(),
                const SizedBox(width: CsSpacing.md),
                Expanded(
                  child: Text(
                    'Upcoming trips',
                    style: CsTypography.sectionTitle.copyWith(
                      color: AppColors.textOnDark,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(
              CsSpacing.pageHorizontal,
              0,
              CsSpacing.pageHorizontal,
              CsSpacing.section,
            ),
            itemCount: trips.length,
            itemBuilder: (context, i) => Padding(
              padding: EdgeInsets.only(
                bottom: i == trips.length - 1 ? 0 : CsSpacing.md,
              ),
              child: TripCard(
                trip: trips[i].trip,
                restaurantCount: trips[i].restaurantCount,
                hotelCount: trips[i].hotelCount,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => TripDetailScreen(trip: trips[i].trip),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}
