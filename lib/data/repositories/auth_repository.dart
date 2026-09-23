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
      // MT001 — check_username_not_blocked() trigger (username
      // blocklist migration). A reserved name or a blocked term,
      // distinct from "taken"/"bad format" above.
      if (e.code == 'MT001') {
        throw const AuthException('That username is not allowed.');
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

  // ── Change password ─────────────────────────────────────────────────────
  //
  // Supabase's updateUser() never asks for the current password — it trusts
  // the caller's access token alone. That's not enough here: an unattended,
  // already-unlocked phone would let anyone holding it lock the real owner
  // out. So this re-authenticates with [currentPassword] first (the only
  // password-verification primitive GoTrue actually exposes — there's no
  // "check this password without changing the session" endpoint) and only
  // calls updateUser() if that succeeds. A wrong [currentPassword] surfaces
  // as its own AuthException here rather than GoTrue's generic "Invalid
  // login credentials", so ChangePasswordScreen can show a message that
  // actually matches what the user just typed in the wrong field.
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final email = currentUser?.email;
    if (email == null) {
      throw const AuthException(
        'You need to be signed in to change your password.',
      );
    }
    try {
      await _client.auth.signInWithPassword(
        email: email,
        password: currentPassword,
      );
    } on AuthException {
      throw const AuthException('Current password is incorrect.');
    }
    await _client.auth.updateUser(UserAttributes(password: newPassword));
    // A password change is often prompted by suspecting someone else has
    // access — if their session on another device just kept working, the
    // change accomplished nothing. SignOutScope.others revokes every
    // session except this one and (per gotrue's own doc comment on the
    // enum) never fires a signedOut event on the current session, so this
    // can't accidentally log the person out of the screen they're on.
    await _client.auth.signOut(scope: SignOutScope.others);
  }
}
