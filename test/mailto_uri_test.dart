// Covers mailtoUri directly — the one place this app's mailto encoding
// is meant to live, extracted from notifications_screen.dart's own
// claimQuestionMailtoUri (see that file's own doc comment) once a second
// call site (VenueManagementScreen's contact line) needed the same
// construction. claimQuestionMailtoUri/venueQuestionMailtoUri each keep
// their own thin tests for their own email/subject text; this is the
// encoding mechanics itself, tested once.

import 'package:flutter_test/flutter_test.dart';
import 'package:michelin_passport/core/utils/mailto_uri.dart';

void main() {
  group('mailtoUri', () {
    test('builds a plain mailto: URI addressing the given email', () {
      final uri = mailtoUri('someone@example.com', subject: 'Hello');
      expect(uri.scheme, 'mailto');
      expect(uri.path, 'someone@example.com');
      expect(uri.queryParameters['subject'], 'Hello');
    });

    test('the encoded query string uses %20 for spaces, never the '
        'form-encoded "+" — a decoded-getter assertion alone would pass '
        'even with "+" in the wire form, since Uri.queryParameters '
        'decodes "+" back to a space', () {
      final uri = mailtoUri('someone@example.com', subject: 'a b c');
      expect(uri.query, 'subject=a%20b%20c');
      expect(uri.query, isNot(contains('+')));
    });

    test('a non-ASCII character is percent-encoded as its real UTF-8 '
        'bytes, never mangled or stripped', () {
      final uri = mailtoUri('someone@example.com', subject: 'Café — noté');
      expect(uri.query, contains('%C3%A9')); // é
      expect(uri.query, contains('%E2%80%94')); // em dash
      expect(uri.queryParameters['subject'], 'Café — noté');
    });

    test('the full URI string round-trips through Uri.parse back to the '
        'exact original subject, proving a real mail client would decode '
        'it correctly', () {
      final uri = mailtoUri('someone@example.com', subject: 'A — B');
      final parsed = Uri.parse(uri.toString());
      expect(parsed.queryParameters['subject'], 'A — B');
    });
  });
}
