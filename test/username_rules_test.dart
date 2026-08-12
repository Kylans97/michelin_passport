// Covers UsernameRules (Social Foundation Step 1) — the client-side
// mirror of the profiles_username_format CHECK constraint. Every example
// here is the exact valid/invalid set from the task brief itself, plus
// the boundary cases the regex is specifically designed to reject
// (leading/trailing punctuation, consecutive punctuation) without a
// lookahead (Postgres `~` is POSIX ERE, which has none — see the
// migration's own comment on why the pattern is shaped the way it is).

import 'package:flutter_test/flutter_test.dart';
import 'package:michelin_passport/core/utils/username_rules.dart';

void main() {
  group('UsernameRules.normalize', () {
    test('trims and lowercases', () {
      expect(UsernameRules.normalize('  Kylan.S  '), 'kylan.s');
    });
  });

  group('UsernameRules.validate — valid examples from the brief', () {
    for (final valid in ['kylan', 'kylan.s', 'kylan_28', 'chef123']) {
      test('"$valid" is accepted', () {
        expect(UsernameRules.validate(valid), isNull);
      });
    }
  });

  group('UsernameRules.validate — invalid examples from the brief', () {
    test('"ky" — too short', () {
      expect(UsernameRules.validate('ky'), isNotNull);
    });

    test('"_kylan" — starts with punctuation', () {
      expect(UsernameRules.validate('_kylan'), isNotNull);
    });

    test('"kylan_" — ends with punctuation', () {
      expect(UsernameRules.validate('kylan_'), isNotNull);
    });

    test('"kylan scheepstra" — contains a space', () {
      expect(UsernameRules.validate('kylan scheepstra'), isNotNull);
    });

    test('"kylan!!!" — disallowed punctuation', () {
      expect(UsernameRules.validate('kylan!!!'), isNotNull);
    });
  });

  group('UsernameRules.validate — additional boundary cases', () {
    test('empty string', () {
      expect(UsernameRules.validate(''), isNotNull);
    });

    test('31 characters — one over the limit', () {
      expect(UsernameRules.validate('a' * 31), isNotNull);
    });

    test('30 characters — exactly at the limit', () {
      expect(UsernameRules.validate('a' * 30), isNull);
    });

    test('3 characters — exactly at the minimum', () {
      expect(UsernameRules.validate('abc'), isNull);
    });

    test('consecutive punctuation ("kylan__x") is rejected', () {
      expect(UsernameRules.validate('kylan__x'), isNotNull);
    });

    test('consecutive punctuation ("kylan.._x") is rejected', () {
      expect(UsernameRules.validate('kylan.._x'), isNotNull);
    });

    test('uppercase input fails validate (call normalize first)', () {
      // UsernameRules.validate expects an already-normalized string —
      // this documents that contract rather than silently lowercasing.
      expect(UsernameRules.validate('Kylan'), isNotNull);
    });

    test('single interior punctuation characters are fine', () {
      expect(UsernameRules.validate('a.b_c.d'), isNull);
    });
  });
}
