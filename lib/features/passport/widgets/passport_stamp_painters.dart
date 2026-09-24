import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/passport_stamp_award.dart';
import '../utils/passport_stamp_style.dart' show StampVariant;
import '../utils/passport_stamp_text_fit.dart';

/// Each variant's own fixed footprint — the exact sizes from the design
/// spec (§ "The 5 stamp designs"). Used both to size the [CustomPaint]
/// each painter below is wrapped in and, by the page layout, to keep a
/// jittered stamp from falling off the page or covering its header.
Size stampVariantSize(StampVariant variant) => switch (variant) {
  StampVariant.roundSeal => const Size(
    RoundSealPainter.diameter,
    RoundSealPainter.diameter,
  ),
  StampVariant.doubleFrame => const Size(
    DoubleFramePainter.width,
    DoubleFramePainter.height,
  ),
  StampVariant.oval => const Size(OvalPainter.width, OvalPainter.height),
  StampVariant.octagon => const Size(
    OctagonPainter.diameter,
    OctagonPainter.diameter,
  ),
  StampVariant.postmark => const Size(
    PostmarkPainter.width,
    PostmarkPainter.height,
  ),
};

/// The [CustomPainter] for [variant], built from [data].
CustomPainter stampPainterFor(StampVariant variant, StampPaintData data) =>
    switch (variant) {
      StampVariant.roundSeal => RoundSealPainter(data),
      StampVariant.doubleFrame => DoubleFramePainter(data),
      StampVariant.oval => OvalPainter(data),
      StampVariant.octagon => OctagonPainter(data),
      StampVariant.postmark => PostmarkPainter(data),
    };

/// Everything one of the 5 stamp painters needs to draw itself — bundled
/// so each painter class takes one constructor argument instead of eight.
/// Value-equal (see [==]/[hashCode]) so each painter's `shouldRepaint` can
/// compare by value rather than always repainting.
class StampPaintData {
  final String seedId;
  final String cityName;
  final String countryCode;
  final String venueName;
  final DateTime date;
  final StampAward? award;
  final Color ink;

  const StampPaintData({
    required this.seedId,
    required this.cityName,
    required this.countryCode,
    required this.venueName,
    required this.date,
    required this.award,
    required this.ink,
  });

  @override
  bool operator ==(Object other) =>
      other is StampPaintData &&
      other.seedId == seedId &&
      other.cityName == cityName &&
      other.countryCode == countryCode &&
      other.venueName == venueName &&
      other.date == date &&
      other.ink == ink &&
      _awardEquals(other.award, award);

  static bool _awardEquals(StampAward? a, StampAward? b) => switch ((a, b)) {
    (null, null) => true,
    (StarsAward a, StarsAward b) => a.count == b.count,
    (KeysAward a, KeysAward b) => a.count == b.count,
    (EventTypeAward a, EventTypeAward b) => a.label == b.label,
    _ => false,
  };

  @override
  int get hashCode =>
      Object.hash(seedId, cityName, countryCode, venueName, date, ink);
}

const _months = [
  'JAN',
  'FEB',
  'MAR',
  'APR',
  'MAY',
  'JUN',
  'JUL',
  'AUG',
  'SEP',
  'OCT',
  'NOV',
  'DEC',
];

String _fullDateLabel(DateTime date) =>
    '${date.day} ${_months[date.month - 1]} ${date.year}';

// ── Shared drawing helpers ──────────────────────────────────────────────

/// Isolates [draw] in its own layer, composited back onto whatever is
/// already painted beneath (the ivory page) with [BlendMode.multiply] —
/// this alone is what makes a stamp read as pressed INTO the paper rather
/// than a flat opaque shape sitting on top of it. [draw] receives the ink
/// color already resolved to ~90% opacity; everything it paints (strokes,
/// fills, text) should use that color as-is. After [draw] returns, a
/// sparse, deterministically-seeded (from [seedId]) scatter of small
/// [BlendMode.dstOut] dots erodes 10-15% of the ink's own alpha at random
/// points — a cheap stand-in for a real grain/noise texture asset, using
/// only canvas primitives so no new dependency or bundled image is
/// needed.
void paintStampInk(
  Canvas canvas,
  Size size,
  Color ink,
  String seedId,
  void Function(Canvas canvas, Color inkColor) draw,
) {
  final bounds = Offset.zero & size;
  canvas.saveLayer(bounds, Paint()..blendMode = BlendMode.multiply);
  draw(canvas, ink.withValues(alpha: 0.9));
  _paintInkGrain(canvas, bounds, seedId);
  canvas.restore();
}

