import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/app_colors.dart';
import '../models/passport_stamp_award.dart';
import '../utils/passport_stamp_style.dart' show StampVariant;
import '../utils/passport_stamp_text_fit.dart';

/// Each variant's own fixed footprint — the exact sizes from the September
/// 2026 stamp redesign brief (all 5 designs got physically bigger than the
/// original round). Used both to size the [CustomPaint] each painter below
/// is wrapped in and, by the page layout, to keep a jittered stamp from
/// falling off the page or covering its header — see passport_page.dart.
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

/// The verified-venue stamp's own fixed footprint (156pt ring + the
/// overlapping 184pt nameplate + the 40pt seal poking past the ring's
/// right edge) — see [VerifiedVenueStampPainter]. Used instead of
/// [stampVariantSize] whenever [PassportStampItem.verified] is true,
/// regardless of which of the 5 ordinary variants would otherwise have
/// been picked for that visit.
const verifiedStampSize = Size(210, 220);

/// The [CustomPainter] for [variant], built from [data].
CustomPainter stampPainterFor(StampVariant variant, StampPaintData data) =>
    switch (variant) {
      StampVariant.roundSeal => RoundSealPainter(data),
      StampVariant.doubleFrame => DoubleFramePainter(data),
      StampVariant.oval => OvalPainter(data),
      StampVariant.octagon => OctagonPainter(data),
      StampVariant.postmark => PostmarkPainter(data),
    };

/// Everything one of the 5 stamp painters (or [VerifiedVenueStampPainter])
/// needs to draw itself — bundled so each painter class takes one
/// constructor argument instead of eight. Value-equal (see [==]/
/// [hashCode]) so each painter's `shouldRepaint` can compare by value
/// rather than always repainting.
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

/// "12 MAR 2026" — the shared date-slot format every design uses (see the
/// brief's own SLOTS section), except the postmark's own day-big/month-
/// year-below split treatment. Month names are the same fixed English
/// abbreviations this file already used before this redesign — "de maand
/// in de locale van de gebruiker" is NOT implemented: this app has no
/// localization infrastructure at all yet (no `flutter_localizations`, no
/// `supportedLocales`, confirmed by grep — it is English-only today), and
/// standing one up is far outside "pas alleen de stempels aan." Disclosed
/// here rather than silently ignored or worked around with a new
/// dependency (`intl` isn't part of this project either).
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

