import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/app_colors.dart';
import '../../passport/models/passport_stamp_award.dart';
import '../../passport/widgets/passport_stamp_painters.dart'
    show drawArcText, drawIconGlyph, paintStampInk;

/// The friend-profile passport's own two stamp designs — deliberately a
/// SMALLER, separate set from the main Passport's five (see
/// passport_stamp_painters.dart): this screen's stamps carry a score the
/// main ones don't, and the design brief specifies its own exact sizes/
/// content, not a reuse of `RoundSealPainter`/`DoubleFramePainter` as-is.
/// What IS reused directly: the hard-won rendering techniques ([paintStampInk]'s
/// multiply-blend-plus-grain "pressed into paper" effect, [drawArcText]'s
/// character-by-character ring text, [drawIconGlyph]'s icon-font star/Key
/// glyphs) — importing three small, already-public, already-shipped
/// functions from the Passport feature, not duplicating them a second
/// time.
enum FriendStampVariant { roundSeal, doubleFrame }

/// The two inks a friend-profile stamp can be printed in — dark gold or
/// green, both already-defined editorial-pass tokens (see
/// [AppColors.accent700]/[AppColors.green600]), not new colors.
enum FriendStampInk {
  deepGold(AppColors.accent700),
  green(AppColors.green600);

  final Color color;
  const FriendStampInk(this.color);
}

/// Small, local, self-contained stable hash — same FNV-1a algorithm as
/// passport_stamp_style.dart's `stampStableHash`, deliberately duplicated
/// rather than imported: cs_friends_stack.dart already established this
/// exact precedent (a generic, few-line pure function is cheaper to
/// duplicate than to relocate into a shared module for a task that wasn't
/// asked to do that relocation).
int _stableHash(String input) {
  const fnvPrime = 0x01000193;
  var hash = 0x811c9dc5;
  for (final unit in input.codeUnits) {
    hash ^= unit;
    hash = (hash * fnvPrime) & 0xFFFFFFFF;
  }
  return hash;
}

FriendStampVariant pickFriendStampVariant(String id, {FriendStampVariant? avoid}) {
  final values = FriendStampVariant.values;
  final index = _stableHash('$id:variant') % values.length;
  final variant = values[index];
  if (avoid != null && variant == avoid) {
    return values[(index + 1) % values.length];
  }
  return variant;
}

FriendStampInk pickFriendStampInk(String id, {FriendStampInk? avoid}) {
  final values = FriendStampInk.values;
  final index = _stableHash('$id:ink') % values.length;
  final ink = values[index];
  if (avoid != null && ink == avoid) {
    return values[(index + 1) % values.length];
  }
  return ink;
}

/// Degrees in [-10, 8], deterministic per [id].
double pickFriendStampRotation(String id) {
  final t = (_stableHash('$id:rotation') % 10000) / 10000;
  return -10 + t * 18;
}

const _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

String _dateLabel(DateTime date) =>
    '${date.day} ${_months[date.month - 1]} ${date.year}';
String _shortDateLabel(DateTime date) =>
    '${date.day} ${_months[date.month - 1].toUpperCase()}';

double _measure(String text, TextStyle style) => (TextPainter(
  text: TextSpan(text: text, style: style),
  textDirection: TextDirection.ltr,
)..layout()).width;

/// "AMSTERDAM · NL · FLORE · 8/10 ·" — the round seal's own ring text.
/// Only the venue name is ever shortened (with `…`); city/country/score
/// stay intact, mirroring `fitRoundSealArcText`'s own "never touch
/// anything but the venue name" rule from the main Passport stamps.
String fitFriendArcText({
  required String cityName,
  required String countryCode,
  required String venueName,
  required int? score,
  required TextStyle style,
  required double maxArcLength,
}) {
  final city = cityName.toUpperCase();
  final lc = countryCode.toUpperCase();
  final scoreText = score != null ? '$score/10' : null;

  String build(String? venue) {
    final parts = [
      city,
      lc,
      if (venue != null && venue.isNotEmpty) venue.toUpperCase(),
      ?scoreText,
    ];
    return '${parts.join(' · ')} ·';
  }

  final full = build(venueName);
  if (_measure(full, style) <= maxArcLength) return full;

  var truncated = venueName;
  while (truncated.isNotEmpty) {
    truncated = truncated.substring(0, truncated.length - 1);
    final candidate = build('$truncated…');
    if (_measure(candidate, style) <= maxArcLength) return candidate;
  }
  return build(null);
}

/// Everything one of the two friend-profile stamp painters needs.
class FriendStampPaintData {
  final String seedId;
  final String cityName;
  final String countryCode;
  final String venueName;
  final DateTime date;
  final int? score;
  final StampAward? award;
  final Color ink;

