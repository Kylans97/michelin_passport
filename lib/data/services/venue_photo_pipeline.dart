/// Venue photo submission — Layers 1 (client-side validation + EXIF
/// strip) and 2 (perceptual hash for duplicate detection). Pure Dart, no
/// Flutter/Supabase import — every function here is a plain byte-in,
/// value-out transform, independent of how the bytes were picked or
/// where they end up, matching this app's `core`/`data/services`
/// separation (Supabase orchestration lives in
/// `VenuePhotoSubmissionRepository` instead).
library;

import 'dart:math' as math;
import 'dart:typed_data';
import 'package:image/image.dart' as img;
import '../../core/constants/venue_photo_submission_limits.dart';

/// Why Layer 1 rejected a photo, or that it passed — a distinct case per
/// requirement rather than one generic failure, so the caller can show
/// "duidelijke melding welke eis niet gehaald is" instead of one flat
/// "invalid image" message.
enum VenuePhotoRejectionReason {
  undecodable,
  unsupportedFormat,
  tooLarge,
  tooLowResolution,
  aspectRatioOutOfRange,
}

sealed class VenuePhotoValidation {
  const VenuePhotoValidation();
}

class VenuePhotoValidationOk extends VenuePhotoValidation {
  const VenuePhotoValidationOk();
}

class VenuePhotoValidationRejected extends VenuePhotoValidation {
  const VenuePhotoValidationRejected(this.reason, this.message);
  final VenuePhotoRejectionReason reason;
  final String message;
}

/// Layer 1 — every check runs in order, cheapest/no-decode-needed first,
/// and returns on the FIRST failing requirement (matching "weiger met
/// een duidelijke melding welke eis niet gehaald is" — one specific
/// reason, not every reason at once).
VenuePhotoValidation validateVenuePhoto(Uint8List bytes) {
  if (bytes.lengthInBytes > maxVenuePhotoSubmissionBytes) {
    final maxMb = maxVenuePhotoSubmissionBytes / (1024 * 1024);
    return VenuePhotoValidationRejected(
      VenuePhotoRejectionReason.tooLarge,
      'This photo is larger than ${maxMb.toStringAsFixed(0)} MB. '
      'Please choose a smaller file.',
    );
  }

  // findDecoderForData/decodeImage aren't guaranteed well-behaved on
  // arbitrary/malformed/truncated input — some format sniffers in this
  // package read past a too-short buffer and throw rather than
  // returning null (observed with a 5-byte input). A submission is
  // untrusted, attacker-shaped input by nature, so any exception here
  // is treated exactly like "not a decodable image," never allowed to
  // propagate as a crash.
  img.Decoder? decoder;
  img.Image? decoded;
  try {
    decoder = img.findDecoderForData(bytes);
    if (decoder is img.JpegDecoder || decoder is img.PngDecoder) {
      decoded = img.decodeImage(bytes);
    }
  } catch (_) {
    decoder = null;
    decoded = null;
  }

  if (decoder is! img.JpegDecoder && decoder is! img.PngDecoder) {
    return const VenuePhotoValidationRejected(
      VenuePhotoRejectionReason.unsupportedFormat,
      'Only JPEG and PNG photos are accepted.',
    );
  }

  if (decoded == null) {
    return const VenuePhotoValidationRejected(
      VenuePhotoRejectionReason.undecodable,
      'This file could not be read as a photo.',
    );
  }

  final shortSide = math.min(decoded.width, decoded.height);
  if (shortSide < minVenuePhotoShortSidePx) {
    return VenuePhotoValidationRejected(
      VenuePhotoRejectionReason.tooLowResolution,
      'This photo is too small — the shorter side must be at least '
      '$minVenuePhotoShortSidePx pixels (this one is $shortSide).',
    );
  }

  final longSide = math.max(decoded.width, decoded.height);
  final ratio = longSide / shortSide;
  if (ratio < minVenuePhotoAspectRatio || ratio > maxVenuePhotoAspectRatio) {
    return const VenuePhotoValidationRejected(
      VenuePhotoRejectionReason.aspectRatioOutOfRange,
      'This photo\'s proportions don\'t fit — please use something '
      'between a 3:4 portrait and a 16:9 landscape shot, not a banner '
      'or a screenshot.',
    );
  }

  return const VenuePhotoValidationOk();
}

/// Layer 1 — "Dit is niet optioneel": always returns freshly re-encoded
/// bytes with no EXIF metadata, regardless of what the source carried.
/// Decoding then re-encoding through the `image` package does not
/// automatically carry EXIF over on its own, but [img.Image.exif] is
/// explicitly cleared before encoding anyway rather than relying on that
/// implicit behaviour — GPS coordinates (a submitter's home address, for
/// a chef uploading from their kitchen) must never survive this step by
/// accident.
///
/// Re-encodes as the same format it decoded (JPEG stays JPEG, PNG stays
/// PNG) — [validateVenuePhoto] already guarantees the input is one of
/// the two, so this never needs a third branch.
Uint8List stripExifFromVenuePhoto(Uint8List bytes) {
  final decoder = img.findDecoderForData(bytes);
  final decoded = img.decodeImage(bytes);
  if (decoded == null) {
    throw ArgumentError('Cannot strip EXIF: bytes are not a decodable image.');
  }
  decoded.exif.clear();

  final isPng = decoder is img.PngDecoder;
  return Uint8List.fromList(
    isPng ? img.encodePng(decoded) : img.encodeJpg(decoded, quality: 92),
  );
}