/// The distinction/award slot shared by all 5 variants (plus the verified
/// stamp's own nameplate): Michelin stars, Keys, or (for an event stamp,
/// a pragmatic extension the brief's own restaurant/hotel-focused test
/// matrix doesn't cover but this app's event stamps still need) the event
/// type label. Per the brief's SLOTS section, a venue with neither stars
/// nor Keys shows NO distinction row at all — that's [award] being null,
/// which every caller already treats as "omit this piece from the stack"
/// (see [_StackPiece] usage below) rather than painting an empty gap.
/// Stars and Keys are both drawn via the same icon-font codepoint
/// technique ([drawIconGlyph]) — the same [Icons.star_rounded]/
/// [Icons.vpn_key_rounded] glyphs [StarRow]/[KeyRow] already render
/// elsewhere in the app. Deliberately NOT a plain Unicode '★' text glyph:
/// confirmed missing (a tofu/missing-glyph box) under Flutter Web's
/// CanvasKit font fallback during this feature's own visual QA. Draws
/// nothing at all when [award] is null.
void _drawAward(
  Canvas canvas,
  Offset center,
  StampAward? award,
  Color ink, {
  double starFontSize = 15,
  double iconSize = 14,
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

/// One piece of a vertical stack: its own height, and how to paint itself
/// given the y-coordinate of its own top edge.
typedef _StackPiece = ({double height, void Function(double top) paint});

/// Lays out [pieces] as a vertical stack centered as a WHOLE GROUP on
/// [centerY] — the shared mechanism behind every variant's "a venue with
/// neither stars nor Keys shows no distinction row, and the rest shifts
/// together" requirement: callers simply never add a piece for an absent
/// slot, so the total stack height (and therefore where the group's
/// center-line falls) already reflects only what's actually present, with
/// [gap] between each pair of pieces that IS present.
void _paintCenteredStack(
  Canvas canvas,
  List<_StackPiece> pieces,
  double centerY,
  double gap,
) {
  if (pieces.isEmpty) return;
  final total =
      pieces.fold<double>(0, (sum, p) => sum + p.height) +
      gap * (pieces.length - 1);
  var top = centerY - total / 2;
  for (final piece in pieces) {
    piece.paint(top);
    top += piece.height + gap;
  }
}

// `textAlign: TextAlign.center` deliberately omitted: every caller already
// centers the result manually via `_paintCentered` (using the painter's
// own measured `.width`, not the box it was laid out in), so the
// TextPainter's own alignment is redundant — and, paired with an
// unbounded `layout(maxWidth: double.infinity)` for a caller that omits
// [maxWidth] (every date/day/month-year label below), it isn't just
// redundant but a real crash: the engine's internal centering math over
// an infinite width threw a `dart:ui` assertion, caught only by actually
// running these tests, not by analyze.
TextPainter _plainText(String text, TextStyle style, {double? maxWidth}) {
  final painter = TextPainter(
    text: TextSpan(text: text, style: style),
    textDirection: TextDirection.ltr,
    maxLines: 1,
    ellipsis: maxWidth == null ? null : '…',
  );
  painter.layout(maxWidth: maxWidth ?? double.infinity);
  return painter;
}

void _paintCentered(Canvas canvas, TextPainter painter, double centerX, double top) {
  painter.paint(canvas, Offset(centerX - painter.width / 2, top));
}

/// Plain-text arc truncation — used by every arc label in this file (a
/// city name, "VERIFIED VISIT · MANTELIER", a date): shrink-free, just
/// truncate with an ellipsis once the label doesn't fit [maxArcLength] at
/// [style].
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

/// Draws [text] character-by-character around a circle of [radius]
/// centered on [center], starting at [startAngle] (canvas convention: 0 =
/// right, π/2 = down, increasing clockwise) and sweeping clockwise. Each
/// character's own angular width is `measuredCharWidth / radius`.
///
/// [upsideDown] (default false, so every existing caller is unaffected):
/// the `charAngle + π/2` rotation below only reads right-side-up for an
/// arc across the TOP of the circle (confirmed — that's every pre-existing
/// caller, including [drawArcText]'s own reuse by the Friend Profile
/// screen's read-only stamp). Applied to an arc across the BOTTOM instead
/// (this redesign's own date arcs on [RoundSealPainter]/
/// [VerifiedVenueStampPainter]), the same rotation renders each glyph
/// upside down — caught only by actually screenshotting the round seal,
/// not by analyze/tests. Passing true both flips that rotation by π AND
/// walks [text] in reverse, so the first character of the string still
/// ends up on the LEFT: for a bottom arc, increasing angle moves right
/// to left (the mirror image of the top arc's left-to-right sweep), so
/// preserving the original left-to-right reading order requires placing
/// the string's characters in reverse along that same increasing-angle
/// direction.
void drawArcText(
  Canvas canvas, {
  required String text,
  required TextStyle style,
  required Offset center,
  required double radius,
  required double startAngle,
  bool upsideDown = false,
}) {
  final chars = upsideDown ? text.split('').reversed : text.split('');
  var angle = startAngle;
  for (final char in chars) {
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
    canvas.rotate(charAngle + (upsideDown ? -math.pi / 2 : math.pi / 2));
    painter.paint(canvas, Offset(-painter.width / 2, -painter.height / 2));
    canvas.restore();
    angle += angularWidth;
  }
}

/// [drawArcText], but centered within [sweep] radians starting at
/// [sweepStart] rather than left-justified from it — every arc label in
/// this redesign (city, date, "VERIFIED VISIT · MANTELIER") reads better
/// centered in its own half-ring than jammed against one end of it.
void _drawCenteredArcText(
  Canvas canvas, {
  required String text,
  required TextStyle style,
  required Offset center,
  required double radius,
  required double sweepStart,
  required double sweep,
  bool upsideDown = false,
}) {
  final measured = (TextPainter(
    text: TextSpan(text: text, style: style),
    textDirection: TextDirection.ltr,
  )..layout()).width;
  final actualAngular = measured / radius;
  final leftover = (sweep - actualAngular).clamp(0.0, sweep);
  drawArcText(
    canvas,
    text: text,
    style: style,
    center: center,
    radius: radius,
    startAngle: sweepStart + leftover / 2,
    upsideDown: upsideDown,
  );
}

// ── 1. Round seal ────────────────────────────────────────────────────────

/// 176pt circular seal: an outer (r85) and inner (r60) ring, the city on
/// the upper arc and the date on the lower arc (never the venue name — no
/// design in this redesign puts a name on an arc), two small dots marking
/// 9/3 o'clock where the two arcs meet, and — inside the inner ring — the
/// distinction row above the venue name, both centered as a group.
class RoundSealPainter extends CustomPainter {
  final StampPaintData data;
  const RoundSealPainter(this.data);

  static const diameter = 176.0;
  static const _outerRadius = 85.0;
  static const _innerRadius = 60.0;
  static const _nameMaxWidth = 104.0;

  @override
  void paint(Canvas canvas, Size size) {
    paintStampInk(canvas, size, data.ink, data.seedId, (canvas, ink) {
      final center = size.center(Offset.zero);

      canvas.drawCircle(
        center,
        _outerRadius,
        Paint()
          ..color = ink
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.2,
      );
      canvas.drawCircle(
        center,
        _innerRadius,
        Paint()
          ..color = ink
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1,
      );

      final textRadius = (_outerRadius + _innerRadius) / 2;
      const dotGap = 12 * math.pi / 180;
      final halfSweep = math.pi - 2 * dotGap;

      final arcStyle = GoogleFonts.inter(
        color: ink,
        fontSize: 10.5,
        letterSpacing: 2.4,
        fontWeight: FontWeight.w600,
      );
      final maxArc = textRadius * halfSweep;
      _drawCenteredArcText(
        canvas,
        text: _fitPlainArcText(data.cityName.toUpperCase(), arcStyle, maxArc),
        style: arcStyle,
        center: center,
        radius: textRadius,
        sweepStart: math.pi + dotGap,
        sweep: halfSweep,
      );
      _drawCenteredArcText(
        canvas,
        text: _fitPlainArcText(_fullDateLabel(data.date), arcStyle, maxArc),
        style: arcStyle,
        center: center,
        radius: textRadius,
        sweepStart: dotGap,
        sweep: halfSweep,
        upsideDown: true, // this arc runs along the BOTTOM of the ring
      );

      // The two dots marking where the arcs meet, at 9 and 3 o'clock.
      final dotPaint = Paint()..color = ink;
      canvas.drawCircle(center + Offset(-textRadius, 0), 2.2, dotPaint);
      canvas.drawCircle(center + Offset(textRadius, 0), 2.2, dotPaint);

      final namePainter = fitStampNameBalanced(
        text: data.venueName,
        styleFor: (fontSize) => GoogleFonts.cormorantGaramond(
          color: ink,
          fontSize: fontSize,
          fontWeight: FontWeight.w600,
        ),
        maxWidth: _nameMaxWidth,
        sizeL: 22,
        sizeM: 17,
        sizeS: 15,
      );

      final pieces = <_StackPiece>[
        if (data.award != null)
          (
            height: 15,
            paint: (top) => _drawAward(canvas, Offset(center.dx, top + 7.5), data.award, ink),
          ),
        (
          height: namePainter.height,
          paint: (top) => _paintCentered(canvas, namePainter, center.dx, top),
        ),
      ];
      _paintCenteredStack(canvas, pieces, center.dy, 6);
    });
  }

  @override
  bool shouldRepaint(covariant RoundSealPainter oldDelegate) =>
      oldDelegate.data != data;
}

// ── 2. Double frame ──────────────────────────────────────────────────────

/// A 196×140 stamp with a 3px double border: city, venue name, the
/// distinction row, a short hairline, then the date — all centered as one
/// group inside the frame ("alles gecentreerd").
class DoubleFramePainter extends CustomPainter {
  final StampPaintData data;
  const DoubleFramePainter(this.data);

  static const width = 196.0;
  static const height = 140.0;

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

      const horizontalPadding = 12.0;
      final maxWidth = inner.width - horizontalPadding * 2;
      final centerX = inner.center.dx;

      final cityPainter = _plainText(
        [
          data.cityName.toUpperCase(),
          data.countryCode.toUpperCase(),
        ].where((s) => s.isNotEmpty).join(' · '),
        GoogleFonts.inter(
          color: ink,
          fontSize: 8.5,
          letterSpacing: 1.2,
          fontWeight: FontWeight.w500,
        ),
        maxWidth: maxWidth,
      );

      final namePainter = fitStampNameBalanced(
        text: data.venueName.toUpperCase(),
        styleFor: (fontSize) => GoogleFonts.cormorantGaramond(
          color: ink,
          fontSize: fontSize,
          fontWeight: FontWeight.w600,
          letterSpacing: fontSize * 0.06,
        ),
        maxWidth: maxWidth,
        sizeL: 30,
        sizeM: 21,
        sizeS: 15,
      );

      final datePainter = _plainText(
        _fullDateLabel(data.date),
        GoogleFonts.cormorantGaramond(
          color: ink,
          fontSize: 13,
          fontStyle: FontStyle.italic,
          fontWeight: FontWeight.w600,
        ),
      );

      final pieces = <_StackPiece>[
        (
          height: cityPainter.height,
          paint: (top) => _paintCentered(canvas, cityPainter, centerX, top),
        ),
        (
          height: namePainter.height,
          paint: (top) => _paintCentered(canvas, namePainter, centerX, top),
        ),
        if (data.award != null)
          (
            height: 15,
            paint: (top) => _drawAward(canvas, Offset(centerX, top + 7.5), data.award, ink),
          ),
        (
          height: 1,
          paint: (top) => canvas.drawLine(
            Offset(centerX - 20, top),
            Offset(centerX + 20, top),
            Paint()
              ..color = ink
              ..strokeWidth = 1,
          ),
        ),
        (
          height: datePainter.height,
          paint: (top) => _paintCentered(canvas, datePainter, centerX, top),
        ),
      ];
      _paintCenteredStack(canvas, pieces, inner.center.dy, 8);
    });
  }

  @override
  bool shouldRepaint(covariant DoubleFramePainter oldDelegate) =>
      oldDelegate.data != data;
}

