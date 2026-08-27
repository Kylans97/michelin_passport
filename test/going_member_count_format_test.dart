// Events V2 Step 7 — covers formatGoingMemberCount and GoingMemberCount
// (lib/features/events/going_member_count_format.dart,
// lib/models/going_member_count.dart): the exact 0-hidden / 1-99-exact /
// 100+-capped display contract, with no Supabase dependency.
//
// This file cannot prove the SERVER never sends the true count once it
// reaches 100 or more — that guarantee lives in the SQL function itself
// (get_event_going_member_count, validated separately via local
// disposable-fixture queries against a real Postgres instance, see the
// Step 7 pre-apply report). What this file protects is the second half
// of the privacy contract: given whatever capped integer the server
// already decided to send, the client always renders it correctly and
// never fabricates a more precise number than it actually received.

import 'package:flutter_test/flutter_test.dart';
import 'package:michelin_passport/features/events/going_member_count_format.dart';
import 'package:michelin_passport/models/going_member_count.dart';

void main() {
  group('GoingMemberCount — isCapped', () {
    test('0 is not capped', () {
      expect(const GoingMemberCount(0).isCapped, isFalse);
    });

    test('99 is not capped', () {
      expect(const GoingMemberCount(99).isCapped, isFalse);
    });

    test('exactly 100 is capped', () {
      expect(const GoingMemberCount(100).isCapped, isTrue);
    });
  });

  group('formatGoingMemberCount — exact boundary contract', () {
    test('0 -> null (hidden entirely, never "0 members going")', () {
      expect(formatGoingMemberCount(const GoingMemberCount(0)), isNull);
    });

    test('1 -> singular "1 Mantelier member going"', () {
      expect(
        formatGoingMemberCount(const GoingMemberCount(1)),
        '1 Mantelier member going',
      );
    });

    test('2 -> plural "2 Mantelier members going"', () {
      expect(
        formatGoingMemberCount(const GoingMemberCount(2)),
        '2 Mantelier members going',
      );
    });

    test('37 -> exact plural', () {
      expect(
        formatGoingMemberCount(const GoingMemberCount(37)),
        '37 Mantelier members going',
      );
    });

    test('99 -> exact plural, the highest uncapped value', () {
      expect(
        formatGoingMemberCount(const GoingMemberCount(99)),
        '99 Mantelier members going',
      );
    });

    test('100 (the server\'s capped sentinel) -> "100+ Mantelier '
        'members going", never the literal "100"', () {
      final copy = formatGoingMemberCount(const GoingMemberCount(100));
      expect(copy, '100+ Mantelier members going');
      expect(copy, isNot(contains('100 Mantelier')));
    });

    test('copy never says "users," "attendees," or "people registered" — '
        'Going is intent, not a ticket/registration count', () {
      for (final count in [1, 2, 37, 100]) {
        final copy = formatGoingMemberCount(GoingMemberCount(count))!;
        expect(copy, isNot(contains('users')));
        expect(copy, isNot(contains('attendees')));
        expect(copy, isNot(contains('registered')));
        expect(copy, contains('Mantelier'));
      }
    });

    test('a defensively-out-of-range value above 100 still renders as '
        '"100+", never a fabricated exact number — belt-and-suspenders '
        'only, since the server contract guarantees this never actually '
        'happens', () {
      // GoingMemberCount can technically be constructed with any int in
      // Dart (it does not re-validate the server's own contract) — this
      // proves the formatter itself never regresses to showing a raw
      // value above 99 even in that defensive edge case.
      expect(
        formatGoingMemberCount(const GoingMemberCount(523)),
        '100+ Mantelier members going',
      );
    });
  });
}
