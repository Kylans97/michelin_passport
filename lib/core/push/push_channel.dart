import 'package:flutter/services.dart';

/// What iOS currently allows. `provisional` (quiet delivery) counts as
/// allowed: the token is the same and the person can promote it in
/// Settings.
enum PushAuthorization {
  notDetermined,
  denied,
  authorized;

  static PushAuthorization fromWire(String? value) => switch (value) {
    'authorized' || 'provisional' => PushAuthorization.authorized,
    'denied' => PushAuthorization.denied,
    _ => PushAuthorization.notDetermined,
  };
}

/// The native side of push — `PushNotificationsPlugin` in
/// ios/Runner/AppDelegate.swift. Platform-neutral on purpose: on any
/// platform without that plugin every call reports "not available"
/// rather than throwing, so callers need no platform checks.
class PushChannel {
  PushChannel({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel('app.mantelier/push');

  final MethodChannel _channel;

  Future<PushAuthorization> authorizationStatus() async {
    try {
      return PushAuthorization.fromWire(
        await _channel.invokeMethod<String>('getAuthorizationStatus'),
      );
    } on MissingPluginException {
      return PushAuthorization.denied;
    }
  }

  /// Shows iOS's own permission prompt (only ever the first time; after
  /// that iOS answers with the stored choice and shows nothing).
  Future<bool> requestAuthorization() async {
    try {
      return await _channel.invokeMethod<bool>('requestAuthorization') ?? false;
    } on MissingPluginException {
      return false;
    }
  }

  /// The APNs device token as lowercase hex, or null when this build
  /// can't register (no push entitlement, simulator without APNs).
  Future<String?> deviceToken() async {
    try {
      return await _channel.invokeMethod<String>('registerForRemoteNotifications');
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    }
  }

  /// 'sandbox' or 'production' — which APNs host the token belongs to.
  Future<String> apnsEnvironment() async {
    try {
      return await _channel.invokeMethod<String>('getApnsEnvironment') ?? 'production';
    } on MissingPluginException {
      return 'production';
    }
  }

  /// The tap that launched the app, if any. Also tells the native side
  /// that taps may now be delivered through [setHandlers].
  Future<Map<String, dynamic>?> takeInitialNotification() async {
    try {
      final raw = await _channel.invokeMethod<Map<Object?, Object?>>('takeInitialNotification');
      return raw?.map((k, v) => MapEntry(k.toString(), v));
    } on MissingPluginException {
      return null;
    }
  }

  void setHandlers({
    required void Function(Map<String, dynamic> data) onTap,
    required void Function(Map<String, dynamic> data) onForeground,
  }) {
    _channel.setMethodCallHandler((call) async {
      final raw = call.arguments;
      final data = raw is Map
          ? raw.map((k, v) => MapEntry(k.toString(), v))
          : <String, dynamic>{};
      switch (call.method) {
        case 'onNotificationTap':
          onTap(data);
        case 'onForegroundNotification':
          onForeground(data);
      }
    });
  }
}
