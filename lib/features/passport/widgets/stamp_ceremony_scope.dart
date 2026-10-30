import 'dart:math' as math;
import 'package:flutter/widgets.dart';

/// Marks one stamp in the subtree below as the one a stamp ceremony is
/// pressing in (see stamp_ceremony.dart). [PassportStampWidget] looks this
/// up for itself: the matching stamp hands its entrance to [press] instead
/// of playing its own short "just stamped" animation, so the ceremony runs
/// on the REAL booklet — real page layout, real painter, real rotation —
/// with nothing threaded through PassportFlipBook/PassportOpenBookPager/
/// PassportPage, and nothing to drift from what the Passport tab shows.
class StampCeremonyScope extends InheritedWidget {
  final String stampId;

  /// 0 → 1 over the press itself. At 0 the stamp is not yet on the page.
  final Animation<double> press;

  /// True swaps the press (drop in, rotation easing out, ink settling)
  /// for a plain fade, honouring the system's reduce-motion setting.
  final bool reducedMotion;

  const StampCeremonyScope({
    super.key,
    required this.stampId,
    required this.press,
    required this.reducedMotion,
    required super.child,
  });

  /// No dependency is registered: [press] drives repaints on its own, and
  /// a stamp never moves from one ceremony to another.
  static StampCeremonyScope? maybeOf(BuildContext context) =>
      context.getInheritedWidgetOfExactType<StampCeremonyScope>();

  // The stamp lands in the first 60% of the press; the rest is the ink
  // settling from full strength back to a stamp's normal 0.9 opacity.
  static const _landing = Interval(0, 0.6, curve: Curves.easeOutCubic);
  static const _inkIn = Interval(0, 0.25, curve: Curves.easeOut);
  static const _inkSettle = Interval(0.6, 1, curve: Curves.easeInOut);

  static const double startScale = 1.2;
  static const double startExtraDegrees = 6;

  /// Wraps [child] (the stamp, already rotated to its own resting angle)
  /// in the press transform for [t].
  static Widget pressed({
    required double t,
    required bool reducedMotion,
    required Widget child,
  }) {
    if (reducedMotion) {
      return Opacity(opacity: 0.9 * t.clamp(0.0, 1.0), child: child);
    }
    final landed = _landing.transform(t);
    final opacity = t < 0.6
        ? _inkIn.transform(t)
        : 1 - 0.1 * _inkSettle.transform(t);
    return Opacity(
      opacity: opacity.clamp(0.0, 1.0),
      child: Transform.scale(
        scale: startScale - (startScale - 1) * landed,
        child: Transform.rotate(
          angle: startExtraDegrees * (1 - landed) * math.pi / 180,
          child: child,
        ),
      ),
    );
  }

  @override
  bool updateShouldNotify(StampCeremonyScope oldWidget) =>
      stampId != oldWidget.stampId ||
      press != oldWidget.press ||
      reducedMotion != oldWidget.reducedMotion;
}
