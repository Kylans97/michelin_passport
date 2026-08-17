// Covers PrivateChefConnectSection — Instagram only, website only, both,
// neither (self-omitting), and that tapping fires the supplied callback
// (URL-opening itself is the screen's responsibility, not this widget's).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:michelin_passport/features/private_chefs/widgets/private_chef_connect_section.dart';

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  group('PrivateChefConnectSection', () {
    testWidgets('neither link -> omits itself entirely (no heading)', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap(const PrivateChefConnectSection()));
      expect(find.text('CONNECT'), findsNothing);
    });

    testWidgets('Instagram only', (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        _wrap(PrivateChefConnectSection(onTapInstagram: () => tapped = true)),
      );
      expect(find.text('CONNECT'), findsOneWidget);
      expect(find.text('Instagram'), findsOneWidget);
      expect(find.text('Website'), findsNothing);
      await tester.tap(find.text('Instagram'));
      expect(tapped, isTrue);
    });

    testWidgets('website only', (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        _wrap(PrivateChefConnectSection(onTapWebsite: () => tapped = true)),
      );
      expect(find.text('CONNECT'), findsOneWidget);
      expect(find.text('Website'), findsOneWidget);
      expect(find.text('Instagram'), findsNothing);
      await tester.tap(find.text('Website'));
      expect(tapped, isTrue);
    });

    testWidgets('both links render together', (tester) async {
      await tester.pumpWidget(
        _wrap(
          PrivateChefConnectSection(onTapInstagram: () {}, onTapWebsite: () {}),
        ),
      );
      expect(find.text('Instagram'), findsOneWidget);
      expect(find.text('Website'), findsOneWidget);
    });
  });
}
