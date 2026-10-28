// Covers CardPhotoScreen (20261015120000): it starts on the photo the
// cards show today, Save stays off until something changes, saving sends
// the chosen photo and its card crop through set_venue_card_photo,
// "Follow my cover" clears the choice, a failure stays open with a
// message, and a chef card left at its default is saved as untouched.

import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:michelin_passport/data/repositories/venue_photo_submission_repository.dart';
import 'package:michelin_passport/features/profile/card_photo_screen.dart';
import 'package:michelin_passport/models/managed_venue.dart';
import 'package:michelin_passport/models/photo_framing.dart';
import 'package:michelin_passport/models/private_chef.dart';
import 'package:michelin_passport/models/published_venue_photo.dart';
import 'package:michelin_passport/models/restaurant.dart';

SupabaseClient _dummyClient() => SupabaseClient(
  'https://test.supabase.co',
  'test-anon-key',
  authOptions: const AuthClientOptions(autoRefreshToken: false),
);

typedef _Call = ({String venueId, String? photoId, PhotoFraming framing});

class _FakeRepo extends VenuePhotoSubmissionRepository {
  _FakeRepo({this.error}) : super(_dummyClient());
  final Object? error;
  final calls = <_Call>[];

  @override
  Future<void> setCardPhoto({
    required String venueType,
    required String venueId,
    required String? photoId,
    PhotoFraming framing = PhotoFraming.center,
  }) async {
    if (error != null) throw error!;
    calls.add((venueId: venueId, photoId: photoId, framing: framing));
  }
}

final _image = MemoryImage(
  Uint8List.fromList(img.encodePng(img.Image(width: 400, height: 200))),
);

// Decoded before any google_fonts text is built — see
// photo_framing_editor_test.dart's _precache for why.
Future<void> _precache(WidgetTester tester) => tester.runAsync(() {
  final done = Completer<void>();
  final stream = _image.resolve(ImageConfiguration.empty);
  late final ImageStreamListener listener;
  listener = ImageStreamListener((_, _) {
    stream.removeListener(listener);
    if (!done.isCompleted) done.complete();
  });
  stream.addListener(listener);
  return done.future;
});

ManagedVenue _restaurant() => ManagedRestaurant(
  Restaurant.fromJson({'id': 'r1', 'name': 'Flore', 'city_name': 'Amsterdam'}),
);

ManagedVenue _chef() => ManagedPrivateChef(
  PrivateChef.fromJson({'id': 'c1', 'display_name': 'Lucas'}),
);

const _p1 = PublishedVenuePhoto(
  id: 'p1',
  imageUrl: 'https://example.test/1.jpg',
  displayOrder: 0,
);
const _p2 = PublishedVenuePhoto(
  id: 'p2',
  imageUrl: 'https://example.test/2.jpg',
  displayOrder: 1,
);

Future<List<bool?>> _pump(
  WidgetTester tester,
  _FakeRepo repo, {
  List<PublishedVenuePhoto> photos = const [_p1, _p2],
  ManagedVenue? venue,
}) async {
  final popped = <bool?>[];
  await _precache(tester);
  await tester.binding.setSurfaceSize(const Size(800, 1800));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () async {
              popped.add(
                await Navigator.push<bool>(
                  context,
                  MaterialPageRoute(
                    builder: (_) => CardPhotoScreen(
                      venue: venue ?? _restaurant(),
                      photos: photos,
                      repository: repo,
                      imageFor: (_) => _image,
                    ),
                  ),
                ),
              );
            },
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  return popped;
}

FilledButton _saveButton(WidgetTester tester) => tester.widget<FilledButton>(
  find.ancestor(of: find.text('Save'), matching: find.byType(FilledButton)),
);

Finder _choice(int index) => find
    .byWidgetPredicate((w) => w is Semantics && w.properties.button == true)
    .at(index);

void main() {
  test('currentCardPhoto: the flagged photo, else the cover', () {
    expect(CardPhotoScreen.currentCardPhoto(const [_p1, _p2])?.id, 'p1');
    const flagged = PublishedVenuePhoto(
      id: 'p2',
      imageUrl: 'https://example.test/2.jpg',
      displayOrder: 1,
      isCard: true,
    );
    expect(CardPhotoScreen.currentCardPhoto(const [_p1, flagged])?.id, 'p2');
    expect(CardPhotoScreen.currentCardPhoto(const []), isNull);
  });

  testWidgets('with no choice yet, it starts on the cover and Save makes '
      'the cover the card photo explicitly', (tester) async {
    final repo = _FakeRepo();
    final popped = await _pump(tester, repo);
    expect(find.text('Follow my cover'), findsNothing);
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(repo.calls.single.photoId, 'p1');
    expect(popped, [true]);
  });

  testWidgets('picking another photo and zooming saves that photo with its '
      'own card crop', (tester) async {
    final repo = _FakeRepo();
    await _pump(tester, repo);
    await tester.tap(_choice(1));
    await tester.pump();
    tester.widget<Slider>(find.byType(Slider)).onChanged!(2);
    await tester.pump();
    await tester.ensureVisible(find.text('Save'));
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(repo.calls.single.venueId, 'r1');
    expect(repo.calls.single.photoId, 'p2');
    expect(repo.calls.single.framing, const PhotoFraming(zoom: 2));
  });

  testWidgets('with a choice already made, Save is off until something '
      'changes, and Follow my cover clears it', (tester) async {
    final repo = _FakeRepo();
    const flagged = PublishedVenuePhoto(
      id: 'p2',
      imageUrl: 'https://example.test/2.jpg',
      displayOrder: 1,
      isCard: true,
    );
    final popped = await _pump(tester, repo, photos: const [_p1, flagged]);
    expect(_saveButton(tester).onPressed, isNull);
    await tester.ensureVisible(find.text('Follow my cover'));
    await tester.tap(find.text('Follow my cover'));
    await tester.pumpAndSettle();
    expect(repo.calls.single.photoId, isNull);
    expect(popped, [true]);
  });

  testWidgets('a failed save shows a message and stays open', (tester) async {
    final popped = await _pump(tester, _FakeRepo(error: Exception('boom')));
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.text('Could not save. Please try again.'), findsOneWidget);
    expect(find.byType(CardPhotoScreen), findsOneWidget);
    expect(popped, isEmpty);
  });

  testWidgets('a chef card saved at its default is stored as untouched', (
    tester,
  ) async {
    final repo = _FakeRepo();
    await _pump(tester, repo, venue: _chef());
    await tester.ensureVisible(find.text('Save'));
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(repo.calls.single.framing, PhotoFraming.center);
  });
}
