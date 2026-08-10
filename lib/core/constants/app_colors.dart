import 'package:flutter/material.dart';

/// Chasing Stars' design tokens — understated luxury in the vein of Aman,
/// Belmond and Soho House: deep sophisticated green as the brand color,
/// warm ivory/cream surfaces (not stark white or black), and a single
/// restrained warm-gold accent used sparingly rather than "gold
/// everywhere". Every screen in the app reads color exclusively through
/// these names — never a raw hex — so this file alone defines the app's
/// entire visual identity; changing a value here reskins every screen that
/// uses it. [background]/[surface]/[surfaceElevated] are deliberately
/// LIGHT (the ivory content backdrop); [brandGreen] is the separate deep
/// chrome/hero color used for overlay navigation and hero treatments — see
/// DetailHero. Text tokens are paired with those surfaces accordingly:
/// [textPrimary]/[textSecondary] read as ink-on-ivory, [textOnDark] reads
/// as warm white on [brandGreen].
class AppColors {
  AppColors._();

  // ── Brand ────────────────────────────────────────────────────────────
  // Deep, sophisticated bottle green — the one true "brand" color. Used
  // for hero backdrops, overlay chrome, and other deliberate brand
  // moments; never as a general-purpose background.
  static const Color brandGreen = Color(0xFF16302A);
  static const Color brandGreenLight = Color(0xFF25453C);

  // ── Surfaces (warm ivory/cream, not stark white) ────────────────────
  // Page backdrop — the lightest, warmest tone.
  static const Color background = Color(0xFFF7F2E9);
  // A card/panel lifted off the page.
  static const Color surface = Color(0xFFFFFDF8);
  // The most "raised" surface — bottom sheets, dialogs, modals.
  static const Color surfaceElevated = Color(0xFFFFFFFF);
  // Alias for [surface] — kept because the majority of existing detail-card
  // styling reads AppColors.card specifically; same warm-white value.
  static const Color card = surface;
  static const Color cardBorder = Color(0xFFE7DFCE);

  // ── Restrained warm gold accent ─────────────────────────────────────
  // A muted antique-brass gold rather than a bright showroom gold — the
  // "restrained" accent used for the odd highlight (a rating number, a
  // selected state, a badge), not painted across every icon.
  static const Color gold = Color(0xFFAC8244);
  static const Color goldLight = Color(0xFFC7A46B);
  // Semantic alias matching the design-system brief's token name; same
  // value as [gold] so existing call sites and new ones stay in lockstep.
  static const Color accent = gold;
  static const Color goldAlpha10 = Color(0x1AAC8244); // ~10 % opacity
  static const Color goldMuted = Color(0x33AC8244); // ~20 % opacity
  static const Color goldAlpha30 = Color(0x4DAC8244); // ~30 % opacity
  static const Color goldBorder40 = Color(0x66AC8244); // ~40 % opacity
  static const Color goldBorder50 = Color(0x80AC8244); // ~50 % opacity
  static const Color goldBorder60 = Color(0x99AC8244); // ~60 % opacity
  // Michelin star fill — unified with the restrained accent rather than a
  // separate bright yellow, matching "restrained gold, not gold
  // everywhere".
  static const Color starFilled = gold;

  // ── Text ─────────────────────────────────────────────────────────────
  // Ink-on-ivory — a warm near-black with a whisper of the brand green,
  // not a flat pure black.
  static const Color textPrimary = Color(0xFF20261F);
  static const Color textSecondary = Color(0xFF6B6355);
  // Warm white for text/icons drawn over [brandGreen] (hero overlays,
  // dark chrome) — never used over the ivory surfaces.
  static const Color textOnDark = Color(0xFFF5EFE1);

  static const Color divider = cardBorder;
  // A refined brick/terracotta red — editorial rather than an alarm red.
  static const Color error = Color(0xFFA23E32);

