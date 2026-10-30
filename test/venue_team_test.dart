// Covers the venue team (20261030150000) apart from its screens: the
// model's parsing and order, the preview merge, and the section a
// restaurant's or hotel's page shows.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:michelin_passport/core/constants/app_colors.dart';
import 'package:michelin_passport/core/widgets/venue_team_section.dart';
import 'package:michelin_passport/models/review_item.dart';
import 'package:michelin_passport/models/venue_about_submission.dart';
import 'package:michelin_passport/models/venue_team_member.dart';

VenueTeamSubmission _submission(
  VenueTeamRole role,
  String name, {
  VenueAboutSubmissionStatus status = VenueAboutSubmissionStatus.pending,
  DateTime? removedAt,
}) => VenueTeamSubmission(
  id: 's-$name',
  role: role,
  name: name,
  status: status,
  submittedAt: DateTime.utc(2026, 10, 30),
  removedAt: removedAt,
);

void main() {
  group('VenueTeamMember', () {
    test(
      'parses a venue_team_current row, and skips a role it does not know',
      () {
        final chef = VenueTeamMember.fromJson({
          'role': 'chef',
          'name': 'Jonnie Boer',
          'bio': 'Since 1989.',
        });
        expect(chef!.role, VenueTeamRole.chef);
        expect(chef.bio, 'Since 1989.');
        expect(
          VenueTeamMember.fromJson({'role': 'sommelier', 'name': 'X'}),
          isNull,
        );
      },
    );

    test('the page lists the chef first', () {
      final ordered = VenueTeamMember.ordered(const [
        VenueTeamMember(role: VenueTeamRole.manager, name: 'M'),
        VenueTeamMember(role: VenueTeamRole.chef, name: 'C'),
      ]);
      expect(ordered.map((m) => m.name), ['C', 'M']);
    });

    test('a hotel has a hotel manager, a restaurant a restaurant manager', () {
      expect(VenueTeamRole.manager.labelFor('hotel'), 'Hotel manager');
      expect(
        VenueTeamRole.manager.labelFor('restaurant'),
        'Restaurant manager',
      );
      expect(VenueTeamRole.chef.labelFor('hotel'), 'Chef');
    });
  });

  group('previewTeam', () {
    const current = [
      VenueTeamMember(role: VenueTeamRole.chef, name: 'Live chef'),
      VenueTeamMember(role: VenueTeamRole.manager, name: 'Live manager'),
    ];

    test('a pending submission takes its role\'s place', () {
      final team = previewTeam(
        current: current,
        mine: {VenueTeamRole.chef: _submission(VenueTeamRole.chef, 'New chef')},
      );
      expect(team.map((m) => m.name), ['New chef', 'Live manager']);
    });

    test('a pending submission for an empty role is added', () {
      final team = previewTeam(
        current: const [],
        mine: {
          VenueTeamRole.manager: _submission(
            VenueTeamRole.manager,
            'New manager',
          ),
        },
      );
      expect(team.single.name, 'New manager');
    });

    test('rejected and withdrawn submissions change nothing', () {
      final team = previewTeam(
        current: current,
        mine: {
          VenueTeamRole.chef: _submission(
            VenueTeamRole.chef,
            'Rejected',
            status: VenueAboutSubmissionStatus.rejected,
          ),
          VenueTeamRole.manager: _submission(
            VenueTeamRole.manager,
            'Withdrawn',
            removedAt: DateTime.utc(2026, 10, 30, 12),
          ),
        },
      );
      expect(team.map((m) => m.name), ['Live chef', 'Live manager']);
    });
  });

  group('ReviewItem', () {
    test('reads a venue_team row from get_review_queue', () {
      final item = ReviewItem.fromJson({
        'kind': 'venue_team',
        'item_id': 'i1',
        'venue_type': 'restaurant',
        'venue_id': 'r1',
        'venue_name': 'De Librije',
        'submitted_by': 'u1',
        'submitted_at': '2026-10-30T10:00:00Z',
        'team_role': 'chef',
        'team_name': 'Jonnie Boer',
        'team_bio': 'Since 1989.',
      })!;
      expect(item.kind, ReviewKind.venueTeam);
      expect(item.teamRole, 'chef');
      expect(item.teamName, 'Jonnie Boer');
      expect(item.teamBio, 'Since 1989.');
    });
  });

  group('VenueTeamSection', () {
    Widget wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

    testWidgets('nothing at all when no one is shown — no empty heading', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(const VenueTeamSection(members: [], venueType: 'restaurant')),
      );
      expect(find.text('THE TEAM'), findsNothing);
    });

    testWidgets('each person with role, name and text, never gold', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(
          const VenueTeamSection(
            venueType: 'hotel',
            members: [
              VenueTeamMember(
                role: VenueTeamRole.chef,
                name: 'Jonnie Boer',
                bio: 'Since 1989.',
              ),
              VenueTeamMember(
                role: VenueTeamRole.manager,
                name: 'Thérèse Boer',
              ),
            ],
          ),
        ),
      );
      expect(find.text('THE TEAM'), findsOneWidget);
      expect(find.text('Chef'), findsOneWidget);
      expect(find.text('Hotel manager'), findsOneWidget);
      expect(find.text('Jonnie Boer'), findsOneWidget);
      expect(find.text('Since 1989.'), findsOneWidget);
      for (final text in tester.widgetList<Text>(find.byType(Text))) {
        expect(text.style?.color, isNot(AppColors.gold));
      }
    });
  });
}
