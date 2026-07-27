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
  // Passes display_name in raw_user_meta_data so the DB trigger
  // (handle_new_user) can write it directly into profiles.display_name.

  Future<void> signUp({
    required String email,
    required String password,
    required String displayName,
  }) async {
    final response = await _client.auth.signUp(
      email: email,
      password: password,
      data: {'display_name': displayName},
    );
    // Supabase returns a user even when email confirmation is required;
    // a null user means the request itself failed.
    if (response.user == null) {
      throw Exception('Sign-up failed — please try again.');
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