// ── 3. Oval ───────────────────────────────────────────────────────────────

/// A 228×132 oval stamp: an outer + inset-6 inner oval border, then city,
/// venue name (italic serif), distinction and date, all centered as one
/// group and horizontally constrained to the brief's own literal 32pt
/// horizontal padding.
class OvalPainter extends CustomPainter {
  final StampPaintData data;
  const OvalPainter(this.data);

  static const width = 228.0;
  static const height = 132.0;

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
      const horizontalPadding = 32.0;
      final maxWidth = size.width - horizontalPadding * 2;

      final cityPainter = _plainText(
        [
          data.cityName.toUpperCase(),
          data.countryCode.toUpperCase(),
        ].where((s) => s.isNotEmpty).join(' · '),
        GoogleFonts.inter(
          color: ink,
          fontSize: 8.5,
          letterSpacing: 1.2,
          fontWeight: FontWeight.w500,
        ),
        maxWidth: maxWidth,
      );

      final namePainter = fitStampNameBalanced(
        text: data.venueName,
        styleFor: (fontSize) => GoogleFonts.cormorantGaramond(
          color: ink,
          fontSize: fontSize,
          fontStyle: FontStyle.italic,
          fontWeight: FontWeight.w600,
        ),
        maxWidth: maxWidth,
        sizeL: 28,
        sizeM: 20,
        sizeS: 17,
      );

