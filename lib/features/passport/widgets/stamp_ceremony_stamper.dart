import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Where the stamper is at one moment of the ceremony's stamping run
/// (see [StamperPath]).
class StamperPose {
  /// The point under the centre of the rubber face — on the ink pad, on
  /// the page, or in between.
  final Offset ground;

  /// How far the stamper is lifted above [ground]; 0 means touching.
  final double height;

  /// 0 → 1 as the rubber face takes up ink at the pad.
  final double inked;
  final double opacity;

  const StamperPose({
    required this.ground,
    required this.height,
    required this.inked,
    required this.opacity,
  });
}

/// The stamper's run, as a function of one 0 → 1 progress value: fade in
/// over the ink pad, dip into it, lift, travel over the page, press down
/// at [contact], hold a beat, lift away.
class StamperPath {
  final Offset pad;
  final Offset target;

  const StamperPath({required this.pad, required this.target});

  /// The moment the rubber touches the page — the impression and the
  /// haptic both start here.
  static const double contact = 0.8;

  static const double _hover = 54;
  static const double _travelHeight = 72;

  StamperPose at(double t) {
    double seg(double a, double b, [Curve curve = Curves.linear]) =>
        curve.transform(((t - a) / (b - a)).clamp(0.0, 1.0));

    var ground = pad;
    double height;
    if (t < 0.12) {
      height = _hover;
    } else if (t < 0.26) {
      height = _hover * (1 - seg(0.12, 0.26, Curves.easeIn));
    } else if (t < 0.38) {
      height = _travelHeight * seg(0.26, 0.38, Curves.easeOut);
    } else if (t < 0.7) {
      final p = seg(0.38, 0.7, Curves.easeInOut);
      ground = Offset.lerp(pad, target, p)!;
      // A shallow arc over the page rather than a flat slide.
      height = _travelHeight + 22 * math.sin(math.pi * p);
    } else if (t < contact) {
      ground = target;
      height = _travelHeight * (1 - seg(0.7, contact, Curves.easeIn));
    } else if (t < 0.86) {
      ground = target;
      height = 0;
    } else {
      ground = target;
      height = 90 * seg(0.86, 1, Curves.easeOut);
    }

    return StamperPose(
      ground: ground,
      height: height,
      inked: seg(0.2, 0.26),
      opacity: t < 0.86 ? seg(0, 0.1) : 1 - seg(0.9, 1),
    );
  }
}

/// The ink pad, the stamper's shadow and the stamper itself — a small
/// wooden rubber stamp drawn side-on, its rubber face taking up [ink] at
/// the pad. Decoration around the impression only: the impression on the
/// page is still drawn by the real stamp painter (see StampCeremonyScope).
class StamperPainter extends CustomPainter {
  final StamperPose pose;
  final Offset pad;
  final double width;
  final Color ink;
  final double padOpacity;

  const StamperPainter({
    required this.pose,
    required this.pad,
    required this.width,
    required this.ink,
    required this.padOpacity,
  });

  static const _wood = Color(0xFF7A4E2F);
  static const _woodDark = Color(0xFF5A3720);
  static const _woodLight = Color(0xFF94633F);
  static const _brass = Color(0xFFB8975A);
  static const _rubber = Color(0xFF3B3431);
  static const _tin = Color(0xFF2A2724);

  /// The ink pad's footprint for a stamper of [width], centred on its own
  /// position.
  static Size padSize(double width) => Size(width * 1.12, width * 0.36);

  @override
  void paint(Canvas canvas, Size size) {
    _paintPad(canvas);
    if (pose.opacity <= 0) return;
    _paintShadow(canvas);
    _paintStamper(canvas);
  }

  void _paintPad(Canvas canvas) {
    if (padOpacity <= 0) return;
    final s = padSize(width);
    final rect = Rect.fromCenter(center: pad, width: s.width, height: s.height);
    final tin = RRect.fromRectAndRadius(rect, Radius.circular(s.height * 0.22));
    canvas.drawRRect(
      tin.shift(const Offset(0, 3)),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.28 * padOpacity)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
    );
    canvas.drawRRect(tin, Paint()..color = _tin.withValues(alpha: padOpacity));
    final felt = RRect.fromRectAndRadius(
      rect.deflate(s.height * 0.14),
      Radius.circular(s.height * 0.12),
    );
    canvas.drawRRect(
      felt,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.lerp(ink, Colors.black, 0.25)!.withValues(alpha: padOpacity),
            Color.lerp(ink, Colors.black, 0.45)!.withValues(alpha: padOpacity),
          ],
        ).createShader(felt.outerRect),
    );
  }

  void _paintShadow(Canvas canvas) {
    final lift = (pose.height / 110).clamp(0.0, 1.0);
    final w = width * (0.92 + 0.25 * lift);
    canvas.drawOval(
      Rect.fromCenter(
        center: pose.ground + Offset(6 * lift, 4 + 8 * lift),
        width: w,
        height: w * 0.16,
      ),
      Paint()
        ..color = Colors.black.withValues(
          alpha: (0.32 - 0.2 * lift) * pose.opacity,
        )
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 3 + 9 * lift),
    );
  }

  void _paintStamper(Canvas canvas) {
    final w = width;
    final alpha = pose.opacity;
    Paint fill(Color c) => Paint()..color = c.withValues(alpha: alpha);

    // Built upward from the bottom of the rubber face.
    final bottom = pose.ground.dy - pose.height;
    final cx = pose.ground.dx;

    final rubberH = w * 0.06;
    final rubber = Rect.fromLTWH(cx - w / 2, bottom - rubberH, w, rubberH);
    canvas.drawRRect(
      RRect.fromRectAndCorners(
        rubber,
        bottomLeft: const Radius.circular(2),
        bottomRight: const Radius.circular(2),
      ),
      fill(Color.lerp(_rubber, ink, pose.inked)!),
    );

    final blockH = w * 0.17;
    final block = Rect.fromLTWH(
      cx - w / 2 - w * 0.02,
      rubber.top - blockH,
      w * 1.04,
      blockH,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(block, Radius.circular(w * 0.025)),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            _woodLight.withValues(alpha: alpha),
            _wood.withValues(alpha: alpha),
            _woodDark.withValues(alpha: alpha),
          ],
        ).createShader(block),
    );
    // A thin brass label along the block, the one bit of shine.
    canvas.drawRect(
      Rect.fromCenter(
        center: block.center,
        width: w * 0.34,
        height: blockH * 0.22,
      ),
      fill(_brass),
    );

    final neckW = w * 0.2;
    final neckH = w * 0.26;
    final neck = Rect.fromLTWH(cx - neckW / 2, block.top - neckH, neckW, neckH);
    canvas.drawRect(
      neck,
      Paint()
        ..shader = LinearGradient(
          colors: [
            _woodDark.withValues(alpha: alpha),
            _woodLight.withValues(alpha: alpha),
            _woodDark.withValues(alpha: alpha),
          ],
        ).createShader(neck),
    );

    final knob = Rect.fromCenter(
      center: Offset(cx, neck.top - w * 0.07),
      width: w * 0.42,
      height: w * 0.2,
    );
    canvas.drawOval(
      knob,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.3, -0.5),
          colors: [
            _woodLight.withValues(alpha: alpha),
            _woodDark.withValues(alpha: alpha),
          ],
        ).createShader(knob),
    );
  }

  @override
  bool shouldRepaint(StamperPainter old) =>
      old.pose != pose ||
      old.pad != pad ||
      old.width != width ||
      old.ink != ink ||
      old.padOpacity != padOpacity;
}
