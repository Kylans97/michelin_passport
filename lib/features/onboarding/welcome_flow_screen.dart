import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../core/constants/app_colors.dart';
import '../../core/theme/cs_fonts.dart';
import '../../core/theme/cs_spacing.dart';
import '../../core/theme/cs_typography.dart';
import '../../core/widgets/cs_header_drawing.dart';
import '../../core/widgets/cs_primary_button.dart';
import '../../core/widgets/key_row.dart';
import '../../core/widgets/star_row.dart';
import '../../models/event.dart';
import '../../models/journey.dart';
import '../map/globe/globe_camera.dart';
import '../map/globe/globe_outlines.dart';
import '../map/globe/globe_painter.dart';
import '../passport/models/passport_stamp_award.dart';
import '../passport/passport_booklet_data.dart';
import '../passport/utils/passport_stamp_style.dart';
import '../passport/widgets/passport_stamp_painters.dart';
import '../passport/widgets/passport_cover.dart';

/// The six-page, swipe-through first-run welcome flow, shown once per
/// account (see OnboardingGate, which decides whether to show this at all
/// and owns the has_seen_welcome read/write; this widget has no Supabase
/// knowledge of its own). [onDone] fires from BOTH Skip and the final
/// "Begin" button, deliberately identical: either way the person has seen
/// it and it shouldn't show again.
///
/// Redesigned 2026-11-20 from the product owner's brief: a striking first
/// impression, and a member who understands what the app does once they
/// reach the end. One story in six pages: arrival (the slowly turning My
/// Map globe), events, where to go, planning, the Passport, and finally
/// the member's own Passport cover with their name and number.
///
/// Every picture is the app's own vocabulary (the globe outlines, the
/// header line drawings, the star and Key rows, the leather Passport
/// cover), never an invented venue, name or date. Gold appears only where
/// it already does elsewhere: the stars, the Key and the cover's foil.
/// Copy carries no dashes (product owner, 2026-11-20: "this is really AI
/// like").
///
/// Motion stays a whisper: the globe turns, the event drawings cross-fade,
/// one stamp presses in on the Passport page. All of it stops when the
/// system asks for reduced motion.
class WelcomeFlow extends StatefulWidget {
  final VoidCallback onDone;

  /// The member's first name for the last page's "Your Passport is
  /// ready, …". Null (not loaded, failed, or no display name) leaves the
  /// line without a name rather than inventing one.
  final String? firstName;

  /// Printed on the Passport cover exactly as the Passport itself prints
  /// it; null shows the cover's own "NO. —".
  final int? memberNumber;

  const WelcomeFlow({
    super.key,
    required this.onDone,
    this.firstName,
    this.memberNumber,
  });

  @override
  State<WelcomeFlow> createState() => _WelcomeFlowState();
}

class _WelcomeFlowState extends State<WelcomeFlow> {
  final _pageController = PageController();
  int _pageIndex = 0;

  static const _pageCount = 6;