// ============================================================
// Layer 2 — perceptual hash (64-bit DCT pHash) + Hamming distance
// ============================================================
//
// The standard "Looks Like It"/phash.org algorithm: grayscale, resize to
// 32x32, 2D DCT-II, take the top-left 8x8 low-frequency block, threshold
// each coefficient against the mean of that block (excluding the DC
// term at [0][0], which only reflects overall brightness) to produce 64
// bits. Implemented directly against the `image` package rather than a
// ready-made pHash package — see this feature's own pubspec.yaml
// comment for why (the one available pure-Dart option's PHash support is
// explicitly marked "under development... not yet validated" by its own
// maintainer).
//
// Output is a 64-character string of '0'/'1' characters, matching
// Postgres's `bit(64)` text input format exactly — sent as a plain JSON
// string through PostgREST on insert, no client-side encoding beyond
// producing this string.

const int _dctSize = 32;
const int _hashBlockSize = 8;

/// Computes the 64-bit perceptual hash of [bytes] as a 64-character
/// '0'/'1' string. Throws [ArgumentError] if the bytes aren't a
/// decodable image — call this only after [validateVenuePhoto] confirms
/// the photo is valid.
String computeVenuePhotoHash(Uint8List bytes) {
  final decoded = img.decodeImage(bytes);
  if (decoded == null) {
    throw ArgumentError('Cannot hash: bytes are not a decodable image.');
  }

  final gray = img.grayscale(decoded);
  final small = img.copyResize(
    gray,
    width: _dctSize,
    height: _dctSize,
    interpolation: img.Interpolation.average,
  );

  final matrix = List.generate(
    _dctSize,
    (y) => List.generate(
      _dctSize,
      (x) => small.getPixel(x, y).r.toDouble(),
    ),
  );

  final dct = _dct2d(matrix);

  final block = <double>[
    for (var y = 0; y < _hashBlockSize; y++)
      for (var x = 0; x < _hashBlockSize; x++) dct[y][x],
  ];

  // Exclude index 0 (the [0][0] DC coefficient — first element in
  // row-major order) from the mean; it carries the block's average
  // brightness, not structure, and including it would bias every hash
  // toward whichever half of the photo happens to be lighter overall.
  final withoutDc = block.sublist(1);
  final mean = withoutDc.reduce((a, b) => a + b) / withoutDc.length;

  return block.map((v) => v > mean ? '1' : '0').join();
}

/// The number of differing bits between two same-length pHash strings —
/// 0 means identical, 64 means every bit differs. Used client-side only
/// for testing this module in isolation; the actual duplicate-detection
/// gate runs server-side (`enforce_photo_duplicate_check`,
/// 20260828130000) via Postgres's `bit_count(a # b)`, since that check
/// needs visibility into other users' submissions this client can't
/// itself read under RLS.
int hammingDistance(String a, String b) {
  if (a.length != b.length) {
    throw ArgumentError('Hashes must be the same length (${a.length} vs ${b.length}).');
  }
  var distance = 0;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) distance++;
  }
  return distance;
}

/// Precomputed once per call — cheap enough (32x32) that there's no need
/// to cache across calls; a submission flow hashes exactly one photo.
List<List<double>> _buildDctCosTable(int n) => List.generate(
  n,
  (k) => List.generate(
    n,
    (i) => math.cos(math.pi / n * (i + 0.5) * k),
  ),
);

List<double> _dct1d(List<double> x, List<List<double>> cosTable) {
  final n = x.length;
  return List.generate(n, (k) {
    var sum = 0.0;
    for (var i = 0; i < n; i++) {
      sum += x[i] * cosTable[k][i];
    }
    return sum;
  });
}

/// Separable 2D DCT-II: 1D DCT over every row, then 1D DCT over every
/// column of that result — standard for a square, real-valued input.
List<List<double>> _dct2d(List<List<double>> matrix) {
  final n = matrix.length;
  final cosTable = _buildDctCosTable(n);

  final rowDct = matrix.map((row) => _dct1d(row, cosTable)).toList();

  final result = List.generate(n, (_) => List<double>.filled(n, 0));
  for (var col = 0; col < n; col++) {
    final column = List<double>.generate(n, (row) => rowDct[row][col]);
    final colDct = _dct1d(column, cosTable);
    for (var row = 0; row < n; row++) {
      result[row][col] = colDct[row];
    }
  }
  return result;
}
