import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/analytics/analytics_properties.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/navigation/route_observer.dart';
import '../../../core/theme/cs_spacing.dart';
import '../../../core/theme/cs_surface_context.dart';
import '../../../core/theme/cs_typography.dart';
import '../../../core/utils/visit_years.dart';
import '../../../core/widgets/cs_filter_chip.dart';
import '../../../core/widgets/cs_primary_button.dart' show CsSecondaryButton;
import '../../../core/widgets/year_filter_control.dart';
import '../../../data/repositories/country_lookup.dart';
import '../../../data/repositories/event_confirmed_attendance_repository.dart';
import '../../../data/repositories/visited_repository.dart';
import '../../../models/hotel.dart';
import '../../../models/passport_venue.dart';
import '../../../models/restaurant.dart';
import '../../../models/venue_entry.dart';
import '../../events/event_detail_screen.dart';
import '../../explore/explore_screen.dart';
import '../../explore/models/explore_filters.dart' show ExploreVenueType;
import '../../hotels/hotel_detail_screen.dart';
import '../../restaurants/restaurant_detail_screen.dart';
import '../models/passport_stamp_item.dart';
import '../passport_filter_type.dart';
import '../passport_stamp_source.dart';
import '../passport_view_model.dart';
import 'passport_empty_state.dart';
import 'passport_page_view.dart';
import 'passport_stamp_stats_row.dart';

/// Passport's default "Passport" subsection content: entity filter, time
/// filter, the stats row, and — since the ink-stamp redesign — a
/// paginated [PassportPageView] instead of a flat list of venue/event
/// cards. Extracted from what used to be [PassportScreen]'s entire body;
/// the header and Passport/Wishlist/Ranking/Trips tab bar live once,
/// persistently, in the shared shell above this widget.
///
/// STAMP REDESIGN — what changed vs. the previous card-based list:
/// - Each stamp is now one VISIT/STAY/confirmed attendance, not one
///   deduplicated venue (see passport_stamp_source.dart's own doc
///   comment) — a place visited three times now shows three stamps.
/// - Events participate in the same paginated stamp page as Restaurants/
///   Hotels (the filter chips still show exactly one type at a time,
///   unchanged) rather than their own separate card list.
/// - The wishlist bookmark toggle the previous restaurant/hotel cards
///   carried is gone — a real stamp has no such affordance, and the
///   design spec for this redesign doesn't call for one. `WishlistRepository`
///   is no longer touched by this widget as a result.
/// - The "YOUR COLLECTION" section title is gone — each stamp page now
///   carries its own "ENTRIES · X" / "p. NN" header, making a second,
///   plain-text heading above it redundant.
class PassportCollectionBody extends StatefulWidget {
  const PassportCollectionBody({super.key});

  @override
  State<PassportCollectionBody> createState() => _PassportCollectionBodyState();
}

