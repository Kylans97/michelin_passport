import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;
import 'package:flutter_svg/flutter_svg.dart';
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
    final item = widget.item;
    final verified = item.verified;
    final size = verified ? verifiedStampSize : stampVariantSize(widget.variant);
    final data = StampPaintData(
      seedId: item.id,
      cityName: item.cityName,
      countryCode: item.countryCode,
      venueName: item.venueName,
      date: item.date,
      award: stampAwardFor(item),
      ink: widget.ink.color,
    );
    final painter = verified
        ? VerifiedVenueStampPainter(data)
        : stampPainterFor(widget.variant, data);

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
                  child: Stack(
                    // Non-positioned children of a loose (the default)
                    // Stack get LOOSENED constraints — a plain CustomPaint
                    // with no size/child of its own then lays out at
                    // Size.zero instead of filling this SizedBox, which
                    // fed the painters a zero-size canvas: deflate()ing it
                    // produced negative rects, and a maxWidth derived from
                    // that (DoubleFrame/Oval/Postmark, whose name-box
                    // width comes FROM the received canvas size, unlike
                    // RoundSeal/Octagon's own hardcoded constants) hit a
                    // negative `TextPainter.layout(maxWidth: ...)` —
                    // caught only by actually running the widget tests,
                    // not by analyze. `expand` forces every non-positioned
                    // child (just the CustomPaint layer here) to fill this
                    // exact [size] again, matching the pre-Stack behavior.
                    fit: StackFit.expand,
                    children: [
                      RepaintBoundary(child: CustomPaint(painter: painter)),
                      if (verified && item.venueArtworkApproved && item.venueArtworkUrl != null)
                        _VenueArtwork(
                          url: item.venueArtworkUrl!,
                          tint: widget.ink.color,
                          rect: VerifiedVenueStampPainter.artworkRect(size),
                        ),
                    ],
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

/// The venue's own single-color SVG, tinted to the stamp's ink via
/// [ColorFilter] (same technique [CsMastheadLogo] already uses to recolor
/// a monochrome vector asset) and positioned over
/// [VerifiedVenueStampPainter]'s own reserved artwork circle. Only ever
/// shown when [PassportStampItem.venueArtworkApproved] is true — an
/// uploaded-but-unapproved SVG must never render (see that field's own
/// doc comment on `Restaurant`/`Hotel`).
///
/// Accepts either a real URL ([SvgPicture.network], the production case)
/// or literal inline `<svg ...>` markup ([SvgPicture.string]) — the latter
/// exists purely so this feature's own "test de weergave nu met een
/// test-SVG" requirement can be exercised (in previews and tests) without
/// a live server to fetch from; production data always goes through
/// `stamp_artwork_url`, a real URL, once the upload/approval flow this
/// feature's own scope explicitly defers actually exists.
class _VenueArtwork extends StatelessWidget {
  final String url;
  final Color tint;
  final Rect rect;

  const _VenueArtwork({required this.url, required this.tint, required this.rect});

  @override
  Widget build(BuildContext context) {
    final colorFilter = ColorFilter.mode(tint, BlendMode.srcIn);
    final svg = url.trimLeft().startsWith('<svg')
        ? SvgPicture.string(url, colorFilter: colorFilter)
        : SvgPicture.network(url, colorFilter: colorFilter);
    return Positioned.fromRect(
      rect: rect,
      child: ExcludeSemantics(child: svg),
    );
  }
}
