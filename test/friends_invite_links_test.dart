import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:michelin_passport/data/repositories/invite_link_repository.dart';
import 'package:michelin_passport/features/invites/invite_links_section.dart';
import 'package:michelin_passport/models/invite_link.dart';

SupabaseClient _dummyClient() => SupabaseClient(
  'https://test.supabase.co',
  'test-anon-key',
  authOptions: const AuthClientOptions(autoRefreshToken: false),
);

final _now = DateTime.now();

MyInviteLink _link(
  String id, {
  String kind = 'friend',
  int maxUses = 1,
  int useCount = 0,
  Duration left = const Duration(days: 12, hours: 3),
  bool revoked = false,
  String? usedBy,
}) => MyInviteLink.fromRow({
  'id': id,
  'token': 'tok$id',
  'code': 'K7Q2M9XD',
  'kind': kind,
  'max_uses': maxUses,
  'use_count': useCount,
  'expires_at': _now.add(left).toUtc().toIso8601String(),
  'revoked_at': revoked ? _now.toUtc().toIso8601String() : null,
  'created_at': _now.toUtc().toIso8601String(),
  'venue_name': kind == 'visit' ? 'Hof van Cleve' : null,
  'visited_on': kind == 'visit' ? '2026-11-14' : null,
  'last_used_by_name': usedBy,
});

class _Repo extends InviteLinkRepository {
  _Repo(this.links) : super(_dummyClient());
  final List<MyInviteLink> links;

  @override
  Future<List<MyInviteLink>> myLinks() async => links;
}

void main() {
  group('MyInviteLink labels', () {
    test('a friend link says what kind it is and how long it has', () {
      final personal = _link('1');
      expect(personal.title, 'Personal link');
      expect(personal.statusLine(_now), '13 days left');

      final group = _link('2', maxUses: 8, useCount: 3);
      expect(group.title, 'Group link for 8');
      expect(group.statusLine(_now), '3 of 8 joined · 13 days left');
    });

    test('a visit shared with a group says so under its own title', () {
      final l = _link('3', kind: 'visit', maxUses: 6);
      expect(l.title, 'Hof van Cleve, 14 November');
      expect(l.statusLine(_now), 'Group link for 6 · 13 days left');
    });

    test('used, last day, expired, cancelled; never a dash', () {
      expect(
        _link('4', useCount: 1, usedBy: 'Claudia').statusLine(_now),
        'Accepted by Claudia',
      );
      expect(
        _link('5', left: const Duration(hours: 5)).statusLine(_now),
        'Last day',
      );
      expect(
        _link('6', left: const Duration(hours: -1)).statusLine(_now),
        'Expired',
      );
      expect(_link('7', revoked: true).statusLine(_now), 'Cancelled');
      for (final l in [_link('8'), _link('9', maxUses: 4)]) {
        expect(l.statusLine(_now).contains(' - '), isFalse);
        expect(l.statusLine(_now).contains('—'), isFalse);
      }
    });
  });

  group('OpenInviteLinksLine', () {
    Future<void> pump(WidgetTester tester, List<MyInviteLink> links) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: OpenInviteLinksLine(repository: _Repo(links))),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('counts only open links, and opens only them', (tester) async {
      await pump(tester, [
        _link('a'),
        _link('b', maxUses: 8),
        _link('c', revoked: true),
        _link('d', left: const Duration(hours: -2)),
        _link('e', useCount: 1, usedBy: 'Claudia'),
      ]);
      expect(find.text('2 open links'), findsOneWidget);

      await tester.tap(find.text('2 open links'));
      await tester.pumpAndSettle();
      expect(find.text('Open links'), findsOneWidget);
      expect(find.text('Personal link'), findsOneWidget);
      expect(find.text('Group link for 8'), findsOneWidget);
      expect(find.text('Cancelled'), findsNothing);
      expect(find.text('Expired'), findsNothing);

      // The rest wait folded away.
      await tester.tap(find.text('Show earlier links (3)'));
      await tester.pumpAndSettle();
      expect(find.text('Cancelled'), findsOneWidget);
      expect(find.text('Expired'), findsOneWidget);
      expect(find.text('Accepted by Claudia'), findsOneWidget);
    });

    testWidgets('nothing at all while no link is open', (tester) async {
      await pump(tester, [_link('c', revoked: true)]);
      expect(find.textContaining('open link'), findsNothing);
    });

    testWidgets('one is singular', (tester) async {
      await pump(tester, [_link('a')]);
      expect(find.text('1 open link'), findsOneWidget);
    });
  });

  testWidgets('the person-plus sheet offers link, username and code', (
    tester,
  ) async {
    var found = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showInviteSheet(
                context,
                onFindByUsername: () => found++,
                repository: _Repo(const []),
              ),
              child: const Text('plus'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('plus'));
    await tester.pumpAndSettle();
    expect(find.text('Add a friend'), findsOneWidget);
    expect(find.text('Share a link'), findsOneWidget);
    expect(find.text('Find by username'), findsOneWidget);
    expect(find.text('Enter a code'), findsOneWidget);

    await tester.tap(find.text('Enter a code'));
    await tester.pumpAndSettle();
    expect(find.text('Enter an invitation code'), findsOneWidget);

    Navigator.of(tester.element(find.text('Enter an invitation code'))).pop();
    await tester.pumpAndSettle();
    await tester.tap(find.text('plus'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Find by username'));
    await tester.pumpAndSettle();
    expect(found, 1);
  });
}
