import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/maps/maptiler_config.dart';
import '../../../core/theme/cs_spacing.dart';
import '../../../core/theme/cs_surface_context.dart';
import '../../../core/theme/cs_typography.dart';
import '../../../core/widgets/cs_primary_button.dart';
import '../../../core/widgets/editorial_back_button.dart';
import '../../../core/widgets/key_row.dart';
import '../../../core/widgets/star_row.dart';
import '../../../core/widgets/venue_thumbnail.dart';
import '../../../data/repositories/map_repository.dart';
import '../../../models/event.dart';
import '../../../models/event_trip_match.dart';
import '../../../models/passport_venue.dart';
import '../../../models/photo_framing.dart';
import '../../../models/planned_trip.dart';
import '../../../models/trip_destination.dart';
import '../../events/event_date_format.dart';
import '../trip_legs.dart';
import 'trip_map_items.dart';

/// The map inside a trip: every Mantelier restaurant and Key hotel in one
/// leg's place, the trip's events in that leg, and what's already planned,
/// on a street map. Tapping a marker opens a small card with "Add to trip".
/// A trip with several destinations switches leg from the chips on top.
///
/// Markers: green pins with cutlery for a restaurant and a key for a hotel,
/// as on the visited map ([VenuePin]), an ivory pin with a calendar for an
/// event and with a check for anything already on the trip. Nearby pins
/// fold into a numbered cluster until zoomed in; planned places and events
/// never fold. Zoomed in, a pin shows its name (see [pickTripMapLabels]).
/// No gold on the map itself: stars and Keys appear only on the card, the
/// way the rest of the app shows them.
class TripMapScreen extends StatefulWidget {
  final PlannedTrip trip;

  /// The trip's events, already matched to it (eventsMatchingTrip).
  final List<Event> events;

  /// `TripMapVenueItem.key`s of what's already planned on this trip.
  final Set<String> plannedKeys;

  final String Function(TripDestination leg) legLabel;
  final Future<List<MappedVenue>> Function(TripDestination leg) loadVenues;

  /// Plans [venue] on the trip for [leg]; true when saved.
  final Future<bool> Function(PassportVenue venue, TripDestination leg)
  addToTrip;

  final void Function(PassportVenue venue) openVenue;
  final void Function(Event event) openEvent;

  /// Overrides [MapTilerConfig.key] — for tests, which load no `.env`.
  final String? mapTilerKey;

  const TripMapScreen({
    super.key,
    required this.trip,
    required this.events,
    required this.plannedKeys,
    required this.legLabel,
    required this.loadVenues,
    required this.addToTrip,
    required this.openVenue,
    required this.openEvent,
    this.mapTilerKey,
  });

  @override
  State<TripMapScreen> createState() => _TripMapScreenState();
}

class _TripMapScreenState extends State<TripMapScreen> {
  late final List<TripDestination> _legs = effectiveLegs(widget.trip);
  late final String? _tileKey = widget.mapTilerKey ?? MapTilerConfig.key;
  late final Set<String> _planned = {...widget.plannedKeys};
  // One per leg, like the map itself: a controller belongs to one map.
  var _mapController = MapController();

  int _legIndex = 0;
  bool _loading = true;
  bool _failed = false;
  List<MappedVenue> _venues = [];
  String? _selectedKey;
  bool _adding = false;

