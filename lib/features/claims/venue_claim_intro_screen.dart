import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/theme/cs_spacing.dart';
import '../../core/theme/cs_typography.dart';
import '../../core/widgets/cs_header_drawing.dart';
import '../../core/widgets/cs_primary_button.dart';
import '../../models/event.dart';
import 'claim_venue_screen.dart';

/// Three short pages for someone who runs a venue: what a venue can do on
/// Mantelier, how its guests find it, and how claiming works, ending on
/// "Claim my venue", which opens the existing claim flow
/// (ClaimVenueScreen). Designed with the product owner on 2026-11-25
/// (canvas https://claude.ai/artifact/TiM3WfXrgJDc3uZWkxffTT), in the
/// welcome flow's style.
///
/// Reached three ways: the quiet "Link your venue" when a new Passport is
/// issued, a `mantelier.app/claim` link from the website's venue guide
/// (ClaimLinkGate), and "How claiming works" on the claim screen itself.
/// From the claim screen ([fromClaimScreen]) the last page only leads
/// back there.
///
/// Nothing here decides anything: a claim stays a request reviewed by
/// hand, and permission to edit a venue comes only from an approved
/// manager row. Copy carries no dashes and no gold (product owner).
class VenueClaimIntroScreen extends StatefulWidget {
  const VenueClaimIntroScreen({
    super.key,
    this.fromClaimScreen = false,
    this.openClaim,
  });

  /// Opened from the claim screen: "Claim my venue" goes back to it, and
  /// there is no "Later".
  final bool fromClaimScreen;

  /// Test seam: what "Claim my venue" opens. Defaults to replacing this
  /// screen with ClaimVenueScreen.
  final void Function(BuildContext context)? openClaim;

  @override
  State<VenueClaimIntroScreen> createState() => _VenueClaimIntroScreenState();
}

class _VenueClaimIntroScreenState extends State<VenueClaimIntroScreen> {
  final _pageController = PageController();
  int _pageIndex = 0;

  static const _pageCount = 3;

  bool get _onLastPage => _pageIndex == _pageCount - 1;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _goTo(int page) => _pageController.animateToPage(
    page,
    duration: const Duration(milliseconds: 450),
    curve: Curves.easeOutCubic,
  );

