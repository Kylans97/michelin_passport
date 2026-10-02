// Covers NotificationsScreen's per-type row rendering and the unread-dot
// distinction. NotificationsScreen constructs NotificationsRepository/
// FriendshipRepository against Supabase.instance.client eagerly in
// initState (same established limitation as every other Supabase-eager
// screen in this app), so this reconstructs the exact row shapes from
// lib/features/notifications/notifications_screen.dart rather than
// pumping the real screen — same approach friends_screen_states_test.dart
// already uses for FriendsScreen.
//
// The friendRequestReceived row's Accept/Decline is the exact interaction
// that used to be tested under "FriendsScreen incoming request row" in
// friends_screen_states_test.dart before Notifications V1 moved it here —
// see that file's own note.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:michelin_passport/core/constants/app_colors.dart';
import 'package:michelin_passport/core/theme/cs_typography.dart';
import 'package:michelin_passport/features/friends/widgets/identity_row.dart';
import 'package:michelin_passport/features/notifications/notifications_screen.dart'
    show claimQuestionMailtoUri;

Widget _unreadDot({required bool visible}) => SizedBox(
  width: 8,
  height: 8,
  child: visible
      ? const DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.error,
          ),
        )
      : null,
);

Widget _friendRequestReceivedRow({
  required VoidCallback onAccept,
  required VoidCallback onDecline,
  bool isRead = false,
}) => Row(
  crossAxisAlignment: CrossAxisAlignment.start,
  children: [
    Padding(
      padding: const EdgeInsets.only(top: 12, right: 4),
      child: _unreadDot(visible: !isRead),
    ),
    Expanded(
      child: IdentityRow(
        label: 'Kylan',
        username: 'kylan',
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextButton(onPressed: onDecline, child: const Text('Decline')),
            TextButton(onPressed: onAccept, child: const Text('Accept')),
          ],
        ),
      ),
    ),
  ],
);

Widget _friendRequestAcceptedRow({VoidCallback? onTap}) => IdentityRow(
  label: 'Kylan',
  username: null,
  onTap: onTap,
  trailing: Text(
    'Accepted',
    style: CsTypography.metadata.copyWith(color: AppColors.taupe),
  ),
);

Widget _missingListingAddedRow({
  required String name,
  required String city,
}) => Padding(
  padding: const EdgeInsets.symmetric(vertical: 8),
  child: Row(
    children: [
      const Icon(
        Icons.storefront_outlined,
        color: AppColors.forestGreen,
        size: 20,
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Text(
          '$name in $city has been added.',
          style: CsTypography.body.copyWith(color: AppColors.forestGreen),
        ),
      ),
    ],
  ),
);

