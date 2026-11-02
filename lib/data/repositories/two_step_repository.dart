import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// One authenticator app linked to the account (a verified TOTP factor).
class TwoStepFactor {
  final String id;
  final String? name;
  final DateTime addedAt;

  const TwoStepFactor({required this.id, this.name, required this.addedAt});
}

/// A set-up in progress: what goes into the authenticator app, before the
/// first code confirms it.
class TwoStepEnrollment {
  final String factorId;

  /// The otpauth:// link — opens the authenticator app (Passwords on
  /// iPhone) with Mantelier filled in.
  final String uri;

  /// The same key, for typing in by hand.
  final String secret;

  const TwoStepEnrollment({
    required this.factorId,
    required this.uri,
    required this.secret,
  });
}

/// Keeps only the digits of a typed or pasted code ("123 456" → "123456").
String twoStepDigits(String input) => input.replaceAll(RegExp(r'[^0-9]'), '');

/// The secret in groups of four, easier to type over ("ABCD EFGH …").
String twoStepGroupedSecret(String secret) {
  final clean = secret.replaceAll(' ', '');
  final groups = <String>[];
  for (var i = 0; i < clean.length; i += 4) {
    groups.add(clean.substring(i, i + 4 > clean.length ? clean.length : i + 4));
  }
  return groups.join(' ');
}

/// True when [session] belongs to an account with two-step sign-in on but
/// hasn't had its code entered yet: the token says aal1 and the user has a
/// verified factor. Read from the session itself, not the network, so
/// AuthGate can decide on every auth event without waiting.
bool sessionNeedsTwoStep(Session session) {
  final hasFactor =
      session.user.factors?.any((f) => f.status == FactorStatus.verified) ??
      false;
  if (!hasFactor) return false;
  return _aalOf(session.accessToken) != 'aal2';
}

String? _aalOf(String jwt) {
  final parts = jwt.split('.');
  if (parts.length != 3) return null;
  try {
    final payload = jsonDecode(
      utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
    );
    return payload is Map ? payload['aal'] as String? : null;
  } catch (_) {
    return null;
  }
}

/// Two-step sign-in with an authenticator app (TOTP, Supabase Auth MFA).
/// No phone numbers and no email codes, by decision (2026-11-02): an
/// authenticator app is free, stores nothing extra about the member, and
/// on iPhone the Passwords app fills the code in by itself.
///
/// A member can link more than one authenticator, so a second one is a
/// backup if a phone is lost. A code from any of them signs in, and a code
/// from any of them is needed to remove one — removing the last turns
/// two-step sign-in off.
class TwoStepRepository {
  TwoStepRepository(this._auth);

  final GoTrueClient _auth;

  /// The verified authenticators, oldest first.
  Future<List<TwoStepFactor>> factors() async {
    final response = await _auth.mfa.listFactors();
    final list =
        response.totp
            .map(
              (f) => TwoStepFactor(
                id: f.id,
                name: f.friendlyName,
                addedAt: f.createdAt,
              ),
            )
            .toList()
          ..sort((a, b) => a.addedAt.compareTo(b.addedAt));
    return list;
  }

  /// Starts linking an authenticator. A set-up left unfinished earlier is
  /// removed first, so the key on screen is always the one that counts.
  Future<TwoStepEnrollment> start() async {
    final response = await _auth.mfa.listFactors();
    for (final f in response.all) {
      if (f.status != FactorStatus.verified) {
        await _auth.mfa.unenroll(f.id);
      }
    }
    // Supabase wants a different name per factor.
    final taken = response.all.map((f) => f.friendlyName).toSet();
    var name = 'Authenticator';
    for (var i = 2; taken.contains(name); i++) {
      name = 'Authenticator $i';
    }
    final enrolled = await _auth.mfa.enroll(
      factorType: FactorType.totp,
      issuer: 'Mantelier',
      friendlyName: name,
    );
    final totp = enrolled.totp!;
    return TwoStepEnrollment(
      factorId: enrolled.id,
      uri: totp.uri,
      secret: totp.secret,
    );
  }

  /// Confirms a new authenticator with its first code. The session is then
  /// fully signed in (aal2).
  Future<void> confirm(String factorId, String code) => _auth.mfa
      .challengeAndVerify(factorId: factorId, code: twoStepDigits(code));

  /// The code step after the password. Tries each linked authenticator,
  /// since the member doesn't know — and shouldn't have to — which one the
  /// code came from. Throws if none accepts it.
  Future<void> verifySignIn(String code) async {
    final digits = twoStepDigits(code);
    final linked = await factors();
    if (linked.isEmpty) return;
    Object? lastError;
    for (final f in linked) {
      try {
        await _auth.mfa.challengeAndVerify(factorId: f.id, code: digits);
        return;
      } catch (e) {
        lastError = e;
      }
    }
    throw lastError ?? const AuthException('Invalid code');
  }

  /// Removes one authenticator, after a code from any linked one.
  Future<void> remove(String factorId, String code) async {
    await verifySignIn(code);
    await _auth.mfa.unenroll(factorId);
  }

  Future<void> signOut() => _auth.signOut();
}

/// What a code field accepts: digits only, six at most. A pasted "123 456"
/// keeps its digits.
final twoStepCodeFormatters = <TextInputFormatter>[
  FilteringTextInputFormatter.digitsOnly,
  LengthLimitingTextInputFormatter(6),
];