  bool get _onLastPage => _pageIndex == _pageCount - 1;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _next() => _pageController.nextPage(
    duration: const Duration(milliseconds: 450),
    curve: Curves.easeOutCubic,
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.deepGreen,
    body: SafeArea(
      child: Column(
        children: [
          SizedBox(
            height: 48,
            child: Align(
              alignment: Alignment.centerRight,
              // Hidden on the final page: it has its own clear CTA, and a
              // second dismiss action there would just be clutter.
              child: _onLastPage
                  ? null
                  : Padding(
                      padding: const EdgeInsets.only(right: CsSpacing.sm),
                      child: TextButton(
                        onPressed: widget.onDone,
                        child: Text(
                          'Skip',
                          style: CsTypography.bodyMedium.copyWith(
                            color: AppColors.secondaryOnDark,
                          ),
                        ),
                      ),
                    ),
            ),
          ),
          Expanded(
            child: PageView(
              controller: _pageController,
              onPageChanged: (index) => setState(() => _pageIndex = index),
              children: [
                const _WelcomePage(
                  visual: _ArrivalVisual(),
                  eyebrow: null,
                  title: 'The tables, rooms and evenings worth travelling for',
                  body: 'Find them, plan them, and keep every one of them.',
                  wordmark: true,
                ),
                _WelcomePage(
                  visual: _EveningsVisual(active: _pageIndex == 1),
                  eyebrow: 'EVENTS',
                  title: 'Some evenings only happen once',
                  body:
                      'Four hands dinners, guest chefs, winemaker nights and '
                      'galas across Europe. Mark Interested or Going, and '
                      'see which friends will be there.',
                ),
                const _WelcomePage(
                  visual: _WhereToGoVisual(),
                  eyebrow: 'EXPLORE',
                  title: 'Know where to go',
                  body:
                      "Restaurants, Key hotels, wine estates and private "
                      "chefs, chosen by MICHELIN, The World's 50 Best, "
                      'Gault&Millau and our own Selection. Follow the chefs '
                      'and places you love.',
                ),
                const _WelcomePage(
                  visual: _PlanVisual(),
                  eyebrow: 'WISHLIST  ·  TRIPS',
                  title: 'Plan the journey',
                  body:
                      'Save the places you dream of, then shape them into a '
                      'trip, day by day, with the evenings on your route '
                      'already in view.',
                ),
                _WelcomePage(
                  visual: _KeepVisual(active: _pageIndex == 4),
                  eyebrow: 'PASSPORT',
                  title: "Keep what you've tasted",
                  body:
                      'Every table, stay and evening you record becomes a '
                      'stamp in your Passport, and each country lights up '
                      'on My Map. Private unless you choose to share.',
                ),
                _WelcomePage(
                  visual: _PassportVisual(memberNumber: widget.memberNumber),
                  eyebrow: null,
                  title: _readyTitle(widget.firstName),
                  body:
                      'Start exploring your culinary journey. Find new '
                      'spots, enjoy new experiences, and remember them '
                      'forever.',
                  centered: true,
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              CsSpacing.xxl,
              CsSpacing.base,
              CsSpacing.base,
              CsSpacing.base,
            ),
            child: _onLastPage
                ? Padding(
                    padding: const EdgeInsets.only(right: CsSpacing.base),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: double.infinity,
                          child: CsPrimaryButton(
                            label: 'Begin',
                            onTap: widget.onDone,
                          ),
                        ),
                        const SizedBox(height: CsSpacing.md),
                        // The one line for venues in the guests' flow
                        // (product owner, 2026-11-25).
                        Text(
                          'Own a venue? You can claim it any time in Profile.',
                          textAlign: TextAlign.center,
                          style: CsTypography.metadata.copyWith(
                            color: AppColors.secondaryOnDark,
                          ),
                        ),
                      ],
                    ),
                  )
                : SizedBox(
                    height: 52,
                    child: Row(
                      children: [
                        _PageDots(count: _pageCount, index: _pageIndex),
                        const Spacer(),
                        TextButton(
                          onPressed: _next,
                          child: Text(
                            'Next',
                            style: CsTypography.bodyMedium.copyWith(
                              color: AppColors.ivory,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    ),
  );
}

String _readyTitle(String? firstName) {
  final name = firstName?.trim();
  return name == null || name.isEmpty
      ? 'Your Passport is ready'
      : 'Your Passport is ready, $name';
}

bool _reduceMotion(BuildContext context) =>
    MediaQuery.maybeDisableAnimationsOf(context) ?? false;

/// One page: the picture takes whatever height the text leaves, the text
/// sits in a fixed rhythm below it so titles line up from page to page.
class _WelcomePage extends StatelessWidget {
  final Widget visual;
  final String? eyebrow;
  final String title;
  final String body;
  final bool wordmark;
  final bool centered;

  const _WelcomePage({
    required this.visual,
    required this.eyebrow,
    required this.title,
    required this.body,
    this.wordmark = false,
    this.centered = false,
  });

  @override
  Widget build(BuildContext context) {
    final align = centered ? TextAlign.center : TextAlign.start;
    return Column(
      crossAxisAlignment: centered
          ? CrossAxisAlignment.center
          : CrossAxisAlignment.start,
      children: [
        Expanded(child: visual),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            CsSpacing.xxl,
            CsSpacing.xl,
            CsSpacing.xxl,
            0,
          ),
          child: Column(
            crossAxisAlignment: centered
                ? CrossAxisAlignment.center
                : CrossAxisAlignment.start,
            children: [
              if (wordmark) ...[
                SvgPicture.asset(
                  'assets/branding/wordmark-ivory.svg',
                  height: 28,
                  excludeFromSemantics: true,
                ),
                const SizedBox(height: CsSpacing.base),
              ],
              if (eyebrow != null) ...[
                Text(
                  eyebrow!,
                  style: CsTypography.eyebrow.copyWith(
                    color: AppColors.secondaryOnDark,
                    letterSpacing: 12 * 0.24,
                  ),
                ),
                const SizedBox(height: CsSpacing.md),
              ],
              Text(
                title,
                textAlign: align,
                style: CsTypography.screenTitle.copyWith(
                  color: AppColors.ivory,
                ),
              ),
              const SizedBox(height: CsSpacing.md),
              Text(
                body,
                textAlign: align,
                style: CsTypography.body.copyWith(
                  color: AppColors.secondaryOnDark,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// A soft fade from the picture into the page, so a drawing never ends on
/// a hard edge above the title.
class _FadeIntoPage extends StatelessWidget {
  const _FadeIntoPage();

  @override
  Widget build(BuildContext context) => const IgnorePointer(
    child: DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0x0016302A), AppColors.deepGreen],
        ),
      ),
    ),
  );
}

// ── 1 · Arrival ──────────────────────────────────────────────────────────

class _ArrivalVisual extends StatelessWidget {
  const _ArrivalVisual();

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final side = math.max(constraints.maxWidth * 1.3, constraints.maxHeight);
      return ClipRect(
        child: Stack(
          children: [
            Positioned(
              left: (constraints.maxWidth - side) / 2,
              top: (constraints.maxHeight - side) / 2 + side * 0.08,
              width: side,
              height: side,
              child: const _SpinningGlobe(
                // Benelux first, the way the catalogue started.
                latitude: 32,
                startLongitude: -10,
                litCountries: {'NL', 'BE', 'LU'},
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: constraints.maxHeight * 0.35,
              child: const _FadeIntoPage(),
            ),
          ],
        ),
      );
    },
  );
}

/// My Map's own globe painter, turning slowly on its own, with no pins and
/// no gestures (a drag here belongs to the page swipe).
class _SpinningGlobe extends StatefulWidget {
  final double latitude;
  final double startLongitude;
  final Set<String> litCountries;
  final Duration revolution;

  const _SpinningGlobe({
    required this.latitude,
    required this.startLongitude,
    required this.litCountries,
    this.revolution = const Duration(seconds: 90),
  });

  @override
  State<_SpinningGlobe> createState() => _SpinningGlobeState();
}

class _SpinningGlobeState extends State<_SpinningGlobe>
    with SingleTickerProviderStateMixin {
  late final AnimationController _turn = AnimationController(
    vsync: this,
    duration: widget.revolution,
  )..addListener(_onTick);
  late final _camera = ValueNotifier(
    GlobeCamera(latitude: widget.latitude, longitude: widget.startLongitude),
  );
  late final Future<GlobeOutlines> _outlines = GlobeOutlines.load();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_reduceMotion(context)) {
      _turn.stop();
    } else if (!_turn.isAnimating) {
      _turn.repeat();
    }
  }

  // Turning west to east, the way the earth does when seen from above the
  // north pole.
  void _onTick() => _camera.value = _camera.value.copyWith(
    longitude: widget.startLongitude - 360 * _turn.value,
  );

  @override
  void dispose() {
    _turn.dispose();
    _camera.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: FutureBuilder<GlobeOutlines>(
      future: _outlines,
      builder: (context, snapshot) => CustomPaint(
        size: Size.infinite,
        painter: GlobePainter(
          camera: _camera,
          outlines: snapshot.data,
          visitedCountryCodes: widget.litCountries,
        ),
      ),
    ),
  );
}

// ── 2 · Evenings ─────────────────────────────────────────────────────────

class _EveningsVisual extends StatefulWidget {
  final bool active;
  const _EveningsVisual({required this.active});

  @override
  State<_EveningsVisual> createState() => _EveningsVisualState();
}

class _EveningsVisualState extends State<_EveningsVisual> {
  // Three event types that each have their own drawing; the seeds only
  // fix which variant of a scene is drawn.
  static final _scenes = [
    HeaderDrawing.event('welcome-gala', EventType.gala),
    HeaderDrawing.event('welcome-dinner', EventType.dinner),
    HeaderDrawing.event('welcome-festival', EventType.festival),
  ];

  Timer? _timer;
  int _scene = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(covariant _EveningsVisual oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  // Cross-fades only while the page is on screen, so the member always
  // lands on the first drawing and nothing ticks behind other pages.
  void _sync() {
    final run = widget.active && !_reduceMotion(context);
    if (run && _timer == null) {
      _timer = Timer.periodic(const Duration(milliseconds: 4200), (_) {
        setState(() => _scene = (_scene + 1) % _scenes.length);
      });
    } else if (!run) {
      _timer?.cancel();
      _timer = null;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => Stack(
      children: [
        Positioned.fill(
          child: ExcludeSemantics(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 1400),
              child: CsHeaderDrawing(
                key: ValueKey(_scene),
                drawing: _scenes[_scene],
              ),
            ),
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          height: constraints.maxHeight * 0.4,
          child: const _FadeIntoPage(),
        ),
        Positioned(
          left: CsSpacing.xl,
          bottom: CsSpacing.base,
          child: Transform.rotate(
            angle: -2 * math.pi / 180,
            child: const _EventCardSketch(),
          ),
        ),
      ],
    ),
  );
}

/// The shape of an event card, not a real one: its type and tag in the
/// app's own words, then quiet bars where a name and place would be.
class _EventCardSketch extends StatelessWidget {
  const _EventCardSketch();

  @override
  Widget build(BuildContext context) => Container(
    width: 220,
    padding: const EdgeInsets.all(CsSpacing.base),
    decoration: BoxDecoration(
      color: AppColors.darkGreen.withValues(alpha: 0.88),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: AppColors.hairlineOnGreen),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'DINNER  ·  FOUR HANDS',
          style: CsTypography.eyebrow.copyWith(
            color: AppColors.secondaryOnDark,
            fontSize: 10,
            letterSpacing: 10 * 0.18,
          ),
        ),
        const SizedBox(height: CsSpacing.sm),
        const _Bar(width: 150, height: 9, alpha: 0.24),
        const SizedBox(height: 6),
        const _Bar(width: 100, height: 7, alpha: 0.12),
        const SizedBox(height: CsSpacing.md),
        Row(
          children: [
            const _FriendDot(color: AppColors.forestGreen),
            Transform.translate(
              offset: const Offset(-8, 0),
              child: const _FriendDot(color: AppColors.brandGreenLight),
            ),
            Text(
              'Friends going',
              style: CsTypography.metadata.copyWith(
                color: AppColors.secondaryOnDark,
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

class _FriendDot extends StatelessWidget {
  final Color color;
  const _FriendDot({required this.color});

  @override
  Widget build(BuildContext context) => Container(
    width: 20,
    height: 20,
    decoration: BoxDecoration(
      color: color,
      shape: BoxShape.circle,
      border: Border.all(color: AppColors.darkGreen, width: 1.5),
    ),
  );
}

class _Bar extends StatelessWidget {
  final double width;
  final double height;
  final double alpha;
  const _Bar({required this.width, required this.height, required this.alpha});

  @override
  Widget build(BuildContext context) => Container(
    width: width,
    height: height,
    decoration: BoxDecoration(
      color: AppColors.ivory.withValues(alpha: alpha),
      borderRadius: BorderRadius.circular(height / 2),
    ),
  );
}

// ── 3 · Where to go ──────────────────────────────────────────────────────

class _WhereToGoVisual extends StatelessWidget {
  const _WhereToGoVisual();

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final w = constraints.maxWidth;
      final h = constraints.maxHeight;
      final card = Size(
        math.min(w * 0.52, h * 0.62),
        math.min(w * 0.52, h * 0.62) * 1.25,
      );
      return ExcludeSemantics(
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              left: w * 0.06,
              top: h * 0.12,
              child: _TiltedCard(
                size: card,
                angle: -8,
                drawing: const HeaderDrawing.vineyard('welcome-estate'),
                // Two short lines, so the label clears the front card.
                award: Text(
                  "WORLD'S\n50 BEST",
                  style: CsTypography.eyebrow.copyWith(
                    color: AppColors.secondaryOnDark,
                    fontSize: 10,
                    height: 1.4,
                    letterSpacing: 10 * 0.16,
                  ),
                ),
              ),
            ),
            Positioned(
              right: w * 0.06,
              top: h * 0.04,
              child: _TiltedCard(
                size: card,
                angle: 7,
                alignEnd: true,
                drawing: const HeaderDrawing.hotel('welcome-hotel'),
                award: const KeyRow(count: 1, size: 16),
              ),
            ),
            Positioned(
              left: (w - card.width * 0.92) / 2,
              bottom: 0,
              child: _TiltedCard(
                size: card * 0.92,
                angle: 0,
                lifted: true,
                drawing: const HeaderDrawing.restaurant('welcome-restaurant'),
                award: const StarRow(count: 3, size: 15),
              ),
            ),
          ],
        ),
      );
    },
  );
}

class _TiltedCard extends StatelessWidget {
  final Size size;
  final double angle;
  final HeaderDrawing drawing;
  final Widget award;
  final bool lifted;

  /// Puts the award and name bar on the right, for the card whose left
  /// side sits behind the front one.
  final bool alignEnd;

  const _TiltedCard({
    required this.size,
    required this.angle,
    required this.drawing,
    required this.award,
    this.lifted = false,
    this.alignEnd = false,
  });

  @override
  Widget build(BuildContext context) => Transform.rotate(
    angle: angle * math.pi / 180,
    child: Container(
      width: size.width,
      height: size.height,
      decoration: BoxDecoration(
        color: lifted ? AppColors.forestGreen : AppColors.darkGreen,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.hairlineOnGreen),
        boxShadow: lifted
            ? const [
                BoxShadow(
                  color: Color(0x59000000),
                  blurRadius: 40,
                  offset: Offset(0, 18),
                ),
              ]
            : null,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: CsHeaderDrawing(drawing: drawing)),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
            child: Column(
              crossAxisAlignment: alignEnd
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.start,
              children: [
                award,
                const SizedBox(height: CsSpacing.sm),
                _Bar(width: size.width * 0.6, height: 8, alpha: 0.22),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

// ── 4 · Plan ─────────────────────────────────────────────────────────────

class _PlanVisual extends StatelessWidget {
  const _PlanVisual();

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => ExcludeSemantics(
      child: Stack(
        children: [
          // The train runs along the bottom; the route is drawn in the
          // open sky above it.
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: constraints.maxHeight * 0.62,
            child: CsHeaderDrawing(
              drawing: HeaderDrawing.journey(
                'welcome-train',
                JourneyKind.train,
              ),
            ),
          ),
          const Positioned.fill(child: CustomPaint(painter: _RoutePainter())),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: constraints.maxHeight * 0.3,
            child: const _FadeIntoPage(),
          ),
          Positioned(
            right: CsSpacing.xl,
            top: constraints.maxHeight * 0.4,
            child: const _Chip(
              icon: Icons.bookmark_rounded,
              label: 'Saved to Wishlist',
            ),
          ),
          Positioned(
            left: CsSpacing.xl,
            top: constraints.maxHeight * 0.04,
            child: const _DaySketch(),
          ),
        ],
      ),
    ),
  );
}

/// Three stops joined by a dotted line, the way a trip reads on its map.
class _RoutePainter extends CustomPainter {
  const _RoutePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final a = Offset(size.width * 0.16, size.height * 0.5);
    final b = Offset(size.width * 0.48, size.height * 0.34);
    final c = Offset(size.width * 0.82, size.height * 0.16);
    final path = Path()
      ..moveTo(a.dx, a.dy)
      ..quadraticBezierTo(size.width * 0.26, size.height * 0.32, b.dx, b.dy)
      ..quadraticBezierTo(size.width * 0.68, size.height * 0.34, c.dx, c.dy);
    final dash = Paint()
      ..color = AppColors.ivory.withValues(alpha: 0.6)
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    for (final metric in path.computeMetrics()) {
      for (var d = 0.0; d < metric.length; d += 9) {
        canvas.drawPath(metric.extractPath(d, d + 2), dash);
      }
    }
    final glow = Paint()..color = AppColors.ivory.withValues(alpha: 0.09);
    final dot = Paint()..color = AppColors.ivory;
    for (final (p, r) in [(a, 4.0), (b, 4.0), (c, 5.0)]) {
      canvas.drawCircle(p, r * 4.5, glow);
      canvas.drawCircle(p, r, dot);
    }
  }

  @override
  bool shouldRepaint(covariant _RoutePainter oldDelegate) => false;
}

class _Chip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _Chip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    decoration: BoxDecoration(
      color: AppColors.darkGreen.withValues(alpha: 0.88),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: AppColors.hairlineOnGreen),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: AppColors.ivory),
        const SizedBox(width: CsSpacing.sm),
        Text(
          label,
          style: CsTypography.metadata.copyWith(color: AppColors.ivory),
        ),
      ],
    ),
  );
}

class _DaySketch extends StatelessWidget {
  const _DaySketch();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: AppColors.darkGreen.withValues(alpha: 0.88),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: AppColors.hairlineOnGreen),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'DAY 3',
          style: CsTypography.eyebrow.copyWith(
            color: AppColors.secondaryOnDark,
            fontSize: 10,
            letterSpacing: 10 * 0.18,
          ),
        ),
        const SizedBox(height: CsSpacing.sm),
        const Row(
          children: [
            _Bar(width: 6, height: 6, alpha: 1),
            SizedBox(width: CsSpacing.sm),
            _Bar(width: 72, height: 7, alpha: 0.24),
          ],
        ),
        const SizedBox(height: CsSpacing.sm),
        const Row(
          children: [
            _Bar(width: 6, height: 6, alpha: 0.4),
            SizedBox(width: CsSpacing.sm),
            _Bar(width: 54, height: 7, alpha: 0.14),
          ],
        ),
      ],
    ),
  );
}