      final datePainter = _plainText(
        _fullDateLabel(data.date),
        GoogleFonts.cormorantGaramond(
          color: ink,
          fontSize: 11,
          fontStyle: FontStyle.italic,
          fontWeight: FontWeight.w600,
        ),
      );

      final pieces = <_StackPiece>[
        (
          height: cityPainter.height,
          paint: (top) => _paintCentered(canvas, cityPainter, centerX, top),
        ),
        (
          height: namePainter.height,
          paint: (top) => _paintCentered(canvas, namePainter, centerX, top),
        ),
        if (data.award != null)
          (
            height: 14,
            paint: (top) => _drawAward(canvas, Offset(centerX, top + 7), data.award, ink),
          ),
        (
          height: datePainter.height,
          paint: (top) => _paintCentered(canvas, datePainter, centerX, top),
        ),
      ];
      _paintCenteredStack(canvas, pieces, size.height / 2, 6);
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

/// A 176pt octagon, customs-stamp style: the distinction row, the venue
/// name, the date set in paper-colored text on a solid ink bar, and the
/// city — all centered as one group.
class OctagonPainter extends CustomPainter {
  final StampPaintData data;
  const OctagonPainter(this.data);

  static const diameter = 176.0;
  static const _nameMaxWidth = 132.0;

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
        _octagonPath(outerRect.deflate(9)),
        Paint()
          ..color = ink
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.8,
      );

