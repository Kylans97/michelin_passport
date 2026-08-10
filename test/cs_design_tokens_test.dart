// Covers the Step 1 design-system foundation tokens: the color contrast
// audit that drove several token choices (see AppColors' "Redesign
// foundation tokens" section for the full reasoning), plus the exact
// values CsTypography/CsSpacing/CsRadius must hold per the brand brief.
// These are regression guards — if a token value ever drifts, the
// contrast ratios and role definitions this task deliberately verified
// should fail loudly rather than silently degrade.

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:michelin_passport/core/constants/app_colors.dart';
import 'package:michelin_passport/core/theme/app_spacing.dart';
import 'package:michelin_passport/core/theme/cs_spacing.dart';
import 'package:michelin_passport/core/theme/cs_typography.dart';

// WCAG 2.x relative-luminance / contrast-ratio formulas — used only to
// verify the token audit in this test file, not a runtime dependency.
double _srgbToLinear(double c) =>
    c <= 0.04045 ? c / 12.92 : math.pow((c + 0.055) / 1.055, 2.4).toDouble();

double _relativeLuminance(Color c) {
  final r = _srgbToLinear(c.r);
  final g = _srgbToLinear(c.g);
  final b = _srgbToLinear(c.b);
  return 0.2126 * r + 0.7152 * g + 0.0722 * b;
}

double _contrastRatio(Color a, Color b) {
  final l1 = _relativeLuminance(a);
  final l2 = _relativeLuminance(b);
  final lighter = math.max(l1, l2);
  final darker = math.min(l1, l2);
  return (lighter + 0.05) / (darker + 0.05);
}

const double _aaNormalText = 4.5;
const double _aaLargeText = 3.0;

