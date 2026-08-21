// Events V2 Step 6 UX correction — covers followSnackMessage
// (lib/data/repositories/follow_repository.dart), the shared pure
// function all three Detail screens (Restaurant/Hotel/Private Chef) call
// to build their post-write success snackbar text.
//
// RestaurantDetailScreen/HotelDetailScreen/PrivateChefDetailScreen are all
// Supabase-eager (repositories constructed in field initializers), so —
// matching this codebase's established limitation for every such screen —
// this file cannot pump the real screens to prove the snackbar fires only
// after a successful write, only on failure, or is skipped on a
// busy-ignored tap. That is proven by code inspection instead: in all
// three screens, `_showSnack(followSnackMessage(...))` sits inside the
// `try` block, strictly after the awaited repository write and its
// `setState`, and the `catch` block calls only the existing
// error-snackbar path — never this function. The `if (_followBusy) return;`
// guard at the top of each `_toggleFollow` exits before any snackbar call
// of either kind. This file protects the one thing that IS network-free
// and directly testable: the exact message text for every input.

import 'package:flutter_test/flutter_test.dart';
import 'package:michelin_passport/data/repositories/follow_repository.dart';

void main() {
  group('followSnackMessage — Restaurant', () {
    test('follow success -> "Following {name}"', () {
      expect(
        followSnackMessage(wasFollowing: false, entityName: 'Parkheuvel'),
        'Following Parkheuvel',
      );
    });

    test('unfollow success -> "Unfollowed {name}"', () {
      expect(
        followSnackMessage(wasFollowing: true, entityName: 'Parkheuvel'),
        'Unfollowed Parkheuvel',
      );
    });
  });

  group('followSnackMessage — Hotel (same shared function, same '
      'behavior)', () {
    test('follow success -> "Following {name}"', () {
      expect(
        followSnackMessage(
          wasFollowing: false,
          entityName: 'Hotel Okura Amsterdam',
        ),
        'Following Hotel Okura Amsterdam',
      );
    });

    test('unfollow success -> "Unfollowed {name}"', () {
      expect(
        followSnackMessage(
          wasFollowing: true,
          entityName: 'Hotel Okura Amsterdam',
        ),
        'Unfollowed Hotel Okura Amsterdam',
      );
    });
  });

  group('followSnackMessage — Private Chef (same shared function, same '
      'behavior)', () {
    test('follow success -> "Following {name}"', () {
      expect(
        followSnackMessage(wasFollowing: false, entityName: 'Lucas de Jager'),
        'Following Lucas de Jager',
      );
    });

    test('unfollow success -> "Unfollowed {name}"', () {
      expect(
        followSnackMessage(wasFollowing: true, entityName: 'Lucas de Jager'),
        'Unfollowed Lucas de Jager',
      );
    });
  });

  group('followSnackMessage — general', () {
    test('never says "Unfollow" (imperative) for the follow-success case, '
        'only "Following" (past/present confirmation)', () {
      final message = followSnackMessage(
        wasFollowing: false,
        entityName: 'Test Venue',
      );
      expect(message, isNot(contains('Unfollow')));
      expect(message, startsWith('Following'));
    });

    test('never says "Following" for the unfollow-success case', () {
      final message = followSnackMessage(
        wasFollowing: true,
        entityName: 'Test Venue',
      );
      expect(message, isNot(startsWith('Following')));
      expect(message, startsWith('Unfollowed'));
    });
  });
}
