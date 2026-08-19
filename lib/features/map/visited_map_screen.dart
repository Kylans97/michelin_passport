import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants/app_colors.dart';
import '../../core/theme/cs_spacing.dart';
import '../../core/theme/cs_typography.dart';
import '../../core/widgets/cs_filter_chip.dart';
import '../../core/widgets/editorial_back_button.dart';
import '../../data/repositories/map_repository.dart';
import '../../data/repositories/visited_repository.dart';
import '../../models/passport_venue.dart';
import '../../models/venue_entry.dart';
import '../explore/models/explore_filters.dart' show ExploreVenueType;
import '../passport/passport_view_model.dart';
import 'widgets/venue_pin.dart';
import 'widgets/venue_preview_sheet.dart';

// Roughly centered on the world, zoomed out enough to show every populated
// continent — used only when there are no pins to fit to, so the map never
// defaults to any particular country.
const _worldCenter = LatLng(20, 0);
const _worldZoom = 1.6;
const _singlePinZoom = 12.0;

/// "My Map": every restaurant the user has visited and every hotel they've
/// stayed at, plotted once each (repeat visits/stays collapse to one pin —
/// see [PassportFilterResult.of], the same aggregation My Passport uses).
/// Tapping a pin opens a preview sheet, which hands off to the existing
/// Restaurant/Hotel Detail screens — this screen owns no venue data beyond
/// what [VisitedRepository.loadPassportVenues] already resolves.
///
/// No GPS/location permission is used or requested: every coordinate shown
/// comes from the venues themselves (restaurants_full/hotels_full), never
/// from the device's current position.
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
  final _mapController = MapController();

  List<VenueEntry>? _entries; // null until the first load completes.

  // Keyed by Restaurant.id / Hotel.id. Loaded separately from _entries, via
  // MapRepository — see that class for why coordinates are never part of
  // the shared Restaurant/Hotel column lists. Empty (not null) both while
  // loading and if the coordinate migration hasn't been applied yet; either
  // way the map itself still renders, just without pins.
  Map<String, (double, double)> _restaurantCoords = {};
  Map<String, (double, double)> _hotelCoords = {};

  bool _loading = true;
  bool _loadError = false;
  ExploreVenueType _venueType = ExploreVenueType.all;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final uid = Supabase.instance.client.auth.currentUser?.id ?? '';
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

      if (!mounted) return;
      setState(() {
        _entries = entries;
        _restaurantCoords = restaurantCoords;
        _hotelCoords = hotelCoords;
        _loading = false;
        _loadError = false;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) => _fitCamera());
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError = true;
      });
    }
  }

  List<PassportVenueStats> get _visibleStats {
    final allEntries = _entries ?? [];
    return PassportFilterResult.of(
      allEntries,
      venueType: _venueType,
      year: null,
    ).entries;
  }

  List<LatLng> get _visiblePoints => [
    for (final stats in _visibleStats)
      if (_coordsOf(stats) case (final lat, final lng)) LatLng(lat, lng),
  ];

  (double, double)? _coordsOf(PassportVenueStats stats) {
    final venue = stats.venue;
    return switch (venue) {
      RestaurantVenue(:final restaurant) => _restaurantCoords[restaurant.id],
      HotelVenue(:final hotel) => _hotelCoords[hotel.id],
    };
  }

  void _fitCamera() {
    final points = _visiblePoints;
    if (points.isEmpty) {
      _mapController.move(_worldCenter, _worldZoom);
    } else if (points.length == 1) {
      _mapController.move(points.first, _singlePinZoom);
    } else {
      _mapController.fitCamera(
        CameraFit.bounds(
          bounds: LatLngBounds.fromPoints(points),
          padding: const EdgeInsets.fromLTRB(40, 120, 40, 60),
          maxZoom: 14,
        ),
      );
    }
  }

  void _onSelectVenueType(ExploreVenueType type) {
    setState(() => _venueType = type);
    WidgetsBinding.instance.addPostFrameCallback((_) => _fitCamera());
  }

  @override
  Widget build(BuildContext context) {
    final visibleStats = _visibleStats;
    final plottable = [
      for (final stats in visibleStats)
        if (_coordsOf(stats) != null) stats,
    ];
    final hasAnyVisitedVenue = (_entries ?? []).isNotEmpty;

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
                          for (final type in ExploreVenueType.values) ...[
                            if (type != ExploreVenueType.values.first)
                              const SizedBox(width: CsSpacing.sm),
                            CsFilterChip(
                              label: type.label,
                              selected: _venueType == type,
                              onTap: () => _onSelectVenueType(type),
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
              color: AppColors.background,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: FlutterMap(
                      mapController: _mapController,
                      options: MapOptions(
                        initialCenter: _worldCenter,
                        initialZoom: _worldZoom,
                        interactionOptions: const InteractionOptions(
                          flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                        ),
                      ),
                      children: [
                        TileLayer(
                          urlTemplate:
                              'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                          userAgentPackageName: 'com.chasingstars.app',
                          // A tile request failing (no connectivity, a rate
                          // limit) just leaves that tile blank — flutter_map
                          // already swallows the error internally, so
                          // there's nothing further to do here to keep the
                          // screen from crashing.
                          maxZoom: 19,
                        ),
                        MarkerLayer(
                          markers: [
                            for (final stats in plottable)
                              if (_coordsOf(stats) case (final lat, final lng))
                                Marker(
                                  point: LatLng(lat, lng),
                                  width: VenuePin.size,
                                  height: VenuePin.size,
                                  child: VenuePin(
                                    venue: stats.venue,
                                    onTap: () =>
                                        showVenuePreviewSheet(context, stats),
                                  ),
                                ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (_loading)
                    const Center(
                      child: CircularProgressIndicator(
                        color: AppColors.forestGreen,
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
                  else if (!hasAnyVisitedVenue)
                    const _MapMessage(
                      icon: Icons.explore_outlined,
                      message: 'Your map is waiting for its first destination.',
                    )
                  else if (plottable.isEmpty)
                    _MapMessage(
                      icon: Icons.location_off_outlined,
                      message: switch (_venueType) {
                        ExploreVenueType.hotels => 'No hotel stays yet.',
                        ExploreVenueType.restaurants =>
                          'No restaurant visits yet.',
                        ExploreVenueType.all => 'No visited venues yet.',
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
/// blocks the map itself; it sits on top, map remains visible and pannable
/// underneath.
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
