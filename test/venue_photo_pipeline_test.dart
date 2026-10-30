// Covers lib/data/services/venue_photo_pipeline.dart — Layer 1
// (validation, EXIF strip) and Layer 2 (perceptual hash) of the venue
// photo submission pipeline. Pure Dart, no Supabase/Flutter widget
// dependency — every test builds synthetic images in-memory via the
// `image` package rather than bundling fixture files.

import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:michelin_passport/core/constants/venue_photo_submission_limits.dart';
import 'package:michelin_passport/data/services/venue_photo_pipeline.dart';

Uint8List _jpeg(int width, int height, {int r = 120, int g = 90, int b = 60}) {
  final image = img.Image(width: width, height: height);
  img.fill(image, color: img.ColorRgb8(r, g, b));
  return Uint8List.fromList(img.encodeJpg(image));
}

Uint8List _png(int width, int height) {
  final image = img.Image(width: width, height: height);
  img.fill(image, color: img.ColorRgb8(200, 50, 50));
  return Uint8List.fromList(img.encodePng(image));
}

void main() {
  group('validateVenuePhoto', () {
    test('accepts a valid landscape JPEG at the exact boundary '
        '(1600x1200, 4:3, short side 1200)', () {
      final result = validateVenuePhoto(_jpeg(1600, 1200));
      expect(result, isA<VenuePhotoValidationOk>());
    });

    test('accepts a valid PNG within range', () {
      final result = validateVenuePhoto(_png(1920, 1200));
      expect(result, isA<VenuePhotoValidationOk>());
    });

    test('rejects a file larger than 5 MB with tooLarge', () {
      // A real 1600x1200 JPEG is nowhere near 5MB, so pad past the
      // limit with trailing bytes — validateVenuePhoto checks byte
      // length before ever attempting to decode, so the padding never
      // needs to be valid image data.
      final bytes = _jpeg(1600, 1200);
      final oversized = Uint8List(6 * 1024 * 1024)
        ..setRange(0, bytes.length, bytes);
      final result = validateVenuePhoto(oversized);
      expect(result, isA<VenuePhotoValidationRejected>());
      expect(
        (result as VenuePhotoValidationRejected).reason,
        VenuePhotoRejectionReason.tooLarge,
      );
    });

    test('rejects an undecodable / non-JPEG-non-PNG file with '
        'unsupportedFormat', () {
      final result = validateVenuePhoto(Uint8List.fromList([1, 2, 3, 4, 5]));
      expect(result, isA<VenuePhotoValidationRejected>());
      expect(
        (result as VenuePhotoValidationRejected).reason,
        VenuePhotoRejectionReason.unsupportedFormat,
      );
    });

    test('rejects a photo whose short side is under 1200px with '
        'tooLowResolution', () {
      final result = validateVenuePhoto(_jpeg(1600, 1199));
      expect(result, isA<VenuePhotoValidationRejected>());
      expect(
        (result as VenuePhotoValidationRejected).reason,
        VenuePhotoRejectionReason.tooLowResolution,
      );
    });

    test('rejects a near-square photo (ratio below 4:3) with '
        'aspectRatioOutOfRange', () {
      final result = validateVenuePhoto(_jpeg(1300, 1300));
      expect(result, isA<VenuePhotoValidationRejected>());
      expect(
        (result as VenuePhotoValidationRejected).reason,
        VenuePhotoRejectionReason.aspectRatioOutOfRange,
      );
    });

    test('rejects an overly elongated banner (ratio above 16:9) with '
        'aspectRatioOutOfRange', () {
      final result = validateVenuePhoto(_jpeg(3200, 1200));
      expect(result, isA<VenuePhotoValidationRejected>());
      expect(
        (result as VenuePhotoValidationRejected).reason,
        VenuePhotoRejectionReason.aspectRatioOutOfRange,
      );
    });

    test('portrait orientation is judged by the same long/short ratio, '
        'not width vs height directly', () {
      // 1200x1600 is the exact transpose of the accepted 1600x1200 case
      // above — same 4:3 ratio, just portrait.
      final result = validateVenuePhoto(_jpeg(1200, 1600));
      expect(result, isA<VenuePhotoValidationOk>());
    });
  });

  group('prepareVenuePhoto', () {
    test('removes EXIF metadata (including GPS) that was present in '
        'the source', () {
      final image = img.Image(width: 1600, height: 1200);
      img.fill(image, color: img.ColorRgb8(10, 10, 10));
      image.exif.gpsIfd['GPSLatitudeRef'] = 'N';
      image.exif.imageIfd['Software'] = 'test-harness';
      final withExif = Uint8List.fromList(img.encodeJpg(image));

      // Sanity check: the source really does carry EXIF, so the
      // assertion below actually proves something.
      final decodedSource = img.decodeImage(withExif)!;
      expect(decodedSource.exif.isEmpty, isFalse);

      final stripped = prepareVenuePhoto(withExif).bytes;
      final decodedStripped = img.decodeImage(stripped)!;
      expect(decodedStripped.exif.isEmpty, isTrue);
    });

    test('re-encodes as the same format it decoded (JPEG stays JPEG, '
        'PNG stays PNG)', () {
      final strippedJpeg = prepareVenuePhoto(_jpeg(1600, 1200)).bytes;
      expect(img.findDecoderForData(strippedJpeg), isA<img.JpegDecoder>());

      final strippedPng = prepareVenuePhoto(_png(1600, 1200)).bytes;
      expect(img.findDecoderForData(strippedPng), isA<img.PngDecoder>());
    });

    test('preserves visual content — decoded dimensions unchanged', () {
      final stripped = prepareVenuePhoto(_jpeg(1600, 1200)).bytes;
      final decoded = img.decodeImage(stripped)!;
      expect(decoded.width, 1600);
      expect(decoded.height, 1200);
    });
  });

  group('prepareVenuePhoto — type and size (2026-10-30)', () {
    // Pixel noise: compresses badly, the way a real photo does, so a size
    // limit actually bites. A flat fill compresses to almost nothing.
    img.Image noise(int width, int height) {
      final image = img.Image(width: width, height: height);
      var seed = 7;
      for (final p in image) {
        seed = (seed * 1103515245 + 12345) & 0x7fffffff;
        p
          ..r = seed & 0xff
          ..g = (seed >> 8) & 0xff
          ..b = (seed >> 16) & 0xff;
      }
      return image;
    }

    test('a PNG is uploaded as a PNG, a JPEG as a JPEG', () {
      final png = prepareVenuePhoto(_png(1600, 1200));
      expect(png.extension, 'png');
      expect(png.contentType, 'image/png');
      expect(img.findDecoderForData(png.bytes), isA<img.PngDecoder>());

      final jpeg = prepareVenuePhoto(_jpeg(1600, 1200));
      expect(jpeg.extension, 'jpg');
      expect(jpeg.contentType, 'image/jpeg');
      expect(img.findDecoderForData(jpeg.bytes), isA<img.JpegDecoder>());
    });

    test('caps the long edge, keeping the aspect ratio', () {
      final landscape = img.decodeImage(
        prepareVenuePhoto(_jpeg(4000, 3000)).bytes,
      )!;
      expect(
        [landscape.width, landscape.height],
        [maxVenuePhotoLongEdgePx, 1920],
      );

      final portrait = img.decodeImage(
        prepareVenuePhoto(_jpeg(2250, 3000)).bytes,
      )!;
      expect(
        [portrait.width, portrait.height],
        [1920, maxVenuePhotoLongEdgePx],
      );
    });

    test('steps down until the file fits the limit, never below the '
        'minimum short side', () {
      final source = Uint8List.fromList(img.encodePng(noise(2400, 1800)));
      // ~3 bytes per noise pixel: 13 MB at full size, fits after two steps.
      const limit = 7 * 1024 * 1024;
      final prepared = prepareVenuePhoto(source, maxBytes: limit);
      final out = img.decodeImage(prepared.bytes)!;

      expect(prepared.bytes.lengthInBytes, lessThanOrEqualTo(limit));
      expect(prepared.isPng, isTrue);
      expect(out.width, lessThan(2400));
      expect(out.height, greaterThanOrEqualTo(minVenuePhotoShortSidePx));
    });

    test('a PNG that cannot fit at the minimum size becomes a JPEG, and '
        'says so', () {
      final source = Uint8List.fromList(img.encodePng(noise(1600, 1200)));
      final prepared = prepareVenuePhoto(source, maxBytes: 1024 * 1024);
      final out = img.decodeImage(prepared.bytes)!;

      expect(prepared.isPng, isFalse);
      expect(prepared.contentType, 'image/jpeg');
      expect(img.findDecoderForData(prepared.bytes), isA<img.JpegDecoder>());
      expect(out.height, minVenuePhotoShortSidePx);
    });
  });

  group('computeVenuePhotoHash / hammingDistance', () {
    test('produces a 64-character binary string', () {
      final hash = computeVenuePhotoHash(_jpeg(1600, 1200));
      expect(hash.length, 64);
      expect(RegExp(r'^[01]{64}$').hasMatch(hash), isTrue);
    });

    test('the same photo hashes identically — distance 0', () {
      final bytes = _jpeg(1600, 1200, r: 80, g: 140, b: 200);
      final a = computeVenuePhotoHash(bytes);
      final b = computeVenuePhotoHash(bytes);
      expect(hammingDistance(a, b), 0);
    });

    test('re-encoding the same image at a different JPEG quality '
        'stays a near-duplicate (small Hamming distance)', () {
      final image = img.Image(width: 1600, height: 1200);
      img.fill(image, color: img.ColorRgb8(90, 130, 60));
      // A flat single-colour fill is the least interesting case for a
      // frequency-domain hash (every DCT coefficient outside DC is
      // already ~0), so draw a few distinct shapes into it — enough
      // structure that re-compression noise is a meaningfully smaller
      // perturbation than genuinely different content, without needing
      // a real photograph as a fixture.
      img.fillRect(
        image,
        x1: 200,
        y1: 150,
        x2: 900,
        y2: 700,
        color: img.ColorRgb8(220, 200, 40),
      );
      img.fillCircle(
        image,
        x: 1200,
        y: 850,
        radius: 250,
        color: img.ColorRgb8(30, 60, 160),
      );

      final highQuality = Uint8List.fromList(img.encodeJpg(image, quality: 95));
      final lowQuality = Uint8List.fromList(img.encodeJpg(image, quality: 60));

      final hashHigh = computeVenuePhotoHash(highQuality);
      final hashLow = computeVenuePhotoHash(lowQuality);

      // The production duplicate-detection trigger's own threshold
      // (venue_photo_duplicate_hamming_threshold, 20260828130000) is 10
      // — a mere quality re-encode of the identical image must fall
      // well inside it.
      expect(hammingDistance(hashHigh, hashLow), lessThanOrEqualTo(10));
    });

    test('visually different photos hash far apart (large Hamming '
        'distance)', () {
      final a = img.Image(width: 1600, height: 1200);
      img.fill(a, color: img.ColorRgb8(10, 10, 10));
      img.fillCircle(
        a,
        x: 400,
        y: 300,
        radius: 250,
        color: img.ColorRgb8(240, 240, 240),
      );

      final b = img.Image(width: 1600, height: 1200);
      img.fill(b, color: img.ColorRgb8(240, 240, 240));
      img.fillRect(
        b,
        x1: 900,
        y1: 100,
        x2: 1500,
        y2: 1100,
        color: img.ColorRgb8(10, 10, 10),
      );

      final hashA = computeVenuePhotoHash(Uint8List.fromList(img.encodeJpg(a)));
      final hashB = computeVenuePhotoHash(Uint8List.fromList(img.encodeJpg(b)));

      expect(hammingDistance(hashA, hashB), greaterThan(10));
    });

    test('hammingDistance throws on mismatched lengths', () {
      expect(() => hammingDistance('0101', '010'), throwsArgumentError);
    });
  });
}
