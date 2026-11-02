// Covers in-app review (20261017120000): ReviewItem parsing from
// get_review_queue(), the queue screen's grouping and empty state, and
// the review screen — the right action per kind, reject requiring a
// note, the photo shown with its framing, and failures staying open.

import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:michelin_passport/core/widgets/framed_image.dart';
import 'package:michelin_passport/data/repositories/review_repository.dart';
import 'package:michelin_passport/features/review/review_item_screen.dart';
import 'package:michelin_passport/features/review/review_queue_screen.dart';
import 'package:michelin_passport/models/photo_framing.dart';
import 'package:michelin_passport/models/review_item.dart';

SupabaseClient _dummyClient() => SupabaseClient(
  'https://test.supabase.co',
  'test-anon-key',
  authOptions: const AuthClientOptions(autoRefreshToken: false),
);

class _FakeReviewRepo extends ReviewRepository {
  _FakeReviewRepo({this.queue = const [], this.error}) : super(_dummyClient());
  final List<ReviewItem> queue;
  final Object? error;
  final calls = <String>[];

  Future<void> _record(String call) async {
    if (error != null) throw error!;
    calls.add(call);
  }

  @override
  Future<List<ReviewItem>> loadQueue() async => queue;
  @override
  Future<void> approveClaim(ReviewItem item) =>
      _record('approveClaim:${item.itemId}');
  @override
  Future<void> rejectClaim(ReviewItem item, String note) =>
      _record('rejectClaim:${item.itemId}:$note');
  @override
  Future<void> approveAbout(ReviewItem item) =>
      _record('approveAbout:${item.itemId}');
  @override
  Future<void> rejectAbout(ReviewItem item, String note) =>
      _record('rejectAbout:${item.itemId}:$note');
  @override
  Future<void> approvePhoto(ReviewItem item) =>
      _record('approvePhoto:${item.itemId}');
  @override
  Future<void> rejectPhoto(ReviewItem item, String note) =>
      _record('rejectPhoto:${item.itemId}:$note');
  @override
  Future<void> markContactEditSeen(ReviewItem item) =>
      _record('contactSeen:${item.itemId}');
  @override
  Future<void> resolveContentReport(ReviewItem item) =>
      _record('reportResolved:${item.itemId}');
  @override
  Future<void> markMissingListingHandled(ReviewItem item) =>
      _record('missingHandled:${item.itemId}');
}

final _contactEdit = ReviewItem.fromJson(
  _row(
    'venue_contact_edit',
    extra: {
      'contact_field': 'phone',
      'contact_old_value': '+31 20 000 0000',
      'contact_new_value': '+31 20 123 4567',
    },
  ),
)!;
final _report = ReviewItem.fromJson({
  ..._row(
    'content_report',
    extra: {
      'report_content_type': 'photo',
      'report_content_id': 'p1',
      'report_reason': 'spam',
      'report_details': 'An advert',
    },
  ),
  'venue_type': null,
  'venue_id': null,
  'venue_name': null,
  'venue_city': null,
})!;
final _missing = ReviewItem.fromJson({
  ..._row(
    'missing_listing',
    extra: {
      'missing_subject_type': 'restaurant',
      'missing_name': 'Somewhere New',
      'missing_city': 'Utrecht',
      'missing_message': 'Opened in October',
      'missing_works_here': true,
      'missing_reporter_role': 'Chef',
      'missing_reporter_contact': 'chef@example.test',
    },
  ),
  'venue_type': null,
  'venue_id': null,
  'venue_name': null,
  'venue_city': null,
})!;

Map<String, dynamic> _row(
  String kind, {
  Map<String, dynamic> extra = const {},
}) => {
  'kind': kind,
  'item_id': '$kind-1',
  'venue_type': 'restaurant',
  'venue_id': 'r1',
  'venue_name': 'Flore',
  'venue_city': 'Amsterdam',
  'submitted_by': 'u1',
  'submitter_label': '@manager_one',
  'submitted_at': '2026-10-28T10:00:00Z',
  ...extra,
};

