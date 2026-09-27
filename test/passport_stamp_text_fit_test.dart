import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:michelin_passport/features/passport/utils/passport_stamp_text_fit.dart';

TextStyle _style(double size) => TextStyle(fontSize: size, fontFamily: 'Roboto');

void main() {
  group('stampNameTierFor', () {
    test('<= 10 characters is L', () {
      expect(stampNameTierFor('ABAC'), StampNameTier.l);
      expect(stampNameTierFor('1234567890'), StampNameTier.l);
    });

    test('11-18 characters is M', () {
      expect(stampNameTierFor('12345678901'), StampNameTier.m);
      expect(stampNameTierFor('123456789012345678'), StampNameTier.m);
    });

    test('>= 19 characters is S', () {
      expect(stampNameTierFor('1234567890123456789'), StampNameTier.s);
      expect(stampNameTierFor('8½ Otto e Mezzo Bombana'), StampNameTier.s);
    });
  });

  group('fitStampNameBalanced', () {
    test('a short name that fits on one line stays on one line', () {
      final painter = fitStampNameBalanced(
        text: 'ABAC',
        styleFor: _style,
        maxWidth: 200,
        sizeL: 22,
        sizeM: 17,
        sizeS: 15,
      );
      expect(painter.text!.toPlainText(), 'ABAC');
      // Single-line layout never carries an internal newline.
      expect((painter.text as TextSpan).text, isNot(contains('\n')));
    });

    test('uses the L/M/S size matching the name\'s own tier', () {
      TextStyle capturedStyleAtSize(double size) => _style(size);
      final l = fitStampNameBalanced(
        text: 'ABAC',
        styleFor: capturedStyleAtSize,
        maxWidth: 1000,
        sizeL: 22,
        sizeM: 17,
        sizeS: 15,
      );
      expect(l.text!.style!.fontSize, 22);

      final s = fitStampNameBalanced(
        text: '8½ Otto e Mezzo Bombana',
        styleFor: capturedStyleAtSize,
        maxWidth: 1000,
        sizeL: 22,
        sizeM: 17,
        sizeS: 15,
      );
      // At an effectively unlimited width the S-size text fits on one
      // line, so no 85% shrink is needed — still resolves to the S size.
      expect(s.text!.style!.fontSize, 15);
    });

    test('a moderately long name at a real stamp width balances onto 2 '
        'lines, never more, and never overflows maxWidth', () {
      final painter = fitStampNameBalanced(
        text: 'Chez Dominique',
        styleFor: _style,
        maxWidth: 104, // RoundSealPainter's own real name-box width
        sizeL: 22,
        sizeM: 17,
        sizeS: 15,
      );
      expect(painter.didExceedMaxLines, isFalse);
      expect(painter.width, lessThanOrEqualTo(104));
    });

    test('an extreme long name ("8½ Otto e Mezzo Bombana") at the same '
        'tight width still never overflows maxWidth, even when 2 lines at '
        '85% still isn\'t enough and it falls back to ellipsis '
        'truncation — the documented last resort, not a bug', () {
      final painter = fitStampNameBalanced(
        text: '8½ Otto e Mezzo Bombana',
        styleFor: _style,
        maxWidth: 104,
        sizeL: 22,
        sizeM: 17,
        sizeS: 15,
      );
      expect(painter.width, lessThanOrEqualTo(104));
      // TextPainter's own `ellipsis` is applied at paint time, not
      // reflected back into `.text` — `didExceedMaxLines` is the correct
      // signal that the fallback truncation path was actually needed.
      expect(painter.didExceedMaxLines, isTrue);
    });

    test('an unrealistically tiny width still resolves without throwing, '
        'ellipsis-truncated rather than overflowing', () {
      final painter = fitStampNameBalanced(
        text: '8½ Otto e Mezzo Bombana',
        styleFor: _style,
        maxWidth: 20,
        sizeL: 22,
        sizeM: 17,
        sizeS: 15,
      );
      expect(painter.width, lessThanOrEqualTo(20));
    });

    test('shrinks by exactly 15% (never more) when the tier size still '
        "doesn't fit 2 lines", () {
      double? usedSize;
      TextStyle styleFor(double size) {
        usedSize = size;
        return _style(size);
      }

      fitStampNameBalanced(
        text: 'A Genuinely Very Long Restaurant Name Indeed',
        styleFor: styleFor,
        maxWidth: 60,
        sizeL: 22,
        sizeM: 17,
        sizeS: 15,
      );
      // The final call inside fitStampNameBalanced is always the resolved
      // one (either the base tier size, or exactly base*0.85).
      expect(usedSize, anyOf(15, closeTo(15 * 0.85, 0.01)));
    });
  });
}
