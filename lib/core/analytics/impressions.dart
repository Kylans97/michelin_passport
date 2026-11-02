import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'analytics_properties.dart';

/// Where a card was shown. Matches `entity_impressions.surface`'s CHECK
/// (20261101250000_add_venue_insight_tracking.sql); extend both together,
/// in a new migration.
enum ImpressionSurface {
  explore,
  search,
  map,
  guides,
  rankings,
  events,
  wishlist,
  community,
  privateChefs;

  String get wireName => switch (this) {
    ImpressionSurface.explore => 'explore',
    ImpressionSurface.search => 'search',
    ImpressionSurface.map => 'map',
    ImpressionSurface.guides => 'guides',
    ImpressionSurface.rankings => 'rankings',
    ImpressionSurface.events => 'events',
    ImpressionSurface.wishlist => 'wishlist',
    ImpressionSurface.community => 'community',
    ImpressionSurface.privateChefs => 'private_chefs',
  };
}

/// Records that a card was shown in a list: "seen" for a venue's or
/// event's reach, next to the page opens that followed. Call it from a
/// card's build inside a lazily built list, which only builds what is on
/// or next to the screen.
///
/// The same card on the same surface counts once per [_window], so a
/// card rebuilt while scrolling is one impression, not twenty. Buffered
/// and sent in batches through `record_impressions`, which adds them up
/// per member per day: once [_maxBatch] are waiting, on the first card
/// seen [_flushAfter] after the last send, and when the app goes to the
/// background. No timer of its own, so nothing is left pending in a test.
/// Never throws, never awaited: a failed send is dropped, like every
/// other tracking call.
void trackImpression(
  AnalyticsEntityType type,
  String id,
  ImpressionSurface surface,
) => ImpressionBuffer.instance.add(type, id, surface);

class ImpressionBuffer with WidgetsBindingObserver {
  ImpressionBuffer._();

  static final instance = ImpressionBuffer._();

  static const _window = Duration(minutes: 30);
  static const _flushAfter = Duration(seconds: 20);
  static const _maxBatch = 200;

  final Map<String, DateTime> _lastSeen = {};
  final Map<String, Map<String, Object>> _pending = {};
  DateTime? _lastFlush;
  bool _observing = false;

  void add(AnalyticsEntityType type, String id, ImpressionSurface surface) {
    if (type != AnalyticsEntityType.restaurant &&
        type != AnalyticsEntityType.hotel &&
        type != AnalyticsEntityType.privateChef &&
        type != AnalyticsEntityType.event) {
      return;
    }
    final key = '${type.wireName}|$id|${surface.wireName}';
    final now = DateTime.now();
    final last = _lastSeen[key];
    if (last != null && now.difference(last) < _window) return;
    _lastSeen[key] = now;

    final item = _pending[key];
    if (item == null) {
      _pending[key] = {
        'entity_type': type.wireName,
        'entity_id': id,
        'surface': surface.wireName,
        'count': 1,
      };
    } else {
      item['count'] = (item['count'] as int) + 1;
    }

    if (!_observing) {
      _observing = true;
      WidgetsBinding.instance.addObserver(this);
    }
    final lastFlush = _lastFlush ??= now;
    if (_pending.length >= _maxBatch ||
        now.difference(lastFlush) >= _flushAfter) {
      unawaited(flush());
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      unawaited(flush());
    }
  }

  Future<void> flush() async {
    _lastFlush = DateTime.now();
    if (_pending.isEmpty) return;
    final items = _pending.values.toList();
    _pending.clear();
    try {
      final client = Supabase.instance.client;
      if (client.auth.currentUser == null) return;
      await client.rpc('record_impressions', params: {'p_items': items});
    } catch (error) {
      debugPrint('IMPRESSIONS TRACK FAILED: $error');
    }
  }

  @visibleForTesting
  int get pendingCount => _pending.length;

  @visibleForTesting
  void reset() {
    _lastFlush = null;
    _pending.clear();
    _lastSeen.clear();
  }
}
