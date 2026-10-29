// The "Travelling with" row on Trip Detail is also the way to invite: a
// trip with nobody else on it or invited says "Invite friends", not a
// status line that doesn't read as tappable.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:michelin_passport/features/trips/widgets/trip_members_sheet.dart';
import 'package:michelin_passport/models/trip_member.dart';

const _me = TripMember(userId: 'me', status: TripMemberStatus.owner);

Future<void> _pump(WidgetTester tester, List<TripMember> members) =>
    tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TripCompanionsRow(
            members: members,
            currentUserId: 'me',
            onTap: () {},
          ),
        ),
      ),
    );

void main() {
  testWidgets('alone on the trip: reads Invite friends', (tester) async {
    await _pump(tester, const [_me]);
    expect(find.text('Invite friends'), findsOneWidget);
    expect(find.byIcon(Icons.person_add_alt_1_outlined), findsOneWidget);
  });

  testWidgets('a pending invitation: shows the status, not the prompt', (
    tester,
  ) async {
    await _pump(tester, const [
      _me,
      TripMember(
        memberId: 'm1',
        userId: 'f1',
        status: TripMemberStatus.pending,
        displayName: 'Sam',
      ),
    ]);
    expect(find.text('Invite friends'), findsNothing);
    expect(find.text('Just you so far · 1 invited'), findsOneWidget);
  });

  testWidgets('with a companion: names them', (tester) async {
    await _pump(tester, const [
      _me,
      TripMember(
        memberId: 'm1',
        userId: 'f1',
        status: TripMemberStatus.accepted,
        displayName: 'Sam',
      ),
    ]);
    expect(find.text('With Sam'), findsOneWidget);
    expect(find.text('Invite friends'), findsNothing);
  });
}
