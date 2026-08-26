// PROFILE UI REDESIGN V1 — coverage for the canonical MemberAvatar
// component (lib/core/widgets/member_avatar.dart). Unlike ProfileScreen
// itself, MemberAvatar touches no Supabase state and can be pumped
// directly — every avatarUrl/onEdit input is a plain constructor
// parameter.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:michelin_passport/core/constants/app_colors.dart';
import 'package:michelin_passport/core/widgets/member_avatar.dart';

Widget _wrap(Widget child) =>
    MaterialApp(home: Scaffold(backgroundColor: AppColors.deepGreen, body: child));

void main() {
  group('MemberAvatar — no photo (initials fallback)', () {
    testWidgets('renders initials from a two-word display name', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(const MemberAvatar(avatarUrl: null, displayName: 'Ada Boone')),
      );
      expect(find.text('AB'), findsOneWidget);
      expect(find.byType(Image), findsNothing);
    });

    testWidgets('strips a leading "@" before deriving initials from a bare '
        'username — initials come from words, not letters, so a single-'
        'word username yields one initial', (tester) async {
      await tester.pumpWidget(
        _wrap(const MemberAvatar(avatarUrl: null, displayName: '@adaboone')),
      );
      expect(find.text('A'), findsOneWidget);
    });

    testWidgets('falls back to "?" for an empty display name, never a '
        'crash', (tester) async {
      await tester.pumpWidget(
        _wrap(const MemberAvatar(avatarUrl: null, displayName: '')),
      );
      expect(find.text('?'), findsOneWidget);
    });

    testWidgets('an empty-string avatarUrl is treated the same as null — '
        'initials, never a broken Image.network', (tester) async {
      await tester.pumpWidget(
        _wrap(const MemberAvatar(avatarUrl: '', displayName: 'Ada Boone')),
      );
      expect(find.text('AB'), findsOneWidget);
      expect(find.byType(Image), findsNothing);
    });

    testWidgets('the initials/border are never gold — restrained ivory/'
        'subtleBorderDark instead (gold is reserved for Michelin '
        'recognition)', (tester) async {
      await tester.pumpWidget(
        _wrap(const MemberAvatar(avatarUrl: null, displayName: 'Ada Boone')),
      );
      final initials = tester.widget<Text>(find.text('AB'));
      expect(initials.style?.color, isNot(AppColors.gold));

      final container = tester.widget<Container>(find.byType(Container).first);
      final decoration = container.decoration! as BoxDecoration;
      expect(decoration.border!.top.color, isNot(AppColors.gold));
    });
  });

  group('MemberAvatar — edit affordance', () {
    testWidgets('shows no pencil badge / is not tappable when onEdit is '
        'omitted (every future read-only consumer — Friends/Community)', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(const MemberAvatar(avatarUrl: null, displayName: 'Ada Boone')),
      );
      expect(find.byIcon(Icons.edit_outlined), findsNothing);
      expect(find.byType(InkWell), findsNothing);
    });

    testWidgets('shows a pencil badge and invokes onEdit when tapped', (
      tester,
    ) async {
      var tapped = false;
      await tester.pumpWidget(
        _wrap(
          MemberAvatar(
            avatarUrl: null,
            displayName: 'Ada Boone',
            onEdit: () => tapped = true,
          ),
        ),
      );
      expect(find.byIcon(Icons.edit_outlined), findsOneWidget);
      await tester.tap(find.byType(InkWell));
      expect(tapped, isTrue);
    });
  });

  group('MemberAvatar — sizing', () {
    testWidgets('defaults to 72 and honors an explicit size override', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(const MemberAvatar(avatarUrl: null, displayName: 'Ada Boone')),
      );
      final defaultSize = tester.getSize(find.byType(Container).first);
      expect(defaultSize, const Size(72, 72));

      await tester.pumpWidget(
        _wrap(
          const MemberAvatar(avatarUrl: null, displayName: 'Ada Boone', size: 40),
        ),
      );
      final overriddenSize = tester.getSize(find.byType(Container).first);
      expect(overriddenSize, const Size(40, 40));
    });
  });
}