      final centerX = size.width / 2;

      final namePainter = fitStampNameBalanced(
        text: data.venueName,
        styleFor: (fontSize) => GoogleFonts.cormorantGaramond(
          color: ink,
          fontSize: fontSize,
          fontWeight: FontWeight.w600,
        ),
        maxWidth: _nameMaxWidth,
        sizeL: 22,
        sizeM: 17,
        sizeS: 14,
      );

      final cityPainter = _plainText(
        data.cityName.toUpperCase(),
        GoogleFonts.inter(
          color: ink,
          fontSize: 9,
          letterSpacing: 1.2,
          fontWeight: FontWeight.w500,
        ),
        maxWidth: _nameMaxWidth,
      );

      final dateLabel = _fullDateLabel(data.date);
      final datePainter = _plainText(
        dateLabel,
        GoogleFonts.inter(
          color: AppColors.background,
          fontSize: 10,
          fontWeight: FontWeight.w600,
          letterSpacing: 2,
        ),
        maxWidth: _nameMaxWidth - 12,
      );
      const barHeight = 20.0;
      const barWidth = _nameMaxWidth;

      final pieces = <_StackPiece>[
        if (data.award != null)
          (
            height: 14,
            paint: (top) => _drawAward(canvas, Offset(centerX, top + 7), data.award, ink),
          ),
        (
          height: namePainter.height,
          paint: (top) => _paintCentered(canvas, namePainter, centerX, top),
        ),
        (
          height: barHeight,
          paint: (top) {
            final barRect = Rect.fromCenter(
              center: Offset(centerX, top + barHeight / 2),
              width: barWidth,
              height: barHeight,
            );
            canvas.drawRect(barRect, Paint()..color = ink);
            _paintCentered(
              canvas,
              datePainter,
              centerX,
              barRect.center.dy - datePainter.height / 2,
            );
          },
        ),
        (
          height: cityPainter.height,
          paint: (top) => _paintCentered(canvas, cityPainter, centerX, top),
        ),
      ];
      _paintCenteredStack(canvas, pieces, size.height / 2, 8);
    });
  }

  @override
  bool shouldRepaint(covariant OctagonPainter oldDelegate) =>
      oldDelegate.data != data;
}

// ── 5. Postmark ──────────────────────────────────────────────────────────

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

/// A 252×128 postmark: a 108pt circle on the left with the city on an arc
/// and the day/month-year in its centre, and exactly 3 wavy cancellation
/// lines to its right with the venue name (italic) and the distinction row
/// set over them, centered as a group.
class PostmarkPainter extends CustomPainter {
  final StampPaintData data;
  const PostmarkPainter(this.data);

  static const width = 252.0;
  static const height = 128.0;

