import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../core/constants/app_colors.dart';
import '../../core/theme/cs_spacing.dart';
import '../../core/theme/cs_typography.dart';
import '../../core/widgets/cs_image_placeholder.dart' show csMonogramAssetPath;
import '../../core/widgets/cs_primary_button.dart';

class _WelcomePageData {
  final String title;
  final String body;
  const _WelcomePageData({required this.title, required this.body});
}

const _textPages = [
  _WelcomePageData(
    title: 'Some evenings only happen once',
    body:
        'Four-hands dinners, guest chefs, winemaker nights — the '
        'evenings that exist once and are almost impossible to find.',
  ),
  _WelcomePageData(
    title: 'Know where to go',
    body:
        "Michelin, World's 50 Best and Gault&Millau, with the details "
        'that matter.',
  ),
  _WelcomePageData(
    title: "Keep what you've tasted",
    body: "Where you've been, where you still want to go, and who "
        "you'd go with.",
  ),
];

/// The four-screen, swipe-through first-run welcome flow — shown once per
/// account (see OnboardingGate, which decides whether to show this at all
/// and owns the has_seen_welcome read/write; this widget has no Supabase
/// knowledge of its own). [onDone] fires from BOTH Skip and the final
/// "Get started" button — deliberately identical, since nothing about this
/// flow distinguishes "skipped" from "completed": either way, the person
/// has seen it and it shouldn't show again.
///
/// No illustrations yet — text and the monogram only, per explicit
/// instruction; the images come later as a separate pass.
class WelcomeFlow extends StatefulWidget {
  final VoidCallback onDone;
  const WelcomeFlow({super.key, required this.onDone});

  @override
  State<WelcomeFlow> createState() => _WelcomeFlowState();
}

class _WelcomeFlowState extends State<WelcomeFlow> {
  final _pageController = PageController();
  int _pageIndex = 0;

  static const _pageCount = 4; // 3 text pages + the final monogram page

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.deepGreen,
    body: SafeArea(
      child: Stack(
        children: [
          PageView(
            controller: _pageController,
            onPageChanged: (index) => setState(() => _pageIndex = index),
            children: [
              for (final page in _textPages) _WelcomeTextPage(data: page),
              _WelcomeFinalPage(onGetStarted: widget.onDone),
            ],
          ),
          // Hidden on the final page — it already has its own clear CTA;
          // a second dismiss action there would just be clutter.
          if (_pageIndex < _pageCount - 1)
            Positioned(
              right: CsSpacing.base,
              top: CsSpacing.sm,
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
          Positioned(
            left: 0,
            right: 0,
            bottom: CsSpacing.xl,
            child: Center(
              child: _PageDots(count: _pageCount, index: _pageIndex),
            ),
          ),
        ],
      ),
    ),
  );
}

class _WelcomeTextPage extends StatelessWidget {
  final _WelcomePageData data;
  const _WelcomeTextPage({required this.data});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: CsSpacing.xxl),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          data.title,
          textAlign: TextAlign.center,
          style: CsTypography.screenTitle.copyWith(color: AppColors.ivory),
        ),
        const SizedBox(height: CsSpacing.md),
        Text(
          data.body,
          textAlign: TextAlign.center,
          style: CsTypography.body.copyWith(
            color: AppColors.secondaryOnDark,
          ),
        ),
      ],
    ),
  );
}

class _WelcomeFinalPage extends StatelessWidget {
  final VoidCallback onGetStarted;
  const _WelcomeFinalPage({required this.onGetStarted});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: CsSpacing.xxl),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SvgPicture.asset(csMonogramAssetPath, width: 80, height: 80),
        const SizedBox(height: CsSpacing.lg),
        Text(
          'Welcome to Mantelier',
          textAlign: TextAlign.center,
          style: CsTypography.screenTitle.copyWith(color: AppColors.ivory),
        ),
        const SizedBox(height: CsSpacing.xxl),
        CsPrimaryButton(label: 'Get started', onTap: onGetStarted),
      ],
    ),
  );
}

/// Same 6px-circle, ivory-active/secondaryOnDark-inactive dot treatment as
/// PrivateChefHero's own `_PhotoPageIndicator` — that file's doc comment
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
