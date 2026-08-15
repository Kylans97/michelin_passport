// Covers VisitVisibility (Social Foundation Step 2): dbValue round-trip,
// fail-safe parsing of unrecognised/null values, and Visit.fromJson's
// default when the visibility column is missing/null on an old row.

import 'package:flutter_test/flutter_test.dart';
import 'package:michelin_passport/models/visit.dart';

void main() {
  group('VisitVisibility.fromDbValue', () {
    test('parses "private" and "friends" correctly', () {
      expect(VisitVisibility.fromDbValue('private'), VisitVisibility.private);
      expect(VisitVisibility.fromDbValue('friends'), VisitVisibility.friends);
    });

    test('fails safe to private for null', () {
      expect(VisitVisibility.fromDbValue(null), VisitVisibility.private);
    });

    test('fails safe to private for an unrecognised value', () {
      expect(VisitVisibility.fromDbValue('public'), VisitVisibility.private);
      expect(VisitVisibility.fromDbValue(''), VisitVisibility.private);
      expect(VisitVisibility.fromDbValue('FRIENDS'), VisitVisibility.private);
    });

    test('dbValue round-trips exactly', () {
      for (final v in VisitVisibility.values) {
        expect(VisitVisibility.fromDbValue(v.dbValue), v);
      }
    });
  });

  group('Visit visibility default', () {
    test('a Visit constructed without visibility defaults to private', () {
      final visit = Visit(
        id: 'v1',
        userId: 'u1',
        entityType: 'restaurant',
        entityId: 'r1',
        visitedOn: DateTime(2026, 1, 1),
      );
      expect(visit.visibility, VisitVisibility.private);
    });

    test('Visit.fromJson defaults to private when the column is missing', () {
      final visit = Visit.fromJson({
        'id': 'v1',
        'user_id': 'u1',
        'entity_type': 'restaurant',
        'entity_id': 'r1',
        'visited_on': '2026-01-01',
      });
      expect(visit.visibility, VisitVisibility.private);
    });

    test('Visit.fromJson parses an explicit friends value', () {
      final visit = Visit.fromJson({
        'id': 'v1',
        'user_id': 'u1',
        'entity_type': 'restaurant',
        'entity_id': 'r1',
        'visited_on': '2026-01-01',
        'visibility': 'friends',
      });
      expect(visit.visibility, VisitVisibility.friends);
    });
  });
}
