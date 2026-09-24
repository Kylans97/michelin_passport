import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;
import '../models/passport_stamp_award.dart';
import '../models/passport_stamp_item.dart';
import '../utils/passport_stamp_style.dart';
import 'passport_stamp_painters.dart';

/// One ink stamp: dispatches to the right [CustomPainter] for [variant],
/// rotates it by [rotationDegrees], and — when [isNew] — plays the "just
/// stamped" entrance (scale 1.35→1, opacity 0→0.9, 220ms ease-out) plus a
/// single light haptic. [variant]/[ink]/[rotationDegrees] are resolved by
/// the caller (see PassportPage), not computed here — picking a variant
/// that differs from the previous stamp on the same page needs to know
/// what that previous stamp was, which only the page-level layout, not
/// one stamp in isolation, has visibility into.
class PassportStampWidget extends StatefulWidget {
  final PassportStampItem item;
  final StampVariant variant;
  final StampInk ink;
  final double rotationDegrees;
  final String semanticLabel;
  final bool isNew;
  final VoidCallback onTap;

  const PassportStampWidget({
    super.key,
    required this.item,
    required this.variant,
    required this.ink,
    required this.rotationDegrees,
    required this.semanticLabel,
    required this.isNew,
    required this.onTap,
  });

  @override
  State<PassportStampWidget> createState() => _PassportStampWidgetState();
}

class _PassportStampWidgetState extends State<PassportStampWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 220),
  );
  late final Animation<double> _scale = Tween(begin: 1.35, end: 1.0).animate(
    CurvedAnimation(parent: _controller, curve: Curves.easeOut),
  );
  late final Animation<double> _opacity = Tween(begin: 0.0, end: 0.9).animate(
    CurvedAnimation(parent: _controller, curve: Curves.easeOut),
  );

  @override
  void initState() {
    super.initState();
    if (widget.isNew) {
      HapticFeedback.lightImpact();
      _controller.forward();
    } else {
      _controller.value = 1;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = stampVariantSize(widget.variant);
    final data = StampPaintData(
      seedId: widget.item.id,
      cityName: widget.item.cityName,
      countryCode: widget.item.countryCode,
      venueName: widget.item.venueName,
      date: widget.item.date,
      award: stampAwardFor(widget.item),
      ink: widget.ink.color,
    );

    return Semantics(
      label: widget.semanticLabel,
      button: true,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) => Opacity(
          opacity: widget.isNew ? _opacity.value : 0.9,
          child: Transform.scale(scale: widget.isNew ? _scale.value : 1, child: child),
        ),
        child: Transform.rotate(
          angle: widget.rotationDegrees * math.pi / 180,
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              onTap: widget.onTap,
              customBorder: const CircleBorder(),
              child: ExcludeSemantics(
                child: SizedBox.fromSize(
                  size: size,
                  child: RepaintBoundary(
                    child: CustomPaint(
                      painter: stampPainterFor(widget.variant, data),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
