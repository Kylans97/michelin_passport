import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/analytics/analytics_properties.dart';
import '../../core/constants/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../data/repositories/events_repository.dart';
import '../../models/event.dart';
import '../../models/venue_country.dart';
import 'event_detail_screen.dart';
import 'models/event_date_filter.dart';
import 'widgets/event_card.dart';
import 'widgets/event_filter_bar.dart';

/// Culinary Events discovery — standalone events, multi-venue events,
/// festivals, tastings. Country + date filtering; city stays in the data
/// model (see Event) without a prominent UI control yet, per the task's
/// explicit "can become visible later" instruction.
class EventsScreen extends StatefulWidget {
  const EventsScreen({super.key});

  @override
  State<EventsScreen> createState() => _EventsScreenState();
}

class _EventsScreenState extends State<EventsScreen> {
  late final EventsRepository _repo = EventsRepository(
    Supabase.instance.client,
  );

  final _searchCtrl = TextEditingController();
  String _query = '';

  EventDateFilter _dateFilter = EventDateFilter(
    mode: EventDateFilterMode.upcoming,
  );
  VenueCountry? _country;

  late Future<List<Event>> _eventsFuture;
  late final Future<List<VenueCountry>> _countriesFuture = _repo.getCountries();

  @override
  void initState() {
    super.initState();
    _eventsFuture = _fetchEvents();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<List<Event>> _fetchEvents() {
    final (from, to) = _dateFilter.resolve();
    return _repo.loadEvents(
      from: from,
      to: to,
      countryCode: _country?.code,
      query: _query,
    );
  }

  void _reload() => setState(() => _eventsFuture = _fetchEvents());

  void _openEvent(Event event) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EventDetailScreen(
          eventId: event.id,
          sourceSurface: AnalyticsSourceSurface.eventsFeed,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Event>>(
      future: _eventsFuture,
      builder: (context, snap) {
        final events = snap.data ?? [];
        final loading = snap.connectionState == ConnectionState.waiting;

        return Scaffold(
          // The root cause of the reported "black background": this screen
          // used to return its CustomScrollView with no enclosing Scaffold
          // at all, so there was no opaque backdrop and the route rendered
          // whatever the default canvas is behind bare slivers — Material's
          // black default. Deep green (matching the hero above) instead of
          // AppColors.background's ivory is a deliberate choice for this
          // screen specifically, not a bug — Events reads as a chrome-first
          // discovery surface (event cards already carry their own
          // off-white AppColors.card background), same relationship
          // DetailHero screens have to their content below.
          backgroundColor: AppColors.brandGreen,
          body: RefreshIndicator(
            color: AppColors.gold,
            backgroundColor: AppColors.card,
            onRefresh: () async => _reload(),
            child: CustomScrollView(
              slivers: [
                SliverAppBar(
                  pinned: true,
                  backgroundColor: AppColors.brandGreen,
                  foregroundColor: AppColors.textOnDark,
                  toolbarHeight: 76,
                  title: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Events',
                        style: AppTypography.editorialHeading.copyWith(
                          color: AppColors.textOnDark,
                          fontSize: 22,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Culinary happenings worth planning a trip around',
                        style: AppTypography.metadata.copyWith(
                          color: AppColors.textOnDark.withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ),
                  bottom: PreferredSize(
                    preferredSize: Size.fromHeight(
                      _dateFilter.mode == EventDateFilterMode.month ? 224 : 170,
                    ),
                    child: Container(
                      color: AppColors.background,
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 18),
                      child: FutureBuilder<List<VenueCountry>>(
                        future: _countriesFuture,
                        builder: (context, countrySnap) {
                          return EventFilterBar(
                            searchCtrl: _searchCtrl,
                            onQueryChanged: (v) {
                              _query = v;
                              _reload();
                            },
                            dateFilter: _dateFilter,
                            onDateFilterChanged: (filter) {
                              setState(() => _dateFilter = filter);
                              _reload();
                            },
                            country: _country,
                            countries: countrySnap.data ?? [],
                            onCountryChanged: (country) {
                              setState(() => _country = country);
                              _reload();
                            },
                          );
                        },
                      ),
                    ),
                  ),
                ),
                if (snap.hasError)
                  SliverFillRemaining(
                    child: Center(
                      child: Text(
                        'Could not load events',
                        style: GoogleFonts.inter(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  )
                else if (loading)
                  const SliverFillRemaining(
                    child: Center(
                      child: CircularProgressIndicator(
                        color: AppColors.gold,
                        strokeWidth: 1.5,
                      ),
                    ),
                  )
                else if (events.isEmpty)
                  SliverFillRemaining(
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.event_outlined,
                              color: AppColors.textSecondary,
                              size: 44,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No events found',
                              style: GoogleFonts.playfairDisplay(
                                color: AppColors.textSecondary,
                                fontSize: 18,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Try a different date range or country.',
                              style: GoogleFonts.inter(
                                color: AppColors.textSecondary,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                else
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, i) => Padding(
                        padding: EdgeInsets.fromLTRB(
                          20,
                          i == 0 ? 20 : 0,
                          20,
                          i == events.length - 1 ? 100 : 12,
                        ),
                        child: EventCard(
                          event: events[i],
                          onTap: () => _openEvent(events[i]),
                        ),
                      ),
                      childCount: events.length,
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