  @override
  void paint(Canvas canvas, Size size) {
    paintStampInk(canvas, size, data.ink, data.seedId, (canvas, ink) {
      const circleRadius = 54.0;
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
        (circleRadius - 12) * sweep,
      );
      _drawCenteredArcText(
        canvas,
        text: cityText,
        style: cityStyle,
        center: circleCenter,
        radius: circleRadius - 12,
        sweepStart: startAngle,
        sweep: sweep,
      );

      final dayPainter = _plainText(
        '${data.date.day}',
        GoogleFonts.cormorantGaramond(
          color: ink,
          fontSize: 26,
          fontWeight: FontWeight.w600,
        ),
      );
      final monthYearPainter = _plainText(
        '${_months[data.date.month - 1]} ${data.date.year}',
        GoogleFonts.inter(color: ink, fontSize: 9, fontWeight: FontWeight.w600),
      );
      dayPainter.paint(
        canvas,
        circleCenter -
            Offset(dayPainter.width / 2, dayPainter.height / 2 + monthYearPainter.height / 2),
      );
      monthYearPainter.paint(
        canvas,
        Offset(
          circleCenter.dx - monthYearPainter.width / 2,
          circleCenter.dy + dayPainter.height / 2 - monthYearPainter.height / 2,
        ),
      );

      final rightArea = Rect.fromLTRB(
        circleCenter.dx + circleRadius + 12,
        10,
        size.width - 8,
        size.height - 10,
      );
      _drawWavyLines(
        canvas,
        rightArea,
        3,
        Paint()
          ..color = ink
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2,
      );

      final namePainter = fitStampNameBalanced(
        text: data.venueName,
        styleFor: (fontSize) => GoogleFonts.cormorantGaramond(
          color: ink,
          fontSize: fontSize,
          fontStyle: FontStyle.italic,
          fontWeight: FontWeight.w600,
        ),
        maxWidth: rightArea.width - 4,
        sizeL: 24,
        sizeM: 19,
        sizeS: 16,
      );

      final pieces = <_StackPiece>[
        (
          height: namePainter.height,
          paint: (top) => _paintCentered(canvas, namePainter, rightArea.center.dx, top),
        ),
        if (data.award != null)
          (
            height: 14,
            paint: (top) =>
                _drawAward(canvas, Offset(rightArea.center.dx, top + 7), data.award, ink),
          ),
      ];
      _paintCenteredStack(canvas, pieces, rightArea.center.dy, 6);
    });
  }

  @override
  bool shouldRepaint(covariant PostmarkPainter oldDelegate) =>
      oldDelegate.data != data;
}

// ── Verified venue stamp ─────────────────────────────────────────────────

/// The compound design for a venue-confirmed visit (see [StampPaintData]'s
/// own doc + `models/passport_stamp_item.dart`'s `verified` fields): a
/// 156pt ring (outer VERIFIED VISIT · MANTELIER arc, lower date arc) that
/// Mantelier — not the venue — always controls, overlapped by a 184pt
/// double-bordered nameplate, plus a fixed 40pt ink-green verified seal
/// poking half past the ring's right edge. The venue's own artwork (an SVG
/// tinted to this stamp's ink) is composited separately, as a plain widget
/// layered on top by [PassportStampWidget] — a [CustomPainter] can't await
/// the artwork's own (possibly network) load, so this painter only ever
/// draws the ring/nameplate/seal chrome around wherever that artwork will
/// sit, never the artwork itself.
class VerifiedVenueStampPainter extends CustomPainter {
  final StampPaintData data;
  const VerifiedVenueStampPainter(this.data);

  static const _ringOuterRadius = 78.0;
  static const _ringInnerRadius = 55.0;
  static const _nameplateWidth = 184.0;
  static const _nameplateHeight = 60.0;
  static const _sealRadius = 20.0;

