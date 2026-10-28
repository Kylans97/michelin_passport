import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/cs_spacing.dart';
import '../../../core/theme/cs_typography.dart';
import '../../../core/widgets/framed_image.dart';
import '../../../models/photo_framing.dart';

/// Lets a venue manager position and zoom one photo: drag to move, pinch
/// (or the slider) to zoom, inside the real header frame, with the card
/// frame beneath updating live. One [PhotoFraming] drives both, exactly
/// as FramedImage applies it everywhere the photo is shown — so what is
/// set here is what visitors see.
///
/// The header frame has the real hero's shape: VenueDetailHero and
/// PrivateChefHero are SliverAppBars, so on a device they are the full
/// screen width by expandedHeight (300; private chef 320) PLUS the status
/// bar, with the status bar and toolbar (back button, actions) drawn over
/// the top of the photo. The editor scales that exact shape down to the
/// page's width and shades that covered strip, so what sits clear of it
/// here sits clear of it on the real page. (Until 2026-10-28 this was a
/// fixed 300px frame at page width — a different aspect ratio, so a face
/// framed here landed higher, under the status bar, on the device.) Card
/// frame: 1:1 (VenueThumbnail; private chef 4:5, PrivateChefDiscoveryCard).
///
/// [defaultFraming] is where an untouched photo sits and what Reset goes
/// back to: centred for restaurants and hotels; for private chefs, high
/// in the frame (PhotoFraming.chefDefault), matching how an unframed chef
/// photo has always been shown so a face clears the Dynamic Island.
///
/// Dragging moves the photo with the finger: the editor reads the image's
/// own pixel size so it can turn a drag into the right focus change (see
/// [_panBy]); until that size is known a drag does nothing.
class PhotoFramingEditor extends StatefulWidget {
  final ImageProvider image;
  final String venueTypeWireValue;
  final PhotoFraming initial;
  final PhotoFraming defaultFraming;
  final ValueChanged<PhotoFraming> onChanged;

  const PhotoFramingEditor({
    super.key,
    required this.image,
    required this.venueTypeWireValue,
    required this.initial,
    this.defaultFraming = PhotoFraming.center,
    required this.onChanged,
  });

  @override
  State<PhotoFramingEditor> createState() => _PhotoFramingEditorState();
}

class _PhotoFramingEditorState extends State<PhotoFramingEditor> {
  late PhotoFraming _framing = widget.initial;
  Size? _imageSize;
  ImageStream? _stream;
  late final ImageStreamListener _listener = ImageStreamListener((info, _) {
    if (!mounted) return;
    setState(() {
      _imageSize = Size(
        info.image.width.toDouble(),
        info.image.height.toDouble(),
      );
    });
  }, onError: (_, _) {});

  double _zoomAtGestureStart = 1;

