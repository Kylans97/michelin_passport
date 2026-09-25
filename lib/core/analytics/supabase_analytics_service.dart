import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'analytics_event.dart';
import 'analytics_properties.dart';
import 'analytics_service.dart';

/// The narrow venue-link-click-tracking path, plus News V1's own equally
/// narrow "article opened" tracking, plus venue-invite send/respond
/// tracking — NOT the general analytics vendor this app's "no vendor
/// selected" contract (EVENTS_V2_ANALYTICS_CONTRACT.md) is waiting on.
/// This implementation only ever writes [AnalyticsEvent.venueBookingLinkOpened],
/// [AnalyticsEvent.newsArticleOpened], and [AnalyticsEvent.venueInviteSent]/
/// `Accepted`/`Declined`; every other [AnalyticsEvent] is silently
/// ignored, matching the explicit "alleen dit, niet de volledige
/// analyticslaag" scope this class was built under. Injected only on
/// Restaurant/Hotel Detail, News Article Detail, the "suggest going
/// together" sheet, and Notifications' accept/decline handlers — every
/// other screen still uses [NoopAnalyticsService].
///
/// Writes to `public.venue_link_clicks`
/// (supabase/migrations/20260829120000_add_venue_link_click_tracking.sql),
/// `public.news_article_opens`
/// (supabase/migrations/20260918140000_add_news_v1.sql), and
/// `public.venue_invite_events`
/// (supabase/migrations/20260925150000_add_venue_invite_event_tracking.sql)
/// — all three tables with no select policy for any client role at all
/// ("deze data is van mij, niet van de gebruiker"). This service only
/// ever inserts; it never reads any of them back.
class SupabaseAnalyticsService implements AnalyticsService {
  SupabaseAnalyticsService(this._client);

  final SupabaseClient _client;

  // No identified-user state is kept: every inserted row's user_id comes
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
    switch (event) {
      case AnalyticsEvent.venueBookingLinkOpened:
        _trackVenueBookingLinkOpened(properties);
      case AnalyticsEvent.newsArticleOpened:
        _trackNewsArticleOpened(properties);
      case AnalyticsEvent.venueInviteSent:
        _trackVenueInviteEvent('sent', properties);
      case AnalyticsEvent.venueInviteAccepted:
        _trackVenueInviteEvent('accepted', properties);
      case AnalyticsEvent.venueInviteDeclined:
        _trackVenueInviteEvent('declined', properties);
      default:
        return;
    }
  }

  void _trackVenueBookingLinkOpened(AnalyticsProperties? properties) {
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

  void _trackNewsArticleOpened(AnalyticsProperties? properties) {
    final articleId = properties?.entityId;

    assert(
      articleId != null,
      'newsArticleOpened requires entityId (the article id)',
    );
    if (articleId == null) return;

    unawaited(_insertNewsArticleOpen(articleId: articleId));
  }

  void _trackVenueInviteEvent(String action, AnalyticsProperties? properties) {
    final inviteId = properties?.inviteId;
    final venueType = properties?.entityType;
    final venueId = properties?.entityId;

    assert(
      inviteId != null && venueType != null && venueId != null,
      'venueInvite$action requires inviteId, entityType and entityId',
    );
    if (inviteId == null || venueType == null || venueId == null) return;

    unawaited(
      _insertVenueInviteEvent(
        inviteId: inviteId,
        action: action,
        venueType: venueType,
        venueId: venueId,
      ),
    );
  }

  Future<void> _insertVenueInviteEvent({
    required String inviteId,
    required String action,
    required AnalyticsEntityType venueType,
    required String venueId,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return; // Signed out — RLS would reject it anyway.

    try {
      await _client.from('venue_invite_events').insert({
        'user_id': userId,
        'invite_id': inviteId,
        'action': action,
        'venue_type': venueType.wireName,
        'venue_id': venueId,
      });
    } catch (error, stackTrace) {
      debugPrint('VENUE INVITE EVENT TRACK FAILED: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
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

  Future<void> _insertNewsArticleOpen({required String articleId}) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return; // Signed out — RLS would reject it anyway.

    try {
      // Plain insert, no .select() — news_article_opens has no select
      // policy for authenticated by design ("deze data is van mij"), and
      // requesting a returned representation (Prefer: return=
      // representation) would need one; a bare insert only needs the
      // insert policy's own WITH CHECK to pass.
      await _client.from('news_article_opens').insert({
        'user_id': userId,
        'article_id': articleId,
      });
    } catch (error, stackTrace) {
      debugPrint('NEWS ARTICLE OPEN TRACK FAILED: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }
}
