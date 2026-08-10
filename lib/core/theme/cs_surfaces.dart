import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

/// A small, intentional surface vocabulary (Step 1 foundation) — semantic
/// ROLE names layered over the raw [AppColors] palette, so future widgets
/// say what a surface IS ("the elevated green panel") rather than which
/// literal color it happens to use today. Hierarchy comes from background
/// contrast, spacing, type and a restrained border first — [elevatedShadow]
/// exists only for the rare case none of those suffice; it is deliberately
/// not used by anything in this file or applied globally.
class CsSurfaces {
  CsSurfaces._();

  /// The primary deep-green canvas — most of a redesigned screen's
  /// background, per the brief's "green is the primary canvas" direction.
  static const Color greenCanvas = AppColors.deepGreen;

  /// A panel lifted off [greenCanvas] — still green, one step lighter, for
  /// content grouped on top of the canvas rather than the canvas itself.
  static const Color greenElevated = AppColors.forestGreen;

  /// The warm ivory content surface — where readable, ivory-canvas content
  /// moments sit (the ~25-35% of the brief's ratio direction).
  static const Color ivorySurface = AppColors.ivory;

  /// A slightly lighter neutral surface than [ivorySurface] — sheets,
  /// modals, anything that should read as "raised" above ivory itself.
  static const Color warmWhiteSurface = AppColors.warmWhite;

  /// A faint hairline for a border drawn over a green surface.
  static const Color subtleGreenBorder = AppColors.subtleBorderDark;

  /// A faint hairline for a border drawn over an ivory/warm-white surface.
  static const Color lightBorder = AppColors.subtleBorderLight;

  /// The one sanctioned shadow, for the rare case background/spacing/type/
  /// border genuinely aren't enough (e.g. a sheet lifting off busy
  /// content behind it) — extremely restrained by design: a soft, low
  /// blur, low-opacity spread, never the default way to show hierarchy.
  static List<BoxShadow> get elevatedShadow => [
    BoxShadow(
      color: AppColors.darkGreen.withValues(alpha: 0.12),
      blurRadius: 24,
      offset: const Offset(0, 8),
    ),
  ];
}
