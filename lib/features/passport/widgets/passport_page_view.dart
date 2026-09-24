import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/cs_spacing.dart';
import '../models/passport_stamp_item.dart';
import '../passport_stamp_source.dart';
import 'passport_page.dart';

/// Swipeable Passport pages: a [PageView] of [PassportPage]s plus a
/// page-indicator dot row (active = a green pill, the rest = small stone
/// dots). When [newStampIds] is non-empty (a fresh load just added
/// stamp(s) — see PassportCollectionBody), auto-advances to the first
/// page containing one of them, so a just-logged visit's stamp is what
/// the user actually sees land, not left off-screen on whatever page they
/// happened to be viewing before.
class PassportPageView extends StatefulWidget {
  final List<List<PassportStampSlot>> pages;
  final String headerLabel;
  final Map<String, String> countryNameByCode;
  final Set<String> newStampIds;
  final void Function(PassportStampItem item) onTapStamp;
  final VoidCallback onTapNextStamp;

  const PassportPageView({
    super.key,
    required this.pages,
    required this.headerLabel,
    required this.countryNameByCode,
    required this.newStampIds,
    required this.onTapStamp,
    required this.onTapNextStamp,
  });

  @override
  State<PassportPageView> createState() => _PassportPageViewState();
}

class _PassportPageViewState extends State<PassportPageView> {
  late final PageController _controller;
  late int _currentPage;

  @override
  void initState() {
    super.initState();
    final target = _pageIndexWithNewStamp();
    _currentPage = target ?? 0;
    _controller = PageController(initialPage: _currentPage);
  }

  @override
  void didUpdateWidget(covariant PassportPageView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.newStampIds.isEmpty || widget.newStampIds == oldWidget.newStampIds) {
      return;
    }
    final target = _pageIndexWithNewStamp();
    if (target == null || target == _currentPage) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_controller.hasClients) return;
      _controller.animateToPage(
        target,
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOut,
      );
    });
  }

  int? _pageIndexWithNewStamp() {
    if (widget.newStampIds.isEmpty) return null;
    for (var p = 0; p < widget.pages.length; p++) {
      for (final slot in widget.pages[p]) {
        if (slot is FilledStampSlot && widget.newStampIds.contains(slot.item.id)) {
          return p;
        }
      }
    }
    return null;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: PassportPage.height,
          child: PageView.builder(
            controller: _controller,
            itemCount: widget.pages.length,
            onPageChanged: (i) => setState(() => _currentPage = i),
            itemBuilder: (context, i) => Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: CsSpacing.pageHorizontal,
              ),
              child: _PageBump(
                trigger: widget.pages[i].any(
                  (slot) =>
                      slot is FilledStampSlot &&
                      widget.newStampIds.contains(slot.item.id),
                ),
                child: PassportPage(
                  slots: widget.pages[i],
                  headerLabel: widget.headerLabel,
                  pageNumber: i + 1,
                  countryNameByCode: widget.countryNameByCode,
                  newStampIds: widget.newStampIds,
                  onTapStamp: widget.onTapStamp,
                  onTapNextStamp: widget.onTapNextStamp,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: CsSpacing.md),
        _PageDots(count: widget.pages.length, activeIndex: _currentPage),
      ],
    );
  }
}

class _PageDots extends StatelessWidget {
  final int count;
  final int activeIndex;
  const _PageDots({required this.count, required this.activeIndex});

  @override
  Widget build(BuildContext context) {
    if (count <= 1) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: CsSpacing.pageHorizontal),
      child: Row(
        children: [
          for (var i = 0; i < count; i++) ...[
            if (i > 0) const SizedBox(width: 6),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: i == activeIndex ? 18 : 6,
              height: 6,
              decoration: BoxDecoration(
                color: i == activeIndex
                    ? AppColors.forestGreen
                    : AppColors.secondaryOnDark.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PageBump extends StatefulWidget {
  final bool trigger;
  final Widget child;
  const _PageBump({required this.trigger, required this.child});

  @override
  State<_PageBump> createState() => _PageBumpState();
}

class _PageBumpState extends State<_PageBump> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 260),
  );
  late final Animation<double> _dy =
      TweenSequence([
        TweenSequenceItem(tween: Tween(begin: 0.0, end: 2.0), weight: 1),
        TweenSequenceItem(tween: Tween(begin: 2.0, end: 0.0), weight: 1),
      ]).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

  @override
  void initState() {
    super.initState();
    if (widget.trigger) {
      // Lands just after the stamp's own 220ms entrance so the page
      // visibly settles once the ink is "down", not simultaneously with
      // it.
      Future.delayed(const Duration(milliseconds: 220), () {
        if (mounted) _controller.forward();
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _controller,
    builder: (context, child) =>
        Transform.translate(offset: Offset(0, _dy.value), child: child),
    child: widget.child,
  );
}