  bool get _isChef => widget.venueTypeWireValue == 'private_chef';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _resolveImage();
  }

  @override
  void didUpdateWidget(PhotoFramingEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.image != widget.image) {
      _imageSize = null;
      _resolveImage();
    }
    if (oldWidget.initial != widget.initial) _framing = widget.initial;
  }

  void _resolveImage() {
    final stream = widget.image.resolve(createLocalImageConfiguration(context));
    if (stream.key == _stream?.key) return;
    _stream?.removeListener(_listener);
    _stream = stream..addListener(_listener);
  }

  @override
  void dispose() {
    _stream?.removeListener(_listener);
    super.dispose();
  }

  void _set(PhotoFraming next) {
    final clamped = next.clamped();
    if (clamped == _framing) return;
    setState(() => _framing = clamped);
    widget.onChanged(clamped);
  }

  // With BoxFit.cover the image is shown at scale s0 = max(W/iw, H/ih),
  // aligned so its focus point sits at the same fraction of the box, then
  // zoomed by z around that point. Its left edge is then
  // fx * (W - iw * s0 * z), so moving it by dx needs
  // dfx = dx / (W - iw * s0 * z) — negative, since dragging right reveals
  // more of the left. Same for y. No slack on an axis (the image exactly
  // fills it) means nothing to move.
  void _panBy(Offset delta, Size box) {
    final image = _imageSize;
    if (image == null || image.isEmpty || box.isEmpty) return;
    final s0 = [
      box.width / image.width,
      box.height / image.height,
    ].reduce((a, b) => a > b ? a : b);
    final slackX = box.width - image.width * s0 * _framing.zoom;
    final slackY = box.height - image.height * s0 * _framing.zoom;
    _set(
      _framing.copyWith(
        focusX: slackX.abs() < 0.5
            ? _framing.focusX
            : _framing.focusX + delta.dx / slackX,
        focusY: slackY.abs() < 0.5
            ? _framing.focusY
            : _framing.focusY + delta.dy / slackY,
      ),
    );
  }

  // Mirrors how the card will really render it: a chef photo left at its
  // default is stored as untouched, and the chef card shows an untouched
  // photo at its own default (PhotoFraming.storedForChef/forChefCard).
  PhotoFraming get _cardFraming =>
      _isChef ? _framing.storedForChef.forChefCard : _framing;

  Widget _image(Alignment alignment) => Image(
    image: widget.image,
    fit: BoxFit.cover,
    alignment: alignment,
    gaplessPlayback: true,
  );

  // VenueDetailHero / PrivateChefHero's own expandedHeight defaults.
  double get _heroExpandedHeight => _isChef ? 320.0 : 300.0;

  @override
  Widget build(BuildContext context) {
    final cardAspectRatio = _isChef ? 4 / 5 : 1.0;
    final screenWidth = MediaQuery.sizeOf(context).width;
    // The device's own status bar, from the view itself: this editor sits
    // under a Scaffold/AppBar, which removes the top padding from
    // MediaQuery (padding and viewPadding both read 0 here). The real hero
    // has no AppBar above it, so it does extend under the status bar.
    final view = View.of(context);
    final statusBar = view.padding.top / view.devicePixelRatio;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label('AS THE HEADER'),
        const SizedBox(height: CsSpacing.xs),
        Text(
          'Drag to position, pinch to zoom. The shaded strip sits behind '
          'the status bar and buttons.',
          style: CsTypography.metadata.copyWith(color: AppColors.taupe),
        ),
        const SizedBox(height: CsSpacing.sm),
        LayoutBuilder(
          builder: (context, constraints) {
            // The real hero is screenWidth x (expandedHeight + status bar);
            // scaled to this page's width, same shape.
            final scale = screenWidth <= 0
                ? 1.0
                : constraints.maxWidth / screenWidth;
            final box = Size(
              constraints.maxWidth,
              (_heroExpandedHeight + statusBar) * scale,
            );
            final coveredStrip = (statusBar + kToolbarHeight) * scale;
            return Semantics(
              label: 'Photo position and zoom',
              // Claims every touch inside the frame straight away, so the
              // screen's own scroll view can't take a vertical drag meant
              // for the photo; the page still scrolls from outside it.
              child: RawGestureDetector(
                gestures: {
                  _EagerScaleGestureRecognizer:
                      GestureRecognizerFactoryWithHandlers<
                        _EagerScaleGestureRecognizer
                      >(_EagerScaleGestureRecognizer.new, (recognizer) {
                        recognizer.onStart = (_) {
                          _zoomAtGestureStart = _framing.zoom;
                        };
                        recognizer.onUpdate = (details) {
                          if (details.pointerCount > 1) {
                            _set(
                              _framing.copyWith(
                                zoom: _zoomAtGestureStart * details.scale,
                              ),
                            );
                          }
                          _panBy(details.focalPointDelta, box);
                        };
                      }),
                },
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: SizedBox(
                    width: box.width,
                    height: box.height,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        FramedImage(framing: _framing, builder: _image),
                        Positioned(
                          top: 0,
                          left: 0,
                          right: 0,
                          height: coveredStrip,
                          child: IgnorePointer(
                            child: DecoratedBox(
                              key: const ValueKey('covered-strip'),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.32),
                                border: Border(
                                  bottom: BorderSide(
                                    color: AppColors.ivory.withValues(
                                      alpha: 0.6,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
        const SizedBox(height: CsSpacing.sm),
        Row(
          children: [
            const Icon(
              Icons.zoom_out_rounded,
              size: 18,
              color: AppColors.taupe,
            ),
            Expanded(
              child: Slider(
                value: _framing.zoom,
                min: PhotoFraming.minZoom,
                max: PhotoFraming.maxZoom,
                activeColor: AppColors.forestGreen,
                label: 'Zoom',
                semanticFormatterCallback: (v) =>
                    'Zoom ${v.toStringAsFixed(1)} times',
                onChanged: (v) => _set(_framing.copyWith(zoom: v)),
              ),
            ),
            const Icon(Icons.zoom_in_rounded, size: 18, color: AppColors.taupe),
            const SizedBox(width: CsSpacing.sm),
            TextButton(
              onPressed: _framing == widget.defaultFraming
                  ? null
                  : () => _set(widget.defaultFraming),
              child: Text(
                'Reset',
                style: CsTypography.metadata.copyWith(
                  color: _framing == widget.defaultFraming
                      ? AppColors.taupe.withValues(alpha: 0.5)
                      : AppColors.forestGreen,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: CsSpacing.md),
        _label('AS A CARD'),
        const SizedBox(height: CsSpacing.sm),
        SizedBox(
          width: 160,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: AspectRatio(
              aspectRatio: cardAspectRatio,
              child: FramedImage(framing: _cardFraming, builder: _image),
            ),
          ),
        ),
      ],
    );
  }

  Widget _label(String text) =>
      Text(text, style: CsTypography.eyebrow.copyWith(color: AppColors.taupe));
}

/// A ScaleGestureRecognizer that wins the gesture arena as soon as a
/// finger lands, instead of waiting for movement past the slop — by which
/// time an enclosing scroll view's vertical drag would already have won.
class _EagerScaleGestureRecognizer extends ScaleGestureRecognizer {
  @override
  void addAllowedPointer(PointerDownEvent event) {
    super.addAllowedPointer(event);
    resolve(GestureDisposition.accepted);
  }
}
