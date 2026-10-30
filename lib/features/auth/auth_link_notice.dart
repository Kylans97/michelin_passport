import 'package:supabase_flutter/supabase_flutter.dart';

// What LoginScreen says when an emailed auth link (sign-up confirmation or
// password reset) opened the app but did not end in a session.
//
// supabase_flutter handles the Universal Link itself (SupabaseAuth.
// _handleDeeplink → getSessionFromUrl) and reports a failure only as an
// error on onAuthStateChange — it never hands the URL itself to the app, so
// the copy below has to be right for either kind of link. Two facts make
// that possible:
//
// - GoTrue's /verify endpoint confirms the email (or accepts the recovery
//   token) BEFORE redirecting to the app with `?code=`. A failure after
//   that point — the PKCE code verifier missing (link opened after a
//   reinstall), or the code already exchanged — means the link itself
//   worked; only the automatic sign-in didn't.
// - A link that fails at /verify (already used, or past its expiry)
//   arrives as `#error_code=otp_expired`, which getSessionFromUrl surfaces
//   as an AuthException whose `statusCode` (not `code` — gotrue maps
//   error_code there) is 'otp_expired'. GoTrue reports both cases with the
//   same code, so the copy can't tell them apart either.
//
// Anything else returns null: the same stream also carries errors that
// have nothing to do with a link (a failed session refresh, say), and
// telling someone "that link failed" when they tapped no link would be
// worse than saying nothing.
enum AuthLinkNotice { expiredOrUsed, verifiedSignInNeeded }

AuthLinkNotice? authLinkNoticeFor(Object error) {
  if (error is! AuthException) return null;
  if (error.statusCode == 'otp_expired') {
    return AuthLinkNotice.expiredOrUsed;
  }
  if (error.message.contains('Code verifier could not be found') ||
      const {
        'flow_state_not_found',
        'flow_state_expired',
        'bad_code_verifier',
      }.contains(error.code)) {
    return AuthLinkNotice.verifiedSignInNeeded;
  }
  return null;
}

extension AuthLinkNoticeCopy on AuthLinkNotice {
  String get message => switch (this) {
    AuthLinkNotice.expiredOrUsed =>
      'That link has expired or has already been used. If you have '
          'already confirmed your email, just sign in below.',
    AuthLinkNotice.verifiedSignInNeeded =>
      'That link was accepted — if you were confirming your email, it is '
          'confirmed. Sign in below to continue.',
  };
}
