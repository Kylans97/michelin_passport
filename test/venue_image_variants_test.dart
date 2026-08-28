// Covers lib/core/utils/venue_image_variants.dart — the Supabase Image
// Transformation URL builders for the three venue photo display sizes.

import 'package:flutter_test/flutter_test.dart';
import 'package:michelin_passport/core/utils/venue_image_variants.dart';

const _supabaseUrl = 'https://wcmxugunvwsrulcpeyrc.supabase.co';

void main() {
  group('venuePhotoThumbnailUrl', () {
    test('points at the render endpoint against the pre-cropped thumb '
        'source, square, with the given size', () {
      final url = venuePhotoThumbnailUrl(
        supabaseUrl: _supabaseUrl,
        thumbSourcePath: 'restaurants/abc-123/0-thumb.jpg',
        size: 64,
      );
      expect(
        url,
        '$_supabaseUrl/storage/v1/render/image/public/catalogue-media/'
        'restaurants/abc-123/0-thumb.jpg?width=64&height=64&resize=cover',
      );
    });

    test('defaults to 128px when no size is given', () {
      final url = venuePhotoThumbnailUrl(
        supabaseUrl: _supabaseUrl,
        thumbSourcePath: 'restaurants/abc-123/0-thumb.jpg',
      );
      expect(url, contains('width=128&height=128'));
    });
  });

  group('venuePhotoMediumUrl', () {
    test('points at the render endpoint against the ORIGINAL path, not '
        'the thumbnail source', () {
      final url = venuePhotoMediumUrl(
        supabaseUrl: _supabaseUrl,
        originalPath: 'restaurants/abc-123/0.jpg',
        width: 480,
        height: 320,
      );
      expect(
        url,
        '$_supabaseUrl/storage/v1/render/image/public/catalogue-media/'
        'restaurants/abc-123/0.jpg?width=480&height=320&resize=cover',
      );
      expect(url, isNot(contains('thumb')));
    });
  });

  group('venuePhotoHeroUrl', () {
    test('is the plain object endpoint with no transform parameters at '
        'all', () {
      final url = venuePhotoHeroUrl(
        supabaseUrl: _supabaseUrl,
        originalPath: 'restaurants/abc-123/0.jpg',
      );
      expect(
        url,
        '$_supabaseUrl/storage/v1/object/public/catalogue-media/'
        'restaurants/abc-123/0.jpg',
      );
      expect(url, isNot(contains('render')));
      expect(url, isNot(contains('?')));
    });
  });
}
