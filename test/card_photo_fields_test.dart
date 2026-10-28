// Covers the card-photo fields (20261015120000) as the app parses them:
// restaurants_full/hotels_full's card_photo_url + card crop, with the
// cover as the fallback, and a published photo's is_card + card crop.
// (A Restaurant/Hotel built in code with only a cover is covered by the
// Passport/Wishlist card tests, which build them that way.)

import 'package:flutter_test/flutter_test.dart';
import 'package:michelin_passport/models/hotel.dart';
import 'package:michelin_passport/models/photo_framing.dart';
import 'package:michelin_passport/models/published_venue_photo.dart';
import 'package:michelin_passport/models/restaurant.dart';

void main() {
  test('a restaurant reads its card photo and card crop, separate from the '
      'cover', () {
    final r = Restaurant.fromJson({
      'id': 'r1',
      'name': 'Flore',
      'cover_photo_url': 'https://example.test/cover.jpg',
      'cover_focus_x': 0.5,
      'cover_focus_y': 0.2,
      'cover_zoom': 1.5,
      'card_photo_url': 'https://example.test/card.jpg',
      'card_focus_x': 0.3,
      'card_focus_y': 0.7,
      'card_zoom': 2.2,
    });
    expect(r.coverImageUrl, 'https://example.test/cover.jpg');
    expect(r.coverFraming, const PhotoFraming(focusY: 0.2, zoom: 1.5));
    expect(r.cardImageUrl, 'https://example.test/card.jpg');
    expect(
      r.cardFraming,
      const PhotoFraming(focusX: 0.3, focusY: 0.7, zoom: 2.2),
    );
  });

  test('without card columns (an older server) the card is the cover, '
      'centred', () {
    final h = Hotel.fromJson({
      'id': 'h1',
      'name': 'De L\'Europe',
      'cover_photo_url': 'https://example.test/cover.jpg',
      'cover_zoom': 2,
    });
    expect(h.cardImageUrl, 'https://example.test/cover.jpg');
    expect(h.cardFraming, PhotoFraming.center);
  });

  test('a published photo reads is_card and its card crop', () {
    final p = PublishedVenuePhoto.fromJson({
      'id': 'p1',
      'image_url': 'https://example.test/1.jpg',
      'display_order': 0,
      'focus_x': 0.4,
      'is_card': true,
      'card_focus_x': 0.6,
      'card_focus_y': 0.4,
      'card_zoom': 1.5,
    });
    expect(p.isCard, isTrue);
    expect(p.framing.focusX, 0.4);
    expect(
      p.cardFraming,
      const PhotoFraming(focusX: 0.6, focusY: 0.4, zoom: 1.5),
    );
    final plain = PublishedVenuePhoto.fromJson({
      'id': 'p2',
      'image_url': 'https://example.test/2.jpg',
      'display_order': 1,
    });
    expect(plain.isCard, isFalse);
    expect(plain.cardFraming, PhotoFraming.center);
  });
}
