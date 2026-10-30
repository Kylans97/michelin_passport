// Covers NotificationSettingsScreen: the two push toggles, and what
// iOS's own permission state shows above them. Everything is
// constructor-injected (hand-rolled fakes, same pattern as
// privacy_settings_screen_test.dart), so the real widget is pumped.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:michelin_passport/core/push/push_channel.dart';
import 'package:michelin_passport/features/notifications/notification_settings_screen.dart';
import 'package:michelin_passport/models/notification_preferences.dart';

Widget _wrap({
  NotificationPreferences prefs = const NotificationPreferences(),
  PushAuthorization status = PushAuthorization.authorized,
  Future<void> Function(NotificationPreferences)? save,
  Future<bool> Function()? request,
  Future<void> Function()? openSettings,
  Future<PushAuthorization> Function()? statusFn,
}) => MaterialApp(
  home: NotificationSettingsScreen(
    loadPreferences: () async => prefs,
    savePreferences: save ?? (_) async {},
    authorizationStatus: statusFn ?? () async => status,
    requestPermission: request ?? () async => true,
    openSystemSettings: openSettings ?? () async {},
  ),
);

void main() {
  testWidgets('both toggles default to on', (tester) async {
    await tester.pumpWidget(_wrap());
    await tester.pumpAndSettle();
    expect(find.text('Friend requests'), findsOneWidget);
    expect(find.text('Events from venues you follow'), findsOneWidget);
    final switches = tester.widgetList<Switch>(find.byType(Switch));
    expect(switches.map((s) => s.value), [true, true]);
    expect(find.text('Turn on notifications'), findsNothing);
  });

  testWidgets('turning one off saves only that change', (tester) async {
    final saved = <NotificationPreferences>[];
    await tester.pumpWidget(_wrap(save: (p) async => saved.add(p)));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(Switch).last);
    await tester.pumpAndSettle();
    expect(saved, [const NotificationPreferences(followedVenueEvents: false)]);
    final switches = tester.widgetList<Switch>(find.byType(Switch));
    expect(switches.map((s) => s.value), [true, false]);
  });

  testWidgets('a failed save leaves the switch where it was', (tester) async {
    await tester.pumpWidget(_wrap(save: (_) async => throw Exception('offline')));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(Switch).first);
    await tester.pumpAndSettle();
    expect(tester.widgetList<Switch>(find.byType(Switch)).first.value, isTrue);
    expect(find.text('Could not update. Please try again.'), findsOneWidget);
  });

  testWidgets('never asked: the switches read off, and turning one on goes to iOS '
      'and keeps it on once allowed', (tester) async {
    var status = PushAuthorization.notDetermined;
    var requested = 0;
    final saved = <NotificationPreferences>[];
    await tester.pumpWidget(
      _wrap(
        prefs: const NotificationPreferences(followedVenueEvents: false),
        save: (p) async => saved.add(p),
        statusFn: () async => status,
        request: () async {
          requested++;
          status = PushAuthorization.authorized;
          return true;
        },
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Turn on notifications'), findsNothing);
    expect(tester.widgetList<Switch>(find.byType(Switch)).map((s) => s.value), [false, false]);

    await tester.tap(find.byType(Switch).last);
    await tester.pumpAndSettle();
    expect(requested, 1);
    expect(saved, [const NotificationPreferences()]);
    expect(tester.widgetList<Switch>(find.byType(Switch)).map((s) => s.value), [true, true]);
  });

  testWidgets('never asked, and iOS says no: nothing is saved', (tester) async {
    var status = PushAuthorization.notDetermined;
    final saved = <NotificationPreferences>[];
    await tester.pumpWidget(
      _wrap(
        save: (p) async => saved.add(p),
        statusFn: () async => status,
        request: () async {
          status = PushAuthorization.denied;
          return false;
        },
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byType(Switch).first);
    await tester.pumpAndSettle();
    expect(saved, isEmpty);
    expect(find.textContaining('turned off for this app in iOS Settings'), findsOneWidget);
  });

  testWidgets('turned off in iOS: one line and Open Settings, no toggles', (tester) async {
    var opened = 0;
    await tester.pumpWidget(
      _wrap(status: PushAuthorization.denied, openSettings: () async => opened++),
    );
    await tester.pumpAndSettle();
    expect(find.byType(Switch), findsNothing);
    expect(find.textContaining('turned off for this app in iOS Settings'), findsOneWidget);
    await tester.tap(find.text('Open Settings'));
    expect(opened, 1);
  });

  testWidgets('a failed load offers Retry', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: NotificationSettingsScreen(
          loadPreferences: () async => throw Exception('offline'),
          authorizationStatus: () async => PushAuthorization.authorized,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Could not load your notification settings'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
  });
}