  const FriendStampPaintData({
    required this.seedId,
    required this.cityName,
    required this.countryCode,
    required this.venueName,
    required this.date,
    required this.score,
    required this.award,
    required this.ink,
  });
}

void _drawAward(
  Canvas canvas,
  Offset center,
  StampAward? award,
  Color ink, {
  double starSize = 12,
  double iconSize = 12,
}) {
  if (award == null) return;
  switch (award) {
    case StarsAward(:final count):
      if (count <= 0) return;
      final totalWidth = starSize * count + 1.5 * (count - 1);
      var x = center.dx - totalWidth / 2 + starSize / 2;
      for (var i = 0; i < count; i++) {
        drawIconGlyph(canvas, Offset(x, center.dy), Icons.star_rounded, starSize, ink);
        x += starSize + 1.5;
      }
    case KeysAward(:final count):
      if (count <= 0) return;
      final totalWidth = iconSize * count + 2.0 * (count - 1);
      var x = center.dx - totalWidth / 2 + iconSize / 2;
      for (var i = 0; i < count; i++) {
        drawIconGlyph(canvas, Offset(x, center.dy), Icons.vpn_key_rounded, iconSize, ink);
        x += iconSize + 2.0;
      }
    case EventTypeAward():
      // Friend-profile visits are restaurants/hotels only — no event
      // stamps on this screen.
      return;
  }
}

/// 140pt round seal: `CITY · LC · VENUE · SCORE ·` running around the
/// ring, stars/Keys centred, the visit date in italic serif below them.
class FriendRoundSealPainter extends CustomPainter {
  final FriendStampPaintData data;
  const FriendRoundSealPainter(this.data);

  static const diameter = 140.0;

