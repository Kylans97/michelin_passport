// Covers UploadVenuePhotoScreen via its own DI seams (repository,
// pickPhotos), mirroring this feature's established fake-repository
// convention. validateVenuePhoto itself is pure Dart (no network), so
// real encoded test images (matching venue_photo_pipeline_test.dart's
// own `image` package technique) exercise the REAL validation path —
// not a mocked result — proving the guidance copy and the rejection
// message the manager actually sees agree with what the pipeline
// actually enforces.

import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:michelin_passport/core/constants/venue_photo_submission_limits.dart';
import 'package:michelin_passport/data/repositories/venue_photo_submission_repository.dart';
import 'package:michelin_passport/features/profile/upload_venue_photo_screen.dart';
import 'package:michelin_passport/features/profile/widgets/venue_photo_picker.dart';
import 'package:michelin_passport/models/managed_venue.dart';
import 'package:michelin_passport/models/private_chef.dart';
import 'package:michelin_passport/models/published_venue_photo.dart';
import 'package:michelin_passport/models/restaurant.dart';

Uint8List _jpeg(int width, int height) {
  final image = img.Image(width: width, height: height);
  img.fill(image, color: img.ColorRgb8(120, 90, 60));
  return Uint8List.fromList(img.encodeJpg(image));
}

// 1600x1200: short side 1200 (meets the 1200px minimum exactly), ratio
// 1600/1200 = 1.333 (within [4/3, 16/9]) — a genuinely valid photo.
final _validBytes = _jpeg(1600, 1200);

// 800x600: short side 600, below minVenuePhotoShortSidePx (1200) —
// genuinely too small, real rejection from the real pipeline.
final _tooSmallBytes = _jpeg(800, 600);

SupabaseClient _dummyClient() => SupabaseClient(
  'https://test.supabase.co',
  'test-anon-key',
  authOptions: const AuthClientOptions(autoRefreshToken: false),
);

typedef _SubmitCall = ({String venueType, String venueId, String? replacesPhotoId});

class _FakeVenuePhotoSubmissionRepository extends VenuePhotoSubmissionRepository {
  _FakeVenuePhotoSubmissionRepository({this.submitError, this.failOnCallNumber, this.onSubmit})
    : super(_dummyClient());

  final Object? submitError;

  // 1-based: the Nth submit() call throws, every other call succeeds —
  // lets a test simulate "one of several uploads fails" deterministically
  // by call order, matching the order _staged (and therefore submission)
  // happens in.
  final int? failOnCallNumber;
  final void Function(_SubmitCall call)? onSubmit;

  int _calls = 0;

  @override
  Future<Map<String, dynamic>> submit({
    required String userId,
    required String venueType,
    required String venueId,
    required Uint8List rawBytes,
    String? replacesPhotoId,
  }) async {
    _calls++;
    if (submitError != null) throw submitError!;
    if (failOnCallNumber != null && _calls == failOnCallNumber) {
      throw Exception('simulated upload failure');
    }
    onSubmit?.call((venueType: venueType, venueId: venueId, replacesPhotoId: replacesPhotoId));
    return {'id': 'new-submission-$_calls'};
  }
}

typedef _PhotosPicker = Future<List<StagedVenuePhoto>> Function(BuildContext, {required int maxSelectable});

_PhotosPicker _pickerReturning(List<Uint8List> bytesList, {void Function(int maxSelectable)? onCalled}) {
  return (BuildContext context, {required int maxSelectable}) async {
    onCalled?.call(maxSelectable);
    return [for (final b in bytesList) StagedVenuePhoto(bytes: b)];
  };
}

ManagedVenue _restaurant() => ManagedRestaurant(
  Restaurant.fromJson({'id': 'r1', 'name': 'Flore Amsterdam', 'city_name': 'Amsterdam'}),
);

ManagedVenue _chef() =>
    ManagedPrivateChef(PrivateChef.fromJson({'id': 'c1', 'display_name': 'Chef Amara'}));

PublishedVenuePhoto _publishedPhoto(int i) =>
    PublishedVenuePhoto(id: 'p$i', imageUrl: 'https://example.test/$i.jpg', displayOrder: i);