  TripDestination get _leg => _legs[_legIndex];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _failed = false;
      _selectedKey = null;
    });
    final leg = _leg;
    try {
      final venues = await widget.loadVenues(leg);
      if (!mounted || leg != _leg) return;
      setState(() {
        _venues = venues;
        _loading = false;
      });
    } catch (_) {
      if (!mounted || leg != _leg) return;
      setState(() {
        _loading = false;
        _failed = true;
      });
    }
  }

  void _selectLeg(int index) {
    if (index == _legIndex) return;
    setState(() {
      _legIndex = index;
      _mapController = MapController();
    });
    _load();
  }

  // Events in this leg, by the same per-leg rule the trip page uses
  // (firstLegMatchingEvent); a trip without destinations has one leg.
  List<Event> get _legEvents {
    final events = widget.events.where(
      (e) => e.latitude != null && e.longitude != null,
    );
    if (widget.trip.destinations.isEmpty) return events.toList();
    return [
      for (final e in events)
        if (firstLegMatchingEvent(e, widget.trip) == _leg) e,
    ];
  }

  List<TripMapItem> get _items {
    final venues = [
      for (final v in _venues)
        TripMapVenueItem(v.venue, LatLng(v.latitude, v.longitude)),
    ];
    return [
      for (final v in venues)
        TripMapVenueItem(v.venue, v.point, planned: _planned.contains(v.key)),
      for (final e in _legEvents)
        TripMapEventItem(e, LatLng(e.latitude!, e.longitude!)),
    ];
  }

  TripMapItem? get _selected {
    final key = _selectedKey;
    if (key == null) return null;
    for (final item in _items) {
      if (item.key == key) return item;
    }
    return null;
  }

  void _tapCluster(TripMapCluster cluster) {
    if (cluster.items.length == 1) {
      setState(() => _selectedKey = cluster.items.single.key);
      return;
    }
    final points = cluster.items.map((i) => i.point).toSet().toList();
    final camera = _mapController.camera;
    if (points.length == 1) {
      _mapController.move(points.single, camera.zoom + 2);
      return;
    }
    _mapController.fitCamera(
      CameraFit.coordinates(
        coordinates: points,
        padding: const EdgeInsets.all(72),
        maxZoom: 17,
      ),
    );
  }

  Future<void> _add(TripMapVenueItem item) async {
    if (_adding) return;
    setState(() => _adding = true);
    final saved = await widget.addToTrip(item.venue, _leg);
    if (!mounted) return;
    setState(() {
      _adding = false;
      if (saved) _planned.add(item.key);
    });
    if (!saved) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not add that to your trip. Please try again.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.deepGreen,
      body: Column(
        children: [
          SafeArea(bottom: false, child: _header()),
          Expanded(child: _body()),
        ],
      ),
    );
  }

  Widget _header() {
    final range = formatLegDateRange(
      legStart(widget.trip, _leg),
      legEnd(widget.trip, _leg),
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        CsSpacing.base,
        CsSpacing.sm,
        CsSpacing.base,
        CsSpacing.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const EditorialBackButton(),
              const SizedBox(width: CsSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.trip.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: CsTypography.placeTitle.copyWith(
                        color: AppColors.textOnDark,
                        fontSize: 22,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      range.toUpperCase(),
                      style: CsTypography.eyebrow.copyWith(
                        color: AppColors.mutedBrass,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (_legs.length > 1) ...[
            const SizedBox(height: CsSpacing.md),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (var i = 0; i < _legs.length; i++) ...[
                    if (i > 0) const SizedBox(width: CsSpacing.sm),
                    _LegChip(
                      label: widget.legLabel(_legs[i]),
                      selected: i == _legIndex,
                      onTap: () => _selectLeg(i),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _body() {
    if (_tileKey == null) {
      return const _MapMessage("The map can't be shown right now.");
    }
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(
          color: AppColors.textOnDark,
          strokeWidth: 1.5,
        ),
      );
    }
    if (_failed) {
      return const _MapMessage('Could not load the map. Please try again.');
    }
    final items = _items;
    if (items.isEmpty) {
      return _MapMessage(
        'No Mantelier places in ${widget.legLabel(_leg)} yet.',
      );
    }
    final selected = _selected;
    return Stack(
      children: [
        FlutterMap(
          // A new map per leg, so each one opens fitted to its own places.
          key: ValueKey(_legIndex),
          mapController: _mapController,
          options: MapOptions(
            initialCameraFit: CameraFit.coordinates(
              coordinates: [for (final i in items) i.point],
              padding: const EdgeInsets.fromLTRB(48, 48, 48, 160),
              maxZoom: 15,
            ),
            minZoom: 3,
            maxZoom: 18,
            interactionOptions: const InteractionOptions(
              flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
            ),
            onTap: (_, _) => setState(() => _selectedKey = null),
          ),
          children: [
            TileLayer(
              urlTemplate: MapTilerConfig.urlTemplate(_tileKey),
              retinaMode: RetinaMode.isHighDensity(context),
              userAgentPackageName: 'app.mantelier',
            ),
            _ClusteredMarkers(
              items: items,
              selectedKey: _selectedKey,
              onTap: _tapCluster,
            ),
            _MapAttribution(lifted: selected != null),
          ],
        ),
        if (selected != null)
          Align(
            alignment: Alignment.bottomCenter,
            child: _SelectionCard(
              item: selected,
              adding: _adding,
              onAdd: selected is TripMapVenueItem ? () => _add(selected) : null,
              onOpen: () => switch (selected) {
                TripMapVenueItem(:final venue) => widget.openVenue(venue),
                TripMapEventItem(:final event) => widget.openEvent(event),
              },
            ),
          ),
      ],
    );
  }
}

/// The markers, re-clustered whenever the zoom changes: a child layer of
/// the map, so [MapCamera.of] rebuilds it on every camera move.
class _ClusteredMarkers extends StatelessWidget {
  final List<TripMapItem> items;
  final String? selectedKey;
  final ValueChanged<TripMapCluster> onTap;

  const _ClusteredMarkers({
    required this.items,
    required this.selectedKey,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final camera = MapCamera.of(context);
    final zoom = camera.zoom.roundToDouble();
    final clusters = clusterTripMapItems(
      items,
      (p) => camera.projectAtZoom(p, zoom),
    );
    final singles = [
      for (final cluster in clusters)
        if (cluster.items.length == 1) cluster.items.single,
    ];
    final textScaler = MediaQuery.textScalerOf(context);
    final labels = pickTripMapLabels(
      singles,
      zoom: zoom,
      project: (p) => camera.projectAtZoom(p, zoom),
      labelWidth: (item) => _labelWidth(item, textScaler),
      obstacles: [
        for (final cluster in clusters)
          if (cluster.items.length > 1)
            camera.projectAtZoom(cluster.center, zoom),
      ],
      selectedKey: selectedKey,
    );
    return MarkerLayer(
      markers: [
        // Names first, so a pin is always drawn over them.
        for (final item in singles)
          if (labels[item.key] case final side?)
            Marker(
              point: item.point,
              width: _labelWidth(item, textScaler) + _labelInset,
              height: 22,
              alignment: side == TripMapLabelSide.right
                  ? Alignment.centerRight
                  : Alignment.centerLeft,
              child: _ItemLabel(
                item: item,
                side: side,
                onTap: () => onTap(TripMapCluster([item])),
              ),
            ),
        for (final cluster in clusters)
          if (cluster.items.length == 1)
            Marker(
              point: cluster.items.single.point,
              width: 44,
              height: 44,
              child: _ItemMarker(
                item: cluster.items.single,
                selected: cluster.items.single.key == selectedKey,
                onTap: () => onTap(cluster),
              ),
            )
          else
            Marker(
              point: cluster.center,
              width: 44,
              height: 44,
              child: _ClusterMarker(
                count: cluster.items.length,
                onTap: () => onTap(cluster),
              ),
            ),
      ],
    );
  }
}

// From a pin's centre to where its name starts: the pin's radius and a gap.
const double _labelInset = 18;
const double _labelMaxWidth = 130;

TextStyle get _labelStyle => CsTypography.metadata.copyWith(
  color: AppColors.forestGreen,
  fontSize: 11,
  fontWeight: FontWeight.w600,
  height: 1.2,
  // Set, so the Text cannot inherit spacing the theme adds and come out
  // wider than _labelWidth measured.
  letterSpacing: 0,
);

String _itemName(TripMapItem item) => switch (item) {
  TripMapVenueItem(:final venue) => venue.name,
  TripMapEventItem(:final event) => event.name,
};

double _labelWidth(TripMapItem item, TextScaler textScaler) {
  final painter = TextPainter(
    text: TextSpan(text: _itemName(item), style: _labelStyle),
    textDirection: TextDirection.ltr,
    textScaler: textScaler,
    maxLines: 1,
  )..layout();
  final width = painter.width;
  painter.dispose();
  return math.min(width.ceilToDouble() + 1, _labelMaxWidth);
}

/// A pin's name, with a pale halo so it stays readable on any street. The
/// pin carries the name for screen readers, so this is left out of the
/// semantics tree.
class _ItemLabel extends StatelessWidget {
  final TripMapItem item;
  final TripMapLabelSide side;
  final VoidCallback onTap;

  const _ItemLabel({
    required this.item,
    required this.side,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final name = _itemName(item);
    return ExcludeSemantics(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Padding(
          padding: side == TripMapLabelSide.right
              ? const EdgeInsets.only(left: _labelInset)
              : const EdgeInsets.only(right: _labelInset),
          child: Align(
            alignment: side == TripMapLabelSide.right
                ? Alignment.centerLeft
                : Alignment.centerRight,
            child: Stack(
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _labelStyle.copyWith(
                    color: null,
                    foreground: Paint()
                      ..style = PaintingStyle.stroke
                      ..strokeWidth = 3
                      ..strokeJoin = StrokeJoin.round
                      ..color = AppColors.ivory,
                  ),
                ),
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _labelStyle,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ItemMarker extends StatelessWidget {
  final TripMapItem item;
  final bool selected;
  final VoidCallback onTap;

  const _ItemMarker({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  String get _label => switch (item) {
    TripMapVenueItem(:final venue, :final planned) =>
      '${venue.name}${planned ? ', on your trip' : ''}',
    TripMapEventItem(:final event) => 'Event: ${event.name}',
  };

  @override
  Widget build(BuildContext context) {
    final scale = selected ? 1.25 : 1.0;
    Widget pin(IconData icon, {required bool light}) => Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: light ? AppColors.ivory : AppColors.forestGreen,
        shape: BoxShape.circle,
        border: Border.all(
          color: light ? AppColors.forestGreen : AppColors.ivory,
          width: 1.5,
        ),
      ),
      child: Icon(
        icon,
        size: 15,
        color: light ? AppColors.forestGreen : AppColors.ivory,
      ),
    );
    final Widget shape = switch (item) {
      TripMapVenueItem(planned: true) => pin(Icons.check_rounded, light: true),
      TripMapVenueItem(isHotel: true) => pin(
        Icons.vpn_key_rounded,
        light: false,
      ),
      TripMapVenueItem() => pin(Icons.restaurant_rounded, light: false),
      TripMapEventItem() => pin(Icons.event_rounded, light: true),
    };
    return Semantics(
      button: true,
      selected: selected,
      label: _label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Center(
          child: Transform.scale(
            scale: scale,
            child: DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.charcoal.withValues(alpha: 0.25),
                    blurRadius: 4,
                  ),
                ],
              ),
              child: shape,
            ),
          ),
        ),
      ),
    );
  }
}

class _ClusterMarker extends StatelessWidget {
  final int count;
  final VoidCallback onTap;

  const _ClusterMarker({required this.count, required this.onTap});

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: '$count places, zoom in',
    child: GestureDetector(
      onTap: onTap,
      child: Center(
        child: Container(
          width: 34,
          height: 34,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.forestGreen,
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.ivory, width: 1.5),
          ),
          child: ExcludeSemantics(
            child: Text(
              '$count',
              style: CsTypography.metadata.copyWith(
                color: AppColors.ivory,
                fontSize: 12,
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class _SelectionCard extends StatelessWidget {
  final TripMapItem item;
  final bool adding;
  final VoidCallback? onAdd;
  final VoidCallback onOpen;

  const _SelectionCard({
    required this.item,
    required this.adding,
    required this.onAdd,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final (title, subtitle, award, imageUrl, framing) = switch (item) {
      TripMapVenueItem(:final venue) => switch (venue) {
        RestaurantVenue(:final restaurant) => (
          restaurant.name,
          restaurant.cityName,
          restaurant.hasMichelinStar
              ? StarRow(count: restaurant.michelinStars!, size: 12) as Widget
              : null,
          restaurant.cardImageUrl,
          restaurant.cardFraming,
        ),
        HotelVenue(:final hotel) => (
          hotel.name,
          hotel.cityName,
          hotel.hasMichelinKeys
              ? KeyRow(count: hotel.michelinKeys!, size: 12) as Widget
              : null,
          hotel.cardImageUrl,
          hotel.cardFraming,
        ),
      },
      TripMapEventItem(:final event) => (
        event.name,
        formatEventDateRange(event),
        null,
        event.imageUrl,
        null,
      ),
    };
    final planned =
        item is TripMapVenueItem && (item as TripMapVenueItem).planned;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        CsSpacing.pageHorizontal,
        CsSpacing.base,
        CsSpacing.pageHorizontal,
        CsSpacing.base + MediaQuery.paddingOf(context).bottom,
      ),
      decoration: BoxDecoration(
        color: AppColors.warmWhite,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: AppColors.charcoal.withValues(alpha: 0.2),
            blurRadius: 16,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              VenueThumbnail(
                imageUrl: imageUrl,
                framing: framing ?? PhotoFraming.center,
                size: 60,
                borderRadius: BorderRadius.circular(10),
              ),
              const SizedBox(width: CsSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: CsTypography.placeTitle.copyWith(
                        color: AppColors.textPrimary,
                        fontSize: 20,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        if (award != null) ...[
                          award,
                          const SizedBox(width: CsSpacing.sm),
                        ],
                        Flexible(
                          child: Text(
                            subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: CsTypography.metadata.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: CsSpacing.base),
          Row(
            children: [
              if (onAdd != null) ...[
                Expanded(
                  child: planned
                      ? CsSecondaryButton(
                          label: 'On your trip',
                          icon: Icons.check_rounded,
                          onTap: null,
                          surface: CsSurface.light,
                          height: 46,
                        )
                      : CsPrimaryButton(
                          label: 'Add to trip',
                          onTap: onAdd,
                          loading: adding,
                          surface: CsSurface.light,
                          height: 46,
                        ),
                ),
                const SizedBox(width: CsSpacing.md),
              ],
              Expanded(
                child: CsSecondaryButton(
                  label: item is TripMapEventItem ? 'View event' : 'View venue',
                  onTap: onOpen,
                  surface: CsSurface.light,
                  height: 46,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LegChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _LegChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: selected,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? AppColors.ivory : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected ? AppColors.ivory : AppColors.subtleBorderDark,
          ),
        ),
        child: Text(
          label,
          style: CsTypography.metadata.copyWith(
            color: selected ? AppColors.deepGreen : AppColors.secondaryOnDark,
            fontSize: 13,
          ),
        ),
      ),
    ),
  );
}

class _MapMessage extends StatelessWidget {
  final String message;
  const _MapMessage(this.message);

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(CsSpacing.pageHorizontal),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: CsTypography.body.copyWith(color: AppColors.secondaryOnDark),
      ),
    ),
  );
}

/// MapTiler's required credit, kept visible; moved up above the selection
/// card while one is open. Each name opens its copyright page.
class _MapAttribution extends StatelessWidget {
  final bool lifted;
  const _MapAttribution({required this.lifted});

  @override
  Widget build(BuildContext context) {
    final style = CsTypography.metadata.copyWith(
      color: AppColors.taupe,
      fontSize: 11,
    );
    Widget link(String label, Uri uri) => GestureDetector(
      onTap: () => launchUrl(uri, mode: LaunchMode.externalApplication),
      child: Text(label, style: style),
    );
    return Align(
      alignment: lifted ? Alignment.topRight : Alignment.bottomRight,
      child: Semantics(
        label: MapTilerConfig.attribution,
        child: Container(
          margin: const EdgeInsets.all(6),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          color: AppColors.warmWhite.withValues(alpha: 0.85),
          child: ExcludeSemantics(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                link('© MapTiler', MapTilerConfig.maptilerCopyright),
                Text(' ', style: style),
                link(
                  '© OpenStreetMap contributors',
                  MapTilerConfig.openStreetMapCopyright,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
