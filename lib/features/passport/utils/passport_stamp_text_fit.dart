import 'package:flutter/material.dart';

/// Which of a stamp's 3 name sizes applies — purely from character count,
/// independent of variant. Each variant maps its own L/M/S to different
/// literal point sizes (see passport_stamp_painters.dart), but every
/// variant uses this same length-based tier boundary: "≤ 10 tekens is L,
/// 11–18 is M, ≥ 19 is S" per the September 2026 stamp redesign brief.
enum StampNameTier { l, m, s }

StampNameTier stampNameTierFor(String name) {
  final length = name.length;
  if (length <= 10) return StampNameTier.l;
  if (length <= 18) return StampNameTier.m;
  return StampNameTier.s;
}

/// A venue name laid out per the brief's shared fitting rule, used by all
/// 5 stamp variants: never on an arc, a straight text box up to 2 lines,
/// "gebalanceerd afgebroken" (balanced line-break — both lines as close in
/// width as possible, not a greedy first-line-fills-first wrap), sized
/// from [stampNameTierFor] via [sizeL]/[sizeM]/[sizeS]. If the name still
/// doesn't fit 2 lines at its tier's size, shrinks to 85% once; whatever
/// still doesn't fit after that is truncated with an ellipsis by the
/// returned [TextPainter] itself (built with `maxLines: 2, ellipsis:
/// '…'`) — same "let TextPainter do the actual truncation" contract the
/// old `fitStampTextByShrinking` used, for the same UTF-16-safety reason.
///
/// [styleFor] builds the text style for a given resolved font size (so
/// callers can bake in weight/italic/letterSpacing/color/uppercase
/// transforms specific to their own variant) — [text] passed in should
/// already be whatever case the variant wants (e.g. DoubleFramePainter
/// upper-cases it before calling this).
TextPainter fitStampNameBalanced({
  required String text,
  required TextStyle Function(double fontSize) styleFor,
  required double maxWidth,
  required double sizeL,
  required double sizeM,
  required double sizeS,
}) {
  final tier = stampNameTierFor(text);
  final baseSize = switch (tier) {
    StampNameTier.l => sizeL,
    StampNameTier.m => sizeM,
    StampNameTier.s => sizeS,
  };

  TextPainter layoutAt(double fontSize) {
    final style = styleFor(fontSize);
    final oneLine = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
    )..layout();
    if (oneLine.width <= maxWidth) {
      oneLine.layout(maxWidth: maxWidth);
      return oneLine;
    }
    final balanced = _balancedTwoLines(text, style, maxWidth);
    return TextPainter(
      text: TextSpan(text: balanced, style: style),
      textDirection: TextDirection.ltr,
      maxLines: 2,
      textAlign: TextAlign.center,
      ellipsis: '…',
    )..layout(maxWidth: maxWidth);
  }

  final atBaseSize = layoutAt(baseSize);
  if (!atBaseSize.didExceedMaxLines) return atBaseSize;
  return layoutAt(baseSize * 0.85);
}

double _measureWidth(String text, TextStyle style) {
  final painter = TextPainter(
    text: TextSpan(text: text, style: style),
    textDirection: TextDirection.ltr,
  )..layout();
  return painter.width;
}

/// Splits [text] on a single space into 2 lines, choosing whichever split
/// point makes the two resulting line widths closest to each other (a
/// "balanced" wrap) among every split where BOTH lines individually fit
/// within [maxWidth]. Falls back to the original, unsplit [text] when
/// there's only one word or no split keeps both lines within [maxWidth] —
/// the caller's own `TextPainter(maxLines: 2, ellipsis: '…')` still wraps/
/// truncates that safely, just via Flutter's ordinary greedy wrap instead
/// of a balanced one.
String _balancedTwoLines(String text, TextStyle style, double maxWidth) {
  final words = text.split(' ').where((w) => w.isNotEmpty).toList();
  if (words.length <= 1) return text;

  String? best;
  var bestDiff = double.infinity;
  for (var i = 1; i < words.length; i++) {
    final line1 = words.sublist(0, i).join(' ');
    final line2 = words.sublist(i).join(' ');
    final w1 = _measureWidth(line1, style);
    final w2 = _measureWidth(line2, style);
    if (w1 > maxWidth || w2 > maxWidth) continue;
    final diff = (w1 - w2).abs();
    if (diff < bestDiff) {
      bestDiff = diff;
      best = '$line1\n$line2';
    }
  }
  return best ?? text;
}
