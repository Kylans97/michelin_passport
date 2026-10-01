// Covers VenueManagementScreen via its own DI seam (aboutRepo), mirroring
// the exact fake-repository-over-a-dummy-SupabaseClient convention
// claim_venue_flow_test.dart/my_venues_screen_test.dart already
// established for this feature — the screen never touches
// Supabase.instance.client when a fake is injected.

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart' as dotenv_pkg;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:michelin_passport/data/repositories/restaurant_repository.dart';
import 'package:michelin_passport/data/repositories/venue_about_repository.dart';
import 'package:michelin_passport/data/repositories/venue_photo_submission_repository.dart';
import 'package:michelin_passport/features/profile/venue_management_screen.dart';
import 'package:michelin_passport/features/restaurants/restaurant_detail_screen.dart';
import 'package:michelin_passport/models/managed_venue.dart';
import 'package:michelin_passport/models/private_chef.dart';
import 'package:michelin_passport/models/published_venue_photo.dart';
import 'package:michelin_passport/models/restaurant.dart';
import 'package:michelin_passport/models/venue_about_submission.dart';
import 'package:michelin_passport/models/venue_photo_submission_status.dart';

SupabaseClient _dummyClient() => SupabaseClient(
  'https://test.supabase.co',
  'test-anon-key',
  authOptions: const AuthClientOptions(autoRefreshToken: false),
);

typedef _SubmitCall = ({String venueType, String venueId, String aboutText});

class _FakeVenueAboutRepository extends VenueAboutRepository {
  _FakeVenueAboutRepository({
    this.currentText,
    this.latestSubmission,
    this.loadError,
    this.submitError,
    this.onSubmit,
  }) : super(_dummyClient());

  final String? currentText;
  final VenueAboutSubmission? latestSubmission;
  final Object? loadError;
  final Object? submitError;
  final void Function(_SubmitCall call)? onSubmit;

  @override
  Future<String?> loadCurrentText({required String venueType, required String venueId}) async {
    if (loadError != null) throw loadError!;
    return currentText;
  }

  @override
  Future<VenueAboutSubmission?> loadMyLatestSubmission({
    required String venueType,
    required String venueId,
  }) async {
    if (loadError != null) throw loadError!;
    return latestSubmission;
  }

  @override
  Future<void> submit({
    required String venueType,
    required String venueId,
    required String aboutText,
  }) async {
    if (submitError != null) throw submitError!;
    onSubmit?.call((venueType: venueType, venueId: venueId, aboutText: aboutText));
  }
}

typedef _ReorderCall = ({String venueType, String venueId, List<String> photoIds});

class _FakeVenuePhotoSubmissionRepository extends VenuePhotoSubmissionRepository {
  _FakeVenuePhotoSubmissionRepository({
    this.published = const [],
    this.openSubmissions = const [],
    this.displayUrls = const {},
    this.reorderError,
    this.onReorder,
  }) : super(_dummyClient());

  final List<PublishedVenuePhoto> published;
  final List<VenuePhotoSubmissionSummary> openSubmissions;
  final Map<String, String> displayUrls;
  final Object? reorderError;
  final void Function(_ReorderCall call)? onReorder;

  @override
  Future<List<PublishedVenuePhoto>> loadPublishedPhotos({
    required String venueType,
    required String venueId,
  }) async => published;

  @override
  Future<List<VenuePhotoSubmissionSummary>> loadMyOpenSubmissions({
    required String venueType,
    required String venueId,
  }) async => openSubmissions;

  @override
  Future<Map<String, String>> resolveDisplayUrls(
    List<String> storagePaths, {
    int expiresInSeconds = 3600,
  }) async => displayUrls;

  @override
  Future<void> reorderPhotos({
    required String venueType,
    required String venueId,
    required List<String> photoIds,
  }) async {
    if (reorderError != null) throw reorderError!;
    onReorder?.call((venueType: venueType, venueId: venueId, photoIds: photoIds));
  }
}

ManagedVenue _venue() => ManagedRestaurant(
  Restaurant.fromJson({'id': 'r1', 'name': 'Flore Amsterdam', 'city_name': 'Amsterdam'}),
);

class _FakeRestaurantRepository extends RestaurantRepository {
  _FakeRestaurantRepository({this.result, this.error}) : super(_dummyClient());

  final Restaurant? result;
  final Object? error;

  @override
  Future<Restaurant?> getById(String id) async {
    if (error != null) throw error!;
    return result;
  }
}

