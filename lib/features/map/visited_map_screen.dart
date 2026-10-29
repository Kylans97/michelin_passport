import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants/app_colors.dart';
import '../../core/theme/cs_spacing.dart';
import '../../core/theme/cs_typography.dart';
import '../../core/widgets/cs_filter_chip.dart';
import '../../core/widgets/editorial_back_button.dart';
import '../../data/repositories/event_confirmed_attendance_repository.dart';
import '../../data/repositories/map_repository.dart';
import '../../data/repositories/visited_repository.dart';
import '../../models/passport_venue.dart';
import '../../models/venue_entry.dart';
import '../explore/models/explore_filters.dart' show ExploreVenueType;
import '../passport/passport_view_model.dart';
import 'models/map_filter_type.dart';
import 'globe/globe_view.dart';
import 'models/map_pin.dart';
import 'widgets/event_map_preview_sheet.dart';
import 'widgets/map_cluster_sheet.dart';
import 'widgets/venue_preview_sheet.dart';

/// "My Map": every restaurant the user has visited, every hotel they've
/// stayed at, and (Events V2 Step 5) every Event they have a CONFIRMED
/// attendance record for — plotted once each (repeat visits/stays collapse
/// to one pin — see [PassportFilterResult.of], the same aggregation My
/// Passport uses; a confirmed attendance is already unique per event+user
/// at the database level, so no separate collapse is needed there). Tapping
/// a pin opens a preview sheet, which hands off to the existing
/// Restaurant/Hotel/Event Detail screens — this screen owns no venue or
/// Event data beyond what [VisitedRepository.loadPassportVenues] and
/// [EventConfirmedAttendanceRepository.loadPassportEventAttendance] already
/// resolve. Interested/Going Event intent is deliberately never plotted —
/// only confirmed history belongs on a map of "every place you've
/// experienced."
///
/// Drawn as a 3D globe ([GlobeView]) rather than a tiled 2D map: the
/// country outlines are bundled with the app, so My Map loads no map tiles,
/// costs no egress, needs no API key and works offline. Countries with at
/// least one visible pin are drawn lit (see [GlobePainter]).
///
/// No GPS/location permission is used or requested: every coordinate shown
/// comes from the venues/Events themselves (restaurants_full/hotels_full/
/// events), never from the device's current position, and never inferred
/// from a linked venue when an Event's own coordinates are missing — see
/// [eventMapPins]'s own doc comment.
class VisitedMapScreen extends StatefulWidget {
  const VisitedMapScreen({super.key});

  @override
  State<VisitedMapScreen> createState() => _VisitedMapScreenState();
}

class _VisitedMapScreenState extends State<VisitedMapScreen> {
  late final VisitedRepository _visitedRepo = VisitedRepository(
    Supabase.instance.client,
  );
  late final MapRepository _mapRepo = MapRepository(Supabase.instance.client);
  late final EventConfirmedAttendanceRepository _eventsRepo =
      EventConfirmedAttendanceRepository(Supabase.instance.client);
  final _globeController = GlobeController();

  List<VenueEntry>? _entries; // null until the first load completes.
  List<EventAttendanceEntry>? _eventEntries; // null until the first load.

  // Keyed by Restaurant.id / Hotel.id. Loaded separately from _entries, via
  // MapRepository — see that class for why coordinates are never part of
  // the shared Restaurant/Hotel column lists. Empty (not null) both while
  // loading and if the coordinate migration hasn't been applied yet; either
  // way the globe itself still renders, just without pins.
  Map<String, (double, double)> _restaurantCoords = {};
  Map<String, (double, double)> _hotelCoords = {};

  bool _loading = true;
  bool _loadError = false;
  MapFilterType _filter = MapFilterType.all;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final uid = Supabase.instance.client.auth.currentUser?.id ?? '';
      // Kicked off immediately, alongside the venue-entries load below —
      // fully independent of it (Event confirmed attendance has no
      // dependency on restaurant/hotel ids), so it runs concurrently rather
      // than after. Never throws: an Event-attendance hiccup must not take
      // down Restaurant/Hotel pins any more than a coordinate hiccup does
      // (see the comment below) — it only means no Event pins this load.
      final eventEntriesFuture = _loadEventEntriesSafely(uid);
      final entries = await _visitedRepo.loadPassportVenues(uid);

