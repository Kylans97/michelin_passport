import 'package:flutter/widgets.dart';

/// Where the ceremony's stamp ended up on its page, filled in by the
/// stamp itself: [key] sits on the stamp's own (unrotated) artwork box,
/// so its render box gives the stamper a target and a size, and [ink] is
/// the ink colour the page chose for it — what the stamper's rubber face
/// and the ink pad take on.
class StampCeremonyTarget {
  final GlobalKey key = GlobalKey(debugLabel: 'stamp ceremony target');
  Color? ink;
}

/// Marks one stamp in the subtree below as the one a stamp ceremony is
/// pressing in (see stamp_ceremony.dart). [PassportStampWidget] looks this
/// up for itself: the matching stamp hands its entrance to [press] instead
/// of playing its own short "just stamped" animation, so the ceremony runs
/// on the REAL booklet — real page layout, real painter, real rotation —
/// with nothing threaded through PassportFlipBook/PassportOpenBookPager/
/// PassportPage, and nothing to drift from what the Passport tab shows.
class StampCeremonyScope extends InheritedWidget {
  final String stampId;

  /// 0 → 1 from the moment the rubber stamp touches the page. At 0 the
  /// impression is not on the page yet.
  final Animation<double> press;

  /// True swaps the impression's ink transfer for a plain fade, honouring
  /// the system's reduce-motion setting.
  final bool reducedMotion;

  final StampCeremonyTarget target;

  const StampCeremonyScope({
    super.key,
    required this.stampId,
    required this.press,
    required this.reducedMotion,
    required this.target,
    required super.child,
  });

  /// No dependency is registered: [press] drives repaints on its own, and
  /// a stamp never moves from one ceremony to another.
  static StampCeremonyScope? maybeOf(BuildContext context) =>
      context.getInheritedWidgetOfExactType<StampCeremonyScope>();

  // The rubber stamp has already brought the motion; the impression only
  // has to land. Ink transfers almost at once, the paper gives a hair
  // (1.03 → 1), and the ink then settles from full strength to a stamp's
  // normal 0.9 opacity as it soaks in.
  static const _inkIn = Interval(0, 0.12, curve: Curves.easeOut);
  static const _give = Interval(0, 0.4, curve: Curves.easeOutCubic);
  static const _inkSettle = Interval(0.4, 1, curve: Curves.easeInOut);

  static const double startScale = 1.03;

  /// Wraps [child] (the stamp, already rotated to its own resting angle)
  /// in the impression for [t].
  static Widget pressed({
    required double t,
    required bool reducedMotion,
    required Widget child,
  }) {
    if (reducedMotion) {
      return Opacity(opacity: 0.9 * t.clamp(0.0, 1.0), child: child);
    }
    if (t <= 0) return Opacity(opacity: 0, child: child);
    final opacity = t < 0.4
        ? _inkIn.transform(t)
        : 1 - 0.1 * _inkSettle.transform(t);
    return Opacity(
      opacity: opacity.clamp(0.0, 1.0),
      child: Transform.scale(
        scale: startScale - (startScale - 1) * _give.transform(t),
        child: child,
      ),
    );
  }

  @override
  bool updateShouldNotify(StampCeremonyScope oldWidget) =>
      stampId != oldWidget.stampId ||
      press != oldWidget.press ||
      reducedMotion != oldWidget.reducedMotion ||
      target != oldWidget.target;
}
