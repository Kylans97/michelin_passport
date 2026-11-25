// Covers claiming a venue from the first minute (product owner,
// 2026-11-25): the venue explainer (VenueClaimIntroScreen), the venue
// guide's link (isClaimLink, PendingClaim, ClaimLinkGate), OnboardingGate
// leaving the guests' welcome flow out for those arrivals, the entrance
// strip, and the one line on the welcome flow's last page.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:michelin_passport/features/claims/claim_link_gate.dart';
import 'package:michelin_passport/features/claims/pending_claim.dart';
import 'package:michelin_passport/features/claims/venue_claim_intro_screen.dart';
import 'package:michelin_passport/features/invites/invite_link_banner.dart';
import 'package:michelin_passport/features/onboarding/onboarding_gate.dart';
import 'package:michelin_passport/features/onboarding/welcome_flow_screen.dart';

Future<void> _toLastPage(WidgetTester tester) async {
  await tester.tap(find.text('Skip'));
  await tester.pumpAndSettle();
}

Widget _launcher(Widget Function(BuildContext) screen) => MaterialApp(
  home: Builder(
    builder: (context) => Scaffold(
      body: Center(
        child: TextButton(
          onPressed: () => Navigator.of(
            context,
          ).push(MaterialPageRoute<void>(builder: screen)),
          child: const Text('Open'),
        ),
      ),
    ),
  ),
);

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await PendingClaim.instance.clear();
  });

  group('isClaimLink', () {
    test('recognises the venue guide link however it is written', () {
      for (final text in [
        'https://mantelier.app/claim',
        'mantelier.app/claim',
        'https://www.mantelier.app/claim/',
        'https://mantelier.app/claim?from=guide',
        '  https://mantelier.app/claim  ',
      ]) {
        expect(isClaimLink(text), isTrue, reason: text);
      }
    });

    test('ignores other links and look-alikes', () {
      for (final text in [
        null,
        '',
        'https://mantelier.app/i/abcdefghijklmnop',
        'https://mantelier.app/claims',
        'https://mantelier.app/claim-your-venue',
        'https://notmantelier.app/claim',
        'https://example.com/mantelier.app/claimx',
      ]) {
        expect(isClaimLink(text), isFalse, reason: '$text');
      }
    });
  });

  group('VenueClaimIntroScreen', () {
    testWidgets('three pages: your page, your guests, how it works', (
      tester,
    ) async {
      await tester.pumpWidget(const MaterialApp(home: VenueClaimIntroScreen()));
      expect(find.text('Your venue, in your own words'), findsOneWidget);
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      expect(find.text('Bring your guests with you'), findsOneWidget);
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      expect(find.text('How it works'), findsOneWidget);
      expect(find.text('Claim my venue'), findsOneWidget);
      expect(find.text('Later'), findsOneWidget);
      expect(find.text('Skip'), findsNothing);
    });

    testWidgets('Skip goes to how it works, where Later is', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: VenueClaimIntroScreen()));
      await _toLastPage(tester);
      expect(find.text('How it works'), findsOneWidget);
      expect(find.text('Later'), findsOneWidget);
    });

    testWidgets('Claim my venue opens the claim flow', (tester) async {
      var opened = 0;
      await tester.pumpWidget(
        MaterialApp(home: VenueClaimIntroScreen(openClaim: (_) => opened++)),
      );
      await _toLastPage(tester);
      await tester.tap(find.text('Claim my venue'));
      await tester.pump();
      expect(opened, 1);
    });

    testWidgets('Later closes it', (tester) async {
      await tester.pumpWidget(_launcher((_) => const VenueClaimIntroScreen()));
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await _toLastPage(tester);
      await tester.tap(find.text('Later'));
      await tester.pumpAndSettle();
      expect(find.byType(VenueClaimIntroScreen), findsNothing);
      expect(find.text('Open'), findsOneWidget);
    });

    testWidgets('from the claim screen it only leads back there', (
      tester,
    ) async {
      await tester.pumpWidget(
        _launcher((_) => const VenueClaimIntroScreen(fromClaimScreen: true)),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await _toLastPage(tester);
      expect(find.text('Later'), findsNothing);
      expect(
        find.text('Not ready yet? You can claim any time from Profile.'),
        findsNothing,
      );
      await tester.tap(find.text('Back to my claim'));
      await tester.pumpAndSettle();
      expect(find.byType(VenueClaimIntroScreen), findsNothing);
    });

    testWidgets('no copy uses a dash (product owner)', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: VenueClaimIntroScreen()));
      for (var page = 0; page < 3; page++) {
        for (final text in tester.widgetList<Text>(find.byType(Text))) {
          final data = text.data ?? '';
          expect(data, isNot(contains('—')), reason: data);
          expect(data, isNot(contains('–')), reason: data);
          expect(data, isNot(contains(' - ')), reason: data);
        }
        if (page < 2) {
          await tester.tap(find.text('Next'));
          await tester.pumpAndSettle();
        }
      }
    });

    testWidgets('small and large phones: no overflow', (tester) async {
      addTearDown(() => tester.binding.setSurfaceSize(null));
      for (final size in const [
        Size(320, 640),
        Size(375, 667),
        Size(440, 956),
      ]) {
        await tester.binding.setSurfaceSize(size);
        await tester.pumpWidget(
          MaterialApp(home: VenueClaimIntroScreen(key: ValueKey(size))),
        );
        await tester.pumpAndSettle();
        for (var page = 0; page < 3; page++) {
          expect(tester.takeException(), isNull, reason: '$size $page');
          if (page < 2) {
            await tester.tap(find.text('Next'));
            await tester.pumpAndSettle();
          }
        }
      }
      await tester.binding.setSurfaceSize(null);
    });
  });

  group('ClaimLinkGate', () {
    testWidgets('opens the explainer while a venue guide link waits, and '
        'lets it go after Later', (tester) async {
      await PendingClaim.instance.set();
      await tester.pumpWidget(
        const MaterialApp(home: ClaimLinkGate(child: Text('App'))),
      );
      await tester.pumpAndSettle();
      expect(find.byType(VenueClaimIntroScreen), findsOneWidget);
      await _toLastPage(tester);
      await tester.tap(find.text('Later'));
      await tester.pumpAndSettle();
      expect(find.text('App'), findsOneWidget);
      expect(PendingClaim.instance.waiting.value, isFalse);
    });

    testWidgets('does nothing when no link waits', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: ClaimLinkGate(child: Text('App'))),
      );
      await tester.pumpAndSettle();
      expect(find.byType(VenueClaimIntroScreen), findsNothing);
      expect(find.text('App'), findsOneWidget);
    });
  });

  group('OnboardingGate with a venue guide arrival', () {
    testWidgets('leaves the guests welcome flow out and marks it seen', (
      tester,
    ) async {
      await PendingClaim.instance.set();
      final marked = <String>[];
      await tester.pumpWidget(
        MaterialApp(
          home: OnboardingGate(
            userId: 'user-9',
            hasSeenWelcome: (_) async => false,
            markWelcomeSeen: (id) async => marked.add(id),
            pendingClaim: PendingClaim.instance,
            child: const Text('App'),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
      expect(find.byType(WelcomeFlow), findsNothing);
      expect(find.text('App'), findsOneWidget);
      expect(marked, ['user-9']);
    });

    testWidgets('without one, a new member still gets the welcome flow', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: OnboardingGate(
            userId: 'user-9',
            hasSeenWelcome: (_) async => false,
            markWelcomeSeen: (_) async {},
            welcomeGreeting: (_) async => throw Exception('offline'),
            pendingClaim: PendingClaim.instance,
            child: const Text('App'),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
      expect(find.byType(WelcomeFlow), findsOneWidget);
    });
  });

  group('InviteLinkBanner', () {
    testWidgets('a venue guide arrival sees where signing in takes them', (
      tester,
    ) async {
      await PendingClaim.instance.set();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: InviteLinkBanner(pendingClaim: PendingClaim.instance),
          ),
        ),
      );
      await tester.pump();
      expect(find.text('Claiming your venue'), findsOneWidget);
      expect(find.text('Sign in first, and we take you there.'), findsOne);
    });
  });

  testWidgets('the welcome flow last page has the one line for venues', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: WelcomeFlow(onDone: () {}),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    for (var i = 0; i < 5; i++) {
      await tester.drag(find.byType(PageView), const Offset(-600, 0));
      await tester.pumpAndSettle();
    }
    expect(
      find.text('Own a venue? You can claim it any time in Profile.'),
      findsOneWidget,
    );
  });
}
