import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../theme/cs_typography.dart';

/// "AMSTERDAM · NL" — city + ISO country CODE, never a flag emoji. The
/// magazine pass's own country treatment: a flag renders inconsistently
/// across platforms/fonts and reads as decoration, where this pass wants
/// typography to carry every signal.
class CsCountryLabel extends StatelessWidget {
  final String cityName;
  final String countryCode;
  final TextStyle? style;
  final int maxLines;

  const CsCountryLabel({
    super.key,
    required this.cityName,
    required this.countryCode,
    this.style,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    final text = [
      cityName,
      countryCode.toUpperCase(),
    ].where((s) => s.isNotEmpty).join(' · ');
    return Text(
      text,
      maxLines: maxLines,
      overflow: TextOverflow.ellipsis,
      style: style ?? CsTypography.editorialBody,
    );
  }
}

/// A single hand-drawn line-icon key (bow + shaft + two teeth), gold,
/// stroked rather than filled — the magazine pass's own MICHELIN Key
/// glyph, standing in for the Material [Icons.vpn_key_rounded] glyph
/// [KeyRow] uses today wherever this pass wants a thinner, more
/// editorial mark. Purely decorative on its own (excluded from
/// semantics) — [CsEditorialKeyRow] carries the actual accessibility
/// label for a count of these.
class CsKeyGlyph extends StatelessWidget {
  final double size;
  final Color color;

  const CsKeyGlyph({super.key, this.size = 14, this.color = AppColors.gold600});

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _KeyGlyphPainter(color)),
    ),
  );
}

class _KeyGlyphPainter extends CustomPainter {
  final Color color;
  const _KeyGlyphPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    // A single tooth at the very tip, pointing down only — two teeth
    // near the middle of the shaft (the first version of this painter)
    // read as a stray "T" glyph at 14px rather than a key, confirmed via
    // this pass's own visual QA. One tooth at the end, clear of the
    // shaft, reads unambiguously as a key's bit even at small sizes.
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3
      ..strokeCap = StrokeCap.round;

    final bowRadius = size.width * 0.22;
    final bowCenter = Offset(bowRadius + size.width * 0.06, size.height / 2);
    canvas.drawCircle(bowCenter, bowRadius, paint);

    final shaftStart = Offset(bowCenter.dx + bowRadius, size.height / 2);
    final shaftEnd = Offset(size.width * 0.86, size.height / 2);
    canvas.drawLine(shaftStart, shaftEnd, paint);
    canvas.drawLine(
      shaftEnd,
      Offset(shaftEnd.dx, shaftEnd.dy + size.height * 0.26),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _KeyGlyphPainter oldDelegate) =>
      oldDelegate.color != color;
}

/// [count] repeated [CsKeyGlyph]s with the shared accessibility label
/// ("2 MICHELIN Keys") — the editorial-pass equivalent of [KeyRow].
class CsEditorialKeyRow extends StatelessWidget {
  final int count;
  final double size;

  const CsEditorialKeyRow({super.key, required this.count, this.size = 14});

  @override
  Widget build(BuildContext context) => Semantics(
    label: count == 1 ? '1 MICHELIN Key' : '$count MICHELIN Keys',
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < count; i++)
          Padding(
            padding: EdgeInsets.only(left: i == 0 ? 0 : 3),
            child: CsKeyGlyph(size: size),
          ),
      ],
    ),
  );
}

/// [count] gold Michelin stars with the shared accessibility label — the
/// editorial-pass equivalent of [StarRow], with the extra letter-spacing
/// the brief's "★ in goud met letter-spacing 2" calls for.
class CsEditorialStarRow extends StatelessWidget {
  final int count;
  final double size;

  const CsEditorialStarRow({super.key, required this.count, this.size = 14});

  @override
  Widget build(BuildContext context) => Semantics(
    label: count == 1 ? '1 Michelin star' : '$count Michelin stars',
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < count; i++)
          Padding(
            padding: EdgeInsets.only(left: i == 0 ? 0 : 2),
            child: Icon(Icons.star_rounded, size: size, color: AppColors.gold600),
          ),
      ],
    ),
  );
}
