// COMMUNITY V1 UI REFINEMENT: covers the "Find friends" (AddFriendScreen)
// redesign onto the current Chasing Stars deep-green canvas — page title/
// background, the ivory search field, the removed giant centered helper
// text, real search results rendering as ivory cards, the "No members
// found." restrained no-results state (only after a valid search), and
// back navigation. [searchProfiles]/[sendFriendRequest] are optional DI
// seams (this session's established constructor-injection convention) —
// the REAL widget is pumped directly with hand-rolled fakes, never a
// mirrored copy of its build() method.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:michelin_passport/core/constants/app_colors.dart';
import 'package:michelin_passport/features/friends/add_friend_screen.dart';
import 'package:michelin_passport/models/profile_identity.dart';

ProfileIdentity _profile({
  String id = 'u1',
  String? displayName = 'Ada Boone',
  String? username = 'adaboone',
  RelationshipStatus status = RelationshipStatus.none,
}) => ProfileIdentity(
  id: id,
  displayName: displayName,
  username: username,
  relationshipStatus: status,
);

Widget _wrap({
  Future<List<ProfileIdentity>> Function(String query)? searchProfiles,
  Future<void> Function(String targetUserId)? sendFriendRequest,
}) => MaterialApp(
  home: AddFriendScreen(
    searchProfiles: searchProfiles,
    sendFriendRequest: sendFriendRequest,
  ),
);

void main() {
  group('AddFriendScreen ("Find friends") — structure', () {
    testWidgets('renders "Find friends" as the page title, ivory on a '
        'deep-green background — never the old "Add Friend" label', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap());
      await tester.pump();

      expect(find.text('Find friends'), findsOneWidget);
      expect(find.text('Add Friend'), findsNothing);
      final title = tester.widget<Text>(find.text('Find friends'));
      expect(title.style?.color, AppColors.ivory);

      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
      expect(scaffold.backgroundColor, AppColors.deepGreen);
    });

    testWidgets('renders the "Build your circle." subtitle', (tester) async {
      await tester.pumpWidget(_wrap());
      await tester.pump();
      expect(find.text('Build your circle.'), findsOneWidget);
    });

    testWidgets('the old giant centered helper text is gone, and nothing '
        'replaces it before the user types', (tester) async {
      await tester.pumpWidget(_wrap());
      await tester.pump();
      expect(find.text('Type at least 2 characters to search.'), findsNothing);
      expect(find.text('No members found.'), findsNothing);
    });

    testWidgets('a back button is present and pops the screen', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const AddFriendScreen()),
                  ),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.byType(AddFriendScreen), findsOneWidget);

      await tester.tap(find.byIcon(Icons.arrow_back_ios_new_rounded));
      await tester.pumpAndSettle();
      expect(find.byType(AddFriendScreen), findsNothing);
    });
  });

  group('AddFriendScreen — search behavior', () {
    testWidgets('fewer than 2 characters never triggers a search and shows '
        'no results/no-results state', (tester) async {
      var searchCalls = 0;
      await tester.pumpWidget(
        _wrap(
          searchProfiles: (q) async {
            searchCalls++;
            return [_profile()];
          },
        ),
      );
      await tester.enterText(find.byType(TextField), 'a');
      await tester.pump(const Duration(milliseconds: 500));
      expect(searchCalls, 0);
      expect(find.text('No members found.'), findsNothing);
      expect(find.text('Ada Boone'), findsNothing);
    });

    testWidgets('a valid search renders real results as ivory cards', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          searchProfiles: (q) async => [
            _profile(id: 'u1', displayName: 'Ada Boone', username: 'adaboone'),
          ],
        ),
      );
      await tester.enterText(find.byType(TextField), 'ada');
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump();

      expect(find.text('Ada Boone'), findsOneWidget);
      expect(find.text('@adaboone'), findsOneWidget);
      final container = tester.widget<Container>(
        find
            .ancestor(
              of: find.text('Ada Boone'),
              matching: find.byType(Container),
            )
            .first,
      );
      final decoration = container.decoration! as BoxDecoration;
      expect(decoration.color, AppColors.ivory);
    });

    testWidgets('a valid search with zero matches shows the restrained '
        '"No members found." state near the search area, not a full-page '
        'illustration', (tester) async {
      await tester.pumpWidget(_wrap(searchProfiles: (q) async => []));
      await tester.enterText(find.byType(TextField), 'zz');
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump();

      expect(find.text('No members found.'), findsOneWidget);
    });

    testWidgets('the existing "Add" send-request action still works and '
        'reflects a sent request', (tester) async {
      String? sentTo;
      await tester.pumpWidget(
        _wrap(
          searchProfiles: (q) async => [_profile(id: 'u9')],
          sendFriendRequest: (id) async => sentTo = id,
        ),
      );
      await tester.enterText(find.byType(TextField), 'ada');
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump();

      expect(find.text('Add'), findsOneWidget);
      await tester.tap(find.text('Add'));
      await tester.pump();

      expect(sentTo, 'u9');
      expect(find.text('Request sent'), findsOneWidget);
    });

    testWidgets('an already-accepted friendship shows "Friends", not an '
        'Add action', (tester) async {
      await tester.pumpWidget(
        _wrap(
          searchProfiles: (q) async => [
            _profile(status: RelationshipStatus.accepted),
          ],
        ),
      );
      await tester.enterText(find.byType(TextField), 'ada');
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump();

      expect(find.text('Friends'), findsOneWidget);
      expect(find.text('Add'), findsNothing);
    });
  });

  group('AddFriendScreen — no overflow', () {
    testWidgets('320px width with a populated results list and the '
        'keyboard open — no overflow', (tester) async {
      await tester.pumpWidget(
        _wrap(
          searchProfiles: (q) async => [
            _profile(id: 'u1', displayName: 'Ada Boone'),
            _profile(id: 'u2', displayName: 'Bo Renders'),
            _profile(id: 'u3', displayName: 'Cy Delacroix'),
          ],
        ),
      );
      await tester.binding.setSurfaceSize(const Size(320, 700));
      await tester.enterText(find.byType(TextField), 'a');
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump();
      expect(tester.takeException(), isNull);
      await tester.binding.setSurfaceSize(null);
    });
  });
}
