// Covers PushService — registration, the one-time pre-prompt, sign-out
// unregistering, and where a tapped push leads. The native side is faked
// with a mock MethodChannel handler and the two writes with a hand-rolled
// store, so no Supabase or device is involved.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:michelin_passport/core/push/push_channel.dart';
import 'package:michelin_passport/features/events/event_detail_screen.dart';
import 'package:michelin_passport/features/notifications/notifications_screen.dart';
import 'package:michelin_passport/features/notifications/push_prompt_sheet.dart';
import 'package:michelin_passport/features/notifications/push_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _channelName = 'app.mantelier/push';
const _token = 'ab12ab12ab12ab12ab12ab12ab12ab12ab12ab12ab12ab12ab12ab12ab12ab12';

class _FakeStore implements PushDeviceStore {
  final registered = <Map<String, String?>>[];
  final unregistered = <String>[];
  bool failRegister = false;

  @override
  Future<void> registerDevice({
    required String token,
    required String apnsEnvironment,
    String? appVersion,
  }) async {
    if (failRegister) throw Exception('offline');
    registered.add({'token': token, 'env': apnsEnvironment, 'version': appVersion});
  }

  @override
  Future<void> unregisterDevice(String token) async => unregistered.add(token);
}

/// The native plugin's answers, and a log of what was asked.
class _FakeNative {
  String status = 'notDetermined';
  bool grant = true;
  String? token = _token;
  final calls = <String>[];

  Future<Object?> handle(MethodCall call) async {
    calls.add(call.method);
    switch (call.method) {
      case 'getAuthorizationStatus':
        return status;
      case 'requestAuthorization':
        status = grant ? 'authorized' : 'denied';
        return grant;
      case 'registerForRemoteNotifications':
        if (token == null) throw PlatformException(code: 'register_failed');
        return token;
      case 'getApnsEnvironment':
        return 'sandbox';
      case 'takeInitialNotification':
        return null;
    }
    return null;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel(_channelName);
  late _FakeNative native;
  late _FakeStore store;
  late PushService service;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    native = _FakeNative();
    store = _FakeStore();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, native.handle);
    service = PushService(
      channel: PushChannel(channel: channel),
      store: store,
      appVersion: () async => '1.5.0+18',
      markRead: (_) async {},
    );
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  group('registration', () {
    test('registers the token, environment and version once allowed', () async {
      native.status = 'authorized';
      await service.syncRegistration();
      expect(store.registered, [
        {'token': _token, 'env': 'sandbox', 'version': '1.5.0+18'},
      ]);
      expect(service.registeredToken, _token);
    });

    test('never registers, or asks iOS, while not allowed', () async {
      for (final status in ['notDetermined', 'denied']) {
        native.status = status;
        await service.syncRegistration();
      }
      expect(store.registered, isEmpty);
      expect(native.calls, isNot(contains('registerForRemoteNotifications')));
      expect(native.calls, isNot(contains('requestAuthorization')));
    });

    test('a build that cannot get a token registers nothing and does not throw', () async {
      native.status = 'authorized';
      native.token = null;
      await service.syncRegistration();
      expect(store.registered, isEmpty);
    });

    test('a failed write is swallowed and not remembered as registered', () async {
      native.status = 'authorized';
      store.failRegister = true;
      await service.syncRegistration();
      expect(service.registeredToken, isNull);
    });

    test('sign-out unregisters the registered token, once', () async {
      native.status = 'authorized';
      await service.syncRegistration();
      await service.unregisterBeforeSignOut();
      await service.unregisterBeforeSignOut();
      expect(store.unregistered, [_token]);
      expect(service.registeredToken, isNull);
    });
  });

  group('asking', () {
    Future<void> pumpAsker(WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () =>
                  service.askAfter(context, const FollowedVenuePrompt('Hof van Cleve')),
              child: const Text('Follow'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Follow'));
      await tester.pumpAndSettle();
    }

    testWidgets('offers the app sheet first, and iOS prompt only on Turn on', (tester) async {
      await pumpAsker(tester);
      expect(find.text('Hear about new events'), findsOneWidget);
      expect(find.textContaining('Hof van Cleve announces an event'), findsOneWidget);
      expect(native.calls, isNot(contains('requestAuthorization')));

      await tester.tap(find.text('Turn on notifications'));
      await tester.pumpAndSettle();
      expect(native.calls, contains('requestAuthorization'));
      expect(store.registered.single['token'], _token);
    });

    testWidgets('Not now is remembered and never asked again', (tester) async {
      await pumpAsker(tester);
      await tester.tap(find.text('Not now'));
      await tester.pumpAndSettle();
      expect(native.calls, isNot(contains('requestAuthorization')));

      await tester.tap(find.text('Follow'));
      await tester.pumpAndSettle();
      expect(find.text('Hear about new events'), findsNothing);
    });

    testWidgets('shows nothing once iOS has already been answered', (tester) async {
      native.status = 'denied';
      await pumpAsker(tester);
      expect(find.byType(PushPromptSheet), findsNothing);
    });
  });

  group('taps', () {
    test('a followed venue event opens that event', () {
      final route = PushService.routeForPush({
        'type': 'followed_venue_event',
        'subject_id': 'event-1',
      });
      expect(route, isA<MaterialPageRoute<void>>());
    });

    test('a friend request opens Notifications; anything unknown opens nothing', () {
      expect(PushService.routeForPush({'type': 'friend_request_received'}), isNotNull);
      expect(PushService.routeForPush({'type': 'from_a_newer_server'}), isNull);
      expect(PushService.routeForPush({'type': 'followed_venue_event'}), isNull);
    });

    testWidgets('the routes build the right screens', (tester) async {
      final event = PushService.routeForPush({
        'type': 'followed_venue_event',
        'subject_id': 'event-1',
      }) as MaterialPageRoute<void>;
      final friends =
          PushService.routeForPush({'type': 'friend_request_received'}) as MaterialPageRoute<void>;
      late BuildContext context;
      await tester.pumpWidget(Builder(builder: (c) => const SizedBox()));
      context = tester.element(find.byType(SizedBox));
      final eventScreen = event.builder(context);
      expect(eventScreen, isA<EventDetailScreen>());
      expect((eventScreen as EventDetailScreen).eventId, 'event-1');
      expect(friends.builder(context), isA<NotificationsScreen>());
    });
  });
}
