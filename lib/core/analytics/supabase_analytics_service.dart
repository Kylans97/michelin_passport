import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'analytics_event.dart';
import 'analytics_properties.dart';
import 'analytics_service.dart';

/// The narrow venue-link-click-tracking path — NOT the general analytics
/// vendor this app's "no vendor selected" contract (EVENTS_V2_ANALYTICS_
/// CONTRACT.md) is waiting on. This implementation only ever writes
/// [AnalyticsEvent.venueBookingLinkOpened]; every other [AnalyticsEvent]
/// is silently ignored, matching the explicit "alleen dit, niet de
/// volledige analyticslaag" scope this class was built under. Injected
/// only on Restaurant/Hotel Detail — every other screen still uses
/// [NoopAnalyticsService].
///
/// Writes to `public.venue_link_clicks`
/// (supabase/migrations/20260829120000_add_venue_link_click_tracking.sql)
/// — a table with no select policy for any client role at all ("deze
/// data is van mij, niet van de gebruiker"). This service only ever
/// inserts; it never reads that table back.
class SupabaseAnalyticsService implements AnalyticsService {
  SupabaseAnalyticsService(this._client);

  final SupabaseClient _client;

  // No identified-user state is kept: the click row's user_id comes
  // straight from the live Supabase auth session at insert time
  // (_client.auth.currentUser), never from a locally-cached identity —
  // there is nothing for identify()/resetIdentity() to do here.
  @override
  void identify(String userInternalId) {}

  @override
  void resetIdentity() {}

  /// Never throws, never awaited by the caller (matches the abstract
  /// `void track(...)` signature — there is no Future to await in the
  /// first place) — "faal nooit de navigatie als het loggen misgaat": a
  /// failed insert is caught and logged internally, never surfaced to
  /// whoever called [track].
  @override
  void track(AnalyticsEvent event, [AnalyticsProperties? properties]) {
    if (event != AnalyticsEvent.venueBookingLinkOpened) return;

    final venueType = properties?.entityType;
    final venueId = properties?.entityId;
    final destination = properties?.linkDestination;
    final sourceScreen = properties?.sourceScreen;

    // A missing required property is a caller bug, not a runtime case to
    // paper over with a guessed default — surfaced loudly in debug
    // builds, silently dropped in release (never a crash, matching the
    // "never fail navigation" rule for the class as a whole).
    assert(
      venueType != null &&
          venueId != null &&
          destination != null &&
          sourceScreen != null,
      'venueBookingLinkOpened requires entityType, entityId, '
      'linkDestination and sourceScreen',
    );
    if (venueType == null ||
        venueId == null ||
        destination == null ||
        sourceScreen == null) {
      return;
    }

    unawaited(
      _insertClick(
        venueType: venueType,
        venueId: venueId,
        destination: destination,
        sourceScreen: sourceScreen,
        eventId: properties?.eventId,
      ),
    );
  }

  Future<void> _insertClick({
    required AnalyticsEntityType venueType,
    required String venueId,
    required AnalyticsLinkDestination destination,
    required AnalyticsVenueDetailScreen sourceScreen,
    String? eventId,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return; // Signed out — RLS would reject it anyway.

    try {
      await _client.from('venue_link_clicks').insert({
        'user_id': userId,
        'venue_type': venueType.wireName,
        'venue_id': venueId,
        'destination': destination.wireName,
        'source_screen': sourceScreen.wireName,
        'event_id': ?eventId,
      });
    } catch (error, stackTrace) {
      debugPrint('VENUE LINK CLICK TRACK FAILED: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }
}
