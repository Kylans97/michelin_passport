import 'package:supabase_flutter/supabase_flutter.dart';

// AuthRepository wraps every Supabase Auth call so screens never import
// the Supabase package directly.  All methods throw on failure — callers
// catch and display the message.

class AuthRepository {
  AuthRepository(this._client);

  final SupabaseClient _client;

  // ── Current state ─────────────────────────────────────────────────────────

  User? get currentUser => _client.auth.currentUser;

  // Emits an AuthState whenever the session changes (sign-in, sign-out,
  // token refresh).  Feed this into a StreamBuilder to drive AuthGate.
  Stream<AuthState> get authStateChanges => _client.auth.onAuthStateChange;

  // ── Sign up ───────────────────────────────────────────────────────────────
  //
  // Passes display_name AND username in raw_user_meta_data so the DB
  // trigger (handle_new_user) can write both directly into profiles in the
  // same insert — one source of truth for profile creation, never a
  // second client-side INSERT. [username] must already be normalized
  // (UsernameRules.normalize) and pass UsernameRules.validate — the
  // profiles_username_format CHECK constraint is the real authority, but
  // client-side validation should always run first for UX.

  Future<void> signUp({
    required String email,
    required String password,
    required String displayName,
    required String username,
  }) async {
    try {
      final response = await _client.auth.signUp(
        email: email,
        password: password,
        data: {'display_name': displayName, 'username': username},
      );
      // Supabase returns a user even when email confirmation is required;
      // a null user means the request itself failed.
      if (response.user == null) {
        throw Exception('Sign-up failed — please try again.');
      }
    } on AuthException catch (e) {
      // handle_new_user()'s INSERT runs inside the same transaction as
      // account creation — a uniqueness/format violation there surfaces
      // here as the underlying Postgres error code (verified directly
      // against a local Supabase instance: GoTrue passes `code` through
      // unwrapped for this failure path, never a generic wrapper), not a
      // normal auth error. Translated to friendly copy so the raw
      // Postgres message never reaches the UI; re-thrown as a plain
      // AuthException so SignupScreen's existing `on AuthException catch
      // (e) => _error = e.message` handling needs no changes.
      if (e.code == '23505') {
        throw const AuthException('That username is already taken.');
      }
      if (e.code == '23514') {
        throw const AuthException(
          'Usernames are 3–30 characters: lowercase letters, numbers, '
          '"_" or "." only.',
        );
      }
      rethrow;
    }
  }

  // ── Sign in ───────────────────────────────────────────────────────────────

  Future<void> signIn({required String email, required String password}) async {
    await _client.auth.signInWithPassword(email: email, password: password);
  }

  // ── Sign out ──────────────────────────────────────────────────────────────

  Future<void> signOut() async {
    await _client.auth.signOut();
  }
}