// ── 5 · Keep ─────────────────────────────────────────────────────────────

class _KeepVisual extends StatefulWidget {
  final bool active;
  const _KeepVisual({required this.active});

  @override
  State<_KeepVisual> createState() => _KeepVisualState();
}

class _KeepVisualState extends State<_KeepVisual>
    with SingleTickerProviderStateMixin {
  // The last stamp presses in once, the first time this page is reached.
  late final AnimationController _press = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 750),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(covariant _KeepVisual oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  void _sync() {
    if (_reduceMotion(context)) {
      _press.value = 1;
    } else if (widget.active && _press.isDismissed) {
      _press.forward();
    }
  }

  @override
  void dispose() {
    _press.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final w = constraints.maxWidth;
      final h = constraints.maxHeight;
      final pageH = math.min(h * 0.9, w * 0.66 * 410 / 270);
      final pageW = pageH * 270 / 410;
      final globe = math.min(w * 0.3, h * 0.32);
      final stamp = pageW * 0.5;
      return ExcludeSemantics(
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              left: w * 0.1,
              top: (h - pageH) / 2,
              child: Transform.rotate(
                angle: -3 * math.pi / 180,
                child: _OpenPassport(
                  size: Size(pageW, pageH),
                  child: Stack(
                    children: [
                      Positioned(
                        left: pageW * 0.06,
                        top: pageH * 0.13,
                        child: _Stamp(
                          size: stamp,
                          angle: -8,
                          variant: StampVariant.roundSeal,
                          data: _stampData(
                            'welcome-stamp-a',
                            'Amsterdam',
                            'NL',
                            'Dinner',
                            const StarsAward(2),
                            StampInk.green,
                          ),
                        ),
                      ),
                      Positioned(
                        right: pageW * 0.04,
                        top: pageH * 0.45,
                        child: _Stamp(
                          size: stamp * 0.95,
                          angle: 7,
                          variant: StampVariant.oval,
                          data: _stampData(
                            'welcome-stamp-b',
                            'Paris',
                            'FR',
                            'Stay',
                            const KeysAward(1),
                            StampInk.deepGold,
                          ),
                        ),
                      ),
                      Positioned(
                        left: pageW * 0.1,
                        bottom: pageH * 0.04,
                        child: AnimatedBuilder(
                          animation: _press,
                          builder: (context, child) {
                            final t = Curves.easeOutCubic.transform(
                              _press.value,
                            );
                            return Opacity(
                              opacity: (_press.value * 2.5).clamp(0.0, 1.0),
                              child: Transform.scale(
                                scale: 1.35 - 0.35 * t,
                                child: child,
                              ),
                            );
                          },
                          child: _Stamp(
                            size: stamp * 1.05,
                            angle: 12,
                            variant: StampVariant.doubleFrame,
                            data: _stampData(
                              'welcome-stamp-c',
                              'Copenhagen',
                              'DK',
                              'Four hands',
                              const EventTypeAward('DINNER'),
                              StampInk.gold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              right: w * 0.04,
              top: h * 0.02,
              width: globe,
              height: globe,
              child: const _SpinningGlobe(
                latitude: 45,
                startLongitude: 5,
                litCountries: {'NL', 'FR', 'DK'},
                revolution: Duration(seconds: 60),
              ),
            ),
          ],
        ),
      );
    },
  );
}

/// What a sample stamp prints: a city, a kind of visit, never a venue's
/// name, and today's date, so nothing on it claims a visit that happened.
StampPaintData _stampData(
  String seed,
  String city,
  String countryCode,
  String what,
  StampAward award,
  StampInk ink,
) => StampPaintData(
  seedId: seed,
  cityName: city,
  countryCode: countryCode,
  venueName: what,
  date: DateUtils.dateOnly(DateTime.now()),
  award: award,
  ink: ink.color,
);

/// The Passport opened on a stamp page: the leather cover showing round
/// the edge, the page in the Passport's own paper and header.
class _OpenPassport extends StatelessWidget {
  final Size size;
  final Widget child;
  const _OpenPassport({required this.size, required this.child});

  @override
  Widget build(BuildContext context) => Container(
    width: size.width,
    height: size.height,
    padding: const EdgeInsets.fromLTRB(4, 6, 6, 6),
    decoration: const BoxDecoration(
      borderRadius: BorderRadius.only(
        topLeft: Radius.circular(6),
        bottomLeft: Radius.circular(6),
        topRight: Radius.circular(16),
        bottomRight: Radius.circular(16),
      ),
      gradient: RadialGradient(
        center: Alignment(-0.6, -0.7),
        radius: 1.4,
        colors: [AppColors.coverLeather, AppColors.coverLeatherDeep],
      ),
      boxShadow: [
        BoxShadow(
          color: Color(0x80000000),
          blurRadius: 50,
          offset: Offset(0, 22),
        ),
      ],
    ),
    child: Container(
      decoration: const BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(3),
          bottomLeft: Radius.circular(3),
          topRight: Radius.circular(12),
          bottomRight: Radius.circular(12),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          // The fold: a soft shadow along the spine, the way the
          // booklet's own pages read.
          const Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            width: 16,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0x2420261F), Color(0x0020261F)],
                ),
              ),
            ),
          ),
          Positioned(
            left: 18,
            right: 14,
            top: 14,
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'ENTRIES  ·  VISAS',
                    maxLines: 1,
                    style: CsFonts.sans(
                      color: AppColors.textSecondary,
                      fontSize: 9.5,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.4,
                    ),
                  ),
                ),
                Text(
                  'p. 01',
                  style: CsFonts.serif(
                    color: AppColors.textPrimary,
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
          Positioned.fill(child: child),
        ],
      ),
    ),
  );
}

