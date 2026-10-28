import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants/app_colors.dart';
import '../../core/theme/cs_spacing.dart';
import '../../core/theme/cs_typography.dart';
import '../../data/repositories/events_repository.dart';
import '../../models/event.dart';
import '../../models/managed_venue.dart';
import '../events/event_detail_screen.dart';
import '../events/widgets/hosted_events_section.dart';

/// The upcoming events this venue hosts.
///
/// Shown from a venue's landing page (VenueManagementScreen), venue
/// events plan phase 2. These are the same events the venue's public
/// page lists (EventsRepository.loadHostedEventsFor*: `is_host`, published,
/// not cancelled, not ended), so a manager sees exactly what visitors
/// see. Read-only for now: creating and editing events from here is
/// phase 3 (`submit_venue_event`), and is deliberately not scaffolded
/// here, not even as a disabled button.
class VenueEventsScreen extends StatefulWidget {
  final ManagedVenue venue;
  final EventsRepository? eventsRepo;

  const VenueEventsScreen({super.key, required this.venue, this.eventsRepo});

  /// The hosted-events loader for [venue]'s own type — shared with the
  /// landing page's Events summary so both read the same list.
  static Future<List<Event>> loadFor(
    ManagedVenue venue,
    EventsRepository repo,
  ) => switch (venue) {
    ManagedRestaurant() => repo.loadHostedEventsForRestaurant(venue.id),
    ManagedHotel() => repo.loadHostedEventsForHotel(venue.id),
    ManagedPrivateChef() => repo.loadHostedEventsForChef(venue.id),
  };

  @override
  State<VenueEventsScreen> createState() => _VenueEventsScreenState();
}

class _VenueEventsScreenState extends State<VenueEventsScreen> {
  late final _eventsRepo =
      widget.eventsRepo ?? EventsRepository(Supabase.instance.client);
  late Future<List<Event>> _future;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    setState(() {
      _future = VenueEventsScreen.loadFor(widget.venue, _eventsRepo);
    });
  }

  void _openEvent(Event event) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => EventDetailScreen(eventId: event.id)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.warmWhite,
      appBar: AppBar(
        title: Text(
          'Events',
          style: CsTypography.placeTitle.copyWith(
            color: AppColors.forestGreen,
            fontSize: 20,
          ),
        ),
        backgroundColor: AppColors.warmWhite,
        surfaceTintColor: Colors.transparent,
        iconTheme: const IconThemeData(color: AppColors.forestGreen),
      ),
      body: FutureBuilder<List<Event>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting &&
              !snap.hasData) {
            return const Center(
              child: CircularProgressIndicator(
                color: AppColors.forestGreen,
                strokeWidth: 1.5,
              ),
            );
          }
          return RefreshIndicator(
            color: AppColors.forestGreen,
            backgroundColor: AppColors.warmWhite,
            onRefresh: () async => _load(),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(
                horizontal: CsSpacing.pageHorizontal,
                vertical: CsSpacing.md,
              ),
              children: [
                if (snap.hasError)
                  Text(
                    'Could not load events. Pull down to try again.',
                    style: CsTypography.body.copyWith(color: AppColors.taupe),
                  )
                else if (snap.data!.isEmpty)
                  Text(
                    'No upcoming events at ${widget.venue.name}.',
                    style: CsTypography.body.copyWith(color: AppColors.taupe),
                  )
                else
                  HostedEventsSection(
                    events: snap.data!,
                    onTapEvent: _openEvent,
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}
