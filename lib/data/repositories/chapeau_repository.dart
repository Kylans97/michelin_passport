import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';

/// What can receive a Chapeau (20261101860000): a restaurant visit or a
/// hotel stay ('visit'), or an event's confirmed attendance ('event_stamp').
enum ChapeauSubject {
  visit('visit'),
  eventStamp('event_stamp');

  const ChapeauSubject(this.wire);
  final String wire;
}

/// The Chapeaus on one item, as the viewer may see them.
class ChapeauSummary {
  final int count;
  final bool givenByMe;

  /// Up to three names, newest first.
  final List<String> recentNames;

  const ChapeauSummary({
    this.count = 0,
    this.givenByMe = false,
    this.recentNames = const [],
  });

  static const none = ChapeauSummary();

  ChapeauSummary toggled(String myName) => givenByMe
      ? ChapeauSummary(
          count: count > 0 ? count - 1 : 0,
          givenByMe: false,
          recentNames: [for (final n in recentNames) if (n != myName) n],
        )
      : ChapeauSummary(
          count: count + 1,
          givenByMe: true,
          recentNames: [myName, ...recentNames].take(3).toList(),
        );
}

/// Gives, takes back and reads Chapeaus. Reads made in the same frame are
/// sent as one call per kind of item, so a feed of many rows costs one
/// request, not one per row.
class ChapeauRepository {
  ChapeauRepository(this._client);

  final SupabaseClient _client;

  static final _pending = <ChapeauSubject, Map<String, Completer<ChapeauSummary>>>{};
  static Timer? _flush;

  Future<ChapeauSummary> summary(ChapeauSubject subject, String id) {
    final forKind = _pending.putIfAbsent(subject, () => {});
    final completer = forKind.putIfAbsent(id, Completer<ChapeauSummary>.new);
    _flush ??= Timer(Duration.zero, () => _send(_client));
    return completer.future;
  }

  static Future<void> _send(SupabaseClient client) async {
    _flush = null;
    final batch = Map.of(_pending);
    _pending.clear();
    for (final MapEntry(key: subject, value: waiting) in batch.entries) {
      try {
        final rows = await client.rpc(
          'get_chapeaus',
          params: {
            'p_subject_type': subject.wire,
            'p_subject_ids': waiting.keys.toList(),
          },
        );
        final byId = {
          for (final r in (rows as List).cast<Map<String, dynamic>>())
            r['subject_id'] as String: ChapeauSummary(
              count: (r['chapeau_count'] as num).toInt(),
              givenByMe: r['given_by_me'] as bool? ?? false,
              recentNames: [
                for (final n in (r['recent_names'] as List? ?? const [])) '$n',
              ],
            ),
        };
        for (final MapEntry(key: id, value: c) in waiting.entries) {
          c.complete(byId[id] ?? ChapeauSummary.none);
        }
      } catch (_) {
        // Before 20261101860000, or offline: no Chapeaus to show.
        for (final c in waiting.values) {
          if (!c.isCompleted) c.complete(ChapeauSummary.none);
        }
      }
    }
  }

  Future<void> give(ChapeauSubject subject, String id) => _client.rpc(
    'give_chapeau',
    params: {'p_subject_type': subject.wire, 'p_subject_id': id},
  );

  Future<void> takeBack(ChapeauSubject subject, String id) => _client.rpc(
    'take_back_chapeau',
    params: {'p_subject_type': subject.wire, 'p_subject_id': id},
  );
}
