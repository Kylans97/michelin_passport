// Covers FriendRequestRow, the shared incoming-request row used by both
// FriendsScreen's Requests tab and NotificationsScreen. Unlike those two
// screens it has no Supabase dependency, so the real widget is pumped.
//
// Widths here are not device widths: tests render GoogleFonts text in
// the square-glyph test font, which makes "Decline" 122px against 74px
// in real Inter. So these assert "never overflows" and "stacks when
// tight, inline when roomy", not where the switch happens on a phone.
// The real-font thresholds were measured once with the Inter files
// (see friend_request_row.dart's _minNameWidth comment).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:michelin_passport/core/constants/app_colors.dart';
import 'package:michelin_passport/core/theme/cs_spacing.dart';
import 'package:michelin_passport/features/friends/widgets/friend_request_row.dart';

// Same horizontal page padding both screens' lists use.
Widget _wrap(Widget row, {double textScale = 1.0}) => MaterialApp(
  home: MediaQuery(
    data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
    child: Scaffold(
      backgroundColor: AppColors.ivory,
      body: ListView(
        padding: const EdgeInsets.symmetric(
          horizontal: CsSpacing.pageHorizontal,
        ),
        children: [row],
      ),
    ),
  ),
);

FriendRequestRow _row({
  String label = 'User B',
  VoidCallback? onAccept,
  VoidCallback? onDecline,
}) => FriendRequestRow(
  label: label,
  username: 'userb',
  onTap: () {},
  onAccept: onAccept ?? () {},
  onDecline: onDecline ?? () {},
);

Future<void> _pumpAt(
  WidgetTester tester,
  Size size,
  Widget child, {
  double textScale = 1.0,
}) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(_wrap(child, textScale: textScale));
}

bool _sideBySide(WidgetTester tester) =>
    tester.getCenter(find.text('Decline')).dy ==
    tester.getCenter(find.text('Accept')).dy;

void main() {
  testWidgets('Decline and Accept fire their own callbacks', (tester) async {
    var accepted = false;
    var declined = false;
    await _pumpAt(
      tester,
      const Size(390, 844),
      _row(onAccept: () => accepted = true, onDecline: () => declined = true),
    );
    await tester.tap(find.text('Accept'));
    expect(accepted, isTrue);
    expect(declined, isFalse);
    await tester.tap(find.text('Decline'));
    expect(declined, isTrue);
  });

  testWidgets('inline beside the name when there is room', (tester) async {
    await _pumpAt(tester, const Size(600, 844), _row());
    expect(tester.takeException(), isNull);
    expect(_sideBySide(tester), isTrue);
  });

  testWidgets('320px with normal text: no overflow', (tester) async {
    await _pumpAt(tester, const Size(320, 844), _row());
    expect(tester.takeException(), isNull);
  });

  // The case that overflowed by 75px before this widget existed.
  testWidgets('320px with 1.6x text: stacks instead of overflowing', (
    tester,
  ) async {
    await _pumpAt(tester, const Size(320, 844), _row(), textScale: 1.6);
    expect(tester.takeException(), isNull);
    expect(_sideBySide(tester), isFalse);
    // Decline above Accept, both still tappable.
    expect(
      tester.getCenter(find.text('Decline')).dy,
      lessThan(tester.getCenter(find.text('Accept')).dy),
    );
  });

  testWidgets('320px with 2.0x text and a long name: no overflow', (
    tester,
  ) async {
    await _pumpAt(
      tester,
      const Size(320, 844),
      _row(label: 'A Very Long Display Name That Keeps Going'),
      textScale: 2.0,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('the name keeps room at the narrowest case', (tester) async {
    await _pumpAt(
      tester,
      const Size(320, 844),
      _row(label: 'A Very Long Display Name That Keeps Going'),
      textScale: 1.6,
    );
    final name = tester.getSize(
      find.text('A Very Long Display Name That Keeps Going'),
    );
    expect(name.width, greaterThanOrEqualTo(56));
  });
}
