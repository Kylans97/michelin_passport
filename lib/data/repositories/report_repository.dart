import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/content_report.dart';

/// A plain table insert (not an RPC, unlike friendship writes) — a
/// report has no state-machine subtlety, just row ownership, matching
/// `venue_corrections`' own insert-only shape. `content_reports_insert`
/// RLS requires `reporter_id = auth.uid()`, so [submitReport] resolves
/// the current user itself rather than asking every call site to pass it.
class ReportRepository {
  ReportRepository(this._client);

  final SupabaseClient _client;

  Future<void> submitReport({
    required ReportContentType contentType,
    required String contentId,
    required ReportReason reason,
    String? details,
  }) async {
    final reporterId = _client.auth.currentUser?.id;
    if (reporterId == null) throw StateError('Not authenticated');
    final trimmedDetails = details?.trim();
    await _client.from('content_reports').insert({
      'reporter_id': reporterId,
      'content_type': contentType.wireValue,
      'content_id': contentId,
      'reason': reason.wireValue,
      if (trimmedDetails != null && trimmedDetails.isNotEmpty)
        'details': trimmedDetails,
    });
  }
}
