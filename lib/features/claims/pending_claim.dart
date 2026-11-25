import 'dart:async';
import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Whether this phone came from the website's venue guide and should open
/// the venue explainer (VenueClaimIntroScreen) once someone is signed in.
///
/// The guide's Download button points at `mantelier.app/claim`. With the
/// app installed that is a Universal Link (`/claim` in
/// apple-app-site-association) and arrives here directly. Without it, the
/// site's /claim page copies the link on the tap and sends them to the
/// App Store; after installing, the entrance's Paste (InviteLinkBanner)
/// finds it, the same handoff invitation links use (PendingInvite). iOS
/// passes nothing through an App Store install by itself, and App Store
/// link parameters reach only App Store Connect's analytics.
///
/// Kept on the device (shared_preferences), so it survives the sign-up
/// steps and a restart. It opens the explainer only; a claim is still a
/// request reviewed by hand, and nothing here grants anything.
class PendingClaim {
  PendingClaim._();

  static final PendingClaim instance = PendingClaim._();

  static const _prefsKey = 'pending_venue_claim';

  /// True while the explainer is waiting to be shown.
  final ValueNotifier<bool> waiting = ValueNotifier<bool>(false);

  StreamSubscription<Uri>? _links;

  /// Reads a flag kept from an earlier launch and starts listening for
  /// `mantelier.app/claim` links. Called once from main().
  Future<void> start() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool(_prefsKey) ?? false) waiting.value = true;
    } catch (_) {
      // Nothing stored is the same as nothing waiting.
    }
    try {
      _links = AppLinks().uriLinkStream.listen((uri) {
        if (isClaimLink(uri.toString())) unawaited(set());
      });
    } catch (_) {
      // Tests and platforms without the plugin: links simply don't arrive.
    }
  }

  Future<void> set() async {
    waiting.value = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefsKey, true);
    } catch (_) {}
  }

  Future<void> clear() async {
    waiting.value = false;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_prefsKey);
    } catch (_) {}
  }

  @visibleForTesting
  Future<void> dispose() async => _links?.cancel();
}

/// Whether [text] holds the venue guide's link, `mantelier.app/claim`
/// (with or without a scheme, `www.`, a trailing slash or a query).
bool isClaimLink(String? text) {
  if (text == null) return false;
  return RegExp(
    r'(^|[^A-Za-z0-9.])(www\.)?mantelier\.app/claim/?($|[?#\s])',
  ).hasMatch(text.trim());
}
