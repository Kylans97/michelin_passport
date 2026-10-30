import 'dart:async';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/push/push_channel.dart';
import '../../data/repositories/notifications_repository.dart';
import '../../data/repositories/push_repository.dart';
import '../events/event_detail_screen.dart';
import 'notifications_screen.dart';
import 'push_prompt_sheet.dart';

/// The two writes the service makes, so tests can fake them without a
/// Supabase client. [PushRepository] is the real one.
abstract interface class PushDeviceStore {
  Future<void> registerDevice({
    required String token,
    required String apnsEnvironment,
    String? appVersion,
  });
  Future<void> unregisterDevice(String token);
}

class _RepositoryDeviceStore implements PushDeviceStore {
  PushRepository get _repo => PushRepository(Supabase.instance.client);

  @override
  Future<void> registerDevice({
    required String token,
    required String apnsEnvironment,
    String? appVersion,
  }) => _repo.registerDevice(
    token: token,
    apnsEnvironment: apnsEnvironment,
    appVersion: appVersion,
  );

  @override
  Future<void> unregisterDevice(String token) => _repo.unregisterDevice(token);
}

/// Push notifications, app side (20261030130000):
///
/// - **Registration.** Whenever a session exists and iOS allows
///   notifications, this device's APNs token is registered to the
///   signed-in account. Sign-out unregisters it first, while the session
///   can still prove whose token it is ([unregisterBeforeSignOut]).
/// - **Asking.** Never at launch. The first time a push would mean
///   something — following a venue, sending or accepting a friend request
///   — [askAfter] shows the app's own calm sheet, and only "Turn on" leads
///   to iOS's prompt, which iOS shows once per install. A yes there also
///   switches on the matching toggle in Notification settings, so the
///   sheet and the settings can never disagree (someone who turned
///   "Events from venues you follow" off and then says yes after a follow
///   gets it back on). "Not now" is remembered and never asked again;
///   Notification settings still offers it. For a follow the sheet is
///   the only feedback — the screens show no snackbar beside it.
/// - **Taps.** A friend request opens Notifications; a followed venue's
///   event opens that event and marks its notification read.
///
/// Best-effort throughout: nothing here may block or fail what the person
/// was doing, so every failure is swallowed.
class PushService {
  PushService({
    PushChannel? channel,
    PushDeviceStore? store,
    Future<SharedPreferences> Function()? preferences,
    Future<String?> Function()? appVersion,
    Future<void> Function(String notificationId)? markRead,
    Future<void> Function(PushPromptReason reason)? enablePreference,
  }) : _channel = channel ?? PushChannel(),
       _store = store ?? _RepositoryDeviceStore(),
       _preferences = preferences ?? SharedPreferences.getInstance,
       _appVersion = appVersion ?? _platformAppVersion,
       _markRead =
           markRead ??
           ((id) => NotificationsRepository(Supabase.instance.client).markAsRead(id)),
       _enablePreference = enablePreference ?? _enableStoredPreference;

  static final PushService instance = PushService();

  static const promptAnsweredKey = 'push_prompt_answered';

  final PushChannel _channel;
  final PushDeviceStore _store;
  final Future<SharedPreferences> Function() _preferences;
  final Future<String?> Function() _appVersion;
  final Future<void> Function(String notificationId) _markRead;
  final Future<void> Function(PushPromptReason reason) _enablePreference;

  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  /// The token registered to the current account, if any.
  String? get registeredToken => _registeredToken;
  String? _registeredToken;

  StreamSubscription<AuthState>? _authSubscription;
  bool _initialTapHandled = false;

  /// Wires taps and follows the session. Call once, after
  /// Supabase.initialize.
  void start({Stream<AuthState>? authStateChanges}) {
    _channel.setHandlers(onTap: _openFromPush, onForeground: (_) {});
    _authSubscription ??=
        (authStateChanges ?? Supabase.instance.client.auth.onAuthStateChange).listen((state) {
          if (state.session == null) {
            _registeredToken = null;
            return;
          }
          if (state.event == AuthChangeEvent.initialSession ||
              state.event == AuthChangeEvent.signedIn) {
            unawaited(syncRegistration());
            unawaited(_handleInitialTap());
          }
        });
  }