final _claim = ReviewItem.fromJson(
  _row(
    'venue_claim',
    extra: {
      'claim_role': 'owner',
      'claim_business_email': 'owner@example.test',
      'claim_notes': 'I run the kitchen',
    },
  ),
)!;
final _about = ReviewItem.fromJson(
  _row('venue_about', extra: {'about_text': 'A warm new text.'}),
)!;
final _photo = ReviewItem.fromJson(
  _row(
    'venue_photo',
    extra: {
      'photo_storage_path': 'restaurant/r1/u1/x.jpg',
      'photo_focus_x': 0.3,
      'photo_focus_y': 0.6,
      'photo_zoom': 1.5,
    },
  ),
)!;

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

Future<List<bool?>> _pumpItem(
  WidgetTester tester,
  ReviewItem item,
  _FakeReviewRepo repo,
) async {
  final popped = <bool?>[];
  await _precache(tester);
  await tester.binding.setSurfaceSize(const Size(800, 1800));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () async => popped.add(
              await Navigator.push<bool>(
                context,
                MaterialPageRoute(
                  builder: (_) => ReviewItemScreen(
                    item: item,
                    repository: repo,
                    photoImage: _image,
                  ),
                ),
              ),
            ),
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

void main() {
  group('ReviewItem.fromJson', () {
    test('reads each kind and its payload', () {
      expect(_claim.kind, ReviewKind.venueClaim);
      expect(_claim.claimRole, 'owner');
      expect(_about.aboutText, 'A warm new text.');
      expect(_photo.photoStoragePath, 'restaurant/r1/u1/x.jpg');
      expect(
        _photo.photoFraming,
        const PhotoFraming(focusX: 0.3, focusY: 0.6, zoom: 1.5),
      );
      expect(_photo.venueCity, 'Amsterdam');
      expect(_photo.submittedAt, DateTime.utc(2026, 10, 28, 10));
    });

    test('a kind this build does not know is skipped, not a crash', () {
      expect(ReviewItem.fromJson(_row('event')), isNull);
    });
  });

  group('ReviewQueueScreen', () {
    testWidgets('a heading per topic with counts, and one filter that shows '
        'what is waiting per topic', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ReviewQueueScreen(
            repository: _FakeReviewRepo(queue: [_claim, _about, _photo]),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('All topics · 3'), findsOneWidget);
      expect(find.text('CLAIMS · 1'), findsOneWidget);
      expect(find.text('PROFILES · 1'), findsOneWidget);
      expect(find.text('PHOTOS · 1'), findsOneWidget);
      expect(find.text('Flore · Amsterdam'), findsNWidgets(3));

      // The filter says per topic whether anything is waiting.
      await tester.tap(find.text('All topics · 3'));
      await tester.pumpAndSettle();
      expect(find.text('3 waiting'), findsOneWidget);
      expect(find.text('1 waiting'), findsNWidgets(3));
      expect(find.text('Nothing waiting'), findsNWidgets(3));

      await tester.tap(find.text('Photos'));
      await tester.pumpAndSettle();
      expect(find.text('Photos · 1'), findsOneWidget);
      expect(find.text('PHOTOS · 1'), findsOneWidget);
      expect(find.text('CLAIMS · 1'), findsNothing);
      expect(find.text('Flore · Amsterdam'), findsOneWidget);
    });

    testWidgets('an empty queue says so', (tester) async {
      await tester.pumpWidget(
        MaterialApp(home: ReviewQueueScreen(repository: _FakeReviewRepo())),
      );
      await tester.pumpAndSettle();
      expect(find.text('Nothing waiting for review.'), findsOneWidget);
    });
  });

  group('ReviewItemScreen', () {
    testWidgets('a claim shows its details, and Approve approves the claim', (
      tester,
    ) async {
      final repo = _FakeReviewRepo();
      final popped = await _pumpItem(tester, _claim, repo);
      expect(find.text('owner@example.test'), findsOneWidget);
      expect(find.text('I run the kitchen'), findsOneWidget);
      await tester.tap(find.text('Approve'));
      await tester.pumpAndSettle();
      expect(repo.calls, ['approveClaim:venue_claim-1']);
      expect(popped, [true]);
    });

    testWidgets('an about text shows the text and a page preview', (
      tester,
    ) async {
      final repo = _FakeReviewRepo();
      await _pumpItem(tester, _about, repo);
      expect(find.text('A warm new text.'), findsOneWidget);
      expect(find.text('Preview the venue page'), findsOneWidget);
      await tester.tap(find.text('Approve'));
      await tester.pumpAndSettle();
      expect(repo.calls, ['approveAbout:venue_about-1']);
    });

    testWidgets('a photo is shown with its framing, and Approve publishes it', (
      tester,
    ) async {
      final repo = _FakeReviewRepo();
      await _pumpItem(tester, _photo, repo);
      final framed = tester
          .widgetList<FramedImage>(find.byType(FramedImage))
          .first;
      expect(
        framed.framing,
        const PhotoFraming(focusX: 0.3, focusY: 0.6, zoom: 1.5),
      );
      await tester.ensureVisible(find.text('Approve and publish'));
      await tester.tap(find.text('Approve and publish'));
      await tester.pumpAndSettle();
      expect(repo.calls, ['approvePhoto:venue_photo-1']);
    });

    testWidgets('reject needs a note, and sends it', (tester) async {
      final repo = _FakeReviewRepo();
      await _pumpItem(tester, _about, repo);
      await tester.ensureVisible(find.text('Reject with a note'));
      await tester.tap(find.text('Reject with a note'));
      await tester.pumpAndSettle();
      final rejectButton = find.widgetWithText(TextButton, 'Reject');
      expect(tester.widget<TextButton>(rejectButton).onPressed, isNull);
      await tester.enterText(
        find.byType(TextField),
        'Too short, please expand.',
      );
      await tester.pump();
      await tester.tap(rejectButton);
      await tester.pumpAndSettle();
      expect(repo.calls, [
        'rejectAbout:venue_about-1:Too short, please expand.',
      ]);
    });

    testWidgets('a failed decision says so and stays open', (tester) async {
      final repo = _FakeReviewRepo(error: Exception('boom'));
      final popped = await _pumpItem(tester, _claim, repo);
      await tester.tap(find.text('Approve'));
      await tester.pumpAndSettle();
      expect(
        find.text('Could not save the decision. Please try again.'),
        findsOneWidget,
      );
      expect(find.byType(ReviewItemScreen), findsOneWidget);
      expect(popped, isEmpty);
    });
  });

  group('Items marked dealt with, never rejected', () {
    testWidgets('a website or phone change shows was and now, and Mark as '
        'seen clears it', (tester) async {
      final repo = _FakeReviewRepo();
      final popped = await _pumpItem(tester, _contactEdit, repo);
      expect(find.text('Phone number'), findsOneWidget);
      expect(find.text('+31 20 000 0000'), findsOneWidget);
      expect(find.text('+31 20 123 4567'), findsOneWidget);
      expect(find.text('Reject with a note'), findsNothing);
      await tester.tap(find.text('Mark as seen'));
      await tester.pumpAndSettle();
      expect(repo.calls, ['contactSeen:venue_contact_edit-1']);
      expect(popped, [true]);
    });

    testWidgets('a member report shows what and why, and is resolved', (
      tester,
    ) async {
      final repo = _FakeReviewRepo();
      await _pumpItem(tester, _report, repo);
      expect(find.text('A reported photo'), findsOneWidget);
      expect(find.text('spam'), findsOneWidget);
      expect(find.text('An advert'), findsOneWidget);
      expect(find.text('Reject with a note'), findsNothing);
      await tester.tap(find.text('Mark resolved'));
      await tester.pumpAndSettle();
      expect(repo.calls, ['reportResolved:content_report-1']);
    });

    testWidgets('a missing listing shows the reporter\'s details and is '
        'marked handled', (tester) async {
      final repo = _FakeReviewRepo();
      await _pumpItem(tester, _missing, repo);
      expect(find.text('Somewhere New · Utrecht'), findsOneWidget);
      expect(find.text('Opened in October'), findsOneWidget);
      expect(find.text('chef@example.test'), findsOneWidget);
      await tester.tap(find.text('Mark handled'));
      await tester.pumpAndSettle();
      expect(repo.calls, ['missingHandled:missing_listing-1']);
    });

    testWidgets('they sit under their own topics', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ReviewQueueScreen(
            repository: _FakeReviewRepo(
              queue: [_contactEdit, _report, _missing],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('CONTACT · 1'), findsOneWidget);
      expect(find.text('REPORTS · 2'), findsOneWidget);
      expect(find.text('Flore · Amsterdam'), findsOneWidget);
      expect(find.text('REPORTED BY MEMBERS · 1'), findsOneWidget);
      expect(find.text('MISSING LISTINGS · 1'), findsOneWidget);
      expect(find.text('Somewhere New · Utrecht'), findsOneWidget);
    });
  });
}