      // Coordinate loading is independent of the venue-entries load above:
      // a coordinate failure (migration not applied, network hiccup) must
      // never surface as the whole Map screen failing to load, only as
      // missing pins — so this never throws, and its own errors don't touch
      // _loadError. See MapRepository.
      final restaurantIds = [
        for (final entry in entries)
          if (entry.venue case RestaurantVenue(:final restaurant))
            restaurant.id,
      ];
      final hotelIds = [
        for (final entry in entries)
          if (entry.venue case HotelVenue(:final hotel)) hotel.id,
      ];
      final restaurantCoordsFuture = _mapRepo.loadRestaurantCoordinates(
        restaurantIds,
      );
      final hotelCoordsFuture = _mapRepo.loadHotelCoordinates(hotelIds);
      final restaurantCoords = await restaurantCoordsFuture;
      final hotelCoords = await hotelCoordsFuture;
      final eventEntries = await eventEntriesFuture;

      if (!mounted) return;
      setState(() {
        _entries = entries;
        _eventEntries = eventEntries;
        _restaurantCoords = restaurantCoords;
        _hotelCoords = hotelCoords;
        _loading = false;
        _loadError = false;
      });
      // The first view keeps the whole globe in sight, turned towards the
      // user's places, and lets the idle rotation carry on; choosing a
      // filter is what flies in to frame them.
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _globeController.showWholeGlobeAround(_visiblePoints),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError = true;
      });
    }
  }

  Future<List<EventAttendanceEntry>> _loadEventEntriesSafely(String uid) async {
    try {
      return await _eventsRepo.loadPassportEventAttendance(uid);
    } catch (_) {
      return [];
    }
  }

  /// Every pin this user could possibly see, before the active filter —
  /// Restaurant/Hotel pins adapted from the same [PassportFilterResult.of]
  /// aggregation My Passport uses (requesting every venue type here; the
  /// active [MapFilterType] is applied afterward in [_visiblePins], not by
  /// this aggregation step, so multi-visit collapse behavior is untouched),
  /// plus Event pins adapted from confirmed attendance. Every pin returned
  /// here already has a resolved coordinate — [restaurantAndHotelMapPins]/
  /// [eventMapPins] both silently omit anything that doesn't.
  List<MapPin> get _allPins => [
    ...restaurantAndHotelMapPins(
      stats: PassportFilterResult.of(
        _entries ?? [],
        venueType: ExploreVenueType.all,
        year: null,
      ).entries,
      restaurantCoords: _restaurantCoords,
      hotelCoords: _hotelCoords,
    ),
    ...eventMapPins(_eventEntries ?? []),
  ];

  List<MapPin> get _visiblePins => [
    for (final pin in _allPins)
      if (_filter.matches(pin.type)) pin,
  ];

  List<(double, double)> get _visiblePoints => [
    for (final pin in _visiblePins) (pin.latitude, pin.longitude),
  ];

  /// Countries lit on the globe: those of the pins the active filter shows,
  /// by their stored country code.
  Set<String> get _visitedCountryCodes => {
    for (final pin in _visiblePins)
      if (pin.countryCode.isNotEmpty) pin.countryCode.toUpperCase(),
  };

  void _onSelectFilter(MapFilterType type) {
    setState(() => _filter = type);
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _globeController.fitTo(_visiblePoints),
    );
  }

  void _onClusterTap(BuildContext context, List<MapPin> pins) =>
      showMapClusterSheet(
        context,
        pins,
        onSelect: (pin) => _onPinTap(context, pin),
      );

  void _onPinTap(BuildContext context, MapPin pin) {
    switch (pin) {
      case RestaurantMapPin(:final stats):
        showVenuePreviewSheet(context, stats);
      case HotelMapPin(:final stats):
        showVenuePreviewSheet(context, stats);
      case EventMapPin():
        showEventMapPreviewSheet(context, pin);
    }
  }

  @override
  Widget build(BuildContext context) {
    final plottable = _visiblePins;
    final hasAnyHistory =
        (_entries ?? []).isNotEmpty || (_eventEntries ?? []).isNotEmpty;

    return Scaffold(
      backgroundColor: AppColors.deepGreen,
      body: Column(
        children: [
          SafeArea(
            bottom: false,
            child: ColoredBox(
              color: AppColors.deepGreen,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Padding(
                    padding: EdgeInsets.fromLTRB(
                      CsSpacing.base,
                      0,
                      CsSpacing.base,
                      0,
                    ),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: EditorialBackButton(color: AppColors.ivory),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      CsSpacing.pageHorizontal,
                      CsSpacing.xs,
                      CsSpacing.pageHorizontal,
                      CsSpacing.sm,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'My Map',
                          style: CsTypography.screenTitle.copyWith(
                            color: AppColors.ivory,
                          ),
                        ),
                        const SizedBox(height: CsSpacing.xs),
                        Text(
                          "Every place you've experienced.",
                          style: CsTypography.body.copyWith(
                            color: AppColors.secondaryOnDark,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      CsSpacing.pageHorizontal,
                      0,
                      CsSpacing.pageHorizontal,
                      CsSpacing.base,
                    ),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          for (final type in MapFilterType.values) ...[
                            if (type != MapFilterType.values.first)
                              const SizedBox(width: CsSpacing.sm),
                            CsFilterChip(
                              label: type.label,
                              selected: _filter == type,
                              onTap: () => _onSelectFilter(type),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: ColoredBox(
              color: AppColors.deepGreen,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: GlobeView(
                      controller: _globeController,
                      pins: plottable,
                      visitedCountryCodes: _visitedCountryCodes,
                      onPinTap: (pin) => _onPinTap(context, pin),
                      onClusterTap: (pins) => _onClusterTap(context, pins),
                    ),
                  ),
                  if (_loading)
                    const Center(
                      child: CircularProgressIndicator(
                        color: AppColors.ivory,
                        strokeWidth: 2,
                      ),
                    )
                  else if (_loadError)
                    _MapMessage(
                      icon: Icons.wifi_off_rounded,
                      message: 'Could not load your visited venues.',
                      actionLabel: 'Retry',
                      onAction: () {
                        setState(() => _loading = true);
                        _load();
                      },
                    )
                  else if (!hasAnyHistory)
                    const _MapMessage(
                      icon: Icons.explore_outlined,
                      message: 'Your map is waiting for its first destination.',
                    )
                  else if (plottable.isEmpty)
                    _MapMessage(
                      icon: Icons.location_off_outlined,
                      message: switch (_filter) {
                        MapFilterType.hotels => 'No hotel stays yet.',
                        MapFilterType.restaurants =>
                          'No restaurant visits yet.',
                        MapFilterType.events => 'No event attendance yet.',
                        MapFilterType.all => 'No visited venues yet.',
                      },
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Bottom-anchored subtle message overlay — used both for the true empty
/// state (no visits/stays at all) and load-error/no-coordinates cases. Never
/// blocks the globe itself; it sits on top, globe remains visible and
/// spinnable underneath.
class _MapMessage extends StatelessWidget {
  final IconData icon;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _MapMessage({
    required this.icon,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.bottomCenter,
    child: SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 28),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          decoration: BoxDecoration(
            color: AppColors.card.withValues(alpha: 0.92),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.cardBorder, width: 0.5),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: AppColors.textSecondary, size: 18),
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  message,
                  style: GoogleFonts.inter(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                  ),
                ),
              ),
              if (actionLabel != null && onAction != null) ...[
                const SizedBox(width: 10),
                TextButton(
                  onPressed: onAction,
                  child: Text(
                    actionLabel!,
                    style: GoogleFonts.inter(
                      color: AppColors.forestGreen,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    ),
  );
}
