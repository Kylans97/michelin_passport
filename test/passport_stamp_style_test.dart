// Pure-logic tests for passport_stamp_style.dart's deterministic hashing —
// variant/ink/rotation/jitter must all be stable per id (never random
// per-build) and must honor their "avoid the previous pick" rule.

import 'package:flutter_test/flutter_test.dart';
import 'package:michelin_passport/features/passport/utils/passport_stamp_style.dart';

void main() {
  group('stampStableHash', () {
    test('is deterministic — same input always produces the same hash', () {
      expect(stampStableHash('visit-123'), stampStableHash('visit-123'));
    });

    test('different inputs (usually) produce different hashes', () {
      expect(stampStableHash('visit-123'), isNot(stampStableHash('visit-124')));
    });

    test('is always non-negative (32-bit unsigned)', () {
      for (final id in ['a', 'zzzz', 'uuid-like-1234-5678', '']) {
        expect(stampStableHash(id), greaterThanOrEqualTo(0));
      }
    });
  });

  group('pickStampVariant', () {
    test('the same id always resolves to the same variant', () {
      final ids = ['visit-1', 'visit-2', 'attendance-abc', 'stay-99'];
      for (final id in ids) {
        expect(pickStampVariant(id), pickStampVariant(id));
      }
    });

    test('never returns the avoided variant when it would otherwise collide', () {
      // Find an id whose natural (no-avoid) pick is roundSeal, then confirm
      // asking it to avoid roundSeal returns something else.
      final id = StampVariant.values
          .map((v) => 'probe-$v')
          .firstWhere((probe) => pickStampVariant(probe) == StampVariant.roundSeal);
      expect(
        pickStampVariant(id, avoid: StampVariant.roundSeal),
        isNot(StampVariant.roundSeal),
      );
    });

    test('with no avoid, is unaffected by the avoid parameter being absent', () {
      const id = 'visit-42';
      expect(pickStampVariant(id), pickStampVariant(id, avoid: null));
    });
  });

  group('pickStampInk', () {
    test('the same id always resolves to the same ink', () {
      const id = 'visit-77';
      expect(pickStampInk(id), pickStampInk(id));
    });

    test('never returns the avoided ink when it would otherwise collide', () {
      final id = StampInk.values
          .map((ink) => 'probe-$ink')
          .firstWhere((probe) => pickStampInk(probe) == StampInk.gold);
      expect(pickStampInk(id, avoid: StampInk.gold), isNot(StampInk.gold));
    });
  });

  group('pickStampRotationDegrees', () {
    test('is deterministic and always within [-12, 8]', () {
      for (var i = 0; i < 200; i++) {
        final id = 'visit-$i';
        final rotation = pickStampRotationDegrees(id);
        expect(rotation, pickStampRotationDegrees(id));
        expect(rotation, greaterThanOrEqualTo(-12));
        expect(rotation, lessThanOrEqualTo(8));
      }
    });
  });

  group('pickStampPositionJitter', () {
    test('is deterministic and always within [-12, 12] on both axes', () {
      for (var i = 0; i < 200; i++) {
        final id = 'visit-$i';
        final jitter = pickStampPositionJitter(id);
        expect(jitter, pickStampPositionJitter(id));
        expect(jitter.dx, inInclusiveRange(-12, 12));
        expect(jitter.dy, inInclusiveRange(-12, 12));
      }
    });
  });
}