/// One of the Passport's real stamp designs, drawn by the same painter the
/// Passport uses and scaled to [size] wide.
class _Stamp extends StatelessWidget {
  final double size;
  final double angle;
  final StampVariant variant;
  final StampPaintData data;

  const _Stamp({
    required this.size,
    required this.angle,
    required this.variant,
    required this.data,
  });

  @override
  Widget build(BuildContext context) {
    final natural = stampVariantSize(variant);
    return Transform.rotate(
      angle: angle * math.pi / 180,
      child: SizedBox(
        width: size,
        height: size * natural.height / natural.width,
        child: FittedBox(
          child: CustomPaint(
            size: natural,
            painter: stampPainterFor(variant, data),
          ),
        ),
      ),
    );
  }
}

// ── 6 · Your Passport ────────────────────────────────────────────────────

class _PassportVisual extends StatelessWidget {
  final int? memberNumber;
  const _PassportVisual({required this.memberNumber});

  static final _emptyVolume = PassportVolume(
    year: null,
    items: const [],
    countryCodes: const [],
    stars: 0,
    collectionFirstYear: null,
  );

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final height = math.min(
        constraints.maxHeight * 0.86,
        constraints.maxWidth *
            0.62 *
            PassportCoverFace.baseHeight /
            PassportCoverFace.baseWidth,
      );
      final width =
          height * PassportCoverFace.baseWidth / PassportCoverFace.baseHeight;
      return Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: height * 1.3,
            height: height * 1.3,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  AppColors.ivory.withValues(alpha: 0.08),
                  AppColors.ivory.withValues(alpha: 0),
                ],
              ),
            ),
          ),
          Semantics(
            image: true,
            label: memberNumber == null
                ? 'Your Passport'
                : 'Your Passport, number $memberNumber',
            child: ExcludeSemantics(
              child: DecoratedBox(
                decoration: const BoxDecoration(
                  boxShadow: [
                    BoxShadow(
                      color: Color(0x80000000),
                      blurRadius: 60,
                      offset: Offset(0, 26),
                    ),
                  ],
                ),
                child: PassportCoverFace(
                  volume: _emptyVolume,
                  memberNumber: memberNumber,
                  size: Size(width, height),
                ),
              ),
            ),
          ),
        ],
      );
    },
  );
}

/// Same 6px-circle, ivory-active/secondaryOnDark-inactive dot treatment as
/// PrivateChefHero's own `_PhotoPageIndicator`: that file's doc comment
/// is the precedent for this app's restrained, editorial (never numbered,
/// never a large pill control) page-indicator style. A private class in a
/// different file can't be imported directly, so this is a small,
/// deliberate duplication of that same visual spec rather than a forced
/// shared widget for what's currently exactly two call sites.
class _PageDots extends StatelessWidget {
  final int count;
  final int index;
  const _PageDots({required this.count, required this.index});

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < count; i++) ...[
          if (i > 0) const SizedBox(width: 6),
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: i == index
                  ? AppColors.ivory
                  : AppColors.secondaryOnDark.withValues(alpha: 0.5),
            ),
          ),
        ],
      ],
    ),
  );
}
