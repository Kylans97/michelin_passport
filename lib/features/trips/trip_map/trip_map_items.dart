import 'dart:ui';

import 'package:latlong2/latlong.dart';
import '../../../models/event.dart';
import '../../../models/passport_venue.dart';

/// One thing on the trip map: a catalogue venue or an event.
sealed class TripMapItem {
  const TripMapItem();

  LatLng get point;

  /// Unique across venues and events, for selection.
  String get key;
}

class TripMapVenueItem extends TripMapItem {
  final PassportVenue venue;
  @override
  final LatLng point;

  /// Already planned on this trip, by anyone on it.
  final bool planned;

  const TripMapVenueItem(this.venue, this.point, {this.planned = false});

  String get id => switch (venue) {
    RestaurantVenue(:final restaurant) => restaurant.id,
    HotelVenue(:final hotel) => hotel.id,
  };

  bool get isHotel => venue is HotelVenue;

  @override
  String get key => '${isHotel ? 'h' : 'r'}:$id';
}

class TripMapEventItem extends TripMapItem {
  final Event event;
  @override
  final LatLng point;

  const TripMapEventItem(this.event, this.point);

  @override
  String get key => 'e:${event.id}';
}

/// Items close enough on screen to draw as one marker. A cluster of one is
/// drawn as the item itself.
class TripMapCluster {
  final List<TripMapItem> items;

  const TripMapCluster(this.items);

  LatLng get center {
    var lat = 0.0;
    var lng = 0.0;
    for (final item in items) {
      lat += item.point.latitude;
      lng += item.point.longitude;
    }
    return LatLng(lat / items.length, lng / items.length);
  }
}

/// Groups [items] into clusters on a square grid of [cellSize] pixels at
/// the current zoom. [project] maps a coordinate to world pixels at that
/// zoom (flutter_map's `camera.projectAtZoom`), so the grid stays put
/// while the map pans and clusters only change when the zoom does.
///
/// Planned items and events are never folded into a cluster: they're what
/// a traveller looks for first, so they always keep their own marker.
List<TripMapCluster> clusterTripMapItems(
  List<TripMapItem> items,
  Offset Function(LatLng point) project, {
  double cellSize = 56,
}) {
  final cells = <(int, int), List<TripMapItem>>{};
  final standalone = <TripMapCluster>[];
  for (final item in items) {
    final alwaysOwn =
        item is TripMapEventItem || (item is TripMapVenueItem && item.planned);
    if (alwaysOwn) {
      standalone.add(TripMapCluster([item]));
      continue;
    }
    final p = project(item.point);
    final cell = ((p.dx / cellSize).floor(), (p.dy / cellSize).floor());
    (cells[cell] ??= []).add(item);
  }
  return [
    for (final members in cells.values) TripMapCluster(members),
    ...standalone,
  ];
}

/// From this zoom a place on the trip, or an event, shows its name.
const tripMapPriorityLabelZoom = 12.0;

/// From this zoom every other place shows its name too.
const tripMapLabelZoom = 14.0;

/// Which side of its pin a name sits on.
enum TripMapLabelSide { right, left }

/// Which items show their name at [zoom], and on which side of the pin:
/// the selected item first, then planned places, then events, then the
/// rest. A name goes to the right of its pin, or to the left when that
/// would run into a name already placed or another marker; with neither
/// free, it stays hidden until the map is zoomed in further.
///
/// [items] are the markers drawn on their own, [obstacles] where the
/// numbered clusters are, both in the world pixels of [project].
/// [labelWidth] is a name's width in pixels. Pure, so the choice can be
/// tested without a map.
Map<String, TripMapLabelSide> pickTripMapLabels(
  List<TripMapItem> items, {
  required double zoom,
  required Offset Function(LatLng point) project,
  required double Function(TripMapItem item) labelWidth,
  List<Offset> obstacles = const [],
  String? selectedKey,
  double pinRadius = 14,
  double labelHeight = 16,
  double gap = 4,
}) {
  int rank(TripMapItem item) {
    if (item.key == selectedKey) return 0;
    if (item is TripMapVenueItem && item.planned) return 1;
    if (item is TripMapEventItem) return 2;
    return 3;
  }

  Rect pinAt(Offset c) => Rect.fromCircle(center: c, radius: pinRadius);

  final ranked = items.indexed.toList()
    ..sort((a, b) {
      final byRank = rank(a.$2).compareTo(rank(b.$2));
      return byRank != 0 ? byRank : a.$1.compareTo(b.$1);
    });
  final centers = {for (final item in items) item.key: project(item.point)};
  final taken = <Rect>[];
  final picked = <String, TripMapLabelSide>{};

  for (final (_, item) in ranked) {
    final r = rank(item);
    final due =
        r == 0 ||
        zoom >= (r == 3 ? tripMapLabelZoom : tripMapPriorityLabelZoom);
    if (!due) continue;

    final center = centers[item.key]!;
    final width = labelWidth(item);
    bool free(Rect rect) =>
        !taken.any(rect.overlaps) &&
        !obstacles.any((o) => pinAt(o).overlaps(rect)) &&
        !centers.entries.any(
          (e) => e.key != item.key && pinAt(e.value).overlaps(rect),
        );

    final top = center.dy - labelHeight / 2;
    final right = Rect.fromLTWH(
      center.dx + pinRadius + gap,
      top,
      width,
      labelHeight,
    );
    final left = Rect.fromLTWH(
      center.dx - pinRadius - gap - width,
      top,
      width,
      labelHeight,
    );
    if (free(right)) {
      picked[item.key] = TripMapLabelSide.right;
      taken.add(right);
    } else if (free(left)) {
      picked[item.key] = TripMapLabelSide.left;
      taken.add(left);
    }
  }
  return picked;
}