  /// Registers this device if iOS allows notifications. Safe to call any
  /// number of times: the server upserts on the token.
  Future<void> syncRegistration() async {
    try {
      if (await _channel.authorizationStatus() != PushAuthorization.authorized) return;
      final token = await _channel.deviceToken();
      if (token == null) return;
      await _store.registerDevice(
        token: token,
        apnsEnvironment: await _channel.apnsEnvironment(),
        appVersion: await _appVersion(),
      );
      _registeredToken = token;
    } catch (_) {
      // Best-effort: the next launch or sign-in tries again.
    }
  }

  /// Called just before signing out, while the session still exists.
  /// Bounded, so a slow network never holds up the sign-out itself.
  Future<void> unregisterBeforeSignOut() async {
    final token = _registeredToken;
    if (token == null) return;
    try {
      await _store.unregisterDevice(token).timeout(const Duration(seconds: 3));
    } catch (_) {
      // The token stays with the old account until the next sign-in on
      // this device moves it; send-push prunes it if iOS drops it.
    }
    _registeredToken = null;
  }

  /// Offers notifications after an action that makes them meaningful.
  /// Shows nothing unless iOS has never been asked and the person has
  /// never answered the app's own sheet.
  Future<void> askAfter(BuildContext context, PushPromptReason reason) async {
    try {
      if (await _channel.authorizationStatus() != PushAuthorization.notDetermined) return;
      final prefs = await _preferences();
      if (prefs.getBool(promptAnsweredKey) ?? false) return;
      if (!context.mounted) return;
      final accepted = await showPushPromptSheet(context, reason);
      await prefs.setBool(promptAnsweredKey, true);
      if (accepted == true && await requestFromSettings()) {
        await _enablePreference(reason);
      }
    } catch (_) {
      // Never let an offer break the action it followed.
    }
  }

  /// Same as [askAfter] for a venue the person just followed.
  Future<void> offerAfterFollow(BuildContext context, String venueName) =>
      askAfter(context, FollowedVenuePrompt(venueName));

  /// Shows iOS's prompt directly — the person asked for it — and
  /// registers on a yes.
  Future<bool> requestFromSettings() async {
    final granted = await _channel.requestAuthorization();
    if (granted) await syncRegistration();
    return granted;
  }

  Future<PushAuthorization> authorizationStatus() => _channel.authorizationStatus();

  Future<void> _handleInitialTap() async {
    if (_initialTapHandled) return;
    _initialTapHandled = true;
    final data = await _channel.takeInitialNotification();
    if (data == null) return;
    // Let the signed-in home screen mount before pushing over it.
    WidgetsBinding.instance.addPostFrameCallback((_) => _openFromPush(data));
  }

  void _openFromPush(Map<String, dynamic> data) {
    final navigator = navigatorKey.currentState;
    if (navigator == null) return;
    final route = routeForPush(data);
    if (route == null) return;
    final notificationId = data['notification_id'];
    if (data['type'] == 'followed_venue_event' && notificationId is String) {
      unawaited(_markRead(notificationId).catchError((_) {}));
    }
    navigator.push(route);
  }

  /// Where a tapped push leads. Null for anything unrecognised — a push
  /// from a newer server than this build, say — which then just opens
  /// the app.
  static Route<void>? routeForPush(Map<String, dynamic> data) {
    final subjectId = data['subject_id'];
    switch (data['type']) {
      case 'followed_venue_event':
        if (subjectId is! String) return null;
        return MaterialPageRoute(builder: (_) => EventDetailScreen(eventId: subjectId));
      case 'friend_request_received':
        return MaterialPageRoute(builder: (_) => const NotificationsScreen());
      default:
        return null;
    }
  }

  // Switches on the push toggle that matches what the person just said
  // yes to, leaving the other one as it was.
  static Future<void> _enableStoredPreference(PushPromptReason reason) async {
    final client = Supabase.instance.client;
    final uid = client.auth.currentUser?.id;
    if (uid == null) return;
    final repo = PushRepository(client);
    final current = await repo.getPreferences(uid);
    final next = switch (reason) {
      FollowedVenuePrompt() => current.copyWith(followedVenueEvents: true),
      FriendsPrompt() => current.copyWith(friendRequests: true),
    };
    if (next != current) await repo.savePreferences(uid, next);
  }

  static Future<String?> _platformAppVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      return '${info.version}+${info.buildNumber}';
    } catch (_) {
      return null;
    }
  }
}
