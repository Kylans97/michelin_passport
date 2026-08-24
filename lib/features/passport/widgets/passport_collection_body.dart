import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/navigation/route_observer.dart';
import '../../../core/theme/cs_spacing.dart';
import '../../../core/theme/cs_surface_context.dart';
import '../../../core/theme/cs_typography.dart';
import '../../../core/utils/visit_years.dart';
import '../../../core/widgets/cs_filter_chip.dart';
import '../../../core/widgets/cs_primary_button.dart' show CsSecondaryButton;
import '../../../core/widgets/year_filter_control.dart';
import '../../../data/repositories/event_confirmed_attendance_repository.dart';
import '../../../data/repositories/visited_repository.dart';
import '../../../data/repositories/wishlist_repository.dart';
import '../../../models/passport_venue.dart';
import '../../../models/venue_entry.dart';
import '../../explore/models/explore_filters.dart' show ExploreVenueType;
import '../passport_filter_type.dart';
import '../passport_view_model.dart';
import 'passport_collection_header.dart';
import 'passport_empty_state.dart';
import 'passport_event_card.dart';
import 'passport_hotel_card.dart';
import 'passport_restaurant_card.dart';
import 'passport_stats_panel.dart';

/// Passport Unified Experience V1 — the default "Passport" subsection's
/// content: entity filter, time filter, stats panel, and the collection
/// list. Extracted from what used to be [PassportScreen]'s entire body;
/// the header and Passport/Wishlist/Ranking/Trips tab bar now live once,
/// persistently, in the shared shell above this widget. All data-loading
/// and filtering logic is unchanged from before this extraction — only
/// the header/secondary-nav slivers were removed (now owned by the shell)
/// and the entity filter/stats panel were restyled to match the approved
/// visual reference (rounded icon-led filter pills; a bordered, tonal-icon
/// three-column stats panel replacing the previous bare metric strip).
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
  late final WishlistRepository _wishlistRepo = WishlistRepository(
    Supabase.instance.client,
  );

  List<VenueEntry>? _entries; // null until the first load completes.
  List<EventAttendanceEntry> _eventEntries = [];
  // Passport UI Polish V2 — the wishlist membership backing each card's
  // bookmark. Loaded in bulk alongside the main data load (never one
  // query per card); empty by default so a failed/slow wishlist load
  // never blocks or breaks the rest of Passport, it just starts every
  // bookmark unfilled until it resolves.
  Set<String> _wishlistedRestaurantIds = {};
  Set<String> _wishlistedHotelIds = {};
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
      var wishlistedRestaurantIds = <String>{};
      var wishlistedHotelIds = <String>{};
      try {
        wishlistedRestaurantIds = await _wishlistRepo.loadWishlistRestaurantIds(
          uid,
        );
        wishlistedHotelIds = await _wishlistRepo.loadWishlistHotelIds(uid);
      } catch (_) {
        // Never fails the rest of Passport — bookmarks just start unfilled.
      }
      if (!mounted) return;
      final venueYears = availableVisitYears(
        entries.expand((entry) => entry.visits),
      );
      final eventYears = availableEventAttendanceYears(eventEntries);
      setState(() {
        _entries = entries;
        _eventEntries = eventEntries;
        _wishlistedRestaurantIds = wishlistedRestaurantIds;
        _wishlistedHotelIds = wishlistedHotelIds;
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

  // Passport UI Polish V2 — optimistic toggle: flips local membership
  // immediately (so the bookmark responds the instant it's tapped), then
  // persists via the same WishlistRepository.toggleWishlist every other
  // wishlist entry point in the app already uses, and reconciles/reverts
  // if the server's own returned state disagrees or the call fails (e.g.
  // a concurrent toggle from another device).
  Future<void> _toggleRestaurantWishlist(String restaurantId) async {
    final uid = Supabase.instance.client.auth.currentUser?.id ?? '';
    final optimistic = !_wishlistedRestaurantIds.contains(restaurantId);
    setState(() {
      if (optimistic) {
        _wishlistedRestaurantIds.add(restaurantId);
      } else {
        _wishlistedRestaurantIds.remove(restaurantId);
      }
    });
    try {
      final actual = await _wishlistRepo.toggleWishlist(
        userId: uid,
        restaurantId: restaurantId,
      );
      if (!mounted || actual == optimistic) return;
      setState(() {
        if (actual) {
          _wishlistedRestaurantIds.add(restaurantId);
        } else {
          _wishlistedRestaurantIds.remove(restaurantId);
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        if (optimistic) {
          _wishlistedRestaurantIds.remove(restaurantId);
        } else {
          _wishlistedRestaurantIds.add(restaurantId);
        }
      });
    }
  }

  Future<void> _toggleHotelWishlist(String hotelId) async {
    final uid = Supabase.instance.client.auth.currentUser?.id ?? '';
    final optimistic = !_wishlistedHotelIds.contains(hotelId);
    setState(() {
      if (optimistic) {
        _wishlistedHotelIds.add(hotelId);
      } else {
        _wishlistedHotelIds.remove(hotelId);
      }
    });
    try {
      final actual = await _wishlistRepo.toggleHotelWishlist(
        userId: uid,
        hotelId: hotelId,
      );
      if (!mounted || actual == optimistic) return;
      setState(() {
        if (actual) {
          _wishlistedHotelIds.add(hotelId);
        } else {
          _wishlistedHotelIds.remove(hotelId);
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        if (optimistic) {
          _wishlistedHotelIds.remove(hotelId);
        } else {
          _wishlistedHotelIds.add(hotelId);
        }
      });
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
    final result = isEvents
        ? null
        : PassportFilterResult.of(
            allEntries,
            venueType: restaurantOrHotel,
            year: _selectedYear,
          );
    final filteredEventEntries = isEvents
        ? eventAttendanceInYear(_eventEntries, _selectedYear)
        : const <EventAttendanceEntry>[];

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
            if (!isEvents)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    CsSpacing.pageHorizontal,
                    CsSpacing.lg,
                    CsSpacing.pageHorizontal,
                    0,
                  ),
                  child: PassportStatsPanel(
                    stats: [
                      PassportStat(
                        value: '${result!.summary.placesVisited}',
                        label: 'VISITED',
                      ),
                      PassportStat(
                        value: '${result.summary.countriesVisited}',
                        label: 'COUNTRIES',
                      ),
                      PassportStat(
                        value: '${result.summary.awardsExperienced}',
                        label: 'STARS',
                      ),
                    ],
                  ),
                ),
              ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  CsSpacing.pageHorizontal,
                  CsSpacing.xl,
                  CsSpacing.pageHorizontal,
                  CsSpacing.md,
                ),
                child: const PassportCollectionHeader(),
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
            else if (isEvents)
              if (filteredEventEntries.isEmpty)
                SliverFillRemaining(
                  child: PassportEmptyState(
                    message: _eventEmptyMessage(_eventEntries),
                  ),
                )
              else
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, i) => Padding(
                      padding: EdgeInsets.fromLTRB(
                        CsSpacing.pageHorizontal,
                        0,
                        CsSpacing.pageHorizontal,
                        i == filteredEventEntries.length - 1
                            ? 100
                            : CsSpacing.md,
                      ),
                      child: PassportEventCard(entry: filteredEventEntries[i]),
                    ),
                    childCount: filteredEventEntries.length,
                  ),
                )
            else if (_loadError)
              SliverFillRemaining(child: _ErrorState(onRetry: _load))
            else if (result!.entries.isEmpty)
              SliverFillRemaining(
                child: PassportEmptyState(
                  message: _venueEmptyMessage(allEntries),
                ),
              )
            else
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, i) => Padding(
                    padding: EdgeInsets.fromLTRB(
                      CsSpacing.pageHorizontal,
                      0,
                      CsSpacing.pageHorizontal,
                      i == result.entries.length - 1 ? 100 : CsSpacing.md,
                    ),
                    child: switch (result.entries[i].venue) {
                      RestaurantVenue(:final restaurant) =>
                        PassportRestaurantCard(
                          restaurant: restaurant,
                          stats: result.entries[i],
                          isWishlisted: _wishlistedRestaurantIds.contains(
                            restaurant.id,
                          ),
                          onToggleWishlist: () =>
                              _toggleRestaurantWishlist(restaurant.id),
                        ),
                      HotelVenue(:final hotel) => PassportHotelCard(
                        hotel: hotel,
                        stats: result.entries[i],
                        isWishlisted: _wishlistedHotelIds.contains(hotel.id),
                        onToggleWishlist: () => _toggleHotelWishlist(hotel.id),
                      ),
                    },
                  ),
                  childCount: result.entries.length,
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
