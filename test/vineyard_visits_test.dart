// Estate visits (vineyard_visits, 20261101570000): the insert shape, the
// row parsing, and the Passport stamp they make.

import 'package:flutter_test/flutter_test.dart';
import 'package:michelin_passport/features/passport/models/passport_stamp_award.dart';
import 'package:michelin_passport/features/passport/models/passport_stamp_item.dart';
import 'package:michelin_passport/features/passport/passport_booklet_data.dart';
import 'package:michelin_passport/features/passport/passport_stamp_source.dart';
import 'package:michelin_passport/models/vineyard.dart';
import 'package:michelin_passport/models/vineyard_visit.dart';

const _estate = Vineyard(
  id: 'v1',
  vineyardCode: 'vine_0001',
  name: 'Château Smith Haut Lafitte',
  countryCode: 'FR',
  city: 'Martillac',
  region: 'Bordeaux',
);

VineyardVisitEntry _entry(String id, DateTime on) => VineyardVisitEntry(
  visit: VineyardVisit(id: id, vineyardId: 'v1', visitedOn: on),
  vineyard: _estate,
);

void main() {
  group('buildVineyardVisitInsert', () {
    test('writes the date, the activities in a fixed order, and private '
        'by default', () {
      final row = buildVineyardVisitInsert(
        userId: 'u1',
        vineyardId: 'v1',
        visitedOn: DateTime(2026, 5, 4),
        activities: {VineyardActivity.lunch, VineyardActivity.tasting},
      );
      expect(row, {
        'user_id': 'u1',
        'vineyard_id': 'v1',
        'visited_on': '2026-05-04',
        'activities': ['tasting', 'lunch'],
        'visibility': 'private',
      });
    });

    test('a blank note is left out; a shared visit says friends', () {
      final row = buildVineyardVisitInsert(
        userId: 'u1',
        vineyardId: 'v1',
        visitedOn: DateTime(2026, 5, 4),
        comment: '   ',
        friendsVisible: true,
      );
      expect(row.containsKey('comment'), isFalse);
      expect(row['visibility'], 'friends');
    });
  });

  test('VineyardVisit.fromMap reads the row and ignores an activity it '
      'does not know', () {
    final visit = VineyardVisit.fromMap({
      'id': 'x1',
      'vineyard_id': 'v1',
      'visited_on': '2026-05-04',
      'activities': ['cellar_tour', 'something_new'],
      'rating': null,
      'comment': 'Lovely',
      'visibility': 'friends',
    });
    expect(visit.visitedOn, DateTime(2026, 5, 4));
    expect(visit.activities, {VineyardActivity.cellarTour});
    expect(visit.comment, 'Lovely');
    expect(visit.friendsVisible, isTrue);
  });

  group('estate stamps', () {
    test('one stamp per visit, with WINE ESTATE where an award would be — '
        'never a MICHELIN award', () {
      final items = buildVineyardStampItems([
        _entry('a', DateTime(2026, 5, 4)),
        _entry('b', DateTime(2025, 9, 1)),
      ]);
      expect(items.map((i) => i.id), ['b', 'a']); // oldest first
      final stamp = items.first as VineyardStampItem;
      expect(stamp.venueName, 'Château Smith Haut Lafitte');
      expect(stamp.cityName, 'Martillac');
      expect(stamp.countryCode, 'FR');
      final award = stampAwardFor(stamp);
      expect(award, isA<KindLabelAward>());
      expect((award as KindLabelAward).label, 'WINE ESTATE');
    });

    test('estate stamps go into the booklet beside the others', () {
      final volumes = buildPassportVolumes(
        entries: const [],
        eventEntries: const [],
        vineyardEntries: [_entry('a', DateTime.now())],
      );
      expect(volumes.first.items.whereType<VineyardStampItem>(), hasLength(1));
    });
  });
}
