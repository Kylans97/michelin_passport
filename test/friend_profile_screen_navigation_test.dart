// Covers the actual navigation path into FriendProfileScreen — pushed via
// a real Navigator.push(MaterialPageRoute(builder: (_) =>
// FriendProfileScreen(userId: ...))), the exact construction both
// friends_screen.dart's _openProfile and add_friend_screen.dart's new
// tap-through use, rather than a hand-reconstructed mirror of its private
// _Hero widget (every other test in this file/feature does the latter,
// because FriendProfileScreen constructs FriendshipRepository against
// Supabase.instance.client eagerly, which throws with no Supabase
// instance initialized — the same documented limitation as
// add_visit_sheet_shell_test.dart and others). That's precisely the gap a
// real bug report exposed: a widget test can be green while the actual
// pushed screen throws during build on a real device, because nothing in
// this suite previously pumped the real screen at all.
//
// The fix here is a genuine (not fake-network) Supabase.initialize —
// EmptyLocalStorage skips SharedPreferences/platform channels entirely,
// and a MockClient returning a generic JSON error for every request means
// no real network call is ever attempted. FriendshipRepository.
// getProfileIdentity's request fails fast with a PostgrestException,
// which FriendProfileScreen's own FutureBuilder already handles via its
// `snap.hasError` branch ("Could not load this profile") — so the real
// screen still renders something, proving its build() and initState()
// survive being pushed with a real userId end to end, exactly the
// question this bug report raises.
//
// A SECOND, physical-device-found bug this file's first version still
// missed entirely: the error-path test above never reaches _ProfileBody
// (the FutureBuilder's error branch short-circuits before it), so it
// could not have caught _ProfileBody.build() returning
// `Expanded(child: CustomScrollView(...))` directly as Scaffold.body —
// invalid ("Incorrect use of ParentDataWidget"), since Scaffold lays its
// body out via a CustomMultiChildLayout, not a Flex. That assertion only
// fires in debug; release silently produced a blank/grey screen instead.
// The MockClient below now routes on the request body's target_user_id
// so a second test can mock a genuinely SUCCESSFUL get_profile_identity
// response, letting _ProfileBody actually build — which is the only way
// either version of this bug could ever have been caught here.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:michelin_passport/features/friends/friend_profile_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  setUpAll(() async {
    // Supabase.initialize's GoTrue client uses a SharedPreferences-backed
    // async storage for PKCE internally, independent of the localStorage
    // override below — without this mock, that construction throws a
    // MissingPluginException (no platform channel in a widget test).
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'https://test.supabase.co',
      publishableKey: 'test-anon-key',
      authOptions: const FlutterAuthClientOptions(
        localStorage: EmptyLocalStorage(),
        autoRefreshToken: false,
        detectSessionInUri: false,
      ),
      httpClient: MockClient((request) async {
        // postgrest's own error path (and a real response either way)
        // reads response.request!.method — http.Response's `request`
        // field is null unless explicitly attached, which a real
        // Client.send() does automatically but a bare MockClient
        // response does not.
        final body = request.body;
        if (body.contains('success-user-456')) {
          return http.Response(
            '[{"id":"success-user-456","username":"kylan",'
            '"display_name":"Kylan","avatar_url":null,'
            '"relationship_status":null}]',
            200,
            request: request,
          );
        }
        return http.Response(
          '{"message":"not reachable in tests","code":"PGRST000"}',
          400,
          request: request,
        );
      }),
    );
  });

  testWidgets(
    'tapping a friend row (the real friends_screen.dart/'
    'add_friend_screen.dart construction) pushes FriendProfileScreen and '
    "it builds without throwing — doesn't stay on a blank/grey screen",
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ListTile(
                title: const Text('A Friend'),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        const FriendProfileScreen(userId: 'friend-uuid-123'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('A Friend'));
      // One frame to let the route push and FriendProfileScreen.initState
      // run (this is exactly where a synchronous build-time exception —
      // e.g. an unguarded access during the very first build — would
      // surface as a FlutterError instead of a rendered screen).
      await tester.pump();
      expect(tester.takeException(), isNull);

      // Let the (mocked, failing) network round-trip resolve.
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      // The real screen rendered its real error branch — not a blank
      // screen, not an uncaught exception.
      expect(find.byType(FriendProfileScreen), findsOneWidget);
      expect(find.text('Could not load this profile'), findsOneWidget);
    },
  );

  testWidgets(
    'a genuinely successful identity load builds _ProfileBody without '
    'throwing — this is the only path that could ever have caught the '
    'Expanded/CustomMultiChildLayout bug',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ListTile(
                title: const Text('A Friend'),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const FriendProfileScreen(
                      userId: 'success-user-456',
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('A Friend'));
      await tester.pump();
      expect(tester.takeException(), isNull);

      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      // The real hero (identity, avatar initials, relationship action)
      // rendered — proof _ProfileBody's own build() actually ran, not
      // just the loading/error branches above it.
      expect(find.text('Kylan'), findsOneWidget);
      expect(find.text('@kylan'), findsOneWidget);
      expect(find.text('Add friend'), findsOneWidget);
    },
  );
}
