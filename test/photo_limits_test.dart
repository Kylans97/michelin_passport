// Covers Events V2 Step 4's final photo-limit correction: the one
// canonical maxEventAttendancePhotos constant and the pure decision
// functions built on it. These are exercised directly (no Supabase, no
// widget tree) so the actual enforcement logic — not just its UI
// reflection — is proven.

import 'package:flutter_test/flutter_test.dart';
import 'package:michelin_passport/core/constants/photo_limits.dart';

void main() {
  test('maxEventAttendancePhotos is 6', () {
    expect(maxEventAttendancePhotos, 6);
  });

  group('remainingAttendancePhotoCapacity', () {
    test('0 existing -> 6 remaining', () {
      expect(remainingAttendancePhotoCapacity(0), 6);
    });

    test('4 existing -> 2 remaining', () {
      expect(remainingAttendancePhotoCapacity(4), 2);
    });

    test('5 existing -> 1 remaining', () {
      expect(remainingAttendancePhotoCapacity(5), 1);
    });

    test('6 existing (at capacity) -> 0 remaining', () {
      expect(remainingAttendancePhotoCapacity(6), 0);
    });

    test('12 existing (the temporary test fixture\'s current count) -> 0, '
        'never negative', () {
      expect(remainingAttendancePhotoCapacity(12), 0);
    });
  });

  group('canAddAttendancePhoto — the repository-layer gate', () {
    test('below the limit allows adding', () {
      expect(canAddAttendancePhoto(0), isTrue);
      expect(canAddAttendancePhoto(5), isTrue);
    });

    test('exactly at the limit refuses', () {
      expect(canAddAttendancePhoto(6), isFalse);
    });

    test('already over the limit (pre-existing 12-photo fixture) still '
        'refuses — it does not become "more" allowed just because it is '
        'already over', () {
      expect(canAddAttendancePhoto(12), isFalse);
    });
  });

  group('clampToRemainingCapacity — never uploads-then-deletes the excess', () {
    test('picked count within capacity is returned unchanged', () {
      expect(clampToRemainingCapacity([1, 2, 3], 6), [1, 2, 3]);
    });

    test('4 existing + selecting 5 -> only the first 2 are accepted '
        '(exact task example)', () {
      final picked = ['a', 'b', 'c', 'd', 'e'];
      final remaining = remainingAttendancePhotoCapacity(4); // 2
      expect(clampToRemainingCapacity(picked, remaining), ['a', 'b']);
    });

    test('0 remaining capacity yields an empty list, not an error', () {
      expect(clampToRemainingCapacity([1, 2, 3], 0), isEmpty);
    });

    test('negative remaining capacity (defensive) also yields empty, '
        'never throws', () {
      expect(clampToRemainingCapacity([1, 2, 3], -1), isEmpty);
    });

    test('an empty picked list stays empty regardless of capacity', () {
      expect(clampToRemainingCapacity(<int>[], 6), isEmpty);
    });
  });
}