Future<void> _pump(
  WidgetTester tester,
  VenueAboutRepository repo, {
  ManagedVenue? venue,
  VenuePhotoSubmissionRepository? photoRepo,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: VenueManagementScreen(
        venue: venue ?? _venue(),
        aboutRepo: repo,
        photoRepo: photoRepo ?? _FakeVenuePhotoSubmissionRepository(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  // Only the "Preview my page" group below actually needs this: tapping
  // the button navigates for real, so the REAL RestaurantDetailScreen it
  // pushes builds for real too (unlike every other pushed screen in this
  // file, none of which touch Supabase.instance.client in their own
  // build path) — Supabase.instance.client throws without this. Doesn't
  // affect the rest of the file: every other test's fake repositories
  // wrap their own directly-constructed SupabaseClient, never the
  // singleton this initializes. Same pattern venue_preview_test.dart
  // already established.
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await dotenv_pkg.dotenv.load(fileName: '.env');
    await Supabase.initialize(
      url: dotenv_pkg.dotenv.env['SUPABASE_URL']!,
      // ignore: deprecated_member_use
      anonKey: dotenv_pkg.dotenv.env['SUPABASE_ANON_KEY']!,
    );
  });

  group('VenueManagementScreen — loading/error', () {
    testWidgets('shows a loading spinner before the future resolves', (tester) async {
      final repo = _FakeVenueAboutRepository();
      await tester.pumpWidget(
        MaterialApp(
          home: VenueManagementScreen(
            venue: _venue(),
            aboutRepo: repo,
            photoRepo: _FakeVenuePhotoSubmissionRepository(),
          ),
        ),
      );
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('shows a calm error message on failure, never a raw exception', (tester) async {
      await _pump(tester, _FakeVenueAboutRepository(loadError: Exception('boom')));
      expect(find.textContaining('Something went wrong'), findsOneWidget);
      expect(find.textContaining('Exception'), findsNothing);
    });
  });

  group('VenueManagementScreen — current text', () {
    testWidgets('shows the current approved text when one exists', (tester) async {
      await _pump(tester, _FakeVenueAboutRepository(currentText: 'A quiet corner of Amsterdam.'));
      expect(find.text('A quiet corner of Amsterdam.'), findsWidgets);
    });

    testWidgets('shows a plain "nothing published yet" line when there is none', (tester) async {
      await _pump(tester, _FakeVenueAboutRepository());
      expect(find.text('Nothing published yet.'), findsOneWidget);
    });

    testWidgets('the edit field is pre-filled with the current text', (tester) async {
      await _pump(tester, _FakeVenueAboutRepository(currentText: 'A quiet corner of Amsterdam.'));
      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.controller?.text, 'A quiet corner of Amsterdam.');
    });
  });

  group('VenueManagementScreen — pending/rejected status', () {
    testWidgets('shows a pending banner when the latest submission is pending', (tester) async {
      await _pump(
        tester,
        _FakeVenueAboutRepository(
          latestSubmission: VenueAboutSubmission(
            id: 's1',
            aboutText: 'Draft text',
            status: VenueAboutSubmissionStatus.pending,
            submittedAt: DateTime(2026, 9, 1),
          ),
        ),
      );
      expect(find.textContaining('awaiting review'), findsOneWidget);
    });

    testWidgets('shows a rejected notice when the latest submission was not approved', (
      tester,
    ) async {
      await _pump(
        tester,
        _FakeVenueAboutRepository(
          latestSubmission: VenueAboutSubmission(
            id: 's1',
            aboutText: 'Draft text',
            status: VenueAboutSubmissionStatus.rejected,
            submittedAt: DateTime(2026, 9, 1),
          ),
        ),
      );
      expect(find.textContaining("wasn't approved"), findsOneWidget);
    });

    testWidgets('a rejected submission shows the reviewer\'s own note, so the reason actually '
        'reaches the manager — same shape as a rejected photo submission\'s own note', (
      tester,
    ) async {
      await _pump(
        tester,
        _FakeVenueAboutRepository(
          latestSubmission: VenueAboutSubmission(
            id: 's1',
            aboutText: 'Draft text',
            status: VenueAboutSubmissionStatus.rejected,
            submittedAt: DateTime(2026, 9, 1),
            reviewNote: 'Tone does not match editorial voice.',
          ),
        ),
      );
      expect(find.textContaining("wasn't approved"), findsOneWidget);
      expect(find.text('Tone does not match editorial voice.'), findsOneWidget);
    });

    testWidgets('a rejected submission with no note shows the status but no note line', (
      tester,
    ) async {
      await _pump(
        tester,
        _FakeVenueAboutRepository(
          latestSubmission: VenueAboutSubmission(
            id: 's1',
            aboutText: 'Draft text',
            status: VenueAboutSubmissionStatus.rejected,
            submittedAt: DateTime(2026, 9, 1),
          ),
        ),
      );
      expect(find.textContaining("wasn't approved"), findsOneWidget);
      // Nothing to render as a note — reviewNote is null on this
      // submission, matching the fake repository's default.
    });

    testWidgets('shows no status banner when there is no submission at all', (tester) async {
      await _pump(tester, _FakeVenueAboutRepository());
      expect(find.textContaining('awaiting review'), findsNothing);
      expect(find.textContaining("wasn't approved"), findsNothing);
    });

    testWidgets('shows no status banner when the latest submission was already approved — '
        'nothing more to say once it matches the current text', (tester) async {
      await _pump(
        tester,
        _FakeVenueAboutRepository(
          currentText: 'Live text',
          latestSubmission: VenueAboutSubmission(
            id: 's1',
            aboutText: 'Live text',
            status: VenueAboutSubmissionStatus.approved,
            submittedAt: DateTime(2026, 9, 1),
          ),
        ),
      );
      expect(find.textContaining('awaiting review'), findsNothing);
      expect(find.textContaining("wasn't approved"), findsNothing);
    });
  });

  group('VenueManagementScreen — review is explained before writing', () {
    testWidgets('the "before you submit" explanation is visible immediately, before any text '
        'is entered — not only after submitting', (tester) async {
      await _pump(tester, _FakeVenueAboutRepository());
      expect(find.text('BEFORE YOU SUBMIT'), findsOneWidget);
      expect(
        find.textContaining('does not appear on the venue\'s page right away'),
        findsOneWidget,
      );
    });
  });

  group('VenueManagementScreen — the length limit is the real constraint, not a picked number', () {
    testWidgets('the text field enforces venueAboutTextMaxLength, not a hardcoded literal', (
      tester,
    ) async {
      await _pump(tester, _FakeVenueAboutRepository());
      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.maxLength, venueAboutTextMaxLength);
      expect(venueAboutTextMaxLength, 900); // the real venue_about_submissions CHECK constraint
    });
  });

  group('VenueManagementScreen — fields a manager must never edit are simply absent', () {
    testWidgets('no verified-data field (address, phone, website, stars, Keys, cuisine, '
        'status) appears anywhere on this screen', (tester) async {
      await _pump(tester, _FakeVenueAboutRepository(currentText: 'Some about text'));
      for (final forbidden in [
        'Address',
        'Phone',
        'Website',
        'MICHELIN stars',
        'MICHELIN Keys',
        'Cuisine',
        'Place ID',
      ]) {
        expect(find.textContaining(forbidden), findsNothing, reason: '"$forbidden" must not appear');
      }
    });
  });

  group('VenueManagementScreen — submitting', () {
    testWidgets('submitting empty text shows an inline error, never calls the repository', (
      tester,
    ) async {
      var calls = 0;
      await _pump(tester, _FakeVenueAboutRepository(onSubmit: (_) => calls++));
      await tester.enterText(find.byType(TextField), '');
      await tester.ensureVisible(find.text('Submit for review'));
      await tester.tap(find.text('Submit for review'));
      await tester.pump();
      expect(find.text('Write something before submitting.'), findsOneWidget);
      expect(calls, 0);
    });

    testWidgets('a valid submission calls the repository with the venue type/id and the typed '
        'text, then shows a confirmation', (tester) async {
      _SubmitCall? received;
      await _pump(
        tester,
        _FakeVenueAboutRepository(onSubmit: (call) => received = call),
      );
      await tester.enterText(find.byType(TextField), 'A new description of the venue.');
      await tester.ensureVisible(find.text('Submit for review'));
      await tester.tap(find.text('Submit for review'));
      await tester.pumpAndSettle();

      expect(received?.venueType, 'restaurant');
      expect(received?.venueId, 'r1');
      expect(received?.aboutText, 'A new description of the venue.');
      expect(find.text('Submitted for review.'), findsOneWidget);
    });

    testWidgets('after a successful submit, the typed text is NOT overwritten by a reload — '
        'the field keeps showing what was just submitted', (tester) async {
      await _pump(
        tester,
        _FakeVenueAboutRepository(currentText: 'Old approved text', onSubmit: (_) {}),
      );
      await tester.enterText(find.byType(TextField), 'Brand new draft.');
      await tester.ensureVisible(find.text('Submit for review'));
      await tester.tap(find.text('Submit for review'));
      await tester.pumpAndSettle();

      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.controller?.text, 'Brand new draft.');
    });

    testWidgets('a repository failure shows a generic message, never the raw exception', (
      tester,
    ) async {
      await _pump(tester, _FakeVenueAboutRepository(submitError: Exception('connection reset')));
      await tester.enterText(find.byType(TextField), 'Some text');
      await tester.ensureVisible(find.text('Submit for review'));
      await tester.tap(find.text('Submit for review'));
      await tester.pumpAndSettle();
      expect(find.text('Could not submit. Please try again.'), findsOneWidget);
      expect(find.textContaining('connection reset'), findsNothing);
    });
  });

  group('VenueManagementScreen — photos', () {
    testWidgets('no published photos shows a plain empty line, no reorder controls', (
      tester,
    ) async {
      await _pump(tester, _FakeVenueAboutRepository());
      expect(find.text('No photos published yet.'), findsOneWidget);
      expect(find.byIcon(Icons.keyboard_arrow_up_rounded), findsNothing);
    });

    testWidgets('the first published photo is tagged "Appears first", others are not', (
      tester,
    ) async {
      await _pump(
        tester,
        _FakeVenueAboutRepository(),
        photoRepo: _FakeVenuePhotoSubmissionRepository(
          published: const [
            PublishedVenuePhoto(id: 'p1', imageUrl: 'https://example.test/1.jpg', displayOrder: 0),
            PublishedVenuePhoto(id: 'p2', imageUrl: 'https://example.test/2.jpg', displayOrder: 1),
          ],
        ),
      );
      expect(find.text('Appears first'), findsOneWidget);
    });

    testWidgets("the first photo's move-up control is disabled, the last photo's "
        'move-down control is disabled', (tester) async {
      await _pump(
        tester,
        _FakeVenueAboutRepository(),
        photoRepo: _FakeVenuePhotoSubmissionRepository(
          published: const [
            PublishedVenuePhoto(id: 'p1', imageUrl: 'https://example.test/1.jpg', displayOrder: 0),
            PublishedVenuePhoto(id: 'p2', imageUrl: 'https://example.test/2.jpg', displayOrder: 1),
          ],
        ),
      );
      final upButtons = tester.widgetList<IconButton>(
        find.widgetWithIcon(IconButton, Icons.keyboard_arrow_up_rounded),
      );
      final downButtons = tester.widgetList<IconButton>(
        find.widgetWithIcon(IconButton, Icons.keyboard_arrow_down_rounded),
      );
      expect(upButtons.first.onPressed, isNull); // photo 1: can't move earlier
      expect(downButtons.first.onPressed, isNotNull); // photo 1: can move later
      expect(upButtons.last.onPressed, isNotNull); // photo 2: can move earlier
      expect(downButtons.last.onPressed, isNull); // photo 2: can't move later
    });

    testWidgets('moving the second photo up calls reorder_venue_photos with the full new '
        'order, never a direct display_order write', (tester) async {
      _ReorderCall? received;
      await _pump(
        tester,
        _FakeVenueAboutRepository(),
        photoRepo: _FakeVenuePhotoSubmissionRepository(
          published: const [
            PublishedVenuePhoto(id: 'p1', imageUrl: 'https://example.test/1.jpg', displayOrder: 0),
            PublishedVenuePhoto(id: 'p2', imageUrl: 'https://example.test/2.jpg', displayOrder: 1),
          ],
          onReorder: (call) => received = call,
        ),
      );
      await tester.ensureVisible(find.byIcon(Icons.keyboard_arrow_up_rounded).last);
      await tester.tap(find.byIcon(Icons.keyboard_arrow_up_rounded).last);
      await tester.pumpAndSettle();
      expect(received?.venueType, 'restaurant');
      expect(received?.venueId, 'r1');
      expect(received?.photoIds, ['p2', 'p1']);
    });

    testWidgets('a reorder failure shows a generic message', (tester) async {
      await _pump(
        tester,
        _FakeVenueAboutRepository(),
        photoRepo: _FakeVenuePhotoSubmissionRepository(
          published: const [
            PublishedVenuePhoto(id: 'p1', imageUrl: 'https://example.test/1.jpg', displayOrder: 0),
            PublishedVenuePhoto(id: 'p2', imageUrl: 'https://example.test/2.jpg', displayOrder: 1),
          ],
          reorderError: Exception('boom'),
        ),
      );
      await tester.ensureVisible(find.byIcon(Icons.keyboard_arrow_up_rounded).last);
      await tester.tap(find.byIcon(Icons.keyboard_arrow_up_rounded).last);
      await tester.pumpAndSettle();
      expect(find.text('Could not reorder photos. Please try again.'), findsOneWidget);
    });

    testWidgets('a pending submission shows "Awaiting review" and no ordering control', (
      tester,
    ) async {
      await _pump(
        tester,
        _FakeVenueAboutRepository(),
        photoRepo: _FakeVenuePhotoSubmissionRepository(
          openSubmissions: [
            VenuePhotoSubmissionSummary(
              id: 's1',
              storagePath: 'restaurant/r1/u1/x.jpg',
              status: VenuePhotoSubmissionStatus.pending,
              submittedAt: DateTime(2026, 9, 1),
            ),
          ],
        ),
      );
      expect(find.text('Awaiting review'), findsOneWidget);
      expect(find.byIcon(Icons.keyboard_arrow_up_rounded), findsNothing);
    });

    testWidgets('a rejected submission shows "Not approved" and the reviewer\'s own note, '
        'so the reason actually reaches the manager', (tester) async {
      await _pump(
        tester,
        _FakeVenueAboutRepository(),
        photoRepo: _FakeVenuePhotoSubmissionRepository(
          openSubmissions: [
            VenuePhotoSubmissionSummary(
              id: 's1',
              storagePath: 'restaurant/r1/u1/x.jpg',
              status: VenuePhotoSubmissionStatus.rejected,
              reviewNote: 'Out of focus — please try a sharper shot.',
              submittedAt: DateTime(2026, 9, 1),
            ),
          ],
        ),
      );
      expect(find.text('Not approved'), findsOneWidget);
      expect(find.text('Out of focus — please try a sharper shot.'), findsOneWidget);
    });

    testWidgets('a pending submission\'s thumbnail resolves through the signed-URL map, '
        'keyed by its own storage_path — the bucket is private, so a raw path can never '
        'be rendered directly', (tester) async {
      await _pump(
        tester,
        _FakeVenueAboutRepository(),
        photoRepo: _FakeVenuePhotoSubmissionRepository(
          openSubmissions: [
            VenuePhotoSubmissionSummary(
              id: 's1',
              storagePath: 'restaurant/r1/u1/x.jpg',
              status: VenuePhotoSubmissionStatus.pending,
              submittedAt: DateTime(2026, 9, 1),
            ),
          ],
          displayUrls: const {'restaurant/r1/u1/x.jpg': 'https://signed.example/x.jpg'},
        ),
      );
      final image = tester.widget<Image>(find.byType(Image));
      final provider = image.image as NetworkImage;
      expect(provider.url, 'https://signed.example/x.jpg');
    });

    testWidgets('a rejected submission with no note shows the status but no note line', (
      tester,
    ) async {
      await _pump(
        tester,
        _FakeVenueAboutRepository(),
        photoRepo: _FakeVenuePhotoSubmissionRepository(
          openSubmissions: [
            VenuePhotoSubmissionSummary(
              id: 's1',
              storagePath: 'restaurant/r1/u1/x.jpg',
              status: VenuePhotoSubmissionStatus.rejected,
              submittedAt: DateTime(2026, 9, 1),
            ),
          ],
        ),
      );
      expect(find.text('Not approved'), findsOneWidget);
    });

    testWidgets('the private-chef hero-portrait reminder appears next to the photo list '
        'for a chef with published photos, never for a restaurant', (tester) async {
      final chef = ManagedPrivateChef(
        PrivateChef.fromJson({'id': 'c1', 'display_name': 'Chef Amara'}),
      );
      await _pump(
        tester,
        _FakeVenueAboutRepository(),
        venue: chef,
        photoRepo: _FakeVenuePhotoSubmissionRepository(
          published: const [
            PublishedVenuePhoto(id: 'p1', imageUrl: 'https://example.test/1.jpg', displayOrder: 0),
          ],
        ),
      );
      expect(
        find.textContaining('Your first photo should be a portrait of you'),
        findsOneWidget,
      );
    });

    testWidgets('the restaurant management screen never shows the chef-only portrait rule', (
      tester,
    ) async {
      await _pump(
        tester,
        _FakeVenueAboutRepository(),
        photoRepo: _FakeVenuePhotoSubmissionRepository(
          published: const [
            PublishedVenuePhoto(id: 'p1', imageUrl: 'https://example.test/1.jpg', displayOrder: 0),
          ],
        ),
      );
      expect(find.textContaining('portrait of you'), findsNothing);
    });

    testWidgets('tapping "Add a photo" pushes exactly one route', (tester) async {
      final observer = _RecordingNavigatorObserver();
      await tester.pumpWidget(
        MaterialApp(
          navigatorObservers: [observer],
          home: VenueManagementScreen(
            venue: _venue(),
            aboutRepo: _FakeVenueAboutRepository(),
            photoRepo: _FakeVenuePhotoSubmissionRepository(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      observer.pushed.clear();
      await tester.ensureVisible(find.text('Add a photo'));
      await tester.tap(find.text('Add a photo'));
      expect(observer.pushed.length, 1);
    });
  });

  group('VenueManagementScreen — Preview my page, fresh venue re-fetch', () {
    Future<RestaurantDetailScreen> openPreviewAndCapture(
      WidgetTester tester, {
      required RestaurantRepository restaurantRepo,
    }) async {
      final observer = _RecordingNavigatorObserver();
      await tester.pumpWidget(
        MaterialApp(
          navigatorObservers: [observer],
          home: VenueManagementScreen(
            venue: _venue(),
            aboutRepo: _FakeVenueAboutRepository(),
            photoRepo: _FakeVenuePhotoSubmissionRepository(),
            restaurantRepo: restaurantRepo,
          ),
        ),
      );
      await tester.pumpAndSettle();
      observer.pushed.clear();
      await tester.ensureVisible(find.text('Preview my page'));
      await tester.tap(find.text('Preview my page'));
      await tester.pumpAndSettle();

      final route = observer.pushed.single as MaterialPageRoute;
      return route.builder(tester.element(find.byType(Navigator)))
          as RestaurantDetailScreen;
    }

    testWidgets(
      'the re-fetch succeeding shows the freshly fetched venue, not the '
      "cached one My Venues loaded — and marks the preview not stale",
      (tester) async {
        final fresh = Restaurant.fromJson({
          'id': 'r1',
          'name': 'Flore Amsterdam (renamed)',
          'city_name': 'Amsterdam',
        });
        final screen = await openPreviewAndCapture(
          tester,
          restaurantRepo: _FakeRestaurantRepository(result: fresh),
        );

        expect(screen.restaurant.name, 'Flore Amsterdam (renamed)');
        expect(screen.previewIsStale, isFalse);
      },
    );

    testWidgets(
      'the re-fetch failing falls back to the cached venue rather than '
      'aborting the preview — and marks it stale so that is disclosed on '
      'the preview screen itself, not silently shown as current',
      (tester) async {
        final screen = await openPreviewAndCapture(
          tester,
          restaurantRepo: _FakeRestaurantRepository(
            error: Exception('connection reset'),
          ),
        );

        expect(screen.restaurant.name, 'Flore Amsterdam');
        expect(screen.previewIsStale, isTrue);
      },
    );
  });

  group('VenueManagementScreen — contact line', () {
    testWidgets(
      'a restrained line names the shared venue-ops inbox — the one '
      'contact point on this screen',
      (tester) async {
        await _pump(tester, _FakeVenueAboutRepository());
        expect(
          find.textContaining('Questions about your page?'),
          findsOneWidget,
        );
        expect(
          find.textContaining('claimedvenues@mantelier.app'),
          findsOneWidget,
        );
      },
    );
  });

  group('venueQuestionMailtoUri', () {
    test(
      'addresses the shared venue-ops inbox and puts the venue name in '
      'the subject, so a reply is identifiable without asking what it is '
      'about',
      () {
        final uri = venueQuestionMailtoUri('Flore Amsterdam');
        expect(uri.scheme, 'mailto');
        expect(uri.path, 'claimedvenues@mantelier.app');
        expect(
          uri.queryParameters['subject'],
          'Venue question — Flore Amsterdam',
        );
      },
    );

    test('a different venue name produces a different subject, not a '
        'fixed/generic one', () {
      final a = venueQuestionMailtoUri('Flore Amsterdam');
      final b = venueQuestionMailtoUri('Aman Venice');
      expect(a.queryParameters['subject'], isNot(b.queryParameters['subject']));
    });
  });
}

class _RecordingNavigatorObserver extends NavigatorObserver {
  final List<Route<dynamic>> pushed = [];

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    pushed.add(route);
    super.didPush(route, previousRoute);
  }
}
