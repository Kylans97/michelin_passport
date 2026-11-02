// Covers the venue team (20261030170000) apart from its screens: the
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
          VenueTeamMember.fromJson({'role': 'pastry', 'name': 'X'}),
          isNull,
        );
        final sommelier = VenueTeamMember.fromJson({
          'role': 'sommelier',
          'name': 'S',
          'photo_url': 'https://cdn/s.jpg',
        });
        expect(sommelier!.role, VenueTeamRole.sommelier);
        expect(sommelier.photoUrl, 'https://cdn/s.jpg');
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

    testWidgets('a strip of role and name, the full text in a sheet, never '
        'gold', (tester) async {
      await tester.pumpWidget(
        wrap(
          const VenueTeamSection(
            venueType: 'hotel',
            members: [
              VenueTeamMember(
                role: VenueTeamRole.manager,
                name: 'Manager Name',
              ),
              VenueTeamMember(
                role: VenueTeamRole.chef,
                name: 'Chef Name',
                bio: 'Since 1989.',
              ),
            ],
          ),
        ),
      );
      expect(find.text('THE TEAM'), findsOneWidget);
      expect(find.text('Chef'), findsOneWidget);
      expect(find.text('Manager'), findsOneWidget);
      // The chef comes first in the strip.
      expect(
        tester.getTopLeft(find.text('Chef Name')).dx,
        lessThan(tester.getTopLeft(find.text('Manager Name')).dx),
      );
      // The text waits for the sheet; no photo shows initials.
      expect(find.text('Since 1989.'), findsNothing);
      expect(find.text('CN'), findsOneWidget);
      for (final text in tester.widgetList<Text>(find.byType(Text))) {
        expect(text.style?.color, isNot(AppColors.gold));
      }

      await tester.tap(find.text('Chef Name'));
      await tester.pumpAndSettle();
      expect(find.text('Since 1989.'), findsOneWidget);

      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Manager Name'));
      await tester.pumpAndSettle();
      expect(find.text('Hotel manager'), findsOneWidget);
    });

    test('the page order is chef, manager, sommelier', () {
      final ordered = VenueTeamMember.ordered(const [
        VenueTeamMember(role: VenueTeamRole.sommelier, name: 'S'),
        VenueTeamMember(role: VenueTeamRole.manager, name: 'M'),
        VenueTeamMember(role: VenueTeamRole.chef, name: 'C'),
      ]);
      expect(ordered.map((m) => m.name), ['C', 'M', 'S']);
    });

    test('a preview keeps the current photo, shows a waiting one, and drops '
        'a removed one', () {
      const current = [
        VenueTeamMember(
          role: VenueTeamRole.chef,
          name: 'C',
          photoUrl: 'https://cdn/c.jpg',
        ),
        VenueTeamMember(
          role: VenueTeamRole.sommelier,
          name: 'S',
          photoUrl: 'https://cdn/s.jpg',
        ),
      ];
      VenueTeamSubmission pending(
        VenueTeamRole role, {
        String? photoPath,
        bool removePhoto = false,
      }) => VenueTeamSubmission(
        id: role.name,
        role: role,
        name: '${role.name} new',
        status: VenueAboutSubmissionStatus.pending,
        submittedAt: DateTime.utc(2026, 11, 2),
        photoPath: photoPath,
        removePhoto: removePhoto,
      );
      final team = previewTeam(
        current: current,
        mine: {
          VenueTeamRole.chef: pending(VenueTeamRole.chef),
          VenueTeamRole.manager: pending(
            VenueTeamRole.manager,
            photoPath: 'restaurant/r/u/team_manager_1.jpg',
          ),
          VenueTeamRole.sommelier: pending(
            VenueTeamRole.sommelier,
            removePhoto: true,
          ),
        },
        pendingPhotoUrls: {VenueTeamRole.manager: 'https://signed/m.jpg'},
      );
      expect(team.map((m) => (m.name, m.photoUrl)), [
        ('chef new', 'https://cdn/c.jpg'),
        ('manager new', 'https://signed/m.jpg'),
        ('sommelier new', null),
      ]);
    });
  });
}
