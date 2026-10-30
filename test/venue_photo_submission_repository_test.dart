// Covers photoSubmissionConflictMessage() — the branching
// VenuePhotoSubmissionRepository.submit() uses to turn a 23505
// (unique_violation) into the right UI-safe StateError message. Tested
// directly against a hand-built PostgrestException rather than through
// submit() itself: that method needs a real signed-in SupabaseClient with
// Storage access to reach this code, and this repo has no existing
// pattern for faking that in a test — mirrors venue_claim_repository_
// test.dart's own approach exactly. Message text below is copied verbatim
// from a real rollback-transaction probe against the live database, not
// guessed.

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:image/image.dart' as img;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:michelin_passport/data/repositories/venue_photo_submission_repository.dart';

void main() {
  pngSubmissionTests();
  group('photoSubmissionConflictMessage', () {
    test('a second pending submission naming the same replaces_photo_id '
        '(venue_photo_submissions_one_pending_replacement_uidx) is told a '
        'replacement is already awaiting review, not shown the raw '
        'constraint name', () {
      const e = PostgrestException(
        message:
            'duplicate key value violates unique constraint '
            '"venue_photo_submissions_one_pending_replacement_uidx"',
        code: '23505',
        details:
            'Key (replaces_photo_id)=(11111111-1111-1111-1111-111111111111) '
            'already exists.',
      );
      expect(
        photoSubmissionConflictMessage(e),
        "A replacement for this photo is already awaiting review. "
        "You can submit another once that one's been decided.",
      );
    });

    test('a non-23505 PostgrestException is not handled here — the caller '
        'must rethrow it, never swallow it as a submission-conflict '
        'message', () {
      const e = PostgrestException(
        message: 'permission denied for table venue_photo_submissions',
        code: '42501',
      );
      expect(photoSubmissionConflictMessage(e), isNull);
    });

    test('a 23505 from an unrelated constraint (e.g. the near-duplicate-'
        'photo check) is not mapped to the replacement-conflict message — '
        'stays null so the caller rethrows it unchanged rather than '
        'showing a misleading message', () {
      const e = PostgrestException(
        message:
            'duplicate key value violates unique constraint '
            '"some_other_table_uidx"',
        code: '23505',
      );
      expect(photoSubmissionConflictMessage(e), isNull);
    });
  });
}

// A PNG venue photo was uploaded as `<id>.jpg` with `image/jpeg` until
// 2026-10-30. submit() against a fake Storage + PostgREST, recording what
// it uploads.
void pngSubmissionTests() {
  test('a PNG is uploaded as .png with image/png', () async {
    final uploads = <http.BaseRequest>[];
    String? uploadedContentType;
    final client = SupabaseClient(
      'https://test.supabase.co',
      'test-anon-key',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
      httpClient: MockClient((request) async {
        if (request.url.path.contains('/storage/v1/object/')) {
          uploads.add(request);
          // A multipart body: the part's own Content-Type header is what
          // Storage records; read it as bytes, since the image isn't UTF-8.
          final body = latin1.decode(request.bodyBytes);
          uploadedContentType = RegExp(
            r'content-type: (image/\w+)',
            caseSensitive: false,
          ).firstMatch(body)?.group(1);
          return http.Response('{"Key":"k"}', 200, request: request);
        }
        return http.Response(
          jsonEncode({'id': 's1', 'storage_path': 'x'}),
          201,
          request: request,
        );
      }),
    );
    final image = img.Image(width: 1600, height: 1200);
    img.fill(image, color: img.ColorRgb8(40, 80, 60));
    final png = Uint8List.fromList(img.encodePng(image));

    await VenuePhotoSubmissionRepository(
      client,
    ).submit(userId: 'u', venueType: 'restaurant', venueId: 'r', rawBytes: png);

    expect(uploads.single.url.path, endsWith('.png'));
    expect(uploadedContentType, contains('image/png'));
  });
}
