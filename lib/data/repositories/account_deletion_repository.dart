import 'package:supabase_flutter/supabase_flutter.dart';

/// Requests deletion of the CURRENT session's own account — the method
/// takes no user id and never can: the client can only ever ask "delete
/// me," identity is established server-side from the caller's own JWT.
///
/// Backend status (audited 2026-08-23): no `delete-account` Edge Function
/// exists in this project yet (`supabase/functions/` does not exist), so
/// calling this in production today always fails — honestly, via
/// [AccountDeletionFailure], never a false success. See
/// docs/Architecture/NAVIGATION_INFORMATION_ARCHITECTURE_V2.md's Account
/// Deletion section for the audited FK/cascade/Storage findings and the
/// required Edge Function contract, which is intentionally NOT
/// implemented here — deploying a privileged, destructive server-side
/// deletion endpoint is a separate, controlled sub-step, not something to
/// bundle silently into a UI workstream.
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
