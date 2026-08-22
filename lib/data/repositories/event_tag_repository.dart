import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/event_tag.dart';

/// Events V2 Discovery Taxonomy Phase B — reads `public.event_tags`/
/// `public.event_tag_assignments` (Phase A schema, additive — see
/// `supabase/migrations/20260823120000_events_v2_discovery_taxonomy_phase_a.sql`).
/// Public catalogue-style read-only data, same convention as
/// EventsRepository/RestaurantRepository: no write methods here, tags are
/// curated server-side, never authored by app users in this slice (Phase
/// A pre-apply's own tag-governance decision).
class EventTagRepository {
  EventTagRepository(this._client);

  final SupabaseClient _client;

  /// Every curated tag, for a future Phase C picker to render — 6 rows
  /// today, bounded regardless of catalogue size (a fixed taxonomy, not a
  /// per-Event fetch).
  Future<List<EventTag>> loadAllTags() async {
    final rows = await _client.from('event_tags').select('id, slug, name');
    return [
      for (final row in rows as List)
        EventTag.fromJson(row as Map<String, dynamic>),
    ];
  }

  /// Every distinct `event_id` carrying at least one of [slugs] (OR
  /// within the Theme/Tag dimension — Phase B §6). Exactly two queries
  /// regardless of how many Events exist or how many total assignments
  /// there are: [slugs] -> matching `event_tags.id`s, then those ids ->
  /// matching `event_tag_assignments.event_id`s — never one query per
  /// slug, per tag, or per Event (Phase B §11's own "no full per-Event
  /// taxonomy fetch" requirement). An empty [slugs] input returns an
  /// empty set without querying at all — the caller's own job is to skip
  /// calling this when the Theme dimension isn't active, matching
  /// [applyDiscoveryFilters]'s "empty selection = no restriction"
  /// contract; this method never tries to guess that intent itself.
  Future<Set<String>> loadEventIdsForTagSlugs(Set<String> slugs) async {
    if (slugs.isEmpty) return {};

    final tagRows = await _client
        .from('event_tags')
        .select('id')
        .inFilter('slug', slugs.toList());
    final tagIds = [for (final row in tagRows as List) row['id'] as String];
    if (tagIds.isEmpty) return {};

    final assignmentRows = await _client
        .from('event_tag_assignments')
        .select('event_id')
        .inFilter('tag_id', tagIds);
    return {
      for (final row in assignmentRows as List) row['event_id'] as String,
    };
  }
}
