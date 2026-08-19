// Covers buildTelUri — Restaurant Enrichment Step 1D's tel: URI builder.
// Strips a stored, human-readable phone number down to a machine-safe
// tel: URI, preserving a leading international '+' prefix.

import 'package:flutter_test/flutter_test.dart';
import 'package:michelin_passport/core/utils/phone_utils.dart';

void main() {
  group('buildTelUri', () {
    test('strips spaces and parentheses, keeps the leading + prefix', () {
      final uri = buildTelUri('+31 (0)10 436 07 66');
      // '+' then every digit in order, with the "(0)" national trunk
      // prefix dropped entirely (not dialed internationally): 31, 10,
      // 436, 07, 66. Confirmed against a physical device: dialing
      // tel:+31104360766 successfully reached Parkheuvel from Spain.
      expect(uri.toString(), 'tel:+31104360766');
    });

    test('a "(0)" trunk prefix is dropped anywhere it appears, not just '
        'for this one number', () {
      final uri = buildTelUri('+49 (0)89 12345678');
      expect(uri.toString(), 'tel:+498912345678');
    });

    test('a real area code in parens (not a bare "0") is kept, not '
        'mistaken for trunk notation', () {
      final uri = buildTelUri('+1 (212) 555-1234');
      expect(uri.toString(), 'tel:+12125551234');
    });

    test('a plain international number with no formatting round-trips '
        'unchanged', () {
      final uri = buildTelUri('+31104360766');
      expect(uri.toString(), 'tel:+31104360766');
    });

    test('a domestic number with no + prefix keeps only its digits', () {
      final uri = buildTelUri('010 436 07 66');
      expect(uri.toString(), 'tel:0104360766');
    });

    test('a + that appears anywhere other than the first character is '
        'dropped, not treated as a second prefix', () {
      final uri = buildTelUri('010 436+07 66');
      expect(uri.toString(), 'tel:0104360766');
    });

    test('hyphens and dots are stripped like any other non-digit', () {
      final uri = buildTelUri('+31-10-436.07.66');
      expect(uri.toString(), 'tel:+31104360766');
    });

    test('empty string returns null — nothing safe to dial', () {
      expect(buildTelUri(''), isNull);
    });

    test('a string with no digits at all (only formatting) returns null', () {
      expect(buildTelUri('   -- ()'), isNull);
    });

    test('a bare "+" with no digits returns null', () {
      expect(buildTelUri('+'), isNull);
    });
  });
}
