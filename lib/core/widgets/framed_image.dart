import 'package:flutter/widgets.dart';
import '../../models/photo_framing.dart';

/// Applies a [PhotoFraming] to an image that fills its box with
/// BoxFit.cover. [builder] gets the alignment to pass to that image (its
/// own Image.network, error fallback etc. stay the caller's); this widget
/// then zooms around the same point and clips, so the chosen focus stays
/// put at every zoom level.
///
/// A centred, unzoomed framing adds nothing but the clip — every photo
/// framed before this existed renders exactly as it did.
class FramedImage extends StatelessWidget {
  final PhotoFraming framing;
  final Widget Function(Alignment alignment) builder;

  const FramedImage({super.key, required this.framing, required this.builder});

  @override
  Widget build(BuildContext context) {
    final alignment = framing.alignment;
    final image = builder(alignment);
    if (framing.zoom == 1) return ClipRect(child: image);
    return ClipRect(
      child: Transform.scale(
        scale: framing.zoom,
        alignment: alignment,
        child: image,
      ),
    );
  }
}