Future<void> _pump(
  WidgetTester tester, {
  ManagedVenue? venue,
  List<PublishedVenuePhoto> publishedPhotos = const [],
  VenuePhotoSubmissionRepository? repository,
  _PhotosPicker? pickPhotos,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: UploadVenuePhotoScreen(
        venue: venue ?? _restaurant(),
        publishedPhotos: publishedPhotos,
        repository: repository ?? _FakeVenuePhotoSubmissionRepository(),
        pickPhotos: pickPhotos,
        currentUserId: 'u1',
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _tapChoose(WidgetTester tester) async {
  final label = find.textContaining('Choose a photo').evaluate().isNotEmpty
      ? find.textContaining('Choose a photo')
      : find.textContaining('Choose photos');
  await tester.tap(label.first);
  await tester.pumpAndSettle();
}

void main() {
  group('UploadVenuePhotoScreen — guidance, before picking', () {
    testWidgets('states the real limits before any file is picked', (tester) async {
      await _pump(tester);
      expect(find.text('BEFORE YOU UPLOAD'), findsOneWidget);
      expect(find.textContaining('Up to $maxVenuePhotoCount photos'), findsOneWidget);
      expect(find.textContaining('$minVenuePhotoShortSidePx pixels'), findsOneWidget);
      expect(find.textContaining('review every photo by hand'), findsOneWidget);
    });

    testWidgets('states the private-chef portrait rule up front, for a chef venue only', (
      tester,
    ) async {
      await _pump(tester, venue: _chef());
      expect(
        find.textContaining('Your first photo is a portrait of you'),
        findsOneWidget,
      );
    });

    testWidgets('never shows the chef-only portrait rule for a restaurant', (tester) async {
      await _pump(tester);
      expect(find.textContaining('portrait of you'), findsNothing);
    });

    testWidgets('states the real remaining capacity before picking, not after — some photos '
        'already published, venue not at cap', (tester) async {
      await _pump(tester, publishedPhotos: [for (var i = 0; i < 4; i++) _publishedPhoto(i)]);
      // maxVenuePhotoCount is 5 in this codebase's real constant — 4
      // published leaves exactly 1 remaining.
      expect(
        find.textContaining(
          'already has 4 of $maxVenuePhotoCount — you can add up to '
          '${maxVenuePhotoCount - 4} more right now',
        ),
        findsOneWidget,
      );
    });

    testWidgets('says nothing extra about remaining capacity with zero published photos '
        '(it would just repeat the sentence above)', (tester) async {
      await _pump(tester);
      expect(find.textContaining('you can add up to'), findsNothing);
    });

    testWidgets('the button says "Choose photos" (plural) when more than one may be picked', (
      tester,
    ) async {
      await _pump(tester);
      expect(find.text('Choose photos'), findsOneWidget);
    });

    testWidgets('the button says "Choose a photo" (singular) at the cap, where only a '
        'replacement may be picked', (tester) async {
      await _pump(tester, publishedPhotos: [for (var i = 0; i < maxVenuePhotoCount; i++) _publishedPhoto(i)]);
      expect(find.text('Choose a photo'), findsOneWidget);
    });

    testWidgets('passes the real remaining capacity to the picker, not the venue-wide max', (
      tester,
    ) async {
      int? seenMaxSelectable;
      await _pump(
        tester,
        publishedPhotos: [for (var i = 0; i < 4; i++) _publishedPhoto(i)],
        pickPhotos: _pickerReturning([], onCalled: (m) => seenMaxSelectable = m),
      );
      await _tapChoose(tester);
      expect(seenMaxSelectable, maxVenuePhotoCount - 4);
    });

    testWidgets('passes exactly 1 to the picker at the cap', (tester) async {
      int? seenMaxSelectable;
      await _pump(
        tester,
        publishedPhotos: [for (var i = 0; i < maxVenuePhotoCount; i++) _publishedPhoto(i)],
        pickPhotos: _pickerReturning([], onCalled: (m) => seenMaxSelectable = m),
      );
      await _tapChoose(tester);
      expect(seenMaxSelectable, 1);
    });
  });

  group('UploadVenuePhotoScreen — picking and validating', () {
    testWidgets('a cancelled pick (empty list) changes nothing', (tester) async {
      await _pump(tester, pickPhotos: _pickerReturning([]));
      await _tapChoose(tester);
      expect(find.text('Choose photos'), findsOneWidget);
    });

    testWidgets('a single genuinely too-small photo is rejected with the real pipeline '
        'message, never a network call', (tester) async {
      var calls = 0;
      await _pump(
        tester,
        pickPhotos: _pickerReturning([_tooSmallBytes]),
        repository: _FakeVenuePhotoSubmissionRepository(onSubmit: (_) => calls++),
      );
      await _tapChoose(tester);
      expect(find.textContaining('too small'), findsOneWidget);
      expect(find.textContaining("couldn't be used"), findsOneWidget);
      expect(find.textContaining('Submit'), findsNothing);
      expect(calls, 0);
    });

    testWidgets('a single valid photo shows the frame preview, not a rejection', (tester) async {
      await _pump(tester, pickPhotos: _pickerReturning([_validBytes]));
      await _tapChoose(tester);
      expect(find.text('AS THE HEADER'), findsOneWidget);
      expect(find.text('AS A CARD'), findsOneWidget);
      expect(find.text('Submit for review'), findsOneWidget);
      // Exactly one photo: no "photo X of Y" progress clutter.
      expect(find.textContaining('PHOTO 1 OF'), findsNothing);
    });

    testWidgets('a mix of valid and invalid photos reports the failures and keeps the good '
        'ones — never all-or-nothing', (tester) async {
      await _pump(tester, pickPhotos: _pickerReturning([_validBytes, _tooSmallBytes, _validBytes]));
      await _tapChoose(tester);
      expect(find.text("1 photo couldn't be used"), findsOneWidget);
      expect(find.textContaining('too small'), findsOneWidget);
      // The 2 valid ones survive into the step-through flow.
      expect(find.textContaining('PHOTO 1 OF 2'), findsOneWidget);
      expect(find.text('Next photo'), findsOneWidget);
    });

    testWidgets('every photo failing validation reports all of them and stays on the '
        'choose-photos state', (tester) async {
      await _pump(tester, pickPhotos: _pickerReturning([_tooSmallBytes, _tooSmallBytes]));
      await _tapChoose(tester);
      expect(find.text("2 photos couldn't be used"), findsOneWidget);
      expect(find.text('Choose photos'), findsOneWidget);
      expect(find.textContaining('Submit'), findsNothing);
    });
  });

  group('UploadVenuePhotoScreen — stepping through multiple photos', () {
    testWidgets('shows progress and steps forward with Next photo, then Back returns to the '
        'first', (tester) async {
      await _pump(tester, pickPhotos: _pickerReturning([_validBytes, _validBytes, _validBytes]));
      await _tapChoose(tester);
      expect(find.text('PHOTO 1 OF 3'), findsOneWidget);
      expect(find.text('Next photo'), findsOneWidget);
      expect(find.text('Back'), findsNothing);

      await tester.ensureVisible(find.text('Next photo'));
      await tester.tap(find.text('Next photo'));
      await tester.pumpAndSettle();
      expect(find.text('PHOTO 2 OF 3'), findsOneWidget);
      expect(find.text('Back'), findsOneWidget);
      expect(find.text('Next photo'), findsOneWidget);

      await tester.ensureVisible(find.text('Next photo'));
      await tester.tap(find.text('Next photo'));
      await tester.pumpAndSettle();
      expect(find.text('PHOTO 3 OF 3'), findsOneWidget);
      expect(find.text('Submit all 3 photos'), findsOneWidget);

      await tester.ensureVisible(find.text('Back'));
      await tester.tap(find.text('Back'));
      await tester.pumpAndSettle();
      expect(find.text('PHOTO 2 OF 3'), findsOneWidget);
    });
  });

  group('UploadVenuePhotoScreen — submitting', () {
    testWidgets('a valid single submission calls the repository with this venue\'s type/id and '
        'no replacement, then confirms', (tester) async {
      _SubmitCall? received;
      await _pump(
        tester,
        pickPhotos: _pickerReturning([_validBytes]),
        repository: _FakeVenuePhotoSubmissionRepository(onSubmit: (c) => received = c),
      );
      await _tapChoose(tester);
      await tester.ensureVisible(find.text('Submit for review'));
      await tester.tap(find.text('Submit for review'));
      await tester.pumpAndSettle();

      expect(received?.venueType, 'restaurant');
      expect(received?.venueId, 'r1');
      expect(received?.replacesPhotoId, isNull);
      expect(find.text('Submitted for review'), findsOneWidget);
    });

    testWidgets('submitting several photos calls the repository once per photo, then confirms '
        'with the real count', (tester) async {
      final received = <_SubmitCall>[];
      await _pump(
        tester,
        pickPhotos: _pickerReturning([_validBytes, _validBytes, _validBytes]),
        repository: _FakeVenuePhotoSubmissionRepository(onSubmit: received.add),
      );
      await _tapChoose(tester);
      await tester.ensureVisible(find.text('Next photo'));
      await tester.tap(find.text('Next photo'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Next photo'));
      await tester.tap(find.text('Next photo'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Submit all 3 photos'));
      await tester.tap(find.text('Submit all 3 photos'));
      await tester.pumpAndSettle();

      expect(received.length, 3);
      expect(received.every((c) => c.replacesPhotoId == null), isTrue);
      expect(find.text('Submitted 3 photos for review'), findsOneWidget);
    });

    testWidgets('one photo failing to upload never rolls back the ones that already '
        'succeeded — the rest still submit and are reported separately', (tester) async {
      await _pump(
        tester,
        pickPhotos: _pickerReturning([_validBytes, _validBytes, _validBytes]),
        repository: _FakeVenuePhotoSubmissionRepository(failOnCallNumber: 2),
      );
      await _tapChoose(tester);
      await tester.ensureVisible(find.text('Next photo'));
      await tester.tap(find.text('Next photo'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Next photo'));
      await tester.tap(find.text('Next photo'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Submit all 3 photos'));
      await tester.tap(find.text('Submit all 3 photos'));
      await tester.pumpAndSettle();

      expect(find.text('Submitted 2 of 3 photos'), findsOneWidget);
      expect(find.textContaining('1 could not be submitted'), findsOneWidget);
    });

    testWidgets('every photo failing to upload reports total failure and never claims success', (
      tester,
    ) async {
      await _pump(
        tester,
        pickPhotos: _pickerReturning([_validBytes, _validBytes]),
        repository: _FakeVenuePhotoSubmissionRepository(submitError: Exception('connection reset')),
      );
      await _tapChoose(tester);
      await tester.ensureVisible(find.text('Next photo'));
      await tester.tap(find.text('Next photo'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Submit all 2 photos'));
      await tester.tap(find.text('Submit all 2 photos'));
      await tester.pumpAndSettle();

      expect(find.text('Could not submit these photos'), findsOneWidget);
      expect(find.textContaining('connection reset'), findsNothing);
    });

    testWidgets('at the photo cap, submitting is blocked until a replacement is chosen', (
      tester,
    ) async {
      final published = [for (var i = 0; i < maxVenuePhotoCount; i++) _publishedPhoto(i)];
      var calls = 0;
      await _pump(
        tester,
        publishedPhotos: published,
        pickPhotos: _pickerReturning([_validBytes]),
        repository: _FakeVenuePhotoSubmissionRepository(onSubmit: (_) => calls++),
      );
      await _tapChoose(tester);
      expect(find.textContaining('choose which one this replaces'), findsOneWidget);

      await tester.ensureVisible(find.text('Submit for review'));
      await tester.tap(find.text('Submit for review'));
      await tester.pump();
      expect(find.text('Choose which existing photo this one replaces.'), findsOneWidget);
      expect(calls, 0);
    });

    testWidgets('at the photo cap, choosing a replacement lets submission proceed with '
        'that photo\'s id', (tester) async {
      final published = [for (var i = 0; i < maxVenuePhotoCount; i++) _publishedPhoto(i)];
      _SubmitCall? received;
      await _pump(
        tester,
        publishedPhotos: published,
        pickPhotos: _pickerReturning([_validBytes]),
        repository: _FakeVenuePhotoSubmissionRepository(onSubmit: (c) => received = c),
      );
      await _tapChoose(tester);
      await tester.ensureVisible(find.text('Currently first'));
      await tester.tap(find.text('Currently first'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Submit for review'));
      await tester.tap(find.text('Submit for review'));
      await tester.pumpAndSettle();
      expect(received?.replacesPhotoId, 'p0');
    });
  });
}