  // ── Redesign foundation tokens (Step 1 — see cs_typography.dart/
  // cs_spacing.dart for the matching type/spacing systems) ───────────────
  //
  // These are ADDITIVE: every token above stays exactly as it is, and every
  // current screen keeps reading it unchanged. Nothing below is wired into
  // AppTheme.chasingStars or any existing widget yet — screens migrate onto
  // these deliberately, one at a time, in a later pass. See CsTheme for a
  // prepared-but-not-applied ThemeData built from this new set.
  //
  // The brand direction shifts the canvas itself from ivory-with-green-
  // chrome to green-with-warm-neutral-moments (~55-65% deep green, ~25-35%
  // warm ivory, ~5-10% accent, treated as an overall direction rather than
  // a per-screen ratio) — hence a slightly richer green ramp (deepGreen/
  // darkGreen/forestGreen) and a warmer, slightly more saturated neutral
  // ramp (ivory/warmWhite/warmStone/softStone/taupe) than the original
  // background/surface/cardBorder trio above, which stayed intentionally
  // quiet as a light-canvas system.

  // deepGreen is [brandGreen] itself — both are 0xFF16302A. Kept as a
  // separate name (not a rename of brandGreen, which 30+ call sites read
  // today) so new/migrated code can adopt the brief's vocabulary without
  // any churn to what already exists.
  static const Color deepGreen = brandGreen;
  static const Color darkGreen = Color(0xFF0E241F);
  static const Color forestGreen = Color(0xFF23473D);

  static const Color ivory = Color(0xFFF4F0E7);
  static const Color warmWhite = Color(0xFFFAF7F0);
  static const Color warmStone = Color(0xFFB8B0A3);
  static const Color softStone = Color(0xFFDED8CE);
  // Accessibility-adjusted from the brief's proposed #756D62: that value is
  // 4.48:1 on `ivory`, just under the 4.5:1 WCAG AA threshold for normal
  // text. #726A60 (a barely-perceptible touch darker, same hue) clears it
  // at 4.68:1 — see the Step 1 report for the full contrast audit.
  static const Color taupe = Color(0xFF726A60);

  static const Color charcoal = Color(0xFF1C1D1A);

  // Muted brass accent — an accent only, per the brief ("VERY sparingly"),
  // never a body-text color. #A4875C is 4.16:1 on [deepGreen]: safe for
  // large/bold text, icons and borders on a green surface, but NOT normal-
  // size text there (needs 4.5:1) — and only 2.98:1 on [ivory]/[warmWhite],
  // failing even large-text AA, so never used as text on a light surface.
  static const Color mutedBrass = Color(0xFFA4875C);
  // The accessible derivative for the one case [mutedBrass] itself can't
  // cover: brass-colored text at normal size on a light (ivory/warmWhite)
  // surface. 4.60:1 on [ivory]. Icons/borders on light surfaces should
  // still use [mutedBrass] itself — this variant is for text only.
  static const Color mutedBrassOnLight = Color(0xFF7F6947);

  // [textOnDark] above (0xFFF5EFE1) already matches the brief's "warm
  // ivory, approximately #F5EFE1" — reused as-is, not duplicated under a
  // new name. 12.29:1 on [deepGreen], comfortably AA.
  //
  // secondaryOnDark: the brief suggests warmStone "or an appropriate
  // accessible derivative" — warmStone is 6.56:1 on deepGreen, already
  // comfortably AA, so no derivative was needed.
  static const Color secondaryOnDark = warmStone;

  // subtleBorderLight is identical to softStone (0xFFDED8CE) — the brief
  // specifies the same value for both; kept as its own name since "a
  // border" and "a neutral surface tone" are different semantic roles even
  // when the color happens to coincide today.
  static const Color subtleBorderLight = softStone;
  // A translucent ivory hairline for borders drawn over a green surface —
  // same "faint line, not a boxed edge" treatment [HeroBadge] already uses
  // via `textOnDark.withValues(alpha: 0.25)`, just centralized as a token.
  // Decorative/structural only, not text, so WCAG's text-contrast ratios
  // don't apply the way they do to the tokens above.
  static const Color subtleBorderDark = Color(0x26F4F0E7);
}
