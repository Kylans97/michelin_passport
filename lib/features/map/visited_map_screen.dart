import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants/app_colors.dart';
import '../../core/theme/cs_spacing.dart';
import '../../core/theme/cs_typography.dart';
import '../../core/widgets/editorial_back_button.dart';
import '../../data/repositories/event_confirmed_attendance_repository.dart';
import '../../data/repositories/map_repository.dart';
import '../../data/repositories/undated_visit_repository.dart';
import '../../data/repositories/undated_visit_preview_repository.dart';
import '../../data/repositories/visited_repository.dart';
import '../../data/repositories/wine_atlas_repository.dart';
import '../../models/passport_venue.dart';
import '../../models/undated_visit.dart';
import '../../models/venue_entry.dart';
import '../../models/wine_atlas.dart';
import '../explore/models/explore_filters.dart' show ExploreVenueType;
import '../passport/passport_view_model.dart';
import '../passport/stamp_ceremony.dart';
import 'add_places/add_places_screen.dart';
import 'models/map_filter_type.dart';
import 'globe/globe_region_layer.dart';
import 'globe/globe_view.dart';
import 'models/map_pin.dart';
import 'widgets/event_map_preview_sheet.dart';
import 'widgets/map_cluster_sheet.dart';
import 'widgets/undated_visit_sheet.dart';
import 'widgets/venue_preview_sheet.dart';
import 'wine/wine_list_search_screen.dart';
import 'wine/wine_region_sheet.dart';
import '../../core/analytics/analytics_properties.dart';
import '../../core/analytics/screen_usage.dart';
import '../../core/theme/cs_fonts.dart';

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
///
/// Given [userId], the same globe shows a friend's places instead of the
/// viewer's own (Friend Profile → "{Name}'s map"). Nothing here widens what
/// is visible: both loads below are plain table reads, so RLS returns only
/// the visits and confirmed attendances that friend marked `friends`, and
/// none at all once the friendship ends or is blocked.
class VisitedMapScreen extends StatefulWidget {
  /// Whose places to plot; null means the signed-in user.
  final String? userId;

  /// The friend's display name, used in the title and empty states. Only
  /// read when [userId] is set.
  final String? ownerName;

  const VisitedMapScreen({super.key, this.userId, this.ownerName});

  bool get _isFriend => userId != null;

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
  late final UndatedVisitRepository _undatedRepo = undatedPreview
      ? PreviewUndatedVisitRepository(Supabase.instance.client)
      : UndatedVisitRepository(Supabase.instance.client);
  final _globeController = GlobeController();

  List<VenueEntry>? _entries; // null until the first load completes.
  List<EventAttendanceEntry>? _eventEntries; // null until the first load.

  // Visits without a date (undated_visits), drawn as dashed pins. Until the
  // table exists (before 20261101700000 is applied) the load fails quietly,
  // [_undatedAvailable] stays false, and My Map is exactly as before: no
  // Add places button, no dashed pins.
  List<UndatedVenue> _undated = const [];
  bool _undatedAvailable = false;

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

  // The wine layer (product owner, 2026-11-20): wine regions instead of
  // the member's places. Only on the member's own map, and only once
  // published regions exist — before the migration or its content, no
  // toggle shows and My Map is exactly as before.
  bool _wineMode = false;
  WineAtlas _atlas = WineAtlas.empty;
  Map<String, int> _myWineCounts = const {};
  String? _selectedRegionId;

  @override
  void initState() {
    super.initState();
    if (!widget._isFriend) {
      trackScreenOpened(AnalyticsScreen.map);
      _loadAtlas();
    }
    _load();
  }

  Future<void> _loadAtlas() async {
    final repo = WineAtlasRepository(Supabase.instance.client);
    try {
      final atlas = await repo.load();
      if (!mounted) return;
      setState(() => _atlas = atlas);
      final uid = Supabase.instance.client.auth.currentUser?.id ?? '';
      final counts = await repo.loadMyWineCountsByRegion(uid);
      if (mounted) setState(() => _myWineCounts = counts);
    } catch (_) {
      // No wine layer: the tables or their content aren't there yet.
    }
  }

  List<GlobeRegion> get _globeRegions => [
    for (final region in _atlas.globeRegions)
      GlobeRegion(
        id: region.id,
        label: region.name,
        latitude: region.latitude,
        longitude: region.longitude,
        radiusKm: region.radiusKm,
        outline: region.outline,
        marked: (_myWineCounts[region.id] ?? 0) > 0,
      ),
  ];

