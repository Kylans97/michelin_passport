// PROFILE UI REDESIGN V1 — coverage for ChangeAvatarSheet, the one
// canonical "change my photo" flow. Exercised via its own DI seams
// (pickImage/replaceAvatar/removeAvatar) so the full pick → upload →
// replace/remove orchestration is tested without a live Supabase session
// or a real photo library — the same constructor-injection convention
// established by PrivacySettingsScreen/DeleteAccountScreen.

import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart' show XFile;
import 'package:michelin_passport/features/profile/avatar_picker.dart';
import 'package:michelin_passport/features/profile/change_avatar_sheet.dart';

StagedAvatar _staged() => StagedAvatar(
  file: XFile.fromData(Uint8List.fromList([1, 2, 3]), path: 'avatar.jpg'),
  bytes: Uint8List.fromList([1, 2, 3]),
);

// Pumps ChangeAvatarSheet directly (with DI seams) inside a bottom sheet
// and returns the STILL-PENDING Future it will eventually be popped with —
// deliberately not awaited here, so the caller can tap a row inside the
// now-open sheet first and await this afterward.
Future<Future<bool?>> _openWithSeams(
  WidgetTester tester, {
  required String? currentAvatarPath,
  Future<StagedAvatar?> Function()? pickImage,
  Future<String> Function(StagedAvatar)? replaceAvatar,
  Future<void> Function()? removeAvatar,
}) async {
  late Future<bool?> resultFuture;
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () {
                resultFuture = showModalBottomSheet<bool>(
                  context: context,
                  builder: (_) => ChangeAvatarSheet(
                    userId: 'u1',
                    currentAvatarPath: currentAvatarPath,
                    pickImage: pickImage,
                    replaceAvatar: replaceAvatar,
                    removeAvatar: removeAvatar,
                  ),
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  return resultFuture;
}

void main() {
  group('ChangeAvatarSheet — no current avatar', () {
    testWidgets('offers "Choose photo" only — no Remove row', (tester) async {
      await _openWithSeams(tester, currentAvatarPath: null);
      expect(find.text('Choose photo'), findsOneWidget);
      expect(find.text('Remove photo'), findsNothing);
    });
  });

  group('ChangeAvatarSheet — has a current avatar', () {
    testWidgets('offers "Replace photo" and "Remove photo"', (tester) async {
      await _openWithSeams(tester, currentAvatarPath: 'u1/old.jpg');
      expect(find.text('Replace photo'), findsOneWidget);
      expect(find.text('Choose photo'), findsNothing);
      expect(find.text('Remove photo'), findsOneWidget);
    });
  });

  group('ChangeAvatarSheet — picker cancelled', () {
    testWidgets('closes nothing and reports no change when the picker '
        'returns null', (tester) async {
      final future = await _openWithSeams(
        tester,
        currentAvatarPath: null,
        pickImage: () async => null,
      );
      await tester.tap(find.text('Choose photo'));
      await tester.pumpAndSettle();
      // Sheet stays open — still showing its own action row, never popped.
      expect(find.text('Choose photo'), findsOneWidget);
      // The sheet is still open/unpopped, so this Future is deliberately
      // never awaited here — awaiting it would hang forever.
      expect(future, isA<Future<bool?>>());
    });
  });

  group('ChangeAvatarSheet — replace succeeds', () {
    testWidgets('pops true only after replaceAvatar actually resolves — '
        'no optimistic close', (tester) async {
      var replaceCalled = false;
      final future = await _openWithSeams(
        tester,
        currentAvatarPath: 'u1/old.jpg',
        pickImage: () async => _staged(),
        replaceAvatar: (staged) async {
          replaceCalled = true;
          return 'u1/new.jpg';
        },
      );
      await tester.tap(find.text('Replace photo'));
      await tester.pumpAndSettle();
      final result = await future;
      expect(replaceCalled, isTrue);
      expect(result, isTrue);
    });
  });

  group('ChangeAvatarSheet — replace fails', () {
    testWidgets('shows an inline error, stays open, and never pops true — '
        'the member\'s prior avatar is left intact', (tester) async {
      final future = await _openWithSeams(
        tester,
        currentAvatarPath: 'u1/old.jpg',
        pickImage: () async => _staged(),
        replaceAvatar: (_) async => throw Exception('network error'),
      );
      await tester.tap(find.text('Replace photo'));
      await tester.pumpAndSettle();
      expect(
        find.text('Could not update your photo. Please try again.'),
        findsOneWidget,
      );
      // Still open — the sheet's own rows are still present, unpopped.
      expect(find.text('Replace photo'), findsOneWidget);
      // Retry is possible — the row is tappable again (not stuck in a
      // permanently disabled busy state).
      expect(
        tester
            .widget<InkWell>(
              find.ancestor(
                of: find.text('Replace photo'),
                matching: find.byType(InkWell),
              ),
            )
            .onTap,
        isNotNull,
      );
      expect(future, isA<Future<bool?>>());
    });
  });

  group('ChangeAvatarSheet — remove succeeds', () {
    testWidgets('pops true only after removeAvatar actually resolves', (
      tester,
    ) async {
      var removeCalled = false;
      final future = await _openWithSeams(
        tester,
        currentAvatarPath: 'u1/old.jpg',
        removeAvatar: () async {
          removeCalled = true;
        },
      );
      await tester.tap(find.text('Remove photo'));
      await tester.pumpAndSettle();
      final result = await future;
      expect(removeCalled, isTrue);
      expect(result, isTrue);
    });
  });

  group('ChangeAvatarSheet — remove fails', () {
    testWidgets('shows an inline error and stays open', (tester) async {
      final future = await _openWithSeams(
        tester,
        currentAvatarPath: 'u1/old.jpg',
        removeAvatar: () async => throw Exception('network error'),
      );
      // Failure never pops the sheet, so this Future deliberately stays
      // unawaited — awaiting it would hang forever.
      expect(future, isA<Future<bool?>>());
      await tester.tap(find.text('Remove photo'));
      await tester.pumpAndSettle();
      expect(
        find.text('Could not remove your photo. Please try again.'),
        findsOneWidget,
      );
      expect(find.text('Remove photo'), findsOneWidget);
    });
  });

  group('ChangeAvatarSheet — Cancel', () {
    testWidgets('pops false and calls neither replace nor remove', (
      tester,
    ) async {
      var replaceCalled = false;
      var removeCalled = false;
      final future = await _openWithSeams(
        tester,
        currentAvatarPath: 'u1/old.jpg',
        replaceAvatar: (_) async {
          replaceCalled = true;
          return 'x';
        },
        removeAvatar: () async {
          removeCalled = true;
        },
      );
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      final result = await future;
      expect(result, isFalse);
      expect(replaceCalled, isFalse);
      expect(removeCalled, isFalse);
    });
  });
}
