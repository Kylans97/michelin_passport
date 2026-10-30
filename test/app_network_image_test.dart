// Photo egress is this project's main cost risk. Every card used to load
// the full original (a 1.6 MB venue photo for a 120 pt tile). These tests
// pin the slot-sized variant URL that replaced it.

import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:michelin_passport/core/widgets/app_network_image.dart';
import 'package:michelin_passport/data/repositories/photo_repository.dart';
import 'package:michelin_passport/data/repositories/profile_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _base = 'https://proj.supabase.co/storage/v1';
const _venuePhoto = '$_base/object/public/catalogue-media/restaurant/r1/a.jpg';

// The test binding answers every image fetch with a 400; only the URL
// matters here.
Widget _noImage(BuildContext _, Object _, StackTrace? _) => const SizedBox();

void main() {
  group('displayImageSize', () {
    test('rounds up to the next shared size, capped at the largest', () {
      expect(displayImageSize(1), 256);
      expect(displayImageSize(256), 256);
      expect(displayImageSize(480), 512);
      expect(displayImageSize(1100), 1536);
      expect(displayImageSize(9000), 2048);
    });
  });

  group('storageVariantUrl', () {
    test('turns a public object into a contain-fit render variant', () {
      expect(
        storageVariantUrl(_venuePhoto, 768),
        '$_base/render/image/public/catalogue-media/restaurant/r1/a.jpg'
        '?width=768&height=768&resize=contain',
      );
    });

    test('leaves signed and external URLs alone', () {
      expect(
        storageVariantUrl(
          '$_base/object/sign/visit-photos/u/v/a.jpg?token=t',
          512,
        ),
        isNull,
      );
      expect(storageVariantUrl('https://example.com/a.jpg', 512), isNull);
    });
  });

  group('AppNetworkImage', () {
    Future<String> loadedUrl(
      WidgetTester tester,
      Widget image, {
      Size slot = const Size(120, 80),
    }) async {
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(devicePixelRatio: 3),
          child: Center(
            child: SizedBox(
              width: slot.width,
              height: slot.height,
              child: image,
            ),
          ),
        ),
      );
      final provider = tester.widget<Image>(find.byType(Image)).image;
      return (provider as NetworkImage).url;
    }

    testWidgets('requests a variant sized to the slot', (tester) async {
      // 120 pt * 3 * 4/3 = 480 -> 512.
      expect(
        await loadedUrl(
          tester,
          const AppNetworkImage(_venuePhoto, errorBuilder: _noImage),
        ),
        storageVariantUrl(_venuePhoto, 512),
      );
    });

    testWidgets('scales the variant by the framing zoom', (tester) async {
      expect(
        await loadedUrl(
          tester,
          const AppNetworkImage(_venuePhoto, zoom: 2, errorBuilder: _noImage),
        ),
        storageVariantUrl(_venuePhoto, 1024),
      );
    });

    testWidgets('an infinite width falls back to the slot', (tester) async {
      expect(
        await loadedUrl(
          tester,
          const AppNetworkImage(
            _venuePhoto,
            width: double.infinity,
            errorBuilder: _noImage,
          ),
        ),
        storageVariantUrl(_venuePhoto, 512),
      );
    });

    testWidgets('a viewer gets the original', (tester) async {
      expect(
        await loadedUrl(
          tester,
          const AppNetworkImage(
            _venuePhoto,
            original: true,
            errorBuilder: _noImage,
          ),
        ),
        _venuePhoto,
      );
    });

    testWidgets('a signed URL is shown as given', (tester) async {
      const signed = '$_base/object/sign/visit-photos/a.jpg?token=t';
      expect(
        await loadedUrl(
          tester,
          const AppNetworkImage(signed, errorBuilder: _noImage),
        ),
        signed,
      );
    });
  });

  group('signed thumbnails', () {
    late List<Map<String, dynamic>> signBodies;

    SupabaseClient client({Set<String> failing = const {}}) {
      signBodies = [];
      return SupabaseClient(
        'https://proj.supabase.co',
        'anon',
        authOptions: const AuthClientOptions(autoRefreshToken: false),
        httpClient: MockClient((request) async {
          final path = request.url.path.split('/object/sign/').last;
          signBodies.add(jsonDecode(request.body) as Map<String, dynamic>);
          if (failing.any(path.endsWith)) {
            return http.Response('{"error":"nope"}', 400, request: request);
          }
          return http.Response(
            jsonEncode({'signedURL': '/render/image/sign/$path?token=t'}),
            200,
            request: request,
          );
        }),
      );
    }

    test(
      'visit photo tiles get a contain-fit copy; a failure is left out',
      () async {
        final repo = PhotoRepository(client(failing: {'b.jpg'}));
        final urls = await repo.resolveThumbnailUrls([
          'u/v/a.jpg',
          'u/v/b.jpg',
        ]);
        expect(urls.keys, ['u/v/a.jpg']);
        expect(urls['u/v/a.jpg'], contains('/render/image/sign/visit-photos/'));
        expect(signBodies.first['transform'], {
          'width': '$visitPhotoThumbnailEdge',
          'height': '$visitPhotoThumbnailEdge',
          'resize': 'contain',
        });
      },
    );

    test('the avatar URL is a small copy, not the stored file', () async {
      final repo = ProfileRepository(client());
      final url = await repo.resolveAvatarUrl('u/1.jpg');
      expect(url, contains('/render/image/sign/'));
      expect(signBodies.single['transform'], {
        'width': '$avatarDisplayEdge',
        'height': '$avatarDisplayEdge',
      });
    });
  });
}
