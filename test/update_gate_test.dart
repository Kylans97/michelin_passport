import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:michelin_passport/data/repositories/app_release_repository.dart';
import 'package:michelin_passport/features/update/update_gate.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('compareVersions', () {
    test('compares part by part as numbers', () {
      expect(compareVersions('1.9.0', '1.10.0'), -1);
      expect(compareVersions('1.10.0', '1.9.0'), 1);
      expect(compareVersions('1.9.0', '1.9.0'), 0);
      expect(compareVersions('1.9', '1.9.0'), 0);
      expect(compareVersions('2.0.0', '1.99.99'), 1);
    });

    test('a value that is not a version never prompts', () {
      expect(compareVersions('1.9.0', 'soon'), 0);
      expect(compareVersions('', '1.0.0'), 0);
    });
  });

  group('UpdateGate', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    Widget app(AppRelease? release, String version, {VoidCallback? onStore}) =>
        MaterialApp(
          home: UpdateGate(
            loadRelease: () async => release,
            currentVersion: () async => version,
            openStore: () async => onStore?.call(),
            child: const Scaffold(body: Text('The app')),
          ),
        );

    testWidgets('current version: nothing asked', (tester) async {
      await tester.pumpWidget(
        app(
          const AppRelease(latestVersion: '1.9.0', minimumVersion: '1.0.0'),
          '1.9.0',
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('The app'), findsOneWidget);
      expect(find.text('A new version of Mantelier'), findsNothing);
    });

    testWidgets('older than latest: a sheet once per version', (tester) async {
      var opened = 0;
      await tester.pumpWidget(
        app(
          const AppRelease(latestVersion: '1.10.0', minimumVersion: '1.0.0'),
          '1.9.0',
          onStore: () => opened++,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('A new version of Mantelier'), findsOneWidget);
      await tester.tap(find.text('Update'));
      await tester.pumpAndSettle();
      expect(opened, 1);
      expect(find.text('The app'), findsOneWidget);

      // A second launch for the same version asks nothing.
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(
        app(
          const AppRelease(latestVersion: '1.10.0', minimumVersion: '1.0.0'),
          '1.9.0',
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('A new version of Mantelier'), findsNothing);
    });

    testWidgets('below the minimum: only Update, the app hidden', (
      tester,
    ) async {
      await tester.pumpWidget(
        app(
          const AppRelease(latestVersion: '1.10.0', minimumVersion: '1.9.0'),
          '1.6.0',
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Time for an update'), findsOneWidget);
      expect(find.text('The app'), findsNothing);
      expect(find.text('Later'), findsNothing);
    });

    testWidgets('no row, or no answer: nothing asked', (tester) async {
      await tester.pumpWidget(app(null, '1.0.0'));
      await tester.pumpAndSettle();
      expect(find.text('The app'), findsOneWidget);
      expect(find.text('Time for an update'), findsNothing);
    });
  });
}
