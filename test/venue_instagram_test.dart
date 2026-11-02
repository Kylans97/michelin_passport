import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:michelin_passport/core/widgets/venue_utility_actions.dart';
import 'package:michelin_passport/data/repositories/venue_instagram_repository.dart';
import 'package:michelin_passport/models/review_item.dart';

void main() {
  group('normalizeInstagramHandle', () {
    test('takes a name, an @name or a profile link', () {
      for (final input in [
        'yourvenue',
        '@yourvenue',
        '  @yourvenue  ',
        'instagram.com/yourvenue',
        'www.instagram.com/yourvenue/',
        'https://www.instagram.com/yourvenue/?hl=en',
        'http://instagram.com/yourvenue',
      ]) {
        expect(normalizeInstagramHandle(input), 'yourvenue', reason: input);
      }
      expect(normalizeInstagramHandle('your.venue_2'), 'your.venue_2');
    });

    test('refuses posts, other sites and names Instagram would not allow', () {
      for (final input in [
        '',
        '@',
        'https://www.instagram.com/p/AbC123/',
        'https://www.instagram.com/reel/AbC123/',
        'https://instagram.evil.com/yourvenue',
        'https://example.com/yourvenue',
        'your venue',
        'yourvenue!',
        'a' * 31,
      ]) {
        expect(normalizeInstagramHandle(input), isNull, reason: input);
      }
    });

    test('the page opens the profile on instagram.com', () {
      expect(
        instagramProfileUri('your.venue').toString(),
        'https://www.instagram.com/your.venue/',
      );
    });
  });

  group('VenueUtilityActions', () {
    Future<void> pump(WidgetTester tester, {VoidCallback? onInstagram}) =>
        tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: VenueUtilityActions(
                onOpenMaps: () {},
                onOpenWebsite: () {},
                onOpenInstagram: onInstagram,
                onCall: () {},
              ),
            ),
          ),
        );

    testWidgets('Instagram sits between Website and Call when there is one', (
      tester,
    ) async {
      var opened = false;
      await pump(tester, onInstagram: () => opened = true);
      final website = tester.getCenter(find.text('Website')).dx;
      final instagram = tester.getCenter(find.text('Instagram')).dx;
      final call = tester.getCenter(find.text('Call')).dx;
      expect(website < instagram && instagram < call, isTrue);
      await tester.tap(find.text('Instagram'));
      expect(opened, isTrue);
    });

    testWidgets('no Instagram action without an account', (tester) async {
      await pump(tester);
      expect(find.text('Instagram'), findsNothing);
      expect(find.byType(InstagramGlyph), findsNothing);
    });
  });

  group('ReviewItem', () {
    Map<String, dynamic> row(String kind) => {
      'kind': kind,
      'item_id': 'i1',
      'venue_type': 'restaurant',
      'venue_id': 'r1',
      'venue_name': 'Venue',
      'submitted_by': 'u1',
      'submitter_label': 'Member',
      'submitted_at': '2026-11-02T10:00:00Z',
    };

    test('reads an Instagram item and a team item with a photo', () {
      final ig = ReviewItem.fromJson({
        ...row('venue_instagram'),
        'instagram_handle': 'yourvenue',
      })!;
      expect(ig.kind, ReviewKind.venueInstagram);
      expect(ig.instagramHandle, 'yourvenue');

      final team = ReviewItem.fromJson({
        ...row('venue_team'),
        'team_role': 'sommelier',
        'team_name': 'S',
        'team_photo_path': 'restaurant/r1/u1/team_sommelier_1.jpg',
        'team_remove_photo': false,
      })!;
      expect(team.teamPhotoPath, 'restaurant/r1/u1/team_sommelier_1.jpg');
      expect(team.teamRemovePhoto, isFalse);
    });
  });
}
