import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// AuthRepository wraps every Supabase Auth call so screens never import
// the Supabase package directly.  All methods throw on failure — callers
// catch and display the message.

class AuthRepository {
  AuthRepository(this._client);

  final SupabaseClient _client;

  // The Universal Link (iOS Associated Domains + Android App Link, both
  // scoped to this one path — see the AASA on mantelier.app and the
  // AndroidManifest intent-filter) that GoTrue's password-recovery email
  // ultimately redirects to. Must exactly match an entry in
  // supabase/config.toml's additional_redirect_urls — GoTrue rejects a
  // redirectTo that isn't on that allow-list.
  static const _passwordRecoveryRedirectUrl =
      'https://mantelier.app/auth/reset-password';

  // Where the sign-up confirmation email lands — the same Universal Link
  // arrangement as above, on its own path. Without an explicit
  // emailRedirectTo GoTrue falls back to the project's Site URL, which in
  // production was still Supabase's default http://localhost:3000: the
  // account got confirmed, then the phone's browser showed "cannot connect
  // to the server". Must also be on the redirect allow-list, or GoTrue
  // silently falls back to the Site URL again.
  static const signupConfirmationRedirectUrl =
      'https://mantelier.app/auth/confirm';

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
    String? homeCountryCode,
  }) async {
    try {
      final response = await _client.auth.signUp(
        email: email,
        password: password,
        // handle_new_user keeps home_country_code only when it's a known
        // country (20261101210000), so a bad one can't fail sign-up.
        data: {
          'display_name': displayName,
          'username': username,
          'home_country_code': ?homeCountryCode,
        },
        emailRedirectTo: signupConfirmationRedirectUrl,
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

  // ── Sign in with Apple ──────────────────────────────────────────────────
  //
  // Native Sign in with Apple (sign_in_with_apple), then Supabase's
  // signInWithIdToken: no browser, no web secret. The nonce Apple signs is
  // the SHA-256 of a random value only this call knows; Supabase checks it
  // against the raw value, so a stolen identity token can't be replayed.
  //
  // Returns false when the member cancelled the Apple sheet, so the screen
  // can stay quiet instead of showing an error.
  //
  // Apple shares the name only the first time someone signs in to the app;
  // it is written to the account's metadata then, so the profile setup
  // step can offer it. The authorization code is handed to the
  // apple-token function (best-effort) so the account's Apple link can be
  // revoked when the account is deleted, as App Review requires.
  Future<bool> signInWithApple() async {
    final rawNonce = _randomNonce();
    final hashedNonce = sha256.convert(utf8.encode(rawNonce)).toString();
    final AuthorizationCredentialAppleID credential;
    try {
      credential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        nonce: hashedNonce,
      );
    } on SignInWithAppleAuthorizationException catch (e) {
      if (e.code == AuthorizationErrorCode.canceled) return false;
      rethrow;
    }
    final idToken = credential.identityToken;
    if (idToken == null) {
      throw const AuthException('Apple did not return a sign-in token.');
    }
    await _client.auth.signInWithIdToken(
      provider: OAuthProvider.apple,
      idToken: idToken,
      nonce: rawNonce,
    );
    final name = [
      credential.givenName,
      credential.familyName,
    ].whereType<String>().where((s) => s.trim().isNotEmpty).join(' ').trim();
    if (name.isNotEmpty) {
      try {
        await _client.auth.updateUser(
          UserAttributes(data: {'apple_name': name}),
        );
      } catch (_) {
        // Only a convenience for the profile setup step.
      }
    }
    final code = credential.authorizationCode;
    if (code.isNotEmpty) {
      try {
        await _client.functions.invoke(
          'apple-token',
          body: {'authorization_code': code},
        );
      } catch (_) {
        // Best-effort: without it, deleting the account still deletes it,
        // only the Apple link is left for the member to remove in Settings.
      }
    }
    return true;
  }

  // ── Link Apple to the signed-in account ──────────────────────────────────
  //
  // For a member who already has an account (a password, or an email code)
  // and wants to sign in with Apple too, also when Apple hides their email
  // (product owner, 2026-11-22, after a hidden-email Apple sign-in on the
  // website made a second, empty account). linkIdentityWithIdToken adds the
  // Apple identity to the current user; it needs "Allow manual linking" on
  // in the project's Auth settings. The authorization code goes to
  // apple-token as at sign-in, so deleting the account revokes Apple too.

  /// Whether an Apple identity is linked to the signed-in account.
  Future<bool> hasAppleLinked() async {
    final identities = await _client.auth.getUserIdentities();
    return identities.any((i) => i.provider == 'apple');
  }

  /// Returns false when the member cancelled Apple's sheet.
  Future<bool> linkApple() async {
    final rawNonce = _randomNonce();
    final hashedNonce = sha256.convert(utf8.encode(rawNonce)).toString();
    final AuthorizationCredentialAppleID credential;
    try {
      credential = await SignInWithApple.getAppleIDCredential(
        scopes: const [],
        nonce: hashedNonce,
      );
    } on SignInWithAppleAuthorizationException catch (e) {
      if (e.code == AuthorizationErrorCode.canceled) return false;
      rethrow;
    }
    final idToken = credential.identityToken;
    if (idToken == null) {
      throw const AuthException('Apple did not return a sign-in token.');
    }
    try {
      await _client.auth.linkIdentityWithIdToken(
        provider: OAuthProvider.apple,
        idToken: idToken,
        nonce: rawNonce,
      );
    } on AuthException catch (e) {
      if (e.code == 'identity_already_exists') {
        throw const AuthException(
          'This Apple ID already belongs to another Mantelier account.',
        );
      }
      if (e.code == 'manual_linking_disabled') {
        throw const AuthException(
          'Linking Apple isn\'t available yet. Please try again later.',
        );
      }
      rethrow;
    }
    final code = credential.authorizationCode;
    if (code.isNotEmpty) {
      try {
        await _client.functions.invoke(
          'apple-token',
          body: {'authorization_code': code},
        );
      } catch (_) {
        // Best-effort, as at sign-in.
      }
    }
    return true;
  }

  static String _randomNonce([int length = 32]) {
    const chars =
        '0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._';
    final random = Random.secure();
    return List.generate(
      length,
      (_) => chars[random.nextInt(chars.length)],
    ).join();
  }

  // ── Sign in with a code by email ────────────────────────────────────────
  //
  // Passwordless: GoTrue emails a six digit code (the Magic Link and
  // Confirm signup templates must contain {{ .Token }}), which the member
  // types back in. shouldCreateUser: a new address becomes a new account;
  // its profile has no username yet, so AuthGate asks for one before the
  // app opens (ProfileSetupScreen). Like resetPasswordForEmail, this never
  // reveals whether the address already had an account.
  Future<void> sendEmailCode(String email) async {
    await _client.auth.signInWithOtp(email: email, shouldCreateUser: true);
  }

  Future<void> verifyEmailCode({
    required String email,
    required String code,
  }) async {
    await _client.auth.verifyOTP(
      email: email,
      token: code,
      type: OtpType.email,
    );
  }

  // ── Resend sign-up confirmation ─────────────────────────────────────────
  //
  // For an account whose confirmation link expired or never arrived —
  // offered by LoginScreen when sign-in fails with email_not_confirmed.
  //
  // Lands on a different, web-only path from signUp()'s: gotrue-dart's
  // resend() sends no PKCE code challenge (GoTrue's /resend accepts one,
  // the client just never passes it), so the new link comes back as an
  // implicit-flow #access_token that supabase_flutter, in PKCE mode,
  // ignores. Opening the app with it would show the sign-in screen with no
  // explanation; the web page says the account is confirmed instead.
  static const resentConfirmationRedirectUrl =
      'https://mantelier.app/auth/confirmed';

  Future<void> resendSignupConfirmation(String email) async {
    await _client.auth.resend(
      type: OtpType.signup,
      email: email,
      emailRedirectTo: resentConfirmationRedirectUrl,
    );
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

  // ── Forgot password ──────────────────────────────────────────────────────
  //
  // Always resolves the same way regardless of whether [email] actually
  // belongs to an account — GoTrue itself never reveals account existence
  // through this endpoint, and LoginScreen's own copy stays equally neutral
  // ("if that address is registered..."), so this never becomes a way to
  // probe which emails have accounts.
  Future<void> resetPasswordForEmail(String email) async {
    await _client.auth.resetPasswordForEmail(
      email,
      redirectTo: _passwordRecoveryRedirectUrl,
    );
  }

  // ── Complete password recovery ──────────────────────────────────────────
  //
  // Called from ResetPasswordScreen, reached only via AuthGate's own
  // AuthChangeEvent.passwordRecovery handling — by the time this runs, the
  // recovery link has already produced a valid (temporary) session proving
  // the person controls the account's inbox, so unlike changePassword()
  // there is no separate "current password" to verify first.
  //
  // Same reasoning as changePassword() for what happens next: a reset is
  // often prompted by suspecting someone else has access, so every OTHER
  // session is revoked first (SignOutScope.others — never fires signedOut
  // on this one). Then, per an explicit decision (not GoTrue's default):
  // this recovery session itself is also ended, returning the person to
  // LoginScreen to sign in fresh with the new password, rather than
  // dropping them straight into the app on the same session that proved
  // identity via a possibly-compromised inbox.
  Future<void> completePasswordRecovery(String newPassword) async {
    await _client.auth.updateUser(UserAttributes(password: newPassword));
    await _client.auth.signOut(scope: SignOutScope.others);
    await _client.auth.signOut();
  }
}
