// Covers Events V2 Step 4.1's update-map construction:
// buildAttendanceDetailsUpdate and WouldRecommendUpdate. Kept as a pure,
// standalone-function test — EventConfirmedAttendanceRepository itself
// constructs SupabaseClient at field-init time via Supabase.instance.client,
// unavailable in this sandbox without Supabase.initialize() (the same,
// already-documented limitation as attendance_details_sheet_shell_test.dart
// and PhotoRepository-backed widgets elsewhere in this feature) — so the
// repository's actual network methods aren't exercised here. Every
// "save true / save false / change true<->false / clear to null / rating
// and comment stay unaffected" scenario the task asked for is a pure
// function of these inputs -> this exact map, independent of the network
// call that follows, which is why testing the map alone is a complete,
// honest proof of the update semantics (the network round-trip itself is
// proven separately, directly against local Postgres, in the Step 4.1
// pre-apply report's own Local Migration Validation section).

import 'package:flutter_test/flutter_test.dart';
import 'package:michelin_passport/data/repositories/event_confirmed_attendance_repository.dart';
import 'package:michelin_passport/models/event_confirmed_attendance.dart';

void main() {
  group('buildAttendanceDetailsUpdate — rating/comment "omit = don\'t '
      'touch" (unchanged pre-existing convention)', () {
    test('both null omits both keys entirely', () {
      expect(buildAttendanceDetailsUpdate(), isEmpty);
    });

    test('a non-null rating includes only the rating key', () {
      expect(buildAttendanceDetailsUpdate(rating: 8), {'rating': 8});
    });

    test('a non-null comment includes only the comment key', () {
      expect(buildAttendanceDetailsUpdate(comment: 'Loved it'), {
        'comment': 'Loved it',
      });
    });

    test('visibility is included only when provided', () {
      expect(
        buildAttendanceDetailsUpdate(
          visibility: ConfirmedAttendanceVisibility.friends,
        ),
        {'visibility': 'friends'},
      );
    });
  });

  group('buildAttendanceDetailsUpdate — wouldRecommend, Step 4.1\'s '
      'explicit set/clear mechanism', () {
    test('omitting the parameter entirely leaves would_recommend '
        'untouched — the key is absent, not sent as null', () {
      final update = buildAttendanceDetailsUpdate(rating: 5);
      expect(update.containsKey('would_recommend'), isFalse);
      expect(update, {'rating': 5});
    });

    test('save true (first Yes answer, or Yes after No)', () {
      expect(
        buildAttendanceDetailsUpdate(
          wouldRecommend: const WouldRecommendUpdate(true),
        ),
        {'would_recommend': true},
      );
    });

    test('save false (first No answer, or No after Yes)', () {
      expect(
        buildAttendanceDetailsUpdate(
          wouldRecommend: const WouldRecommendUpdate(false),
        ),
        {'would_recommend': false},
      );
    });

    test('change true -> false is just two independent saves — the '
        'builder is stateless, so proving both values individually proves '
        'every transition between them', () {
      final asTrue = buildAttendanceDetailsUpdate(
        wouldRecommend: const WouldRecommendUpdate(true),
      );
      final asFalse = buildAttendanceDetailsUpdate(
        wouldRecommend: const WouldRecommendUpdate(false),
      );
      expect(asTrue, {'would_recommend': true});
      expect(asFalse, {'would_recommend': false});
    });

    test('change false -> true', () {
      final asFalse = buildAttendanceDetailsUpdate(
        wouldRecommend: const WouldRecommendUpdate(false),
      );
      final asTrue = buildAttendanceDetailsUpdate(
        wouldRecommend: const WouldRecommendUpdate(true),
      );
      expect(asFalse, {'would_recommend': false});
      expect(asTrue, {'would_recommend': true});
    });

    test('clear to null — the key IS present, mapped to an explicit null, '
        'distinct from omitting the parameter entirely (that case is '
        'covered above)', () {
      final update = buildAttendanceDetailsUpdate(
        wouldRecommend: const WouldRecommendUpdate(null),
      );
      expect(update.containsKey('would_recommend'), isTrue);
      expect(update['would_recommend'], isNull);
    });

    test('rating and comment are unaffected by a wouldRecommend-only '
        'update — no would_recommend key when omitted, no rating/comment '
        'key either', () {
      final update = buildAttendanceDetailsUpdate(
        wouldRecommend: const WouldRecommendUpdate(true),
      );
      expect(update.containsKey('rating'), isFalse);
      expect(update.containsKey('comment'), isFalse);
      expect(update, {'would_recommend': true});
    });

    test('rating and comment are unaffected by a wouldRecommend clear — '
        'all three keys coexist correctly when all three are provided', () {
      final update = buildAttendanceDetailsUpdate(
        rating: 7,
        comment: 'Solid night',
        wouldRecommend: const WouldRecommendUpdate(null),
      );
      expect(update, {
        'rating': 7,
        'comment': 'Solid night',
        'would_recommend': null,
      });
    });
  });
}
