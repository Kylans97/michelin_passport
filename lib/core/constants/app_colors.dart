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
}
