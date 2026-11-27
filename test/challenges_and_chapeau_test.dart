// Challenges, standings (20261101870000) and Chapeau (20261101860000).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:michelin_passport/data/repositories/challenge_repository.dart';
import 'package:michelin_passport/data/repositories/chapeau_repository.dart';
import 'package:michelin_passport/features/community/challenges_screen.dart';
import 'package:michelin_passport/models/app_notification.dart';

final _challenge = Challenge(
  id: 'c1',
  slug: 'three-stars-a-month',
  title: 'Three stars this month',
  description: 'Three MICHELIN-starred restaurants in one calendar month.',
  cadence: 'month',
  periodStart: DateTime(2026, 11, 1),
  periodEnd: DateTime(2026, 11, 30),
);

const _places = [
  RankingPlace(userId: 'k', displayName: 'Kylan', isMe: false, rank: 1, value: 3, target: 3),
  RankingPlace(userId: 'me', displayName: 'Me', isMe: true, rank: 2, value: 2, target: 3),
  RankingPlace(userId: 'a', displayName: 'Anouk', isMe: false, rank: 3, value: 0, target: 3),
];

class _FakeRepo implements ChallengeRepository {

  StandingKind? asked;

  @override
  Future<List<Challenge>> challenges() async => [_challenge];

  @override
  Future<List<RankingPlace>> ranking(String challengeId) async => _places;

  @override
  Future<List<RankingPlace>> standings(StandingKind kind) async {
    asked = kind;
    return const [
      RankingPlace(userId: 'me', displayName: 'Me', isMe: true, rank: 1, value: 12),
      RankingPlace(userId: 'k', displayName: 'Kylan', isMe: false, rank: 2, value: 7),
    ];
  }
}

void main() {
  test('ordinal and period labels', () {
    expect([1, 2, 3, 4, 11, 12, 13, 21, 22].map(ordinal).toList(),
        ['1st', '2nd', '3rd', '4th', '11th', '12th', '13th', '21st', '22nd']);
    expect(_challenge.periodLabel, 'Until 30 November');
    expect(
      Challenge(
        id: 'o', slug: 'o', title: 'o', description: 'o', cadence: 'open',
        periodStart: DateTime(2026),
      ).periodLabel,
      "Until it's done",
    );
  });

  test('progress reads as a count, or the day it was done', () {
    expect(progressMeta(_places[1]), '2 of 3');
    expect(
      progressMeta(RankingPlace(
        userId: 'k', isMe: false, rank: 1, value: 3, target: 3,
        completedOn: DateTime(2026, 11, 13),
      )),
      'Done on 13 November',
    );
  });

  test('a Chapeau toggles on and off with the name first', () {
    const before = ChapeauSummary(count: 1, recentNames: ['Anouk']);
    final given = before.toggled('You');
    expect(given.count, 2);
    expect(given.givenByMe, isTrue);
    expect(given.recentNames, ['You', 'Anouk']);
    final back = given.toggled('You');
    expect(back.count, 1);
    expect(back.givenByMe, isFalse);
    expect(back.recentNames, ['Anouk']);
  });

  test('a Chapeau notification carries its count and place', () {
    final n = AppNotification.tryFromRow({
      'id': 'n1',
      'type': 'chapeau_received',
      'subject_type': 'visit',
      'subject_id': 'v1',
      'is_read': false,
      'created_at': '2026-11-27T10:00:00Z',
      'other_display_name': 'Anouk',
      'chapeau_count': 3,
      'chapeau_subject_name': 'Tacite',
      'chapeau_entity_type': 'restaurant',
    })!;
    expect(n.type, AppNotificationType.chapeauReceived);
    expect(n.chapeauCount, 3);
    expect(n.chapeauSubjectName, 'Tacite');
  });

  testWidgets('challenges show the ring, the ranking and the standings', (tester) async {
    final repo = _FakeRepo();
    await tester.pumpWidget(MaterialApp(home: ChallengesScreen(repository: repo)));
    await tester.pumpAndSettle();

    expect(find.text('Three stars this month'), findsOneWidget);
    expect(find.text('2/3'), findsOneWidget);
    expect(find.text('2nd of 3 · Until 30 November'), findsOneWidget);
    expect(find.text('Kylan'), findsWidgets);
    expect(find.text('You'), findsWidgets);

    await tester.scrollUntilVisible(find.text('50 Best'), 200);
    await tester.tap(find.text('50 Best'));
    await tester.pumpAndSettle();
    expect(repo.asked, StandingKind.w50b);
    expect(find.text("12 World's 50 Best restaurants"), findsOneWidget);
  });
}
