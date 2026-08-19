// Covers PrivateChefPhoto.fromJson — the small model backing
// public.private_chef_photos (Step 2B).

import 'package:flutter_test/flutter_test.dart';
import 'package:michelin_passport/models/private_chef_photo.dart';

void main() {
  group('PrivateChefPhoto.fromJson', () {
    test('maps every field', () {
      final photo = PrivateChefPhoto.fromJson({
        'id': 'p1',
        'private_chef_id': 'c1',
        'image_url': 'https://example.com/1.jpg',
        'alt_text': 'Lucas plating a dish',
        'display_order': 2,
      });
      expect(photo.id, 'p1');
      expect(photo.privateChefId, 'c1');
      expect(photo.imageUrl, 'https://example.com/1.jpg');
      expect(photo.altText, 'Lucas plating a dish');
      expect(photo.displayOrder, 2);
    });

    test('null alt_text stays null, never coerced to empty string', () {
      final photo = PrivateChefPhoto.fromJson({
        'id': 'p1',
        'private_chef_id': 'c1',
        'image_url': 'https://example.com/1.jpg',
        'alt_text': null,
        'display_order': 0,
      });
      expect(photo.altText, isNull);
    });

    test('missing display_order defaults to 0', () {
      final photo = PrivateChefPhoto.fromJson({
        'id': 'p1',
        'private_chef_id': 'c1',
        'image_url': 'https://example.com/1.jpg',
      });
      expect(photo.displayOrder, 0);
    });
  });
}