class _PassportCollectionBodyState extends State<PassportCollectionBody>
    with RouteAware {
  late final VisitedRepository _repo = VisitedRepository(
    Supabase.instance.client,
  );
  late final EventConfirmedAttendanceRepository _eventAttendanceRepo =
      EventConfirmedAttendanceRepository(Supabase.instance.client);

  List<VenueEntry>? _entries; // null until the first load completes.
  List<EventAttendanceEntry> _eventEntries = [];
  Map<String, String> _countryNameByCode = {};

  // Stamp-animation bookkeeping: every visit/stay/attendance id seen as of
  // the last completed load, and — once at least one prior load has
  // happened — the ids that are new since then. The very first load of
  // the app session never has anything to diff against, so it never
  // animates anything (see _load's own comment).
  Set<String> _knownStampIds = {};
  Set<String> _newStampIds = {};
  bool _hasLoadedOnce = false;

  bool _loading = true; // true only for the very first, blocking load.
  bool _loadError = false; // Restaurant/Hotel load failure only.
  bool _refreshing = false; // guards overlapping refresh calls.

  PassportFilterType _filterType = PassportFilterType.restaurants;
  int? _selectedYear; // null = "All time", the default.

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route is PageRoute) {
      appRouteObserver.subscribe(this, route);
    }
  }

  @override
  void dispose() {
    appRouteObserver.unsubscribe(this);
    super.dispose();
  }

  @override
  void didPopNext() => _load();

  Set<String> _allStampIds(
    List<VenueEntry> entries,
    List<EventAttendanceEntry> eventEntries,
  ) {
    final ids = <String>{};
    for (final entry in entries) {
      for (final visit in entry.visits) {
        ids.add(visit.id);
      }
    }
    for (final entry in eventEntries) {
      ids.add(entry.attendance.id);
    }
    return ids;
  }

  Future<void> _load() async {
    if (_refreshing) return;
    _refreshing = true;
    try {
      final uid = Supabase.instance.client.auth.currentUser?.id ?? '';
      final entries = await _repo.loadPassportVenues(uid);
      var eventEntries = <EventAttendanceEntry>[];
      try {
        eventEntries = await _eventAttendanceRepo.loadPassportEventAttendance(
          uid,
        );
      } catch (_) {
        // Never fails the rest of Passport — see _eventEntries' own field.
      }
      var countryNameByCode = <String, String>{};
      try {
        final countries = await getAllCountries(Supabase.instance.client);
        countryNameByCode = {for (final c in countries) c.code: c.name};
      } catch (_) {
        // Never fails the rest of Passport — stamp semantics labels fall
        // back to the bare country code (see stampSemanticLabel).
      }
      if (!mounted) return;

      final allIds = _allStampIds(entries, eventEntries);
      final newIds = _hasLoadedOnce
          ? allIds.difference(_knownStampIds)
          : <String>{};

      final venueYears = availableVisitYears(
        entries.expand((entry) => entry.visits),
      );
      final eventYears = availableEventAttendanceYears(eventEntries);
      setState(() {
        _entries = entries;
        _eventEntries = eventEntries;
        _countryNameByCode = countryNameByCode;
        _newStampIds = newIds;
        _knownStampIds = allIds;
        _hasLoadedOnce = true;
        _loading = false;
        _loadError = false;
        final currentYears = _filterType == PassportFilterType.events
            ? eventYears
            : venueYears;
        if (_selectedYear != null && !currentYears.contains(_selectedYear)) {
          _selectedYear = null;
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError = _entries == null;
      });
    } finally {
      _refreshing = false;
    }
  }

  bool get _isHotel => _filterType == PassportFilterType.hotels;

  bool _matchesVenueType(PassportVenue venue) =>
      _isHotel ? venue is HotelVenue : venue is RestaurantVenue;

  String _venueEmptyMessage(List<VenueEntry> allEntries) {
    final hasAnyHistoryForType = allEntries.any(
      (e) => _matchesVenueType(e.venue),
    );
    if (!hasAnyHistoryForType) {
      return _isHotel ? 'No hotel stays yet.' : 'No restaurant visits yet.';
    }
    return _isHotel
        ? 'No hotel stays in $_selectedYear.'
        : 'No restaurant visits in $_selectedYear.';
  }

  String _eventEmptyMessage(List<EventAttendanceEntry> allEventEntries) {
    if (allEventEntries.isEmpty) return 'No events in your Passport yet.';
    return 'No events in your Passport in $_selectedYear.';
  }

  static const _filterIcons = {
    PassportFilterType.restaurants: Icons.restaurant_outlined,
    PassportFilterType.hotels: Icons.bed_outlined,
    PassportFilterType.events: Icons.confirmation_number_outlined,
  };

  void _openRestaurant(Restaurant restaurant) => Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => RestaurantDetailScreen(restaurant: restaurant),
    ),
  );

  void _openHotel(Hotel hotel) => Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => HotelDetailScreen(hotel: hotel)),
  );

  void _openEvent(String eventId) => Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => EventDetailScreen(
        eventId: eventId,
        sourceSurface: AnalyticsSourceSurface.passport,
      ),
    ),
  );

  void _openExplore() => Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => const ExploreScreen()),
  );

  void _onTapStamp(PassportStampItem item) => switch (item) {
    RestaurantStampItem(:final restaurant) => _openRestaurant(restaurant),
    HotelStampItem(:final hotel) => _openHotel(hotel),
    EventStampItem(:final entry) => _openEvent(entry.event.id),
  };

  @override
  Widget build(BuildContext context) {
    final allEntries = _entries ?? [];
    final isEvents = _filterType == PassportFilterType.events;

    final years = isEvents
        ? availableEventAttendanceYears(_eventEntries)
        : availableVisitYears(allEntries.expand((entry) => entry.visits));

    final restaurantOrHotel = _isHotel
        ? ExploreVenueType.hotels
        : ExploreVenueType.restaurants;
    final venueResult = isEvents
        ? null
        : PassportFilterResult.of(
            allEntries,
            venueType: restaurantOrHotel,
            year: _selectedYear,
          );
    final stampItems = isEvents
        ? buildEventStampItems(_eventEntries, year: _selectedYear)
        : _isHotel
        ? buildHotelStampItems(allEntries, year: _selectedYear)
        : buildRestaurantStampItems(allEntries, year: _selectedYear);

    final headerLabel = 'ENTRIES · ${_filterType.label.toUpperCase()}';

    return ColoredBox(
      color: AppColors.deepGreen,
      child: RefreshIndicator(
        color: AppColors.textOnDark,
        backgroundColor: AppColors.forestGreen,
        onRefresh: _load,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  CsSpacing.pageHorizontal,
                  CsSpacing.md,
                  CsSpacing.pageHorizontal,
                  0,
                ),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (final type in PassportFilterType.values) ...[
                        if (type != PassportFilterType.values.first)
                          const SizedBox(width: CsSpacing.sm),
                        CsFilterChip(
                          label: type.label,
                          icon: _filterIcons[type],
                          selected: _filterType == type,
                          onTap: () => setState(() {
                            _filterType = type;
                            final newYears = type == PassportFilterType.events
                                ? availableEventAttendanceYears(_eventEntries)
                                : availableVisitYears(
                                    allEntries.expand((e) => e.visits),
                                  );
                            if (_selectedYear != null &&
                                !newYears.contains(_selectedYear)) {
                              _selectedYear = null;
                            }
                          }),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            if (years.isNotEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    CsSpacing.pageHorizontal,
                    CsSpacing.md,
                    CsSpacing.pageHorizontal,
                    0,
                  ),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: YearFilterControl(
                      years: years,
                      selectedYear: _selectedYear,
                      onSelect: (year) => setState(() => _selectedYear = year),
                      surface: CsSurface.dark,
                    ),
                  ),
                ),
              ),
            if (venueResult != null)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    CsSpacing.pageHorizontal,
                    CsSpacing.lg,
                    CsSpacing.pageHorizontal,
                    0,
                  ),
                  child: PassportStampStatsRow(
                    stats: [
                      PassportStampStat(
                        value: '${venueResult.summary.placesVisited}',
                        label: PassportMetricLabels.forVenueType(
                          restaurantOrHotel,
                        ).visited,
                      ),
                      PassportStampStat(
                        value: '${venueResult.summary.countriesVisited}',
                        label: 'COUNTRIES',
                      ),
                      PassportStampStat(
                        value: '${venueResult.summary.awardsExperienced}',
                        label: PassportMetricLabels.forVenueType(
                          restaurantOrHotel,
                        ).awards,
                        gold: true,
                      ),
                    ],
                  ),
                ),
              ),
            if (_loading)
              const SliverFillRemaining(
                child: Center(
                  child: CircularProgressIndicator(
                    color: AppColors.textOnDark,
                    strokeWidth: 1.5,
                  ),
                ),
              )
            else if (_loadError)
              SliverFillRemaining(child: _ErrorState(onRetry: _load))
            else if (stampItems.isEmpty)
              SliverFillRemaining(
                child: PassportEmptyState(
                  message: isEvents
                      ? _eventEmptyMessage(_eventEntries)
                      : _venueEmptyMessage(allEntries),
                ),
              )
            else
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    0,
                    CsSpacing.xl,
                    0,
                    100,
                  ),
                  child: PassportPageView(
                    pages: paginateStamps(stampItems),
                    headerLabel: headerLabel,
                    countryNameByCode: _countryNameByCode,
                    newStampIds: _newStampIds,
                    onTapStamp: _onTapStamp,
                    onTapNextStamp: _openExplore,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final VoidCallback onRetry;
  const _ErrorState({required this.onRetry});

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(
          Icons.wifi_off_rounded,
          color: AppColors.secondaryOnDark,
          size: 40,
        ),
        const SizedBox(height: CsSpacing.base),
        Text(
          'Could not load data',
          style: CsTypography.body.copyWith(color: AppColors.secondaryOnDark),
        ),
        const SizedBox(height: CsSpacing.md),
        SizedBox(
          width: 160,
          child: CsSecondaryButton(label: 'Retry', onTap: onRetry, height: 44),
        ),
      ],
    ),
  );
}
