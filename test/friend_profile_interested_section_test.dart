// Events V2 Step 7 — covers the INTERESTED section FriendProfileScreen
// adds for an accepted friend, directly paralleling
// friend_profile_going_section_test.dart's own coverage of GOING one
// status over: loading/error/empty states all omit the section entirely
// (Step 1 §18's "omit rather than clutter" rule, unchanged), the shared
// preview limit, the "View all" trigger, and rendering via the same real
// FriendGoingTile leaf widget (reused as-is — it has no Going-specific
// text baked in, see FriendGoingTile's own doc comment).
//
// _FriendInterestedSection is private to friend_profile_screen.dart, and
// FriendProfileScreen constructs EventAttendanceRepository against
// Supabase.instance.client eagerly in initState — same established
// limitation as GOING's own test file — so this reconstructs the exact
// FutureBuilder + preview/empty-omission shape here.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:michelin_passport/core/constants/app_colors.dart';
import 'package:michelin_passport/core/theme/cs_typography.dart';
import 'package:michelin_passport/features/friends/widgets/friend_going_tile.dart';
import 'package:michelin_passport/models/event.dart';

const _previewLimit = 4;

Event _event(String id, String name, {DateTime? startAt}) => Event(
  id: id,
  name: name,
  city: 'Maastricht',
  startAt: _utc(startAt ?? DateTime(2026, 8, 28)),
  endAt: _utc(startAt ?? DateTime(2026, 8, 30)),
  timezone: 'UTC',
  countryCode: 'NL',
  eventType: EventType.festival,
  status: EventStatus.upcoming,
  createdAt: DateTime(2026, 1, 1),
);

DateTime _utc(DateTime d) =>
    DateTime.utc(d.year, d.month, d.day, d.hour, d.minute, d.second);

// Mirrors _FriendInterestedSection exactly — no trailing SectionDivider,
// since INTERESTED is the last section on the page.
Widget _interestedSection(Future<List<Event>>? future) {
  return FutureBuilder<List<Event>>(
    future: future,
    builder: (context, snap) {
      final loading = snap.connectionState == ConnectionState.waiting;
      if (!loading && !snap.hasError) {
        final events = snap.data ?? const [];
        if (events.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'INTERESTED',
                  style: CsTypography.eyebrow.copyWith(color: AppColors.taupe),
                ),
                if (events.length > _previewLimit)
                  Text(
                    'View all',
                    style: CsTypography.metadata.copyWith(
                      color: AppColors.forestGreen,
                    ),
                  ),
              ],
            ),
            for (var i = 0; i < events.length && i < _previewLimit; i++)
              FriendGoingTile(event: events[i], onTap: () {}),
          ],
        );
      }
      if (snap.hasError) return const SizedBox.shrink();
      return const Center(
        child: CircularProgressIndicator(color: AppColors.forestGreen),
      );
    },
  );
}

Widget _wrap(Widget child) => MaterialApp(
  home: Scaffold(backgroundColor: AppColors.ivory, body: child),
);

void main() {
  group('Friend Profile INTERESTED section (Events V2 Step 7)', () {
    testWidgets('shows a loading spinner while pending', (tester) async {
      final completer = Completer<List<Event>>();
      await tester.pumpWidget(_wrap(_interestedSection(completer.future)));
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets(
      'omits the whole section entirely when empty — never a "nothing '
      'here" line',
      (tester) async {
        await tester.pumpWidget(
          _wrap(_interestedSection(Future.value(const []))),
        );
        await tester.pumpAndSettle();
        expect(find.text('INTERESTED'), findsNothing);
      },
    );

    testWidgets('renders one tile per event the repository returns', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          _interestedSection(
            Future.value([
              _event('e1', 'Festival A'),
              _event('e2', 'Festival B'),
            ]),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(FriendGoingTile), findsNWidgets(2));
      expect(find.text('Festival A'), findsOneWidget);
      expect(find.text('Festival B'), findsOneWidget);
    });

    testWidgets(
      'caps the preview at $_previewLimit rows and shows "View all" only '
      'when more exist',
      (tester) async {
        await tester.pumpWidget(
          _wrap(
            _interestedSection(
              Future.value([
                for (var i = 0; i < 6; i++) _event('e$i', 'Festival $i'),
              ]),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byType(FriendGoingTile), findsNWidgets(_previewLimit));
        expect(find.text('View all'), findsOneWidget);
      },
    );

    testWidgets(
      'omits the section on error, rather than showing a raw error line',
      (tester) async {
        final errorFuture = Future<List<Event>>.error('boom')..ignore();
        await tester.pumpWidget(_wrap(_interestedSection(errorFuture)));
        await tester.pumpAndSettle();
        expect(find.text('INTERESTED'), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  });
}