void _paintInkGrain(Canvas canvas, Rect bounds, String seedId) {
  final random = math.Random(seedId.hashCode);
  final paint = Paint()..blendMode = BlendMode.dstOut;
  final dotCount = ((bounds.width * bounds.height) * 0.02)
      .round()
      .clamp(50, 220);
  for (var i = 0; i < dotCount; i++) {
    final dx = bounds.left + random.nextDouble() * bounds.width;
    final dy = bounds.top + random.nextDouble() * bounds.height;
    final r = 0.4 + random.nextDouble() * 1.0;
    paint.color = Colors.white.withValues(
      alpha: 0.10 + random.nextDouble() * 0.05,
    );
    canvas.drawCircle(Offset(dx, dy), r, paint);
  }
}

/// Paints [icon]'s own glyph directly via [TextPainter] (its codepoint in
/// its own icon font) rather than drawing a hand-built [Path] — the same
/// glyph [KeyRow]/[StarRow] already render elsewhere in the app, so a Key
/// on a stamp matches a Key everywhere else pixel-for-pixel.
void drawIconGlyph(
  Canvas canvas,
  Offset center,
  IconData icon,
  double size,
  Color color,
) {
  final painter = TextPainter(
    text: TextSpan(
      text: String.fromCharCode(icon.codePoint),
      style: TextStyle(
        fontSize: size,
        fontFamily: icon.fontFamily,
        package: icon.fontPackage,
        color: color,
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout();
  painter.paint(canvas, center - Offset(painter.width / 2, painter.height / 2));
}

/// The award row shared by all 5 variants: Michelin stars, Keys, or an
/// event type label. Stars and Keys are both drawn via the same icon-font
/// codepoint technique ([drawIconGlyph]) — the same [Icons.star_rounded]/
/// [Icons.vpn_key_rounded] glyphs [StarRow]/[KeyRow] already render
/// elsewhere in the app, repeated per star/Key. Deliberately NOT a plain
/// Unicode '★' text glyph (the design spec's own literal wording): that
/// depends on whatever font the platform falls back to for symbol
/// characters, which is NOT guaranteed to include it — confirmed missing
/// (rendered as a tofu/missing-glyph box) under Flutter Web's CanvasKit
/// font fallback during this feature's own visual QA. The bundled
/// Material Icons font, by contrast, ships with the app on every target
/// platform, so this can't silently go missing the way a bare Unicode
/// character can. Draws nothing at all when [award] is null.
void _drawAward(
  Canvas canvas,
  Offset center,
  StampAward? award,
  Color ink, {
  double starFontSize = 14,
  double iconSize = 13,
  double eventFontSize = 10,
}) {
  if (award == null) return;
  switch (award) {
    case StarsAward(:final count):
      if (count <= 0) return;
      final totalWidth = starFontSize * count + 1.5 * (count - 1);
      var x = center.dx - totalWidth / 2 + starFontSize / 2;
      for (var i = 0; i < count; i++) {
        drawIconGlyph(
          canvas,
          Offset(x, center.dy),
          Icons.star_rounded,
          starFontSize,
          ink,
        );
        x += starFontSize + 1.5;
      }
    case KeysAward(:final count):
      if (count <= 0) return;
      final totalWidth = iconSize * count + 2.0 * (count - 1);
      var x = center.dx - totalWidth / 2 + iconSize / 2;
      for (var i = 0; i < count; i++) {
        drawIconGlyph(
          canvas,
          Offset(x, center.dy),
          Icons.vpn_key_rounded,
          iconSize,
          ink,
        );
        x += iconSize + 2.0;
      }
    case EventTypeAward(:final label):
      final painter = TextPainter(
        text: TextSpan(
          text: label,
          style: GoogleFonts.inter(
            color: ink,
            fontSize: eventFontSize,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.4,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      painter.paint(
        canvas,
        center - Offset(painter.width / 2, painter.height / 2),
      );
  }
}

/// Draws [text] character-by-character around a circle of [radius]
/// centered on [center], starting at [startAngle] (canvas convention: 0 =
/// right, π/2 = down, increasing clockwise) and sweeping clockwise. Each
/// character's own angular width is `measuredCharWidth / radius` — the
/// same derivation [fitRoundSealArcText] uses to decide how much text
/// fits in the first place, so the two stay exactly consistent.
///
/// Public (not `_drawArcText`): reused as-is by the Friend Profile
/// screen's own read-only stamp (see friend_profile_stamp.dart) — the
/// same ring-text technique, applied to that screen's own different
/// template (it includes a score, this one doesn't), so only the drawing
/// primitive is shared, not a whole painter class.
void drawArcText(
  Canvas canvas, {
  required String text,
  required TextStyle style,
  required Offset center,
  required double radius,
  required double startAngle,
}) {
  var angle = startAngle;
  for (final char in text.split('')) {
    final painter = TextPainter(
      text: TextSpan(text: char, style: style),
      textDirection: TextDirection.ltr,
    )..layout();
    final angularWidth = painter.width / radius;
    final charAngle = angle + angularWidth / 2;
    canvas.save();
    canvas.translate(
      center.dx + radius * math.cos(charAngle),
      center.dy + radius * math.sin(charAngle),
    );
    canvas.rotate(charAngle + math.pi / 2);
    painter.paint(canvas, Offset(-painter.width / 2, -painter.height / 2));
    canvas.restore();
    angle += angularWidth;
  }
}

// ── 1. Round seal ────────────────────────────────────────────────────────

/// 156pt circular seal: outer/inner concentric rings, `CITY · VENUE ·`
/// running around the band between them, stars + year in the centre.
class RoundSealPainter extends CustomPainter {
  final StampPaintData data;
  const RoundSealPainter(this.data);

  static const diameter = 156.0;

  @override
  void paint(Canvas canvas, Size size) {
    paintStampInk(canvas, size, data.ink, data.seedId, (canvas, ink) {
      final center = size.center(Offset.zero);
      final outerRadius = size.width / 2 - 3;

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
        43,
        Paint()
          ..color = ink
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1,
      );

      final labelStyle = GoogleFonts.inter(
        color: ink,
        fontSize: 9.6,
        letterSpacing: 2,
        fontWeight: FontWeight.w500,
      );
      final textRadius = (outerRadius + 43) / 2;
      const gapRadians = 20 * math.pi / 180;
      final sweep = 2 * math.pi - gapRadians;
      final startAngle = math.pi / 2 + gapRadians / 2;
      final arcText = fitRoundSealArcText(
        cityName: data.cityName,
        venueName: data.venueName,
        style: labelStyle,
        maxArcLength: textRadius * sweep,
      );
      drawArcText(
        canvas,
        text: arcText,
        style: labelStyle,
        center: center,
        radius: textRadius,
        startAngle: startAngle,
      );

      _drawAward(
        canvas,
        center - const Offset(0, 9),
        data.award,
        ink,
        starFontSize: 13,
        iconSize: 13,
        eventFontSize: 9,
      );

      final yearPainter = TextPainter(
        text: TextSpan(
          text: '${data.date.year}',
          style: GoogleFonts.cormorantGaramond(
            color: ink,
            fontSize: 17,
            fontStyle: FontStyle.italic,
            fontWeight: FontWeight.w600,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      yearPainter.paint(
        canvas,
        center + Offset(-yearPainter.width / 2, 8),
      );
    });
  }

  @override
  bool shouldRepaint(covariant RoundSealPainter oldDelegate) =>
      oldDelegate.data != data;
}

// ── 2. Double frame ──────────────────────────────────────────────────────

/// A rectangular stamp with a 3px double border: `CITY · CC` on top, the
/// venue name in large serif caps in the middle, the award row at the
/// bottom.
class DoubleFramePainter extends CustomPainter {
  final StampPaintData data;
  const DoubleFramePainter(this.data);

  static const width = 180.0;
  static const height = 112.0;

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
      final contentRect = inner.deflate(0).translate(0, 0);
      final maxWidth = contentRect.width - horizontalPadding * 2;
      final centerX = contentRect.center.dx;

      final topLabel = [
        data.cityName.toUpperCase(),
        data.countryCode.toUpperCase(),
      ].where((s) => s.isNotEmpty).join(' · ');
      final topStyle = GoogleFonts.inter(
        color: ink,
        fontSize: 8.5,
        letterSpacing: 1.2,
        fontWeight: FontWeight.w500,
      );
      final topPainter = TextPainter(
        text: TextSpan(text: topLabel, style: topStyle),
        textDirection: TextDirection.ltr,
        maxLines: 1,
        ellipsis: '…',
      )..layout(maxWidth: maxWidth);
      topPainter.paint(
        canvas,
        Offset(centerX - topPainter.width / 2, contentRect.top + verticalPadding),
      );

      final nameStyle = fitStampTextByShrinking(
        text: data.venueName.toUpperCase(),
        style: GoogleFonts.cormorantGaramond(
          color: ink,
          fontSize: 32,
          fontWeight: FontWeight.w600,
          letterSpacing: 2.56,
        ),
        maxWidth: maxWidth,
      );
      final namePainter = TextPainter(
        text: TextSpan(text: data.venueName.toUpperCase(), style: nameStyle),
        textDirection: TextDirection.ltr,
        maxLines: 1,
        ellipsis: '…',
        textAlign: TextAlign.center,
      )..layout(maxWidth: maxWidth);
      namePainter.paint(
        canvas,
        Offset(
          centerX - namePainter.width / 2,
          contentRect.center.dy - namePainter.height / 2,
        ),
      );

      _drawAward(
        canvas,
        Offset(centerX, contentRect.bottom - verticalPadding - 6),
        data.award,
        ink,
      );
    });
  }

  @override
  bool shouldRepaint(covariant DoubleFramePainter oldDelegate) =>
      oldDelegate.data != data;
}

// ── 3. Oval ───────────────────────────────────────────────────────────────

/// A 190×100 oval stamp: an outer + inset-6 inner oval border, `CITY ·
/// CC`, the venue name in italic serif, then the award row — all laid out
/// within a safely-inscribed rectangle so nothing crosses the oval's own
/// curve.
class OvalPainter extends CustomPainter {
  final StampPaintData data;
  const OvalPainter(this.data);

  static const width = 190.0;
  static const height = 100.0;

  @override
  void paint(Canvas canvas, Size size) {
    paintStampInk(canvas, size, data.ink, data.seedId, (canvas, ink) {
      final outer = (Offset.zero & size).deflate(1.5);
      final inner = outer.deflate(6);
      canvas.drawOval(
        outer,
        Paint()
          ..color = ink
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
      canvas.drawOval(
        inner,
        Paint()
          ..color = ink
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1,
      );

      final centerX = size.width / 2;
      final centerY = size.height / 2;
      // 0.78, not a tighter fraction: confirmed via this feature's own
      // visual QA that anything much narrower truncates even ordinary,
      // non-extreme names ("Le Bernardin") — the oval's own curve still
      // safely contains this width at the vertical positions text
      // actually occupies (top label / venue / award are all within the
      // oval's wider middle band, never near its pointed left/right
      // extremes).
      final maxWidth = size.width * 0.78;

      final topLabel = [
        data.cityName.toUpperCase(),
        data.countryCode.toUpperCase(),
      ].where((s) => s.isNotEmpty).join(' · ');
      final topStyle = GoogleFonts.inter(
        color: ink,
        fontSize: 8.5,
        letterSpacing: 1.2,
        fontWeight: FontWeight.w500,
      );
      final topPainter = TextPainter(
        text: TextSpan(text: topLabel, style: topStyle),
        textDirection: TextDirection.ltr,
        maxLines: 1,
        ellipsis: '…',
        textAlign: TextAlign.center,
      )..layout(maxWidth: maxWidth);
      topPainter.paint(
        canvas,
        Offset(centerX - topPainter.width / 2, centerY - 28),
      );

      final nameStyle = fitStampTextByShrinking(
        text: data.venueName,
        style: GoogleFonts.cormorantGaramond(
          color: ink,
          fontSize: 26,
          fontStyle: FontStyle.italic,
          fontWeight: FontWeight.w600,
        ),
        maxWidth: maxWidth,
      );
      final namePainter = TextPainter(
        text: TextSpan(text: data.venueName, style: nameStyle),
        textDirection: TextDirection.ltr,
        maxLines: 1,
        ellipsis: '…',
        textAlign: TextAlign.center,
      )..layout(maxWidth: maxWidth);
      namePainter.paint(
        canvas,
        Offset(centerX - namePainter.width / 2, centerY - namePainter.height / 2 + 2),
      );

      _drawAward(canvas, Offset(centerX, centerY + 28), data.award, ink);
    });
  }

  @override
  bool shouldRepaint(covariant OvalPainter oldDelegate) =>
      oldDelegate.data != data;
}

// ── 4. Octagon (customs style) ──────────────────────────────────────────

Path _octagonPath(Rect rect) {
  final s = math.min(rect.width, rect.height);
  final c = s / (2 + math.sqrt(2));
  final l = rect.left, t = rect.top, r = rect.left + s, b = rect.top + s;
  return Path()
    ..moveTo(l + c, t)
    ..lineTo(r - c, t)
    ..lineTo(r, t + c)
    ..lineTo(r, b - c)
    ..lineTo(r - c, b)
    ..lineTo(l + c, b)
    ..lineTo(l, b - c)
    ..lineTo(l, t + c)
    ..close();
}

/// A 130pt octagon, customs-stamp style: an outer + thin inset inner
/// octagon, a horizontal date bar across the middle, the venue name (up
/// to 2 lines) above it, the city below it.
class OctagonPainter extends CustomPainter {
  final StampPaintData data;
  const OctagonPainter(this.data);

  static const diameter = 130.0;

  @override
  void paint(Canvas canvas, Size size) {
    paintStampInk(canvas, size, data.ink, data.seedId, (canvas, ink) {
      final outerRect = (Offset.zero & size).deflate(3);
      canvas.drawPath(
        _octagonPath(outerRect),
        Paint()
          ..color = ink
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
      canvas.drawPath(
        _octagonPath(outerRect.deflate(7)),
        Paint()
          ..color = ink
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.8,
      );

      final centerX = size.width / 2;
      final centerY = size.height / 2;
      final maxWidth = size.width * 0.62;

      const barHalfHeight = 9.0;
      final barPaint = Paint()
        ..color = ink
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1;
      final barLeft = centerX - maxWidth / 2;
      final barRight = centerX + maxWidth / 2;
      canvas.drawLine(
        Offset(barLeft, centerY - barHalfHeight),
        Offset(barRight, centerY - barHalfHeight),
        barPaint,
      );
      canvas.drawLine(
        Offset(barLeft, centerY + barHalfHeight),
        Offset(barRight, centerY + barHalfHeight),
        barPaint,
      );

      final datePainter = TextPainter(
        text: TextSpan(
          text: _fullDateLabel(data.date),
          style: GoogleFonts.inter(
            color: ink,
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.6,
          ),
        ),
        textDirection: TextDirection.ltr,
        maxLines: 1,
        ellipsis: '…',
        textAlign: TextAlign.center,
      )..layout(maxWidth: maxWidth);
      datePainter.paint(
        canvas,
        Offset(centerX - datePainter.width / 2, centerY - datePainter.height / 2),
      );

      final nameStyle = fitStampTextByShrinking(
        text: data.venueName,
        style: GoogleFonts.cormorantGaramond(
          color: ink,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
        maxWidth: maxWidth,
        maxLines: 2,
      );
      final namePainter = TextPainter(
        text: TextSpan(text: data.venueName, style: nameStyle),
        textDirection: TextDirection.ltr,
        maxLines: 2,
        ellipsis: '…',
        textAlign: TextAlign.center,
      )..layout(maxWidth: maxWidth);
      namePainter.paint(
        canvas,
        Offset(
          centerX - namePainter.width / 2,
          centerY - barHalfHeight - 4 - namePainter.height,
        ),
      );

      final cityPainter = TextPainter(
        text: TextSpan(
          text: data.cityName.toUpperCase(),
          style: GoogleFonts.inter(
            color: ink,
            fontSize: 9,
            letterSpacing: 1.2,
            fontWeight: FontWeight.w500,
          ),
        ),
        textDirection: TextDirection.ltr,
        maxLines: 1,
        ellipsis: '…',
        textAlign: TextAlign.center,
      )..layout(maxWidth: maxWidth);
      cityPainter.paint(
        canvas,
        Offset(centerX - cityPainter.width / 2, centerY + barHalfHeight + 4),
      );
    });
  }

  @override
  bool shouldRepaint(covariant OctagonPainter oldDelegate) =>
      oldDelegate.data != data;
}

// ── 5. Postmark ──────────────────────────────────────────────────────────

/// Plain-text arc truncation (no `CITY · VENUE ·` framing, unlike
/// [fitRoundSealArcText]) — used by the postmark's city arc, which is
/// just the city name on its own.
String _fitPlainArcText(String text, TextStyle style, double maxArcLength) {
  double width(String t) =>
      (TextPainter(text: TextSpan(text: t, style: style), textDirection: TextDirection.ltr)
            ..layout())
          .width;
  if (width(text) <= maxArcLength) return text;
  var truncated = text;
  while (truncated.isNotEmpty) {
    truncated = truncated.substring(0, truncated.length - 1);
    final candidate = '$truncated…';
    if (width(candidate) <= maxArcLength) return candidate;
  }
  return '…';
}

void _drawWavyLines(Canvas canvas, Rect area, int count, Paint paint) {
  final spacing = area.height / (count + 1);
  for (var i = 1; i <= count; i++) {
    final y = area.top + spacing * i;
    final path = Path()..moveTo(area.left, y);
    const amplitude = 3.6;
    const periods = 2.6;
    const steps = 36;
    for (var s = 1; s <= steps; s++) {
      final t = s / steps;
      final x = area.left + area.width * t;
      final yy = y + amplitude * math.sin(t * periods * 2 * math.pi);
      path.lineTo(x, yy);
    }
    canvas.drawPath(path, paint);
  }
}

/// A 150×110 postmark: a circle on the left (r=44) with the city on an
/// arc and the date in its centre, and 4-5 wavy cancellation lines to its
/// right with the venue name set in italic serif over them.
class PostmarkPainter extends CustomPainter {
  final StampPaintData data;
  const PostmarkPainter(this.data);

  static const width = 150.0;
  static const height = 110.0;

  @override
  void paint(Canvas canvas, Size size) {
    paintStampInk(canvas, size, data.ink, data.seedId, (canvas, ink) {
      const circleRadius = 44.0;
      final circleCenter = Offset(circleRadius + 6, size.height / 2);
      canvas.drawCircle(
        circleCenter,
        circleRadius,
        Paint()
          ..color = ink
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );

      final cityStyle = GoogleFonts.inter(
        color: ink,
        fontSize: 8,
        letterSpacing: 1.6,
        fontWeight: FontWeight.w500,
      );
      const gapRadians = 40 * math.pi / 180;
      final sweep = math.pi - gapRadians;
      final startAngle = math.pi + gapRadians / 2;
      final cityText = _fitPlainArcText(
        data.cityName.toUpperCase(),
        cityStyle,
        (circleRadius - 10) * sweep,
      );
      drawArcText(
        canvas,
        text: cityText,
        style: cityStyle,
        center: circleCenter,
        radius: circleRadius - 10,
        startAngle: startAngle,
      );

      final datePainter = TextPainter(
        text: TextSpan(
          text: '${data.date.day} ${_months[data.date.month - 1]}\n${data.date.year}',
          style: GoogleFonts.inter(
            color: ink,
            fontSize: 9,
            fontWeight: FontWeight.w600,
            height: 1.3,
          ),
        ),
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.center,
      )..layout(maxWidth: circleRadius * 1.3);
      datePainter.paint(
        canvas,
        circleCenter - Offset(datePainter.width / 2, datePainter.height / 2),
      );

      final wavesArea = Rect.fromLTRB(
        circleCenter.dx + circleRadius + 10,
        size.height * 0.18,
        size.width - 4,
        size.height * 0.82,
      );
      _drawWavyLines(
        canvas,
        wavesArea,
        5,
        Paint()
          ..color = ink
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2,
      );

      final nameStyle = fitStampTextByShrinking(
        text: data.venueName,
        style: GoogleFonts.cormorantGaramond(
          color: ink,
          fontSize: 17,
          fontStyle: FontStyle.italic,
          fontWeight: FontWeight.w600,
        ),
        maxWidth: wavesArea.width - 4,
      );
      final namePainter = TextPainter(
        text: TextSpan(text: data.venueName, style: nameStyle),
        textDirection: TextDirection.ltr,
        maxLines: 1,
        ellipsis: '…',
        textAlign: TextAlign.center,
      )..layout(maxWidth: wavesArea.width - 4);
      namePainter.paint(
        canvas,
        Offset(
          wavesArea.center.dx - namePainter.width / 2,
          wavesArea.center.dy - namePainter.height / 2,
        ),
      );
    });
  }

  @override
  bool shouldRepaint(covariant PostmarkPainter oldDelegate) =>
      oldDelegate.data != data;
}
