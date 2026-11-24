import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:michelin_passport/data/repositories/invite_link_repository.dart';
import 'package:michelin_passport/features/invites/invite_confirm_screen.dart';
import 'package:michelin_passport/features/profile/venue_invite_screen.dart';
import 'package:michelin_passport/models/invite_link.dart';
import 'package:michelin_passport/models/managed_venue.dart';
import 'package:michelin_passport/models/private_chef.dart';

SupabaseClient _dummyClient() => SupabaseClient(
  'https://test.supabase.co',
  'test-anon-key',
  authOptions: const AuthClientOptions(autoRefreshToken: false),
);

class _FakeRepo extends InviteLinkRepository {
  _FakeRepo({this.count, this.startEmpty = false}) : super(_dummyClient());

  final int? count;
  final bool startEmpty;
  final created = <bool>[];
  var _n = 0;

  @override
  Future<VenueInviteLink> venueLink(String venueType, String venueId) async {
    if (startEmpty && created.isEmpty) {
      return const VenueInviteLink();
    }
    return VenueInviteLink(
      token: 'tok$_n',
      code: 'R4CW7KMB',
      createdAt: DateTime.utc(2026, 12, 2),
      followedCount: count,
      followedSince: DateTime.utc(2026, 12, 2),
    );
  }

  @override
  Future<void> createVenueLink(
    String venueType,
    String venueId, {
    bool replace = false,
  }) async {
    created.add(replace);
    _n++;
  }
}

ManagedVenue _venue() => ManagedPrivateChef(
  PrivateChef.fromJson({
    'id': 'c1',
    'slug': 'chef',
    'display_name': 'Chef Anna',
    'publication_status': 'published',
  }),
);

Future<void> _pump(WidgetTester tester, _FakeRepo repo) async {
  await tester.pumpWidget(
    MaterialApp(
      home: VenueInviteScreen(venue: _venue(), repository: repo),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _reveal(WidgetTester tester, Finder finder) async {
  await tester.dragUntilVisible(
    finder,
    find.byType(ListView),
    const Offset(0, -150),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('shows the link, its code, a QR code and the count', (
    tester,
  ) async {
    final repo = _FakeRepo(count: 23);
    await _pump(tester, repo);
    expect(find.text('mantelier.app/i/tok0'), findsOneWidget);
    expect(find.textContaining('R4CW 7KMB'), findsOneWidget);
    expect(find.byType(QrImageView), findsOneWidget);
    await _reveal(tester, find.text('23 followed through your link'));
    expect(find.text('23 followed through your link'), findsOneWidget);
    expect(repo.created, isEmpty);
  });

  testWidgets('under 5 never shows a number', (tester) async {
    await _pump(tester, _FakeRepo());
    await _reveal(tester, find.text('Fewer than 5 followed so far'));
    expect(find.text('Fewer than 5 followed so far'), findsOneWidget);
  });

  testWidgets('the first visit makes the link', (tester) async {
    final repo = _FakeRepo(startEmpty: true);
    await _pump(tester, repo);
    expect(repo.created, [false]);
    expect(find.text('mantelier.app/i/tok1'), findsOneWidget);
  });

  testWidgets('Make a new link asks first, then replaces it', (tester) async {
    final repo = _FakeRepo(count: 5);
    await _pump(tester, repo);
    await _reveal(tester, find.text('Make a new link'));
    await tester.tap(find.text('Make a new link'));
    await tester.pumpAndSettle();
    expect(find.text('Make a new link?'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(repo.created, isEmpty);

    await tester.tap(find.text('Make a new link'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Make a new link'));
    await tester.pumpAndSettle();
    expect(repo.created, [true]);
    expect(find.text('mantelier.app/i/tok1'), findsOneWidget);
  });

  group('InviteConfirmScreen, a venue link', () {
    Future<void> pump(WidgetTester tester, _FakeConfirmRepo repo) async {
      await tester.pumpWidget(
        MaterialApp(
          home: InviteConfirmScreen(
            token: 't',
            onDone: () {},
            repository: repo,
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('asks one thing, Follow, and names no member', (tester) async {
      final repo = _FakeConfirmRepo('open');
      await pump(tester, repo);
      expect(find.text('Hof van Cleve'), findsOneWidget);
      expect(find.text('Kruishoutem, Belgium'), findsOneWidget);
      expect(find.text('Follow'), findsOneWidget);
      expect(find.textContaining('friend'), findsNothing);
      expect(find.textContaining('invited you'), findsNothing);
      expect(repo.redeemed, 0);

      await tester.tap(find.text('Follow'));
      await tester.pumpAndSettle();
      expect(repo.redeemed, 1);
      expect(find.text('You follow Hof van Cleve'), findsOneWidget);
      expect(find.text('View Hof van Cleve'), findsOneWidget);
    });

    testWidgets('already following: nothing to accept', (tester) async {
      final repo = _FakeConfirmRepo('following');
      await pump(tester, repo);
      expect(find.text('You already follow Hof van Cleve'), findsOneWidget);
      expect(find.text('Follow'), findsNothing);
    });
  });

  test('the share message speaks for the venue, with no dashes', () {
    final m = venueShareMessage('Hof van Cleve', 'https://mantelier.app/i/t');
    expect(
      m,
      'Hof van Cleve invites you to follow them on Mantelier, for their '
      'events and evenings worth keeping.\nhttps://mantelier.app/i/t',
    );
    expect(m.contains('—'), isFalse);
    expect(m.contains(' - '), isFalse);
  });
}

class _FakeConfirmRepo extends InviteLinkRepository {
  _FakeConfirmRepo(this.state) : super(_dummyClient());

  final String state;
  var redeemed = 0;

  @override
  Future<InviteLinkPreview> preview(String token) async =>
      InviteLinkPreview.fromRow({
        'state': state,
        'kind': 'venue',
        'venue_type': 'restaurant',
        'venue_id': 'r1',
        'venue_name': 'Hof van Cleve',
        'venue_city': 'Kruishoutem',
        'venue_country': 'Belgium',
        'michelin_stars': 3,
      }, token: token);

  @override
  Future<InviteLinkResult> redeem(String token, {bool addVisit = true}) async {
    redeemed++;
    return InviteLinkResult.fromJson({
      'kind': 'venue',
      'became_friends': false,
      'venue_type': 'restaurant',
      'venue_id': 'r1',
    });
  }
}
