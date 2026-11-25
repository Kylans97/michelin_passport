import 'dart:async';
import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/invite_link.dart';

/// The invitation waiting to be answered on this phone: the token from a
/// `mantelier.app/i/<token>` link, kept until the person accepts, says not
/// now, or it turns out to be unusable.
///
/// It arrives three ways: the link opened the app (Universal Link, `/i/*`
/// in apple-app-site-association), the person pasted it on the entrance
/// after installing (the web page copied it on their tap), or they typed
/// its code under Friends. Kept on the device (shared_preferences), so it
/// survives the sign-up steps and an app restart in between. Nothing is
/// read from the clipboard without a tap: [clipboardMayHoldText] asks only
/// whether there is text, which iOS answers without a paste prompt.
class PendingInvite {
  PendingInvite._();

  static final PendingInvite instance = PendingInvite._();

  static const _prefsKey = 'pending_invite_token';

  /// The waiting token, or null.
  final ValueNotifier<String?> token = ValueNotifier<String?>(null);

  StreamSubscription<Uri>? _links;

  /// Reads a token kept from an earlier launch and starts listening for
  /// invitation links. Called once from main().
  Future<void> start() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      token.value ??= prefs.getString(_prefsKey);
    } catch (_) {
      // No stored token is the same as none.
    }
    try {
      // app_links delivers the link that launched the app on this stream
      // too, then every later one.
      _links = AppLinks().uriLinkStream.listen((uri) {
        final t = inviteTokenFrom(uri.toString());
        if (t != null) unawaited(set(t));
      });
    } catch (_) {
      // Tests and platforms without the plugin: links simply don't arrive.
    }
  }

  Future<void> set(String value) async {
    token.value = value;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKey, value);
    } catch (_) {}
  }

  Future<void> clear() async {
    token.value = null;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_prefsKey);
    } catch (_) {}
  }

  /// Whether the clipboard holds text, without reading it (no paste
  /// prompt on iOS).
  Future<bool> clipboardMayHoldText() async {
    try {
      return await Clipboard.hasStrings();
    } catch (_) {
      return false;
    }
  }

  /// Reads the clipboard, on the person's tap (iOS asks them first), and
  /// keeps the invitation in it. Returns false when there is none.
  ///
  /// [alsoAccept] sees the same text first, so one read (and one iOS
  /// prompt) also serves the venue guide's `mantelier.app/claim`
  /// (PendingClaim); it returns true when it took the text.
  Future<bool> pasteFromClipboard({
    Future<bool> Function(String text)? alsoAccept,
  }) async {
    try {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      final text = data?.text;
      if (text != null && alsoAccept != null && await alsoAccept(text)) {
        return true;
      }
      final t = inviteTokenFrom(text);
      if (t == null) return false;
      await set(t);
      return true;
    } catch (_) {
      return false;
    }
  }

  @visibleForTesting
  Future<void> dispose() async => _links?.cancel();
}