  void _setWineMode(bool on) {
    if (on == _wineMode) return;
    setState(() {
      _wineMode = on;
      _selectedRegionId = null;
    });
    if (on) {
      // The first set of regions is all in western Europe: close enough
      // that their names can be read.
      _globeController.flyToPoint(45, 3, zoom: 5);
    } else {
      _globeController.showWholeGlobeAround(_visiblePoints);
    }
  }

  Future<void> _openRegion(WineRegion region) async {
    setState(() => _selectedRegionId = region.id);
    await showWineRegionSheet(
      context,
      atlas: _atlas,
      region: region,
      myWineCount: _myWineCounts[region.id] ?? 0,
    );
    if (mounted) setState(() => _selectedRegionId = null);
  }

  Future<void> _openWineSearch() async {
    final region = await Navigator.push<WineRegion>(
      context,
      MaterialPageRoute(builder: (_) => WineListSearchScreen(atlas: _atlas)),
    );
    if (region == null || !mounted) return;
    final shown = region.parentId == null
        ? region
        : (_atlas.region(region.parentId!) ?? region);
    final globeRegion = _globeRegions.where((r) => r.id == shown.id);
    if (globeRegion.isNotEmpty) {
      await _globeController.flyToRegion(globeRegion.first);
    }
    if (mounted) await _openRegion(region);
  }

  Future<void> _load() async {
    try {
      final uid =
          widget.userId ?? Supabase.instance.client.auth.currentUser?.id ?? '';
      // Kicked off immediately, alongside the venue-entries load below —
      // fully independent of it (Event confirmed attendance has no
      // dependency on restaurant/hotel ids), so it runs concurrently rather
      // than after. Never throws: an Event-attendance hiccup must not take
      // down Restaurant/Hotel pins any more than a coordinate hiccup does
      // (see the comment below) — it only means no Event pins this load.
      final eventEntriesFuture = _loadEventEntriesSafely(uid);
      final undatedFuture = _loadUndatedSafely(uid);
      final entries = await _visitedRepo.loadPassportVenues(uid);
      final undated = await undatedFuture;

      // Coordinate loading is independent of the venue-entries load above:
      // a coordinate failure (migration not applied, network hiccup) must
      // never surface as the whole Map screen failing to load, only as
      // missing pins — so this never throws, and its own errors don't touch
      // _loadError. See MapRepository.
      final restaurantIds = [
        for (final entry in entries)
          if (entry.venue case RestaurantVenue(:final restaurant))
            restaurant.id,
        for (final u in undated?.list ?? const <UndatedVenue>[])
          if (!u.visit.isHotel) u.visit.entityId,
      ];
      final hotelIds = [
        for (final entry in entries)
          if (entry.venue case HotelVenue(:final hotel)) hotel.id,
        for (final u in undated?.list ?? const <UndatedVenue>[])
          if (u.visit.isHotel) u.visit.entityId,
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
        _undated = undated?.list ?? const [];
        _undatedAvailable = undated != null;
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

  /// Null when the undated_visits table can't be read (not there yet, or
  /// a hiccup): like the Event load above, never the whole map failing.
  Future<({List<UndatedVenue> list})?> _loadUndatedSafely(String uid) async {
    try {
      return (list: await _undatedRepo.loadUndatedVenues(uid));
    } catch (_) {
      return null;
    }
  }

  /// `restaurant:id` / `hotel:id` of every venue with a dated visit.
  Set<String> get _datedVenueKeys => {
    for (final entry in _entries ?? const <VenueEntry>[])
      switch (entry.venue) {
        RestaurantVenue(:final restaurant) => 'restaurant:${restaurant.id}',
        HotelVenue(:final hotel) => 'hotel:${hotel.id}',
      },
  };

  Future<void> _openAddPlaces() async {
    final yourCountries = <String, int>{};
    for (final pin in _allPins) {
      if (pin.type == MapPinType.event || pin.countryCode.isEmpty) continue;
      final code = pin.countryCode.toUpperCase();
      yourCountries[code] = (yourCountries[code] ?? 0) + 1;
    }
    final result = await Navigator.push<AddPlacesResult>(
      context,
      MaterialPageRoute(
        builder: (_) => AddPlacesScreen(
          yourCountries: yourCountries,
          knownVenueKeys: {
            ..._datedVenueKeys,
            for (final u in _undated)
              '${u.visit.entityType}:${u.visit.entityId}',
          },
          repository: _undatedRepo,
        ),
      ),
    );
    if (result == null || !mounted) return;
    await _load();
    if (!mounted) return;
    setState(() => _filter = MapFilterType.all);
    final code = result.countryCode.toUpperCase();
    final points = [
      for (final pin in _allPins)
        if (pin.countryCode.toUpperCase() == code)
          (pin.latitude, pin.longitude),
    ];
    if (points.isNotEmpty) _globeController.fitTo(points);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '${result.countryName} is on your globe: ${result.added} without '
          'a date. Tap a dashed pin to add its date.',
        ),
      ),
    );
  }

