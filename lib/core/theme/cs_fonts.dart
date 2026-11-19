import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// Mantelier's two bundled typefaces (see pubspec.yaml's `fonts:` section)
/// — the single place a family name is spelled out. Every text style in the
/// app comes from here, through [CsTypography]/[AppTypography] roles or,
/// for a one-off style, [serif]/[sans] directly.
///
/// Spectral (Production Type) carries display, titles and reading text;
/// Hanken Grotesk carries interface text. Both are bundled, never fetched at
/// runtime, so there is no system-font flash on first launch or offline.
///
/// Only some weights are bundled (Spectral 300/400/500 plus 400 italic,
/// Hanken Grotesk 400/500/600). [serif]/[sans] map any requested weight onto
/// the nearest bundled one themselves rather than letting the engine pick —
/// a request two steps above the nearest real weight would otherwise get a
/// synthesized ("fake") bold.
///
/// When a style gives no line [height], it gets [defaultHeight] instead of
/// the font's own. Spectral's built-in line box is 1.52× its size and
/// Hanken Grotesk's 1.30×, against 1.21× for both Cormorant Garamond and
/// Inter before them; left alone, every serif line would grow ~25% taller
/// and push fixed-height cards and rows into overflow.
class CsFonts {
  CsFonts._();

  static const String serifFamily = 'Spectral';
  static const String sansFamily = 'HankenGrotesk';

  /// The line height used when a style sets none — the 1.21× line box the
  /// layouts were built around.
  static const double defaultHeight = 1.21;

  /// Spectral. Italic exists only at 400, so an italic request is always
  /// set at 400 whatever weight was asked for.
  static TextStyle serif({
    TextStyle? textStyle,
    Color? color,
    Color? backgroundColor,
    double? fontSize,
    FontWeight? fontWeight,
    FontStyle? fontStyle,
    double? letterSpacing,
    double? wordSpacing,
    TextBaseline? textBaseline,
    double? height,
    Locale? locale,
    Paint? foreground,
    Paint? background,
    List<ui.Shadow>? shadows,
    List<ui.FontFeature>? fontFeatures,
    TextDecoration? decoration,
    Color? decorationColor,
    TextDecorationStyle? decorationStyle,
    double? decorationThickness,
  }) {
    final style = fontStyle ?? textStyle?.fontStyle;
    final weight = fontWeight ?? textStyle?.fontWeight;
    return _style(
      serifFamily,
      textStyle: textStyle,
      color: color,
      backgroundColor: backgroundColor,
      fontSize: fontSize,
      fontWeight: style == FontStyle.italic
          ? FontWeight.w400
          : serifWeight(weight),
      fontStyle: fontStyle,
      letterSpacing: letterSpacing,
      wordSpacing: wordSpacing,
      textBaseline: textBaseline,
      height: height,
      locale: locale,
      foreground: foreground,
      background: background,
      shadows: shadows,
      fontFeatures: fontFeatures,
      decoration: decoration,
      decorationColor: decorationColor,
      decorationStyle: decorationStyle,
      decorationThickness: decorationThickness,
    );
  }

  /// Hanken Grotesk.
  static TextStyle sans({
    TextStyle? textStyle,
    Color? color,
    Color? backgroundColor,
    double? fontSize,
    FontWeight? fontWeight,
    FontStyle? fontStyle,
    double? letterSpacing,
    double? wordSpacing,
    TextBaseline? textBaseline,
    double? height,
    Locale? locale,
    Paint? foreground,
    Paint? background,
    List<ui.Shadow>? shadows,
    List<ui.FontFeature>? fontFeatures,
    TextDecoration? decoration,
    Color? decorationColor,
    TextDecorationStyle? decorationStyle,
    double? decorationThickness,
  }) => _style(
    sansFamily,
    textStyle: textStyle,
    color: color,
    backgroundColor: backgroundColor,
    fontSize: fontSize,
    fontWeight: sansWeight(fontWeight ?? textStyle?.fontWeight),
    fontStyle: fontStyle,
    letterSpacing: letterSpacing,
    wordSpacing: wordSpacing,
    textBaseline: textBaseline,
    height: height,
    locale: locale,
    foreground: foreground,
    background: background,
    shadows: shadows,
    fontFeatures: fontFeatures,
    decoration: decoration,
    decorationColor: decorationColor,
    decorationStyle: decorationStyle,
    decorationThickness: decorationThickness,
  );

  /// The bundled Spectral weight nearest to [weight] (300, 400 or 500).
  static FontWeight serifWeight(FontWeight? weight) {
    final v = (weight ?? FontWeight.w400).value;
    if (v <= 300) return FontWeight.w300;
    if (v <= 400) return FontWeight.w400;
    return FontWeight.w500;
  }

  /// The bundled Hanken Grotesk weight nearest to [weight] (400, 500 or
  /// 600) — there is no Light, and Bold requests get SemiBold.
  static FontWeight sansWeight(FontWeight? weight) {
    final v = (weight ?? FontWeight.w400).value;
    if (v <= 400) return FontWeight.w400;
    if (v <= 500) return FontWeight.w500;
    return FontWeight.w600;
  }

  static TextStyle _style(
    String family, {
    TextStyle? textStyle,
    Color? color,
    Color? backgroundColor,
    double? fontSize,
    FontWeight? fontWeight,
    FontStyle? fontStyle,
    double? letterSpacing,
    double? wordSpacing,
    TextBaseline? textBaseline,
    double? height,
    Locale? locale,
    Paint? foreground,
    Paint? background,
    List<ui.Shadow>? shadows,
    List<ui.FontFeature>? fontFeatures,
    TextDecoration? decoration,
    Color? decorationColor,
    TextDecorationStyle? decorationStyle,
    double? decorationThickness,
  }) => (textStyle ?? const TextStyle()).copyWith(
    fontFamily: family,
    height: height ?? textStyle?.height ?? defaultHeight,
    color: color,
    backgroundColor: backgroundColor,
    fontSize: fontSize,
    fontWeight: fontWeight,
    fontStyle: fontStyle,
    letterSpacing: letterSpacing,
    wordSpacing: wordSpacing,
    textBaseline: textBaseline,
    locale: locale,
    foreground: foreground,
    background: background,
    shadows: shadows,
    fontFeatures: fontFeatures,
    decoration: decoration,
    decorationColor: decorationColor,
    decorationStyle: decorationStyle,
    decorationThickness: decorationThickness,
  );
}
