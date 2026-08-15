// Covers VisitPrivacyToggle (Social Foundation Step 2's "Visible to
// friends" control on visit/stay creation and editing). Pumped directly —
// it's pure presentation, no Supabase dependency.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:michelin_passport/features/visits/widgets/visit_privacy_toggle.dart';

Widget _wrap(Widget child, {double width = 390}) => MaterialApp(
  home: Scaffold(
    body: SizedBox(
      width: width,
      child: Center(child: child),
    ),
  ),
);

void main() {
  group('VisitPrivacyToggle', () {
    testWidgets('OFF state shows the copy and an unchecked switch', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(VisitPrivacyToggle(friendsVisible: false, onChanged: (_) {})),
      );
      expect(find.text('Visible to friends'), findsOneWidget);
      expect(
        find.text('Friends can see this visit, your rating and photos.'),
        findsOneWidget,
      );
      final Switch sw = tester.widget(find.byType(Switch));
      expect(sw.value, isFalse);
    });

    testWidgets('ON state shows a checked switch', (tester) async {
      await tester.pumpWidget(
        _wrap(VisitPrivacyToggle(friendsVisible: true, onChanged: (_) {})),
      );
      final Switch sw = tester.widget(find.byType(Switch));
      expect(sw.value, isTrue);
    });

    testWidgets('tapping the row while OFF fires onChanged(true)', (
      tester,
    ) async {
      var lastValue = false;
      var calls = 0;
      await tester.pumpWidget(
        _wrap(
          VisitPrivacyToggle(
            friendsVisible: false,
            onChanged: (v) {
              lastValue = v;
              calls++;
            },
          ),
        ),
      );
      await tester.tap(find.text('Visible to friends'));
      expect(calls, 1);
      expect(lastValue, isTrue);
    });

    testWidgets('tapping the switch while ON fires onChanged(false)', (
      tester,
    ) async {
      var lastValue = true;
      await tester.pumpWidget(
        _wrap(
          VisitPrivacyToggle(
            friendsVisible: true,
            onChanged: (v) => lastValue = v,
          ),
        ),
      );
      await tester.tap(find.byType(Switch));
      expect(lastValue, isFalse);
    });

    testWidgets('never renders technical terms', (tester) async {
      await tester.pumpWidget(
        _wrap(VisitPrivacyToggle(friendsVisible: false, onChanged: (_) {})),
      );
      final texts = tester.widgetList<Text>(find.byType(Text));
      for (final t in texts) {
        final value = (t.data ?? '').toLowerCase();
        expect(value.contains('rls'), isFalse);
        expect(value.contains('visibility'), isFalse);
        expect(value.contains('row policy'), isFalse);
      }
    });

    testWidgets('320px width — no overflow', (tester) async {
      await tester.pumpWidget(
        _wrap(
          VisitPrivacyToggle(friendsVisible: false, onChanged: (_) {}),
          width: 320,
        ),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('1.6x text scale — no overflow', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(1.6)),
            child: Scaffold(
              body: SizedBox(
                width: 320,
                child: VisitPrivacyToggle(
                  friendsVisible: true,
                  onChanged: (_) {},
                ),
              ),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
    });
  });
}
