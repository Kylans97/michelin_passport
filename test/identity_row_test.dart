// Covers IdentityRow (Social Foundation Step 1) — the shared avatar+name+
// @username row used by Friends list, Requests, search results, and the
// Friend/Non-Friend Profile header. A genuinely standalone public widget,
// pumped directly rather than reconstructed.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:michelin_passport/core/constants/app_colors.dart';
import 'package:michelin_passport/features/friends/widgets/identity_row.dart';

Widget _wrap(Widget child) => MaterialApp(
  home: Scaffold(backgroundColor: AppColors.ivory, body: child),
);

void main() {
  group('IdentityRow', () {
    testWidgets('renders label and @username', (tester) async {
      await tester.pumpWidget(
        _wrap(const IdentityRow(label: 'User B', username: 'userb')),
      );
      expect(find.text('User B'), findsOneWidget);
      expect(find.text('@userb'), findsOneWidget);
    });

    testWidgets('renders initials from the label when no avatar is set', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(const IdentityRow(label: 'Kylan Scheepstra')),
      );
      expect(find.text('KS'), findsOneWidget);
    });

    testWidgets('never renders gold — name is forest-green, initials match', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(const IdentityRow(label: 'Kylan Scheepstra')),
      );
      final name = tester.widget<Text>(find.text('Kylan Scheepstra'));
      final initials = tester.widget<Text>(find.text('KS'));
      expect(name.style?.color, AppColors.forestGreen);
      expect(name.style?.color, isNot(AppColors.gold));
      expect(initials.style?.color, AppColors.forestGreen);
      expect(initials.style?.color, isNot(AppColors.gold));
    });

    testWidgets('strips a leading "@" fallback label before computing '
        'initials', (tester) async {
      await tester.pumpWidget(_wrap(const IdentityRow(label: '@userb')));
      expect(find.text('U'), findsOneWidget);
    });

    testWidgets('omits the username line entirely when null', (tester) async {
      await tester.pumpWidget(_wrap(const IdentityRow(label: 'No Username')));
      expect(find.textContaining('@'), findsNothing);
    });

    testWidgets('tapping fires onTap when provided', (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        _wrap(IdentityRow(label: 'User B', onTap: () => tapped = true)),
      );
      await tester.tap(find.text('User B'));
      expect(tapped, isTrue);
    });

    testWidgets('is not wrapped in InkWell when onTap is omitted', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap(const IdentityRow(label: 'User B')));
      expect(find.byType(InkWell), findsNothing);
    });

    testWidgets('renders a trailing widget when provided', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const IdentityRow(
            label: 'User B',
            trailing: Text('Add', key: Key('trailing')),
          ),
        ),
      );
      expect(find.byKey(const Key('trailing')), findsOneWidget);
    });

    testWidgets('320px width, long name — no overflow', (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 844));
      await tester.pumpWidget(
        _wrap(
          const IdentityRow(
            label: 'A Very Long Display Name That Keeps Going',
            username: 'a_very_long_username_indeed',
            trailing: Text('Add'),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      await tester.binding.setSurfaceSize(null);
    });

    testWidgets('1.6x text scale — no overflow', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(1.6)),
            child: Scaffold(
              backgroundColor: AppColors.ivory,
              body: const IdentityRow(
                label: 'User B',
                username: 'userb',
                trailing: Text('Add'),
              ),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
    });
  });
}