  @override
  void paint(Canvas canvas, Size size) {
    paintStampInk(canvas, size, data.ink, data.seedId, (canvas, ink) {
      final center = size.center(Offset.zero);
      final outerRadius = size.width / 2 - 3;
      const innerRadius = 38.0;

      canvas.drawCircle(
        center,
        outerRadius,
        Paint()
          ..color = ink
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.2,
      );
      canvas.drawCircle(
        center,
        innerRadius,
        Paint()
          ..color = ink
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1,
      );

      final ringStyle = GoogleFonts.inter(
        color: ink,
        fontSize: 10.5,
        letterSpacing: 2.4,
        fontWeight: FontWeight.w500,
      );
      final textRadius = (outerRadius + innerRadius) / 2;
      const gapRadians = 20 * math.pi / 180;
      final sweep = 2 * math.pi - gapRadians;
      final startAngle = math.pi / 2 + gapRadians / 2;
      final ringText = fitFriendArcText(
        cityName: data.cityName,
        countryCode: data.countryCode,
        venueName: data.venueName,
        score: data.score,
        style: ringStyle,
        maxArcLength: textRadius * sweep,
      );
      drawArcText(
        canvas,
        text: ringText,
        style: ringStyle,
        center: center,
        radius: textRadius,
        startAngle: startAngle,
      );

      _drawAward(canvas, center - const Offset(0, 8), data.award, ink);

      final datePainter = TextPainter(
        text: TextSpan(
          text: _dateLabel(data.date),
          style: GoogleFonts.cormorantGaramond(
            color: ink,
            fontSize: 16,
            fontStyle: FontStyle.italic,
            fontWeight: FontWeight.w600,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: innerRadius * 1.7);
      datePainter.paint(
        canvas,
        center + Offset(-datePainter.width / 2, 8),
      );
    });
  }

  @override
  bool shouldRepaint(covariant FriendRoundSealPainter oldDelegate) => true;
}

/// A 170×120 double-frame stamp: `CITY · LC` on top, the venue in large
/// serif caps in the middle, stars/Keys, then `DD MMM · SCORE/10` at the
/// bottom.
class FriendDoubleFramePainter extends CustomPainter {
  final FriendStampPaintData data;
  const FriendDoubleFramePainter(this.data);

  static const width = 170.0;
  static const height = 120.0;

  @override
  void paint(Canvas canvas, Size size) {
    paintStampInk(canvas, size, data.ink, data.seedId, (canvas, ink) {
      final outer = (Offset.zero & size).deflate(3);
      final inner = outer.deflate(5);
      final framePaint = Paint()
        ..color = ink
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3;
      canvas.drawRect(outer, framePaint);
      canvas.drawRect(inner, framePaint..strokeWidth = 1.4);

      const horizontalPadding = 16.0;
      const verticalPadding = 10.0;
      final maxWidth = inner.width - horizontalPadding * 2;
      final centerX = inner.center.dx;

      final topLabel = [
        data.cityName.toUpperCase(),
        data.countryCode.toUpperCase(),
      ].where((s) => s.isNotEmpty).join(' · ');
      final topPainter = TextPainter(
        text: TextSpan(
          text: topLabel,
          style: GoogleFonts.inter(
            color: ink,
            fontSize: 8.5,
            letterSpacing: 1.2,
            fontWeight: FontWeight.w500,
          ),
        ),
        textDirection: TextDirection.ltr,
        maxLines: 1,
        ellipsis: '…',
      )..layout(maxWidth: maxWidth);
      topPainter.paint(
        canvas,
        Offset(centerX - topPainter.width / 2, inner.top + verticalPadding),
      );

      var nameSize = 30.0;
      final nameText = data.venueName.toUpperCase();
      TextPainter layoutName(double size) => TextPainter(
        text: TextSpan(
          text: nameText,
          style: GoogleFonts.cormorantGaramond(
            color: ink,
            fontSize: size,
            fontWeight: FontWeight.w600,
            letterSpacing: size * 0.08,
          ),
        ),
        textDirection: TextDirection.ltr,
        maxLines: 1,
        ellipsis: '…',
        textAlign: TextAlign.center,
      )..layout(maxWidth: maxWidth);
      var namePainter = layoutName(nameSize);
      while (namePainter.didExceedMaxLines && nameSize > 30 * 0.85) {
        nameSize -= 0.3;
        namePainter = layoutName(nameSize);
      }
      namePainter.paint(
        canvas,
        Offset(centerX - namePainter.width / 2, inner.center.dy - namePainter.height / 2 - 6),
      );

      _drawAward(
        canvas,
        Offset(centerX, inner.center.dy + namePainter.height / 2 + 6),
        data.award,
        ink,
        starSize: 11,
        iconSize: 11,
      );

      final bottomText = data.score != null
          ? '${_shortDateLabel(data.date)} · ${data.score}/10'
          : _shortDateLabel(data.date);
      final bottomPainter = TextPainter(
        text: TextSpan(
          text: bottomText,
          style: GoogleFonts.inter(
            color: ink,
            fontSize: 8,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.6,
          ),
        ),
        textDirection: TextDirection.ltr,
        maxLines: 1,
        ellipsis: '…',
      )..layout(maxWidth: maxWidth);
      bottomPainter.paint(
        canvas,
        Offset(centerX - bottomPainter.width / 2, inner.bottom - verticalPadding - bottomPainter.height),
      );
    });
  }

  @override
  bool shouldRepaint(covariant FriendDoubleFramePainter oldDelegate) => true;
}

Size friendStampVariantSize(FriendStampVariant variant) => switch (variant) {
  FriendStampVariant.roundSeal => const Size(
    FriendRoundSealPainter.diameter,
    FriendRoundSealPainter.diameter,
  ),
  FriendStampVariant.doubleFrame => const Size(
    FriendDoubleFramePainter.width,
    FriendDoubleFramePainter.height,
  ),
};

CustomPainter friendStampPainterFor(
  FriendStampVariant variant,
  FriendStampPaintData data,
) => switch (variant) {
  FriendStampVariant.roundSeal => FriendRoundSealPainter(data),
  FriendStampVariant.doubleFrame => FriendDoubleFramePainter(data),
};

/// One read-only stamp: picks its painter, applies its deterministic
/// rotation, and carries the accessibility label — no tap/entrance-
/// animation of its own (this is someone else's already-settled history,
/// not a "just stamped" moment); the ENCLOSING venue row/card owns the
/// actual tap-to-open-detail behaviour, matching how a real stamp on a
/// page isn't itself a button, the page turn is.
class FriendProfileStamp extends StatelessWidget {
  final FriendStampPaintData data;
  final FriendStampVariant variant;
  final double rotationDegrees;
  final String semanticLabel;

  const FriendProfileStamp({
    super.key,
    required this.data,
    required this.variant,
    required this.rotationDegrees,
    required this.semanticLabel,
  });

  @override
  Widget build(BuildContext context) {
    final size = friendStampVariantSize(variant);
    return Semantics(
      label: semanticLabel,
      child: Transform.rotate(
        angle: rotationDegrees * math.pi / 180,
        child: ExcludeSemantics(
          child: SizedBox.fromSize(
            size: size,
            child: RepaintBoundary(
              child: CustomPaint(painter: friendStampPainterFor(variant, data)),
            ),
          ),
        ),
      ),
    );
  }
}
