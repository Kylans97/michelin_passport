import 'package:flutter/material.dart';

/// The Passport tab's own icon: a passport booklet with a small globe
/// emblem and a name line, drawn rather than taken from Material, so the
/// centre tab says what it is without a label. Outlined when idle; when
/// selected the booklet fills with [color] and the emblem is cut out in
/// [cutoutColor] (the bar's own green), matching how the other tabs swap
/// an outlined icon for a filled one.
class PassportBookletIcon extends StatelessWidget {
  final Color color;
  final bool selected;
  final Color cutoutColor;

  /// Height in logical pixels; the width follows the booklet's 22:27
  /// proportion.
  final double height;

  const PassportBookletIcon({
    super.key,
    required this.color,
    required this.selected,
    required this.cutoutColor,
    this.height = 25,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(height * 22 / 27, height),
      painter: _PassportBookletPainter(
        color: color,
        selected: selected,
        cutoutColor: cutoutColor,
      ),
    );
  }
}

class _PassportBookletPainter extends CustomPainter {
  final Color color;
  final bool selected;
  final Color cutoutColor;

  const _PassportBookletPainter({
    required this.color,
    required this.selected,
    required this.cutoutColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Drawn on the 22×27 grid of the approved mock-up, then scaled.
    final s = size.height / 27;
    canvas.scale(s);
    const stroke = 1.5;

    final cover = RRect.fromRectAndRadius(
      const Rect.fromLTWH(1.5, 1.5, 19, 24),
      const Radius.circular(2.5),
    );
    final coverPaint = Paint()
      ..color = color
      ..style = selected ? PaintingStyle.fill : PaintingStyle.stroke
      ..strokeWidth = stroke;
    canvas.drawRRect(selected ? cover.inflate(stroke / 2) : cover, coverPaint);

    final emblem = Paint()
      ..color = selected ? cutoutColor : color
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;

    const centre = Offset(11, 11);
    const r = 4.5;
    canvas.drawCircle(centre, r, emblem);
    canvas.drawLine(const Offset(6.5, 11), const Offset(15.5, 11), emblem);
    // The meridian: an ellipse narrower than the globe.
    canvas.drawOval(
      Rect.fromCenter(center: centre, width: r * 1.1, height: r * 2),
      emblem,
    );
    canvas.drawLine(const Offset(7, 20), const Offset(15, 20), emblem);
  }

  @override
  bool shouldRepaint(_PassportBookletPainter old) =>
      old.color != color ||
      old.selected != selected ||
      old.cutoutColor != cutoutColor;
}
