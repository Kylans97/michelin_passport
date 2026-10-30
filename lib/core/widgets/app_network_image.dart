import 'dart:math' as math;

import 'package:flutter/widgets.dart';

/// Every remote image the app shows goes through [AppNetworkImage] or
/// [appImageProvider], for a size that fits the slot: a public Storage
/// photo is fetched from Supabase's render endpoint at the slot's size
/// instead of as the original. A 1536x2048 venue original is 1.6 MB; the
/// 768 variant a card needs is about 150 KB (measured 2026-10-30). The
/// render endpoint needs the Pro plan; production answers it. Signed
/// (private-bucket) URLs are left as their repository made them.
///
/// Full-screen viewers pass `original: true` and get the stored bytes.

/// Long-edge sizes a variant is rounded up to, so slots of slightly
/// different sizes share one transformation.
const displayImageSizes = [256, 512, 768, 1024, 1536, 2048];

/// A photo's aspect ratio isn't known before it loads, so the requested
/// long edge is the slot's long edge times this: enough for a 4:3 photo to
/// cover any slot, in either orientation, without upscaling.
const _aspectAllowance = 4 / 3;

final _publicObject = RegExp(
  r'^(https://[^/]+/storage/v1)/object/public/([^?#]+)$',
);

/// The smallest of [displayImageSizes] at least [longEdgePx], or the
/// largest one.
int displayImageSize(double longEdgePx) => displayImageSizes.firstWhere(
  (size) => size >= longEdgePx,
  orElse: () => displayImageSizes.last,
);

/// The variant size for a slot whose longer side is [longEdge] logical
/// pixels, shown at [zoom] — what [AppNetworkImage] requests, exposed so a
/// precache can ask for the identical variant.
int displayImageSizeFor(
  BuildContext context,
  double longEdge, {
  double zoom = 1,
}) {
  final dpr = MediaQuery.maybeDevicePixelRatioOf(context) ?? 3;
  return displayImageSize(longEdge * dpr * zoom * _aspectAllowance);
}

/// [url] as a render-endpoint variant whose long edge is at most
/// [longEdgePx], keeping the photo's own aspect ratio (`resize=contain` in
/// a square box, so focus-point framing still crops client-side). Null when
/// [url] isn't a public Storage object — signed and external URLs have no
/// variant here. Width alone is not enough: measured on production, the
/// render endpoint then keeps the original height and distorts the photo.
String? storageVariantUrl(String url, int longEdgePx) {
  final match = _publicObject.firstMatch(url);
  if (match == null) return null;
  return '${match[1]}/render/image/public/${match[2]}'
      '?width=$longEdgePx&height=$longEdgePx&resize=contain';
}

/// The provider for [url], at [longEdgePx] when it has a variant (see
/// [storageVariantUrl]).
ImageProvider appImageProvider(String url, {int? longEdgePx}) => NetworkImage(
  (longEdgePx == null ? null : storageVariantUrl(url, longEdgePx)) ?? url,
);

/// `Image.network`, sized and cached — see this file's header. The variant
/// size comes from the slot this widget is laid out in, times the device
/// pixel ratio and [zoom] (pass the framing's zoom when the image sits
/// inside a [FramedImage], which scales it up after layout).
class AppNetworkImage extends StatelessWidget {
  const AppNetworkImage(
    this.url, {
    super.key,
    this.fit,
    this.alignment = Alignment.center,
    this.width,
    this.height,
    this.zoom = 1,
    this.longEdgePx,
    this.original = false,
    this.errorBuilder,
    this.loadingBuilder,
    this.frameBuilder,
    this.semanticLabel,
    this.gaplessPlayback = false,
  });

  final String url;
  final BoxFit? fit;
  final AlignmentGeometry alignment;
  final double? width;
  final double? height;
  final double zoom;

  /// A fixed variant size, from [displayImageSizeFor], instead of one
  /// measured from the slot.
  final int? longEdgePx;

  /// The stored file, never a variant — for full-screen viewers.
  final bool original;
  final ImageErrorWidgetBuilder? errorBuilder;
  final ImageLoadingBuilder? loadingBuilder;
  final ImageFrameBuilder? frameBuilder;
  final String? semanticLabel;
  final bool gaplessPlayback;

  Widget _image(ImageProvider provider) => Image(
    image: provider,
    fit: fit,
    alignment: alignment,
    width: width,
    height: height,
    errorBuilder: errorBuilder,
    loadingBuilder: loadingBuilder,
    frameBuilder: frameBuilder,
    semanticLabel: semanticLabel,
    gaplessPlayback: gaplessPlayback,
  );

  @override
  Widget build(BuildContext context) {
    if (original || storageVariantUrl(url, 0) == null) {
      return _image(appImageProvider(url));
    }
    if (longEdgePx != null) {
      return _image(appImageProvider(url, longEdgePx: longEdgePx));
    }
    final screen = MediaQuery.maybeSizeOf(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        double edge(double? fixed, double max, double? fallback) {
          if (fixed != null && fixed.isFinite) return fixed;
          return max.isFinite ? max : (fallback ?? 0);
        }

        final longEdge = math.max(
          edge(width, constraints.maxWidth, screen?.width),
          edge(height, constraints.maxHeight, null),
        );
        final size = displayImageSizeFor(context, longEdge, zoom: zoom);
        return _image(appImageProvider(url, longEdgePx: size));
      },
    );
  }
}
