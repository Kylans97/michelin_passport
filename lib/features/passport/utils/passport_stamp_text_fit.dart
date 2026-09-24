import 'package:flutter/material.dart';

/// Shrinks [style]'s font size by up to 15%, in ~1% steps, until [text]
/// fits within [maxWidth] at [maxLines] line(s) — "shrink the font by up
/// to 15%, and only then truncate" (every stamp variant except the round
/// seal's arc text, which has its own fitting in [fitRoundSealArcText]).
///
/// Deliberately does NOT perform the truncation itself: manually cutting
/// a [String] with `substring` risks splitting a UTF-16 surrogate pair or
/// combining-mark cluster mid-character. The caller instead paints [text]
/// at the RETURNED style using a `TextPainter(maxLines: ..., ellipsis:
/// '…')` — Flutter's own text layout performs that final truncation
/// correctly, which is also why this function's contract is "never lets
/// text spill outside" even though it returns a style, not a shortened
/// string: whatever doesn't fit at the smallest allowed size is still
/// guaranteed to be truncated, just one layer up from here.
TextStyle fitStampTextByShrinking({
  required String text,
  required TextStyle style,
  required double maxWidth,
  int maxLines = 1,
}) {
  bool overflows(TextStyle candidate) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: candidate),
      textDirection: TextDirection.ltr,
      maxLines: maxLines,
    )..layout(maxWidth: maxWidth);
    return painter.didExceedMaxLines;
  }

  if (!overflows(style)) return style;

  final originalSize = style.fontSize ?? 14;
  final minSize = originalSize * 0.85;
  var size = originalSize;
  var resolved = style;
  while (size > minSize) {
    size -= originalSize * 0.01;
    resolved = style.copyWith(fontSize: size);
    if (!overflows(resolved)) break;
  }
  return resolved;
}

double _measureWidth(String text, TextStyle style) {
  final painter = TextPainter(
    text: TextSpan(text: text, style: style),
    textDirection: TextDirection.ltr,
  )..layout();
  return painter.width;
}

/// The round seal's own fitting rule (distinct from every other variant):
/// "measure the arc length and shorten the venue name with `…` if `CITY ·
/// VENUE ·` doesn't fit" — never shrinks the font here, only truncates
/// [venueName].
///
/// [maxArcLength] must already be `radius * allowedSweepRadians` — the
/// straight-line width measured here is exactly equal to the arc length
/// the text will occupy when drawn, because
/// passport_stamp_painters.dart's `_drawArcText` derives each character's
/// own angular step from that same character's measured width divided by
/// the radius; matching total straight-line width to the allowed arc
/// length is therefore exact, not an approximation.
String fitRoundSealArcText({
  required String cityName,
  required String venueName,
  required TextStyle style,
  required double maxArcLength,
}) {
  final city = cityName.toUpperCase();
  final venue = venueName.toUpperCase();
  final full = venue.isEmpty ? '$city ·' : '$city · $venue ·';
  if (_measureWidth(full, style) <= maxArcLength) return full;

  var truncated = venue;
  while (truncated.isNotEmpty) {
    truncated = truncated.substring(0, truncated.length - 1);
    final candidate = truncated.isEmpty ? '$city ·' : '$city · $truncated… ·';
    if (_measureWidth(candidate, style) <= maxArcLength) return candidate;
  }
  return '$city ·';
}