  Future<void> _openUndated(UndatedVenue undated) async {
    final action = await showUndatedVisitSheet(
      context,
      undated,
      isOwn: !widget._isFriend,
    );
    if (!mounted || action == null) return;
    switch (action) {
      case UndatedSheetAction.addDate:
        await _addDate(undated);
      case UndatedSheetAction.remove:
        await _remove(undated);
    }
  }

  Future<void> _addDate(UndatedVenue undated) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: DateTime(1950),
      lastDate: now, // future dates not allowed, as everywhere a visit is dated
      helpText: undated.venue.name,
    );
    if (picked == null || !mounted) return;
    try {
      final visit = await _undatedRepo.addDate(undated.visit.id, picked);
      if (!mounted) return;
      await celebrateNewStamp(context, EarnedStamp.visit(visit));
      await _load();
    } on UnsupportedError catch (e) {
      // LOCAL PREVIEW ONLY: see undated_visit_preview_repository.dart.
      if (!mounted) return;
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('${e.message}')));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not add the date. Please try again.'),
        ),
      );
    }
  }

  Future<void> _remove(UndatedVenue undated) async {
    final sure = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Remove ${undated.venue.name}?'),
        content: const Text(
          'It comes off your map. You can add it again whenever you like.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (sure != true || !mounted) return;
    try {
      await _undatedRepo.remove(undated.visit.id);
      await _load();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not remove it. Please try again.')),
      );
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
    ...undatedMapPins(
      undated: _undated,
      restaurantCoords: _restaurantCoords,
      hotelCoords: _hotelCoords,
      datedVenueKeys: _datedVenueKeys,
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

  String get _ownerName {
    final name = widget.ownerName?.trim();
    return (name == null || name.isEmpty) ? 'Your friend' : name;
  }

  void _onSelectFilter(MapFilterType type) {
    setState(() => _filter = type);
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _globeController.fitTo(_visiblePoints),
    );
  }

  Future<void> _openFilterMenu() async {
    final picked = await showModalBottomSheet<MapFilterType>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(22),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final type in MapFilterType.values)
                  ListTile(
                    title: Text(
                      type.label,
                      style: CsFonts.serif(
                        color: AppColors.textPrimary,
                        fontSize: 18,
                      ),
                    ),
                    trailing: type == _filter
                        ? const Icon(
                            Icons.check_rounded,
                            color: AppColors.forestGreen,
                          )
                        : null,
                    onTap: () => Navigator.pop(context, type),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
    if (picked != null && picked != _filter) _onSelectFilter(picked);
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
      case UndatedMapPin(:final undated):
        _openUndated(undated);
      case EventMapPin():
        showEventMapPreviewSheet(context, pin);
    }
  }

  @override
  Widget build(BuildContext context) {
    final plottable = _visiblePins;
    final hasAnyHistory =
        (_entries ?? []).isNotEmpty ||
        (_eventEntries ?? []).isNotEmpty ||
        _undated.isNotEmpty;
    final canAddPlaces =
        !widget._isFriend && !_wineMode && !_loading && _undatedAvailable;

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
                  if (!widget._isFriend && !_atlas.isEmpty)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        CsSpacing.pageHorizontal,
                        0,
                        CsSpacing.pageHorizontal,
                        CsSpacing.sm,
                      ),
                      child: _ModeToggle(
                        wine: _wineMode,
                        onChanged: _setWineMode,
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
                          _wineMode
                              ? 'Wine regions'
                              : widget._isFriend
                              ? "$_ownerName's Map"
                              : 'My Map',
                          style: CsTypography.screenTitle.copyWith(
                            color: AppColors.ivory,
                          ),
                        ),
                        const SizedBox(height: CsSpacing.xs),
                        Text(
                          _wineMode
                              ? 'Tap a region to see its grapes and how they taste.'
                              : widget._isFriend
                              ? 'Every place $_ownerName has shared with you.'
                              : "Every place you've experienced.",
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
                    child: _wineMode
                        ? _WineSearchButton(onTap: _openWineSearch)
                        : Row(
                            children: [
                              _FilterButton(
                                label: _filter.label,
                                onTap: _openFilterMenu,
                              ),
                              const Spacer(),
                              if (canAddPlaces)
                                _AddButton(onTap: _openAddPlaces),
                            ],
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
                      pins: _wineMode ? const [] : plottable,
                      visitedCountryCodes: _wineMode
                          ? const {}
                          : _visitedCountryCodes,
                      onPinTap: (pin) => _onPinTap(context, pin),
                      onClusterTap: (pins) => _onClusterTap(context, pins),
                      regions: _wineMode ? _globeRegions : const [],
                      selectedRegionId: _selectedRegionId,
                      onRegionTap: (globeRegion) {
                        final region = _atlas.region(globeRegion.id);
                        if (region != null) _openRegion(region);
                      },
                    ),
                  ),
                  // No overlay in wine mode. SizedBox.expand, not shrink: a
                  // zero-sized child here would make this Stack, and with it
                  // the globe, zero wide (seen in the simulator, 2026-11-20).
                  if (_wineMode)
                    const SizedBox.expand()
                  else if (_loading)
                    const Center(
                      child: CircularProgressIndicator(
                        color: AppColors.ivory,
                        strokeWidth: 2,
                      ),
                    )
                  else if (_loadError)
                    _MapMessage(
                      icon: Icons.wifi_off_rounded,
                      message: widget._isFriend
                          ? "Could not load $_ownerName's places."
                          : 'Could not load your visited venues.',
                      actionLabel: 'Retry',
                      onAction: () {
                        setState(() => _loading = true);
                        _load();
                      },
                    )
                  else if (!hasAnyHistory)
                    _MapMessage(
                      icon: Icons.explore_outlined,
                      message: widget._isFriend
                          ? "$_ownerName hasn't shared any places yet."
                          : 'Your map is waiting for its first destination.',
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
                  style: CsFonts.sans(
                    color: AppColors.textSecondary,
                    fontSize: 13.5,
                  ),
                ),
              ),
              if (actionLabel != null && onAction != null) ...[
                const SizedBox(width: 10),
                TextButton(
                  onPressed: onAction,
                  child: Text(
                    actionLabel!,
                    style: CsFonts.sans(
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

/// "My places | Wine regions" — which layer the globe shows.
class _ModeToggle extends StatelessWidget {
  final bool wine;
  final ValueChanged<bool> onChanged;

  const _ModeToggle({required this.wine, required this.onChanged});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(3),
    decoration: BoxDecoration(
      color: AppColors.darkGreen,
      borderRadius: BorderRadius.circular(22),
      border: Border.all(color: AppColors.subtleBorderDark),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _segment('My places', !wine, () => onChanged(false)),
        _segment('Wine regions', wine, () => onChanged(true)),
      ],
    ),
  );

  Widget _segment(String label, bool selected, VoidCallback onTap) => Semantics(
    button: true,
    selected: selected,
    child: GestureDetector(
      onTap: onTap,
      child: Container(
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? AppColors.ivory : Colors.transparent,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Text(
          label,
          style: CsFonts.sans(
            color: selected ? AppColors.deepGreen : AppColors.secondaryOnDark,
            fontSize: 13,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
          ),
        ),
      ),
    ),
  );
}

/// What the globe shows: one button with the active filter's name,
/// opening the four choices, so the row stays calm.
class _FilterButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _FilterButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: 'Showing $label. Change filter',
    excludeSemantics: true,
    child: GestureDetector(
      onTap: onTap,
      child: Container(
        height: 44,
        padding: const EdgeInsets.only(left: 18, right: 12),
        decoration: BoxDecoration(
          color: AppColors.ivory,
          borderRadius: BorderRadius.circular(22),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: CsTypography.smallLabel.copyWith(
                color: AppColors.deepGreen,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(
              Icons.expand_more_rounded,
              size: 18,
              color: AppColors.deepGreen,
            ),
          ],
        ),
      ),
    ),
  );
}

/// "+": add venues the member has been to, without a date.
class _AddButton extends StatelessWidget {
  final VoidCallback onTap;
  const _AddButton({required this.onTap});

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: 'Add places you have been',
    excludeSemantics: true,
    child: GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: const BoxDecoration(
          color: AppColors.ivory,
          shape: BoxShape.circle,
        ),
        child: const Icon(
          Icons.add_rounded,
          size: 24,
          color: AppColors.deepGreen,
        ),
      ),
    ),
  );
}

/// Opens the wine-list search; looks like the search field it leads to.
class _WineSearchButton extends StatelessWidget {
  final VoidCallback onTap;
  const _WineSearchButton({required this.onTap});

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    child: GestureDetector(
      onTap: onTap,
      child: Container(
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 18),
        decoration: BoxDecoration(
          color: AppColors.ivory,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.search_rounded,
              size: 20,
              color: AppColors.deepGreen,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'On the wine list? Search a region or grape',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: CsFonts.sans(color: AppColors.taupe, fontSize: 14.5),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