  /// The artwork's own safe circle — [PassportStampWidget] centers its SVG
  /// overlay on this exact rect, so painter and overlay never drift apart.
  static Rect artworkRect(Size size) {
    final ringCenter = Offset(size.width / 2, 4 + _ringOuterRadius);
    const artworkDiameter = 100.0;
    return Rect.fromCenter(
      center: ringCenter,
      width: artworkDiameter,
      height: artworkDiameter,
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    final ringCenter = Offset(size.width / 2, 4 + _ringOuterRadius);
    paintStampInk(canvas, size, data.ink, data.seedId, (canvas, ink) {
      canvas.drawCircle(
        ringCenter,
        _ringOuterRadius,
        Paint()
          ..color = ink
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.2,
      );
      canvas.drawCircle(
        ringCenter,
        _ringInnerRadius,
        Paint()
          ..color = ink
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1,
      );

      final textRadius = (_ringOuterRadius + _ringInnerRadius) / 2;
      const dotGap = 10 * math.pi / 180;
      final halfSweep = math.pi - 2 * dotGap;
      final arcStyle = GoogleFonts.inter(
        color: ink,
        fontSize: 8.5,
        letterSpacing: 1.4,
        fontWeight: FontWeight.w600,
      );
      _drawCenteredArcText(
        canvas,
        text: 'VERIFIED VISIT · MANTELIER',
        style: arcStyle,
        center: ringCenter,
        radius: textRadius,
        sweepStart: math.pi + dotGap,
        sweep: halfSweep,
      );
      _drawCenteredArcText(
        canvas,
        text: _fullDateLabel(data.date),
        style: arcStyle,
        center: ringCenter,
        radius: textRadius,
        sweepStart: dotGap,
        sweep: halfSweep,
        upsideDown: true, // this arc runs along the BOTTOM of the ring
      );

      // "Licht overlappend" — a light 4pt overlap into the ring's lower
      // edge, not the 20pt this first read like: the date arc's own text
      // sits right at the ring's bottom (textRadius + half its own text
      // height ≈ 71.5pt below ringCenter), so anything deeper than a few
      // points here cuts straight through it — confirmed by an actual
      // screenshot, not assumed safe from the numbers alone.
      final nameplateRect = Rect.fromLTWH(
        ringCenter.dx - _nameplateWidth / 2,
        ringCenter.dy + _ringOuterRadius - 4,
        _nameplateWidth,
        _nameplateHeight,
      );
      final npOuter = nameplateRect.deflate(1.5);
      final npInner = npOuter.deflate(4);
      final npPaint = Paint()
        ..color = ink
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3;
      canvas.drawRect(npOuter, npPaint);
      canvas.drawRect(npInner, npPaint..strokeWidth = 1);

      final npMaxWidth = npInner.width - 16;
      final namePainter = fitStampNameBalanced(
        text: data.venueName,
        styleFor: (fontSize) => GoogleFonts.cormorantGaramond(
          color: ink,
          fontSize: fontSize,
          fontWeight: FontWeight.w600,
        ),
        maxWidth: npMaxWidth,
        sizeL: 20,
        sizeM: 16,
        sizeS: 13,
      );
      final pieces = <_StackPiece>[
        (
          height: namePainter.height,
          paint: (top) => _paintCentered(canvas, namePainter, npInner.center.dx, top),
        ),
        if (data.award != null)
          (
            height: 13,
            paint: (top) =>
                _drawAward(canvas, Offset(npInner.center.dx, top + 6.5), data.award, ink,
                    starFontSize: 12, iconSize: 12, eventFontSize: 9),
          ),
      ];
      _paintCenteredStack(canvas, pieces, npInner.center.dy, 4);
    });

    // The verified seal is a fixed ink-green badge, drawn OUTSIDE the
    // multiply-ink layer above so it always reads as its own clean green,
    // never tinted by whichever ink this particular stamp was assigned —
    // "in ink-green" is called out in the brief as a fixed override, not
    // something the deterministic per-stamp ink pick touches.
    final sealCenter = ringCenter + const Offset(_ringOuterRadius, 0);
    canvas.drawCircle(
      sealCenter,
      _sealRadius,
      Paint()..color = AppColors.stampInkGreen,
    );
    canvas.drawCircle(
      sealCenter,
      _sealRadius - 5,
      Paint()
        ..color = AppColors.background
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
    drawIconGlyph(canvas, sealCenter, Icons.check_rounded, 18, AppColors.background);
  }

  @override
  bool shouldRepaint(covariant VerifiedVenueStampPainter oldDelegate) =>
      oldDelegate.data != data;
}
