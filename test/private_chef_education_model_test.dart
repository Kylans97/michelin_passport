// Covers PrivateChefEducation.fromJson — the small model backing
// public.private_chef_education (Step 2B, "Background" architecture).

import 'package:flutter_test/flutter_test.dart';
import 'package:michelin_passport/models/private_chef_education.dart';

void main() {
  group('PrivateChefEducation.fromJson', () {
    test('maps every field', () {
      final education = PrivateChefEducation.fromJson({
        'id': 'e1',
        'private_chef_id': 'c1',
        'institution': 'De Rooi Pannen',
        'program': 'Horeca Ondernemend Management',
        'period_text': null,
        'display_order': 0,
      });
      expect(education.id, 'e1');
      expect(education.privateChefId, 'c1');
      expect(education.institution, 'De Rooi Pannen');
      expect(education.program, 'Horeca Ondernemend Management');
      expect(education.periodText, isNull);
      expect(education.displayOrder, 0);
    });

    test('period_text populates when present, never invented when absent', () {
      final withPeriod = PrivateChefEducation.fromJson({
        'id': 'e1',
        'private_chef_id': 'c1',
        'institution': 'Test Institution',
        'program': 'Test Program',
        'period_text': '2015–2017',
      });
      expect(withPeriod.periodText, '2015–2017');

      final withoutPeriod = PrivateChefEducation.fromJson({
        'id': 'e1',
        'private_chef_id': 'c1',
        'institution': 'Test Institution',
        'program': 'Test Program',
      });
      expect(withoutPeriod.periodText, isNull);
    });

    test('missing display_order defaults to 0', () {
      final education = PrivateChefEducation.fromJson({
        'id': 'e1',
        'private_chef_id': 'c1',
        'institution': 'Test Institution',
        'program': 'Test Program',
      });
      expect(education.displayOrder, 0);
    });
  });
}
