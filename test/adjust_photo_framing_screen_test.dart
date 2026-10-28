// Covers AdjustPhotoFramingScreen: Save stays off until the framing
// actually changes, saving goes through set_venue_photo_framing with the
// chosen framing and pops true, a failure says so without popping, and a
// private chef photo left at its default is saved as untouched.

import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:michelin_passport/data/repositories/venue_photo_submission_repository.dart';
import 'package:michelin_passport/features/profile/adjust_photo_framing_screen.dart';
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

class _FakeRepo extends VenuePhotoSubmissionRepository {
  _FakeRepo({this.error}) : super(_dummyClient());
  final Object? error;
  final calls = <({String venueType, String photoId, PhotoFraming framing})>[];

  @override
  Future<void> setPhotoFraming({
    required String venueType,
    required String photoId,
    required PhotoFraming framing,
  }) async {
    if (error != null) throw error!;
    calls.add((venueType: venueType, photoId: photoId, framing: framing));
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

const _photo = PublishedVenuePhoto(
  id: 'p1',
  imageUrl: 'https://example.test/1.jpg',
  displayOrder: 0,
);

Future<List<bool?>> _pump(
  WidgetTester tester,
  _FakeRepo repo, {
  ManagedVenue? venue,
}) async {
  final popped = <bool?>[];
  await _precache(tester);
  await tester.binding.setSurfaceSize(const Size(800, 1400));
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
                    builder: (_) => AdjustPhotoFramingScreen(
                      venue: venue ?? _restaurant(),
                      photo: _photo,
                      repository: repo,
                      image: _image,
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

void main() {
  testWidgets('Save is off until the framing changes', (tester) async {
    await _pump(tester, _FakeRepo());
    expect(_saveButton(tester).onPressed, isNull);
    tester.widget<Slider>(find.byType(Slider)).onChanged!(2);
    await tester.pump();
    expect(_saveButton(tester).onPressed, isNotNull);
  });

  testWidgets('saving calls set_venue_photo_framing and pops true', (
    tester,
  ) async {
    final repo = _FakeRepo();
    final popped = await _pump(tester, repo);
    tester.widget<Slider>(find.byType(Slider)).onChanged!(2);
    await tester.pump();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(repo.calls.single.venueType, 'restaurant');
    expect(repo.calls.single.photoId, 'p1');
    expect(repo.calls.single.framing, const PhotoFraming(zoom: 2));
    expect(popped, [true]);
  });

  testWidgets('a failed save shows a message and stays open', (tester) async {
    final popped = await _pump(tester, _FakeRepo(error: Exception('boom')));
    tester.widget<Slider>(find.byType(Slider)).onChanged!(2);
    await tester.pump();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.text('Could not save. Please try again.'), findsOneWidget);
    expect(find.byType(AdjustPhotoFramingScreen), findsOneWidget);
    expect(popped, isEmpty);
  });

  testWidgets('a chef photo zoomed then reset is saved as untouched', (
    tester,
  ) async {
    final repo = _FakeRepo();
    await _pump(tester, repo, venue: _chef());
    tester.widget<Slider>(find.byType(Slider)).onChanged!(2);
    await tester.pump();
    tester.widget<Slider>(find.byType(Slider)).onChanged!(1);
    await tester.pump();
    // Back at the chef default: nothing to save.
    expect(_saveButton(tester).onPressed, isNull);
    tester.widget<Slider>(find.byType(Slider)).onChanged!(1.5);
    await tester.pump();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(
      repo.calls.single.framing,
      const PhotoFraming(focusY: 0.1, zoom: 1.5),
    );
  });
}