// Mirrors _VenueClaimContent's layout (lib/features/notifications/
// notifications_screen.dart) — same "reconstruct the row" approach as
// _missingListingAddedRow above, for the same reason (Supabase-eager
// screen, private row widget). showContactLine/onEmailTap mirror the
// real widget's received/rejected-only mailto line.
Widget _venueClaimRow({
  required String description,
  required IconData icon,
  bool showContactLine = false,
  VoidCallback? onEmailTap,
  String? note,
}) => Padding(
  padding: const EdgeInsets.symmetric(vertical: 8),
  child: Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(icon, color: AppColors.forestGreen, size: 20),
      const SizedBox(width: 12),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              description,
              style: CsTypography.body.copyWith(color: AppColors.forestGreen),
            ),
            if (note != null) ...[
              const SizedBox(height: 4),
              Text(
                '"$note"',
                style: CsTypography.body.copyWith(
                  color: AppColors.taupe,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
            if (showContactLine) ...[
              const SizedBox(height: 4),
              GestureDetector(
                onTap: onEmailTap,
                child: Text.rich(
                  TextSpan(
                    text: 'Questions about your claim? ',
                    style: CsTypography.metadata.copyWith(color: AppColors.taupe),
                    children: [
                      TextSpan(
                        text: 'claimedvenues@mantelier.app',
                        style: CsTypography.metadata.copyWith(
                          color: AppColors.forestGreen,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    ],
  ),
);

// Mirrors _VenueSubmissionContent's layout — same "reconstruct the row"
// approach as _venueClaimRow above, for the same reason (private widget,
// not reachable from outside its own file regardless of import).
Widget _venueSubmissionRow({
  required String description,
  required IconData icon,
  String? note,
}) => Padding(
  padding: const EdgeInsets.symmetric(vertical: 8),
  child: Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(icon, color: AppColors.forestGreen, size: 20),
      const SizedBox(width: 12),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              description,
              style: CsTypography.body.copyWith(color: AppColors.forestGreen),
            ),
            if (note != null) ...[
              const SizedBox(height: 4),
              Text(
                '"$note"',
                style: CsTypography.body.copyWith(
                  color: AppColors.taupe,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ],
        ),
      ),
    ],
  ),
);

Widget _wrap(Widget child) => MaterialApp(
  home: Scaffold(backgroundColor: AppColors.warmWhite, body: child),
);

void main() {
  group('NotificationsScreen — friend_request_received row', () {
    testWidgets('accept fires its own callback, not decline\'s', (
      tester,
    ) async {
      var accepted = false;
      var declined = false;
      await tester.pumpWidget(
        _wrap(
          _friendRequestReceivedRow(
            onAccept: () => accepted = true,
            onDecline: () => declined = true,
          ),
        ),
      );
      await tester.tap(find.text('Accept'));
      expect(accepted, isTrue);
      expect(declined, isFalse);
    });

    testWidgets('decline fires its own callback, not accept\'s', (
      tester,
    ) async {
      var accepted = false;
      var declined = false;
      await tester.pumpWidget(
        _wrap(
          _friendRequestReceivedRow(
            onAccept: () => accepted = true,
            onDecline: () => declined = true,
          ),
        ),
      );
      await tester.tap(find.text('Decline'));
      expect(declined, isTrue);
      expect(accepted, isFalse);
    });

    testWidgets('shows the unread dot when unread, hides it when read', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          _friendRequestReceivedRow(
            onAccept: () {},
            onDecline: () {},
            isRead: false,
          ),
        ),
      );
      expect(
        find.byWidgetPredicate(
          (w) => w is DecoratedBox && (w.decoration as BoxDecoration).color == AppColors.error,
        ),
        findsOneWidget,
      );

      await tester.pumpWidget(
        _wrap(
          _friendRequestReceivedRow(
            onAccept: () {},
            onDecline: () {},
            isRead: true,
          ),
        ),
      );
      expect(
        find.byWidgetPredicate(
          (w) => w is DecoratedBox && (w.decoration as BoxDecoration).color == AppColors.error,
        ),
        findsNothing,
      );
    });
  });

  group('NotificationsScreen — friend_request_accepted row', () {
    testWidgets('shows "Accepted", no Accept/Decline actions', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap(_friendRequestAcceptedRow()));
      expect(find.text('Accepted'), findsOneWidget);
      expect(find.text('Accept'), findsNothing);
      expect(find.text('Decline'), findsNothing);
    });

    testWidgets('tapping the row opens the other person\'s profile', (
      tester,
    ) async {
      var tapped = false;
      await tester.pumpWidget(
        _wrap(_friendRequestAcceptedRow(onTap: () => tapped = true)),
      );
      await tester.tap(find.text('Kylan'));
      expect(tapped, isTrue);
    });
  });

  group('NotificationsScreen — missing_listing_added row', () {
    testWidgets('renders the listing name and city, no actions', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(_missingListingAddedRow(name: 'Flore', city: 'Amsterdam')),
      );
      expect(
        find.textContaining('Flore in Amsterdam has been added.'),
        findsOneWidget,
      );
      expect(find.text('Accept'), findsNothing);
      expect(find.byIcon(Icons.storefront_outlined), findsOneWidget);
    });
  });

  group('NotificationsScreen — venue_claim rows', () {
    testWidgets('received (pending) row shows the "being reviewed" copy '
        'and the mailto contact line', (tester) async {
      await tester.pumpWidget(
        _wrap(
          _venueClaimRow(
            description: 'Your claim for Flore Amsterdam is being reviewed.',
            icon: Icons.hourglass_top_outlined,
            showContactLine: true,
          ),
        ),
      );
      expect(
        find.text('Your claim for Flore Amsterdam is being reviewed.'),
        findsOneWidget,
      );
      expect(find.textContaining('Questions about your claim?'), findsOneWidget);
      expect(find.textContaining('claimedvenues@mantelier.app'), findsOneWidget);
    });

    testWidgets('rejected (also covers blocked) row shows the "not '
        'approved" copy and the mailto contact line too', (tester) async {
      await tester.pumpWidget(
        _wrap(
          _venueClaimRow(
            description: 'Your claim for Flore Amsterdam was not approved.',
            icon: Icons.storefront_outlined,
            showContactLine: true,
          ),
        ),
      );
      expect(
        find.text('Your claim for Flore Amsterdam was not approved.'),
        findsOneWidget,
      );
      expect(find.textContaining('Questions about your claim?'), findsOneWidget);
    });

    testWidgets(
      "a rejected row also shows the reviewer's own reason — the rejection "
      'notification must carry why, not just that it happened, same '
      'requirement as the submission-review rows below',
      (tester) async {
        await tester.pumpWidget(
          _wrap(
            _venueClaimRow(
              description: 'Your claim for Flore Amsterdam was not approved.',
              icon: Icons.storefront_outlined,
              showContactLine: true,
              note: 'Could not verify ownership of this listing.',
            ),
          ),
        );
        expect(
          find.text('Your claim for Flore Amsterdam was not approved.'),
          findsOneWidget,
        );
        expect(
          find.text('"Could not verify ownership of this listing."'),
          findsOneWidget,
        );
      },
    );

    testWidgets('approved row shows the success copy but no contact line '
        '— nothing to ask once the claim has already succeeded', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          _venueClaimRow(
            description:
                'Your claim for Flore Amsterdam was approved — you can now manage its page.',
            icon: Icons.verified_outlined,
          ),
        ),
      );
      expect(
        find.textContaining('was approved — you can now manage its page.'),
        findsOneWidget,
      );
      expect(find.textContaining('Questions about your claim?'), findsNothing);
    });

    testWidgets('tapping the contact line fires its own callback', (
      tester,
    ) async {
      var tapped = false;
      await tester.pumpWidget(
        _wrap(
          _venueClaimRow(
            description: 'Your claim for Flore Amsterdam is being reviewed.',
            icon: Icons.hourglass_top_outlined,
            showContactLine: true,
            onEmailTap: () => tapped = true,
          ),
        ),
      );
      await tester.tap(find.textContaining('Questions about your claim?'));
      expect(tapped, isTrue);
    });
  });

  group('NotificationsScreen — venue_about/venue_photo submission-review rows', () {
    testWidgets('an approved row shows the "is now live" copy, no note', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          _venueSubmissionRow(
            description: 'Your about text for Flore is now live.',
            icon: Icons.verified_outlined,
          ),
        ),
      );
      expect(
        find.text('Your about text for Flore is now live.'),
        findsOneWidget,
      );
      expect(find.textContaining('"'), findsNothing);
    });

    testWidgets(
      "a rejected row shows the \"not approved\" copy AND the reviewer's "
      'own note — the rejection notification must carry the note, not '
      'just restate that something was rejected',
      (tester) async {
        await tester.pumpWidget(
          _wrap(
            _venueSubmissionRow(
              description: 'Your photo for Flore was not approved.',
              icon: Icons.storefront_outlined,
              note: 'Please use a landscape orientation photo.',
            ),
          ),
        );
        expect(
          find.text('Your photo for Flore was not approved.'),
          findsOneWidget,
        );
        expect(
          find.text('"Please use a landscape orientation photo."'),
          findsOneWidget,
        );
      },
    );
  });

  group('claimQuestionMailtoUri', () {
    test(
      'addresses the shared claims inbox and puts the venue name in the '
      'subject, so a reply is identifiable without asking what it\'s about',
      () {
        final uri = claimQuestionMailtoUri('Flore Amsterdam');
        expect(uri.scheme, 'mailto');
        expect(uri.path, 'claimedvenues@mantelier.app');
        expect(uri.queryParameters['subject'], 'Claim question — Flore Amsterdam');
      },
    );

    test('a different venue name produces a different subject, not a '
        'fixed/generic one', () {
      final uri = claimQuestionMailtoUri('Hôtel de la Paix');
      expect(uri.queryParameters['subject'], 'Claim question — Hôtel de la Paix');
    });

    test(
      'the encoded query string uses %20 for spaces, never the form-encoded '
      '"+" — a decoded-getter assertion alone would pass even with "+" in '
      'the wire form, since Uri.queryParameters decodes "+" back to a space',
      () {
        final uri = claimQuestionMailtoUri('Flore Amsterdam');
        expect(
          uri.query,
          'subject=Claim%20question%20%E2%80%94%20Flore%20Amsterdam',
        );
        expect(uri.query.contains('+'), isFalse);
      },
    );

    test(
      'the em dash is percent-encoded as its real UTF-8 bytes (%E2%80%94), '
      'never collapsed to a double hyphen',
      () {
        final uri = claimQuestionMailtoUri('Flore Amsterdam');
        expect(uri.query, contains('%E2%80%94'));
        expect(uri.query.contains('--'), isFalse);
      },
    );

    test(
      'a non-ASCII venue name is percent-encoded correctly, not mangled or '
      'stripped',
      () {
        final uri = claimQuestionMailtoUri('Hôtel de la Paix');
        expect(
          uri.query,
          'subject=Claim%20question%20%E2%80%94%20H%C3%B4tel%20de%20la%20Paix',
        );
      },
    );

    test(
      'the full mailto URI string round-trips through Uri.parse back to the '
      'exact original subject, proving a real mail client would decode it '
      'correctly rather than just this function\'s own Uri object',
      () {
        final uri = claimQuestionMailtoUri('Flore Amsterdam');
        final reparsed = Uri.parse(uri.toString());
        expect(
          reparsed.queryParameters['subject'],
          'Claim question — Flore Amsterdam',
        );
      },
    );
  });
}