void main() {
  group('Color contrast — normal-size text pairs (WCAG AA 4.5:1)', () {
    test('textOnDark on deepGreen', () {
      expect(
        _contrastRatio(AppColors.textOnDark, AppColors.deepGreen),
        greaterThanOrEqualTo(_aaNormalText),
      );
    });

    test('secondaryOnDark (warmStone) on deepGreen', () {
      expect(
        _contrastRatio(AppColors.secondaryOnDark, AppColors.deepGreen),
        greaterThanOrEqualTo(_aaNormalText),
      );
    });

    test('charcoal on ivory', () {
      expect(
        _contrastRatio(AppColors.charcoal, AppColors.ivory),
        greaterThanOrEqualTo(_aaNormalText),
      );
    });

    test('charcoal on warmWhite', () {
      expect(
        _contrastRatio(AppColors.charcoal, AppColors.warmWhite),
        greaterThanOrEqualTo(_aaNormalText),
      );
    });

    test('taupe on ivory — the value the brief\'s proposed #756D62 was '
        'adjusted to clear (was 4.48:1, just under threshold)', () {
      expect(
        _contrastRatio(AppColors.taupe, AppColors.ivory),
        greaterThanOrEqualTo(_aaNormalText),
      );
    });

    test('mutedBrassOnLight on ivory — the accessible derivative for '
        'brass text on a light surface', () {
      expect(
        _contrastRatio(AppColors.mutedBrassOnLight, AppColors.ivory),
        greaterThanOrEqualTo(_aaNormalText),
      );
    });

    test('deepGreen text on ivory (button)', () {
      expect(
        _contrastRatio(AppColors.deepGreen, AppColors.ivory),
        greaterThanOrEqualTo(_aaNormalText),
      );
    });
  });

  group('Color contrast — accent-only pairs (WCAG AA 3:1, large/bold text '
      'or non-text use only)', () {
    test('mutedBrass on deepGreen clears large-text AA but NOT normal-text '
        'AA — must never be used for normal-size body text there', () {
      final ratio = _contrastRatio(AppColors.mutedBrass, AppColors.deepGreen);
      expect(ratio, greaterThanOrEqualTo(_aaLargeText));
      expect(
        ratio,
        lessThan(_aaNormalText),
        reason:
            'if this starts passing 4.5, the accessibility comment in '
            'AppColors documenting the restriction is stale and should be '
            'revisited, not silently left in place',
      );
    });

    test('mutedBrass on ivory fails even large-text AA — confirms it must '
        'never be used as text on a light surface (mutedBrassOnLight '
        'exists for exactly this case)', () {
      expect(
        _contrastRatio(AppColors.mutedBrass, AppColors.ivory),
        lessThan(_aaLargeText),
      );
    });
  });

  group('CsTypography — role values match the brand brief exactly', () {
    void expectRole(
      TextStyle style, {
      required String fontFamily,
      required double fontSize,
      required FontWeight fontWeight,
      double? height,
      double? letterSpacing,
    }) {
      expect(style.fontSize, fontSize);
      expect(style.fontWeight, fontWeight);
      expect(style.fontFamily, contains(fontFamily));
      if (height != null) {
        expect(style.height, closeTo(height, 0.001));
      }
      if (letterSpacing != null) {
        expect(style.letterSpacing, letterSpacing);
      }
    }

    // testWidgets, not a plain test(): CsTypography roles call
    // GoogleFonts.*, which kicks off an async runtime font-fetch this
    // sandbox has no network for. That fetch runs detached from these
    // assertions (the returned TextStyle's metadata is available
    // synchronously either way) but a plain test() attributes its later
    // rejection as a failure of whatever test happened to be running when
    // it lands; testWidgets' zone handling (already relied on by every
    // other GoogleFonts-backed widget test in this suite) absorbs it
    // instead.
    testWidgets('displayHero — Cormorant Garamond Semibold 40/42', (
      tester,
    ) async {
      expectRole(
        CsTypography.displayHero,
        fontFamily: 'CormorantGaramond',
        fontSize: 40,
        fontWeight: FontWeight.w600,
        height: 42 / 40,
      );
    });

    testWidgets('screenTitle — Cormorant Garamond Semibold 32/36', (
      tester,
    ) async {
      expectRole(
        CsTypography.screenTitle,
        fontFamily: 'CormorantGaramond',
        fontSize: 32,
        fontWeight: FontWeight.w600,
        height: 36 / 32,
      );
    });

    testWidgets('sectionTitle — Cormorant Garamond Semibold 28/32', (
      tester,
    ) async {
      expectRole(
        CsTypography.sectionTitle,
        fontFamily: 'CormorantGaramond',
        fontSize: 28,
        fontWeight: FontWeight.w600,
        height: 32 / 28,
      );
    });

    testWidgets('placeTitle — Cormorant Garamond Semibold 22/26', (
      tester,
    ) async {
      expectRole(
        CsTypography.placeTitle,
        fontFamily: 'CormorantGaramond',
        fontSize: 22,
        fontWeight: FontWeight.w600,
        height: 26 / 22,
      );
    });

    testWidgets('largeMetric — Cormorant Garamond Semibold 28/32', (
      tester,
    ) async {
      expectRole(
        CsTypography.largeMetric,
        fontFamily: 'CormorantGaramond',
        fontSize: 28,
        fontWeight: FontWeight.w600,
        height: 32 / 28,
      );
    });

    testWidgets('body — Inter Regular 16/24', (tester) async {
      expectRole(
        CsTypography.body,
        fontFamily: 'Inter',
        fontSize: 16,
        fontWeight: FontWeight.w400,
        height: 24 / 16,
      );
    });

    testWidgets('bodyMedium — Inter Medium 16/24', (tester) async {
      expectRole(
        CsTypography.bodyMedium,
        fontFamily: 'Inter',
        fontSize: 16,
        fontWeight: FontWeight.w500,
        height: 24 / 16,
      );
    });

    testWidgets('metadata — Inter Regular 14/20', (tester) async {
      expectRole(
        CsTypography.metadata,
        fontFamily: 'Inter',
        fontSize: 14,
        fontWeight: FontWeight.w400,
        height: 20 / 14,
      );
    });

    testWidgets('navigation — Inter Medium 12/16', (tester) async {
      expectRole(
        CsTypography.navigation,
        fontFamily: 'Inter',
        fontSize: 12,
        fontWeight: FontWeight.w500,
        height: 16 / 12,
      );
    });

    testWidgets('eyebrow — Inter Medium 12, letter-spacing 1.8', (
      tester,
    ) async {
      expectRole(
        CsTypography.eyebrow,
        fontFamily: 'Inter',
        fontSize: 12,
        fontWeight: FontWeight.w500,
        letterSpacing: 1.8,
      );
    });

    testWidgets('smallLabel — Inter Medium 12/16', (tester) async {
      expectRole(
        CsTypography.smallLabel,
        fontFamily: 'Inter',
        fontSize: 12,
        fontWeight: FontWeight.w500,
        height: 16 / 12,
      );
    });
  });

  group('CsSpacing — 4pt grid values match the brief', () {
    test('every token', () {
      expect(CsSpacing.xs, 4);
      expect(CsSpacing.sm, 8);
      expect(CsSpacing.md, 12);
      expect(CsSpacing.base, 16);
      expect(CsSpacing.lg, 20);
      expect(CsSpacing.xl, 24);
      expect(CsSpacing.xxl, 32);
      expect(CsSpacing.section, 40);
      expect(CsSpacing.hero, 48);
      expect(CsSpacing.pageHorizontal, 20);
      expect(CsSpacing.cardPadding, 20);
    });
  });

  group('CsRadius — corner values match the brief', () {
    test('every token', () {
      expect(CsRadius.small, 8);
      expect(CsRadius.medium, 12);
      expect(CsRadius.card, 18);
      expect(CsRadius.large, 24);
      expect(CsRadius.pill, 999);
    });
  });

  group('Existing legacy tokens are untouched', () {
    test('AppSpacing.lg is still 16 — DetailCard reads this today; the '
        'brief\'s conflicting lg=20 lives only on CsSpacing, deliberately '
        'not merged into AppSpacing', () {
      expect(AppSpacing.lg, 16);
      expect(CsSpacing.lg, 20);
    });

    test('AppRadii values are untouched — DetailCard/PrimaryButton/'
        'VenueThumbnail keep reading these unchanged', () {
      expect(AppRadii.sm, 12);
      expect(AppRadii.md, 16);
      expect(AppRadii.lg, 20);
      expect(AppRadii.xl, 28);
    });

    test('AppColors.brandGreen equals the new deepGreen alias — same '
        'value, no rename', () {
      expect(AppColors.brandGreen, AppColors.deepGreen);
      expect(AppColors.brandGreen, const Color(0xFF16302A));
    });
  });
}
