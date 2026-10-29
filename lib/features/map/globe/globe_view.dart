import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/app_colors.dart';
import '../models/map_pin.dart';
import '../widgets/venue_pin.dart';
import 'globe_camera.dart';
import 'globe_outlines.dart';
import 'globe_painter.dart';

/// Drives a [GlobeView] from outside — the globe's counterpart to
/// flutter_map's MapController. Calls made before the view is attached are
/// ignored.
class GlobeController {
  _GlobeViewState? _state;

  GlobeCamera? get camera => _state?._camera.value;

  /// Flies to the camera that frames every point (see [fitGlobeCamera]).
  Future<void> fitTo(List<(double, double)> points) async {
    final state = _state;
    if (state == null) return;
    await state._flyTo(fitGlobeCamera(points, fallback: state._camera.value));
  }

  /// Places the globe without animating: centred on the [points]' middle
  /// (latitude tilted no further than ±40°, so the globe stays upright),
  /// whole globe in view. Auto-rotation, if enabled, carries on from here.
  void showWholeGlobeAround(List<(double, double)> points) {
    final state = _state;
    if (state == null) return;
    final fit = fitGlobeCamera(points, fallback: state._camera.value);
    state._camera.value = state._camera.value.copyWith(
      latitude: fit.latitude.clamp(-40.0, 40.0),
      longitude: fit.longitude,
      zoom: GlobeCamera.minZoom,
    );
  }
}

/// My Map's 3D globe: drag to spin (with inertia), pinch to zoom, a slow
/// idle rotation that stops the moment the globe is touched. Pins that land
/// within a finger's width of each other merge into a numbered marker.
///
/// Tapping a pin flies to it, then calls [onPinTap]. Tapping a merged marker
/// flies in until its pins separate — or, when they can never separate
/// (several places in one building, say), flies to it and calls
/// [onClusterTap] with every pin in it.
///
/// Everything drawn comes from the bundled [GlobeOutlines] and the pins'
/// own coordinates: no tiles, no network, no location permission.
class GlobeView extends StatefulWidget {
  final GlobeController controller;
  final List<MapPin> pins;
  final Set<String> visitedCountryCodes;
  final ValueChanged<MapPin> onPinTap;
  final ValueChanged<List<MapPin>> onClusterTap;

  /// Idle rotation. Also off whenever the platform asks for reduced motion.
  final bool autoRotate;

  /// Defaults to [GlobeOutlines.load]; injectable for tests.
  final Future<GlobeOutlines>? outlines;

  const GlobeView({
    super.key,
    required this.controller,
    required this.pins,
    required this.visitedCountryCodes,
    required this.onPinTap,
    required this.onClusterTap,
    this.autoRotate = true,
    this.outlines,
  });

  @override
  State<GlobeView> createState() => _GlobeViewState();
}

class _GlobeViewState extends State<GlobeView> with TickerProviderStateMixin {
  /// Degrees of longitude per second at full idle speed — a full turn takes
  /// two minutes.
  static const _autoRotateSpeed = 3.0;
  static const _autoRotateRampUp = Duration(milliseconds: 1500);

  /// How long the globe waits, untouched and zoomed out, before it starts
  /// turning again.
  static const _resumeAfter = Duration(seconds: 12);
  static const _resumeMaxZoom = 1.3;
  static const _flyToPinMinZoom = 4.0;

  final _camera = ValueNotifier(const GlobeCamera(latitude: 30, longitude: 5));
  GlobeOutlines? _outlines;

  late final Ticker _ticker = createTicker(_onTick);
  Duration _lastTick = Duration.zero;
  double _velocityLat = 0, _velocityLon = 0; // degrees per second
  bool _autoRotating = false;
  double _autoRotateRamp = 0; // 0–1
  Timer? _resumeTimer;

  AnimationController? _flight;
  int _pointers = 0;
  double _scaleStartZoom = 1;
  int _scalePointers = 0;

  bool get _reduceMotion =>
      MediaQuery.maybeDisableAnimationsOf(context) ?? false;

