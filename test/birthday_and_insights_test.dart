// Covers the optional birthday, the sign-up country and the member
// insights (20261101210000): the 16-and-over date limit and the date
// format, the birthday notification's wire value, and the admin insights
// screen — counts per country and age group, "fewer than 5" where the
// database withholds a small count, and the total always shown.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:michelin_passport/data/repositories/profile_private_repository.dart';
import 'package:michelin_passport/data/repositories/review_repository.dart';
import 'package:michelin_passport/features/review/member_insights_screen.dart';
import 'package:michelin_passport/models/app_notification.dart';
import 'package:michelin_passport/models/venue_country.dart';

SupabaseClient _dummyClient() => SupabaseClient(
  'https://test.supabase.co',
  'test-anon-key',
  authOptions: const AuthClientOptions(autoRefreshToken: false),
);

class _FakeReviewRepo extends ReviewRepository {
  _FakeReviewRepo(this.rows) : super(_dummyClient());
  final List<MemberInsight> rows;

  @override
  Future<List<MemberInsight>> loadMemberInsights() async => rows;
}

void main() {
  group('birth date helpers', () {
    test('the latest allowed birth date is 16 years before today', () {
      expect(
        latestAllowedBirthDate(DateTime(2026, 11, 2)),
        DateTime(2010, 11, 2),
      );
    });

    test('a birth date reads as day, month name and year', () {
      expect(formatBirthDate(DateTime(1990, 3, 14)), '14 March 1990');
      expect(formatBirthDate(DateTime(2000, 12, 1)), '1 December 2000');
    });
  });

  test('a birthday notification maps from its wire value', () {
    expect(
      AppNotificationType.fromWire('birthday'),
      AppNotificationType.birthday,
    );
  });

  test('MemberInsight keeps a withheld count as null', () {
    final row = MemberInsight.fromJson({
      'dimension': 'country',
      'bucket': 'BE',
      'members': null,
      'new_last_30_days': null,
    });
    expect(row.members, isNull);
    expect(row.newLast30Days, isNull);
  });

  testWidgets('insights show the total, countries by size and ages in order, '
      'with small groups as "fewer than 5"', (tester) async {
    final repo = _FakeReviewRepo(const [
      MemberInsight(
        dimension: 'total',
        bucket: 'all',
        members: 12,
        newLast30Days: 3,
      ),
      MemberInsight(
        dimension: 'country',
        bucket: 'BE',
        members: null,
        newLast30Days: null,
      ),
      MemberInsight(
        dimension: 'country',
        bucket: 'NL',
        members: 8,
        newLast30Days: null,
      ),
      MemberInsight(dimension: 'age', bucket: 'none', members: 7),
      MemberInsight(dimension: 'age', bucket: '25-34', members: 5),
    ]);
    await tester.pumpWidget(
      MaterialApp(
        home: MemberInsightsScreen(
          repository: repo,
          loadCountries: () async => const [
            VenueCountry(name: 'Belgium', code: 'BE', flag: ''),
            VenueCountry(name: 'Netherlands', code: 'NL', flag: ''),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('12'), findsOneWidget);
    expect(find.text('members · 3 new in 30 days'), findsOneWidget);
    expect(find.text('Netherlands'), findsOneWidget);
    expect(find.text('Belgium'), findsOneWidget);
    expect(find.text('fewer than 5'), findsWidgets);
    expect(
      tester.getTopLeft(find.text('Netherlands')).dy,
      lessThan(tester.getTopLeft(find.text('Belgium')).dy),
    );
    expect(
      tester.getTopLeft(find.text('25-34')).dy,
      lessThan(tester.getTopLeft(find.text('Not given')).dy),
    );
  });
}
