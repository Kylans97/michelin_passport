import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/event_tag.dart';
import '../../models/managed_venue.dart';
import '../../models/venue_event.dart';

/// A venue's own events (venue events phase 3, 20261018130000). Every
/// write goes through an RPC that checks is_active_venue_manager() and
/// validates the event server-side: the one-year window in the event's
/// own timezone, the V1 types and tags, and the time model. The client
/// never writes events or their links directly — no policy allows it.
class VenueEventsRepository {
  final SupabaseClient _client;
  VenueEventsRepository(this._client);

  /// Every event the venue hosts, in any status, for any of its managers.
  Future<List<VenueEvent>> loadVenueEvents(ManagedVenue venue) async {
    final rows = await _client.rpc(
      'get_venue_events',
      params: {'p_venue_type': venue.venueTypeWireValue, 'p_venue_id': venue.id},
    ) as List;
    final ids = [for (final r in rows) (r as Map)['id'].toString()];
    final tags = await _loadTagSlugs(ids);
    return [
      for (final r in rows)
        VenueEvent.fromJson(
          r as Map<String, dynamic>,
          tagSlugs: tags[r['id'].toString()] ?? const [],
        ),
    ];
  }

  // event_tag_assignments and event_tags are world-readable.
  Future<Map<String, List<String>>> _loadTagSlugs(List<String> eventIds) async {
    if (eventIds.isEmpty) return {};
    final rows = await _client
        .from('event_tag_assignments')
        .select('event_id, event_tags(slug)')
        .inFilter('event_id', eventIds);
    final out = <String, List<String>>{};
    for (final r in rows as List) {
      final slug = (r['event_tags'] as Map?)?['slug'] as String?;
      if (slug == null) continue;
      out.putIfAbsent(r['event_id'].toString(), () => []).add(slug);
    }
    return out;
  }

  Future<List<EventTag>> loadTags() async {
    final rows = await _client.from('event_tags').select('id, slug, name').order('name');
    return [for (final r in rows as List) EventTag.fromJson(r as Map<String, dynamic>)];
  }

  /// Every country with its timezones, by name.
  Future<List<EventCountry>> loadCountries() async {
    final rows = await _client
        .from('countries')
        .select('country_code, name, flag_emoji, timezones')
        .order('name');
    return [for (final r in rows as List) EventCountry.fromJson(r as Map<String, dynamic>)];
  }

  /// Creates the event, waiting for review. Returns its id.
  Future<String> submit(ManagedVenue venue, VenueEventDraft draft) async {
    final id = await _client.rpc(
      'submit_venue_event',
      params: {
        'p_venue_type': venue.venueTypeWireValue,
        'p_venue_id': venue.id,
        ...draft.toParams(),
      },
    );
    return id.toString();
  }

  /// Saves an edit. A live event stays live; a rejected one goes back to
  /// review.
  Future<void> update(String eventId, VenueEventDraft draft) => _client.rpc(
    'update_venue_event',
    params: {'p_event_id': eventId, ...draft.toParams()},
  );

  Future<void> cancel(String eventId) =>
      _client.rpc('cancel_venue_event', params: {'p_event_id': eventId});
}

/// The server's own message for a refused event (its validation speaks
/// to the venue directly), or a generic one for anything else.
String venueEventErrorMessage(Object error) {
  if (error is PostgrestException && error.code == 'P0001') return error.message;
  return 'Could not save the event. Please try again.';
}