  @override
  void initState() {
    super.initState();
    widget.controller._state = this;
    (widget.outlines ?? GlobeOutlines.load()).then((outlines) {
      if (mounted) setState(() => _outlines = outlines);
    }, onError: (Object e) => debugPrint('GlobeView: outlines failed: $e'));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _startAutoRotate();
    });
  }

  @override
  void didUpdateWidget(GlobeView old) {
    super.didUpdateWidget(old);
    if (old.controller != widget.controller) {
      old.controller._state = null;
      widget.controller._state = this;
    }
    if (!widget.autoRotate) _autoRotating = false;
  }

  @override
  void dispose() {
    if (widget.controller._state == this) widget.controller._state = null;
    _resumeTimer?.cancel();
    _flight?.dispose();
    _ticker.dispose();
    _camera.dispose();
    super.dispose();
  }

  // ── Motion ────────────────────────────────────────────────────────────

  void _startAutoRotate() {
    if (!widget.autoRotate || _reduceMotion) return;
    if (_camera.value.zoom > _resumeMaxZoom) return;
    _autoRotating = true;
    _autoRotateRamp = 0;
    _ensureTicking();
  }

  void _ensureTicking() {
    if (!_ticker.isActive) {
      _lastTick = Duration.zero;
      _ticker.start();
    }
  }

  void _onTick(Duration elapsed) {
    final dt = (elapsed - _lastTick).inMicroseconds / 1e6;
    _lastTick = elapsed;
    if (dt <= 0) return;
    var camera = _camera.value;
    if (_velocityLat.abs() + _velocityLon.abs() > 0.5) {
      camera = camera.copyWith(
        latitude: camera.latitude + _velocityLat * dt,
        longitude: camera.longitude + _velocityLon * dt,
      );
      final decay = math.exp(-dt * 2.8);
      _velocityLat *= decay;
      _velocityLon *= decay;
    } else if (_autoRotating) {
      _velocityLat = _velocityLon = 0;
      _autoRotateRamp = math.min(
        1,
        _autoRotateRamp + dt * 1e6 / _autoRotateRampUp.inMicroseconds,
      );
      final eased = Curves.easeInOut.transform(_autoRotateRamp);
      camera = camera.copyWith(
        longitude: camera.longitude + _autoRotateSpeed * eased * dt,
      );
    } else {
      _velocityLat = _velocityLon = 0;
      _ticker.stop();
      return;
    }
    _camera.value = camera;
  }

  /// Stops every kind of motion — inertia, idle rotation and any flight in
  /// progress. Called on every touch, before a gesture is even recognised.
  void _halt() {
    _resumeTimer?.cancel();
    _autoRotating = false;
    _velocityLat = _velocityLon = 0;
    _flight?.stop();
  }

  void _scheduleResume() {
    _resumeTimer?.cancel();
    _resumeTimer = Timer(_resumeAfter, () {
      if (mounted && _pointers == 0 && !(_flight?.isAnimating ?? false)) {
        _startAutoRotate();
      }
    });
  }

  Future<void> _flyTo(GlobeCamera target) async {
    _halt();
    final from = _camera.value;
    final to = target.copyWith();
    if (_reduceMotion) {
      _camera.value = to;
      _scheduleResume();
      return;
    }
    final distance = angularDistance(
      from.latitude,
      from.longitude,
      to.latitude,
      to.longitude,
    );
    final zoomChange = (math.log(to.zoom) - math.log(from.zoom)).abs();
    final ms = (550 + distance * 5 + zoomChange * 160).clamp(550, 1500);
    _flight?.dispose();
    final flight = _flight = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: ms.round()),
    );
    final curve = CurvedAnimation(parent: flight, curve: Curves.easeInOutCubic);
    flight.addListener(() => _camera.value = from.lerpTo(to, curve.value));
    try {
      await flight.forward().orCancel;
    } on TickerCanceled {
      return; // interrupted by a touch — that touch owns the globe now.
    }
    _scheduleResume();
  }

  // ── Gestures ──────────────────────────────────────────────────────────

  void _onScaleStart(ScaleStartDetails details) {
    _scaleStartZoom = _camera.value.zoom;
    _scalePointers = details.pointerCount;
  }

  void _onScaleUpdate(ScaleUpdateDetails details, Size size) {
    _scalePointers = math.max(_scalePointers, details.pointerCount);
    final camera = _camera.value;
    final radius = globeBaseRadius(size) * camera.zoom;
    final cosLat = math.max(math.cos(camera.latitude * math.pi / 180), 0.3);
    final delta = details.focalPointDelta;
    _camera.value = camera.copyWith(
      latitude: camera.latitude + delta.dy / radius * 180 / math.pi,
      longitude:
          camera.longitude - delta.dx / (radius * cosLat) * 180 / math.pi,
      zoom: details.pointerCount >= 2
          ? _scaleStartZoom * details.scale
          : camera.zoom,
    );
  }

  void _onScaleEnd(ScaleEndDetails details, Size size) {
    // A pinch ends with leftover finger velocity that isn't a fling.
    if (_scalePointers >= 2) return;
    final camera = _camera.value;
    final radius = globeBaseRadius(size) * camera.zoom;
    final cosLat = math.max(math.cos(camera.latitude * math.pi / 180), 0.3);
    final v = details.velocity.pixelsPerSecond;
    _velocityLat = v.dy / radius * 180 / math.pi;
    _velocityLon = -v.dx / (radius * cosLat) * 180 / math.pi;
    _ensureTicking();
  }

  // ── Pins ──────────────────────────────────────────────────────────────

  Future<void> _tapPin(MapPin pin) async {
    final camera = _camera.value;
    await _flyTo(
      camera.copyWith(
        latitude: pin.latitude,
        longitude: pin.longitude,
        zoom: math.max(camera.zoom, _flyToPinMinZoom),
      ),
    );
    if (mounted) widget.onPinTap(pin);
  }

  Future<void> _tapCluster(List<MapPin> members, Size size) async {
    final camera = _camera.value;
    final points = [for (final p in members) (p.latitude, p.longitude)];
    final fitted = fitGlobeCamera(
      points,
      fallback: camera,
      singlePointZoom: GlobeCamera.maxZoom,
    );
    final separate =
        clusterOnGlobe(
          members,
          projection: GlobeProjection(fitted, size),
          latitude: (p) => p.latitude,
          longitude: (p) => p.longitude,
        ).length >
        1;
    if (separate) {
      await _flyTo(fitted);
      return;
    }
    await _flyTo(
      camera.copyWith(
        latitude: fitted.latitude,
        longitude: fitted.longitude,
        zoom: math.max(camera.zoom, _flyToPinMinZoom),
      ),
    );
    if (mounted) widget.onClusterTap(members);
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final size = constraints.biggest;
      // Zoomed in, the disc is far larger than the view — clip it, or it
      // paints over the header above.
      return ClipRect(
        child: Listener(
          onPointerDown: (_) {
            _pointers++;
            _halt();
          },
          onPointerUp: (_) => _pointerLifted(),
          onPointerCancel: (_) => _pointerLifted(),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onScaleStart: _onScaleStart,
            onScaleUpdate: (d) => _onScaleUpdate(d, size),
            onScaleEnd: (d) => _onScaleEnd(d, size),
            child: Stack(
              children: [
                Positioned.fill(
                  child: RepaintBoundary(
                    child: CustomPaint(
                      painter: GlobePainter(
                        camera: _camera,
                        outlines: _outlines,
                        visitedCountryCodes: widget.visitedCountryCodes,
                      ),
                    ),
                  ),
                ),
                Positioned.fill(
                  child: ValueListenableBuilder<GlobeCamera>(
                    valueListenable: _camera,
                    builder: (context, camera, _) => Stack(
                      children: [
                        for (final cluster in clusterOnGlobe(
                          widget.pins,
                          projection: GlobeProjection(camera, size),
                          latitude: (p) => p.latitude,
                          longitude: (p) => p.longitude,
                        ))
                          _positioned(cluster, size),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );

  void _pointerLifted() {
    _pointers = math.max(0, _pointers - 1);
    if (_pointers == 0) _scheduleResume();
  }

  Widget _positioned(GlobeCluster<MapPin> cluster, Size size) {
    final single = cluster.members.length == 1;
    final pin = cluster.members.first;
    return Positioned(
      key: ValueKey(single ? pin.id : 'cluster:${pin.id}'),
      left: cluster.position.dx - VenuePin.size / 2,
      top: cluster.position.dy - VenuePin.size / 2,
      width: VenuePin.size,
      height: VenuePin.size,
      child: Opacity(
        opacity: cluster.opacity,
        child: IgnorePointer(
          ignoring: cluster.opacity < 0.5,
          child: single
              ? Semantics(
                  button: true,
                  label: pin.title,
                  child: VenuePin(type: pin.type, onTap: () => _tapPin(pin)),
                )
              : Semantics(
                  button: true,
                  label: '${cluster.members.length} places',
                  child: GlobeClusterPin(
                    count: cluster.members.length,
                    onTap: () => _tapCluster(cluster.members, size),
                  ),
                ),
        ),
      ),
    );
  }
}

/// Several pins merged into one marker — the same deepGreen disc and ivory
/// ring as [VenuePin], with the count in place of the icon.
class GlobeClusterPin extends StatelessWidget {
  final int count;
  final VoidCallback onTap;

  const GlobeClusterPin({super.key, required this.count, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: VenuePin.size,
      height: VenuePin.size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.deepGreen,
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.ivory, width: 2),
        boxShadow: const [
          BoxShadow(color: Colors.black38, blurRadius: 4, offset: Offset(0, 2)),
        ],
      ),
      child: Text(
        count > 99 ? '99+' : '$count',
        style: GoogleFonts.inter(
          color: AppColors.ivory,
          fontSize: count > 99 ? 11 : 13,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
  );
}
