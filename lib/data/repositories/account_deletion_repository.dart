import 'package:supabase_flutter/supabase_flutter.dart';

/// Requests deletion of the CURRENT session's own account — the method
/// takes no user id and never can: the client can only ever ask "delete
/// me," identity is established server-side from the caller's own JWT
/// (`supabase.functions.invoke` forwards the current session's access
/// token automatically — no id is ever passed in a request body).
///
/// Backend status (2026-08-24): the `delete-account` Edge Function
/// (`supabase/functions/delete-account/index.ts`) now exists, is unit
/// tested (`index.test.ts`), and has been validated end-to-end against a
/// local Supabase stack with disposable test accounts — including a live
/// "malicious body" attack test confirming a caller cannot delete another
/// account by passing a target id. See
/// docs/Architecture/ACCOUNT_DELETION.md for the full dependency map,
/// security model, and deployment status. Production deployment is a
/// separate, explicitly gated step — check that document for whether it
/// has happened yet before assuming this is live in production.
class AccountDeletionRepository {
  AccountDeletionRepository(this._client);

  final SupabaseClient _client;

  Future<void> deleteCurrentAccount() async {
    try {
      final response = await _client.functions.invoke('delete-account');
      if (response.status != 200) {
        throw const AccountDeletionFailure(
          'Could not delete your account. Please try again.',
        );
      }
    } on AccountDeletionFailure {
      rethrow;
    } catch (_) {
      throw const AccountDeletionFailure(
        'Could not delete your account. Please try again.',
      );
    }
  }
}

/// A restrained, user-facing failure — never a raw Postgrest/Functions
/// exception surfaced to the UI (same rule every other repository in this
/// app follows for its own error messages).
class AccountDeletionFailure implements Exception {
  final String message;
  const AccountDeletionFailure(this.message);

  @override
  String toString() => message;
}
