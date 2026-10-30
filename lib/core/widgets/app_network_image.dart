import 'dart:convert';
import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

/// Every remote image the app shows goes through [AppNetworkImage] or
/// [appImageProvider], for the two things plain `Image.network` never did:
///
/// * **A size that fits the slot.** A public Storage photo is fetched from
///   Supabase's render endpoint at the slot's size instead of as the
///   original. A 1536x2048 venue original is 1.6 MB; the 768 variant a card
///   needs is about 150 KB (measured 2026-10-30). The render endpoint needs
///   the Pro plan; production answers it. Signed (private-bucket) URLs are
///   left as their repository made them.
/// * **A disk cache that survives the URL changing.** Signed URLs carry a
///   fresh token on every load, so they are keyed on the storage path, not
///   the URL ([imageCacheKey]). Storage paths are never reused (every upload
///   writes a new timestamped name), so a cached file stays valid for
///   [_cacheValidity] even though Storage answers `no-cache`.
///
/// Full-screen viewers pass `original: true` and get the stored bytes.

/// Long-edge sizes a variant is rounded up to, so slots of slightly
/// different sizes share one cached file and one transformation.
const displayImageSizes = [256, 512, 768, 1024, 1536, 2048];

/// A photo's aspect ratio isn't known before it loads, so the requested
/// long edge is the slot's long edge times this: enough for a 4:3 photo to
/// cover any slot, in either orientation, without upscaling.
const _aspectAllowance = 4 / 3;

/// How long a cached image is used without asking Storage again. Paths are
/// immutable (see above), so this only bounds how long a deleted photo can
/// linger on a device.
const _cacheValidity = Duration(days: 30);

final _publicObject = RegExp(
  r'^(https://[^/]+/storage/v1)/object/public/([^?#]+)$',
);
final _signedObject = RegExp(
  r'^(https://[^/]+/storage/v1)/(object|render/image)/sign/([^?#]+)\?(.*)$',
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

/// The disk-cache key for [url]: the URL itself, except for a signed
/// Storage URL, whose token changes on every load. That one keys on its
/// bucket/path, plus the transformation the token was signed with, so a
/// thumbnail and the original of one photo never share an entry. A signed
/// render URL whose token can't be read keys on its full URL — never
/// cached across loads, but never shown at the wrong size either.
String imageCacheKey(String url) {
  final match = _signedObject.firstMatch(url);
  if (match == null) return url;
  final base = '${match[1]}/${match[2]}/sign/${match[3]}';
  if (match[2] == 'object') return base;
  final token = Uri.splitQueryString(match[4]!)['token'];
  final transformations = _tokenClaim(token, 'transformations');
  return transformations == null ? url : '$base#$transformations';
}

String? _tokenClaim(String? jwt, String claim) {
  final parts = jwt?.split('.');
  if (parts == null || parts.length != 3) return null;
  try {
    final payload = jsonDecode(
      utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
    );
    final value = payload is Map ? payload[claim] : null;
    return value?.toString();
  } catch (_) {
    return null;
  }
}

/// Off by default, so widget tests (no sqflite, no path_provider) keep
/// plain [NetworkImage]; main() turns it on before runApp.
bool _diskCacheEnabled = false;

void enableImageDiskCache() => _diskCacheEnabled = true;

/// The app's one image cache.
final CacheManager appImageCacheManager = CacheManager(
  Config(
    'mantelierImages',
    stalePeriod: const Duration(days: 60),
    maxNrOfCacheObjects: 1000,
    fileService: ImmutableStorageFileService(),
  ),
);

/// [HttpFileService] with Storage's `no-cache` replaced by [_cacheValidity]
/// for Supabase Storage responses, which are immutable per path. Anything
/// else keeps the validity its own headers give it.
class ImmutableStorageFileService extends FileService {
  ImmutableStorageFileService({FileService? inner})
    : _inner = inner ?? HttpFileService();

  final FileService _inner;

  @override
  int get concurrentFetches => _inner.concurrentFetches;

  @override
  Future<FileServiceResponse> get(
    String url, {
    Map<String, String>? headers,
  }) async {
    final response = await _inner.get(url, headers: headers);
    if (!url.contains('/storage/v1/')) return response;
    return _LongLivedResponse(response, DateTime.now().add(_cacheValidity));
  }
}

class _LongLivedResponse implements FileServiceResponse {
  _LongLivedResponse(this._inner, this.validTill);

  final FileServiceResponse _inner;

  @override
  final DateTime validTill;

  @override
  Stream<List<int>> get content => _inner.content;
  @override
  int? get contentLength => _inner.contentLength;
  @override
  int get statusCode => _inner.statusCode;
  @override
  String? get eTag => _inner.eTag;
  @override
  String get fileExtension => _inner.fileExtension;
}

/// The provider for [url], at [longEdgePx] when it has a variant (see
/// [storageVariantUrl]) and from the disk cache once enabled.
ImageProvider appImageProvider(String url, {int? longEdgePx}) {
  final resolved =
      (longEdgePx == null ? null : storageVariantUrl(url, longEdgePx)) ?? url;
  if (!_diskCacheEnabled) return NetworkImage(resolved);
  return CachedNetworkImageProvider(
    resolved,
    cacheKey: imageCacheKey(resolved),
    cacheManager: appImageCacheManager,
  );
}

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
