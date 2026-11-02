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