  void _claim() {
    if (widget.fromClaimScreen) {
      Navigator.of(context).pop();
      return;
    }
    final open = widget.openClaim;
    if (open != null) {
      open(context);
      return;
    }
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(builder: (_) => const ClaimVenueScreen()),
    );
  }

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
              child: _onLastPage
                  ? null
                  : Padding(
                      padding: const EdgeInsets.only(right: CsSpacing.sm),
                      child: TextButton(
                        // Skip goes to how claiming works, where Later is.
                        onPressed: () => _goTo(_pageCount - 1),
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
                const _IntroPage(
                  visual: _VenuePageSketch(),
                  title: 'Your venue, in your own words',
                  body:
                      'Claim your restaurant, hotel or private dining and look '
                      'after its page yourself: your photos, your own '
                      'description, your events.',
                ),
                const _IntroPage(
                  visual: _GuestsSketch(),
                  title: 'Bring your guests with you',
                  body:
                      "Publish your own evenings, and share your venue's "
                      'invite link. Whoever opens it follows your venue, so '
                      'your evenings find them.',
                ),
                _HowItWorksPage(fromClaimScreen: widget.fromClaimScreen),
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
                            label: widget.fromClaimScreen
                                ? 'Back to my claim'
                                : 'Claim my venue',
                            onTap: _claim,
                          ),
                        ),
                        if (!widget.fromClaimScreen)
                          SizedBox(
                            width: double.infinity,
                            height: 48,
                            child: TextButton(
                              onPressed: () => Navigator.of(context).pop(),
                              child: Text(
                                'Later',
                                style: CsTypography.bodyMedium.copyWith(
                                  color: AppColors.secondaryOnDark,
                                ),
                              ),
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
                          onPressed: () => _goTo(_pageIndex + 1),
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

class _IntroPage extends StatelessWidget {
  final Widget visual;
  final String title;
  final String body;

  const _IntroPage({
    required this.visual,
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Expanded(child: ExcludeSemantics(child: visual)),
      Padding(
        padding: const EdgeInsets.fromLTRB(
          CsSpacing.xxl,
          CsSpacing.xl,
          CsSpacing.xxl,
          0,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'FOR VENUES',
              style: CsTypography.eyebrow.copyWith(
                color: AppColors.secondaryOnDark,
                letterSpacing: 12 * 0.24,
              ),
            ),
            const SizedBox(height: CsSpacing.md),
            Text(
              title,
              style: CsTypography.screenTitle.copyWith(color: AppColors.ivory),
            ),
            const SizedBox(height: CsSpacing.md),
            Text(
              body,
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

/// The shape of a venue page, not a real one: a drawn header, a row of
/// photos with room for one more, a few lines of the venue's own text.
class _VenuePageSketch extends StatelessWidget {
  const _VenuePageSketch();

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final h = math.min(constraints.maxHeight * 0.88, 380.0);
      final w = h * 0.73;
      return Center(
        child: Transform.rotate(
          angle: -3 * math.pi / 180,
          child: Container(
            width: w,
            height: h,
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(18),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x66000000),
                  blurRadius: 50,
                  offset: Offset(0, 22),
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  height: h * 0.5,
                  child: const CsHeaderDrawing(
                    drawing: HeaderDrawing.restaurant('venue-intro-page'),
                  ),
                ),
                Expanded(
                  // Clipped rather than squeezed: on a short phone the
                  // sketch just shows less of the page.
                  child: SingleChildScrollView(
                    physics: const NeverScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(CsSpacing.base),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _Bar(
                          width: w * 0.55,
                          height: 11,
                          color: AppColors.textPrimary,
                          alpha: 0.75,
                        ),
                        const SizedBox(height: CsSpacing.md),
                        Row(
                          children: [
                            for (final shade in const [
                              Color(0xFFD9D1C0),
                              Color(0xFFCFC6B3),
                              Color(0xFFE2DBCC),
                            ]) ...[
                              Expanded(
                                child: AspectRatio(
                                  aspectRatio: 1.3,
                                  child: DecoratedBox(
                                    decoration: BoxDecoration(
                                      color: shade,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                            ],
                            Expanded(
                              child: AspectRatio(
                                aspectRatio: 1.3,
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color: AppColors.textPrimary.withValues(
                                        alpha: 0.3,
                                      ),
                                    ),
                                  ),
                                  child: const Icon(
                                    Icons.add,
                                    size: 18,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: CsSpacing.md),
                        for (final f in const [0.85, 0.78, 0.55]) ...[
                          _Bar(
                            width: w * f,
                            height: 7,
                            color: AppColors.textPrimary,
                            alpha: 0.18,
                          ),
                          const SizedBox(height: 6),
                        ],
                        const SizedBox(height: CsSpacing.sm),
                        Text(
                          'MANAGED BY THE VENUE',
                          style: CsTypography.eyebrow.copyWith(
                            color: AppColors.textSecondary,
                            fontSize: 10,
                            letterSpacing: 10 * 0.16,
                          ),
                        ),
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
}

/// An event card's shape, and the venue's invite link with guests who
/// followed through it.
class _GuestsSketch extends StatelessWidget {
  const _GuestsSketch();

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final w = constraints.maxWidth;
      final h = constraints.maxHeight;
      final card = math.min(w * 0.64, h * 0.75);
      return Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: w * 0.1,
            top: h * 0.04,
            child: Transform.rotate(
              angle: -4 * math.pi / 180,
              child: Container(
                width: card,
                decoration: BoxDecoration(
                  color: AppColors.darkGreen,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.hairlineOnGreen),
                ),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      height: card * 0.56,
                      child: CsHeaderDrawing(
                        drawing: HeaderDrawing.event(
                          'venue-intro-event',
                          EventType.gala,
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'DINNER  ·  GUEST CHEF',
                            style: CsTypography.eyebrow.copyWith(
                              color: AppColors.secondaryOnDark,
                              fontSize: 10,
                              letterSpacing: 10 * 0.18,
                            ),
                          ),
                          const SizedBox(height: CsSpacing.sm),
                          _Bar(width: card * 0.62, height: 9, alpha: 0.24),
                          const SizedBox(height: 6),
                          _Bar(width: card * 0.42, height: 7, alpha: 0.12),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            right: w * 0.07,
            bottom: h * 0.16,
            child: Container(
              width: math.min(w * 0.6, 240),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(14),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x59000000),
                    blurRadius: 40,
                    offset: Offset(0, 18),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "YOUR VENUE'S INVITE LINK",
                    style: CsTypography.eyebrow.copyWith(
                      color: AppColors.textSecondary,
                      fontSize: 10,
                      letterSpacing: 10 * 0.16,
                    ),
                  ),
                  const SizedBox(height: CsSpacing.sm),
                  Row(
                    children: [
                      const Icon(
                        Icons.link,
                        size: 18,
                        color: AppColors.textPrimary,
                      ),
                      const SizedBox(width: CsSpacing.sm),
                      Flexible(
                        child: Text(
                          'mantelier.app/i/…',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: CsTypography.metadata.copyWith(
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: CsSpacing.sm),
                  Row(
                    children: [
                      const _Dot(color: AppColors.forestGreen),
                      Transform.translate(
                        offset: const Offset(-8, 0),
                        child: const _Dot(color: Color(0xFF6B8F83)),
                      ),
                      Flexible(
                        child: Text(
                          'Guests now following',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: CsTypography.metadata.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    },
  );
}

class _HowItWorksPage extends StatelessWidget {
  final bool fromClaimScreen;
  const _HowItWorksPage({required this.fromClaimScreen});

  static const _steps = [
    ('Find your venue', 'Search by name and tell us your role there.'),
    (
      'Add your business details',
      'A business email address and a phone number.',
    ),
    (
      'We review it by hand',
      'We may get in touch to confirm. You hear back in the app, and your '
          'venue appears under My venues.',
    ),
  ];

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: const EdgeInsets.fromLTRB(
      CsSpacing.xxl,
      CsSpacing.section,
      CsSpacing.xxl,
      CsSpacing.base,
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'CLAIMING YOUR VENUE',
          style: CsTypography.eyebrow.copyWith(
            color: AppColors.secondaryOnDark,
            letterSpacing: 12 * 0.24,
          ),
        ),
        const SizedBox(height: CsSpacing.md),
        Text(
          'How it works',
          style: CsTypography.screenTitle.copyWith(color: AppColors.ivory),
        ),
        const SizedBox(height: CsSpacing.xxl),
        for (var i = 0; i < _steps.length; i++) ...[
          if (i > 0) const SizedBox(height: CsSpacing.xl),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 28,
                child: Text(
                  '${i + 1}',
                  style: CsTypography.screenTitle.copyWith(
                    color: AppColors.secondaryOnDark,
                    fontSize: 24,
                    height: 1.1,
                  ),
                ),
              ),
              const SizedBox(width: CsSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _steps[i].$1,
                      style: CsTypography.bodyMedium.copyWith(
                        color: AppColors.ivory,
                      ),
                    ),
                    const SizedBox(height: CsSpacing.xs),
                    Text(
                      _steps[i].$2,
                      style: CsTypography.body.copyWith(
                        color: AppColors.secondaryOnDark,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
        if (!fromClaimScreen) ...[
          const SizedBox(height: CsSpacing.xxl),
          Text(
            'Not ready yet? You can claim any time from Profile.',
            style: CsTypography.metadata.copyWith(
              color: AppColors.secondaryOnDark,
            ),
          ),
        ],
      ],
    ),
  );
}

class _Bar extends StatelessWidget {
  final double width;
  final double height;
  final double alpha;
  final Color color;
  const _Bar({
    required this.width,
    required this.height,
    required this.alpha,
    this.color = AppColors.ivory,
  });

  @override
  Widget build(BuildContext context) => Container(
    width: width,
    height: height,
    decoration: BoxDecoration(
      color: color.withValues(alpha: alpha),
      borderRadius: BorderRadius.circular(height / 2),
    ),
  );
}

class _Dot extends StatelessWidget {
  final Color color;
  const _Dot({required this.color});

  @override
  Widget build(BuildContext context) => Container(
    width: 20,
    height: 20,
    decoration: BoxDecoration(
      color: color,
      shape: BoxShape.circle,
      border: Border.all(color: AppColors.background, width: 1.5),
    ),
  );
}

/// The welcome flow's dots: 6px circles, ivory for the page you are on.
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
