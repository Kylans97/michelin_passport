import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'analytics_properties.dart';

/// Records which of a venue's published photos a member had on screen in
/// its gallery during one visit (`venue_photo_views`,
/// 20261101250000_add_venue_insight_tracking.sql). One insert per visit,
/// never awaited; a failure is swallowed, like every tracking call.
void trackVenuePhotosSeen(
  AnalyticsEntityType venueType,
  String venueId,
  List<String> photoIds,
) {
  if (photoIds.isEmpty) return;
  unawaited(_insert(venueType, venueId, photoIds));
}

Future<void> _insert(
  AnalyticsEntityType venueType,
  String venueId,
  List<String> photoIds,
) async {
  try {
    final client = Supabase.instance.client;
    final userId = client.auth.currentUser?.id;
    if (userId == null) return;
    await client.from('venue_photo_views').insert([
      for (final id in photoIds)
        {
          'user_id': userId,
          'venue_type': venueType.wireName,
          'venue_id': venueId,
          'photo_id': id,
        },
    ]);
  } catch (error) {
    debugPrint('PHOTO VIEWS TRACK FAILED: $error');
  }
}
