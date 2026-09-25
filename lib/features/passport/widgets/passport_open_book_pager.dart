import 'package:flutter/material.dart';
import '../../../core/theme/cs_spacing.dart';
import '../models/passport_stamp_item.dart';
import '../passport_booklet_data.dart';
import '../passport_stamp_source.dart';
import 'passport_data_page.dart';
import 'passport_page.dart';
import 'passport_page_dots.dart';

/// The open book's whole swipeable content: the data page first, then
/// every stamp page for [volume]'s own scope, grouped by year (see
/// [buildYearGroupedStampPages]) — one continuous [PageView], not two
/// separate widgets, so swiping in from the data page straight into the
/// stamp pages is a single gesture, matching the design spec's own
/// "horizontaal swipen vanaf de gegevenspagina gaat door alle
/// stempelpagina's." Page dots below treat the data page as page 0, exactly
/// as specced ("waarbij de gegevenspagina de eerste is").
class PassportOpenBookPager extends StatefulWidget {
  final PassportVolume volume;
  final String holderName;
  final String? avatarUrl;
  final int? memberNumber;
  final Size size;
  final Map<String, String> countryNameByCode;

  /// Ids of any visit/stay/attendance that just appeared since the last
  /// load (see PassportCollectionBody) — used only to auto-scroll to the
  /// page holding one of them, same as the pre-booklet stamp pager did.
  final Set<String> newStampIds;

  /// False removes the dashed "Add your next stamp" empty slot from every
  /// stamp page — see [buildYearGroupedStampPages]'s own doc comment.
  /// Defaults to true, the current-user booklet's unchanged behavior.
  final bool includeNextStampSlot;

  /// Which page to open on — PassportCollectionBody's own "remember which
  /// page" state, restored when reopening the same volume you last closed.
  final int initialPage;
  final ValueChanged<int> onPageChanged;
  final void Function(PassportStampItem item) onTapStamp;
  final VoidCallback onTapNextStamp;

  const PassportOpenBookPager({
    super.key,
    required this.volume,
    required this.holderName,
    required this.avatarUrl,
    required this.memberNumber,
    required this.size,
    required this.countryNameByCode,
    required this.newStampIds,
    this.includeNextStampSlot = true,
    required this.initialPage,
    required this.onPageChanged,
    required this.onTapStamp,
    required this.onTapNextStamp,
  });

  @override
  State<PassportOpenBookPager> createState() => _PassportOpenBookPagerState();
}

class _PassportOpenBookPagerState extends State<PassportOpenBookPager> {
  late final PageController _controller;
  late int _currentPage;

  // The controller's own live, fractional page position — updated on
  // every scroll frame so each page's own background parallax offset can
  // track exactly how far it is from being centered, not just which page
  // is nominally "current". Starts equal to the initial page so nothing
  // drifts before the first real scroll event.
  late double _livePage;

  @override
  void initState() {
    super.initState();
    _currentPage = widget.initialPage;
    _livePage = widget.initialPage.toDouble();
    _controller = PageController(initialPage: _currentPage);
    _controller.addListener(_onScroll);
  }

  void _onScroll() {
    final page = _controller.page;
    if (page != null) setState(() => _livePage = page);
  }

  @override
  void didUpdateWidget(covariant PassportOpenBookPager oldWidget) {
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

  @override
  void dispose() {
    _controller.removeListener(_onScroll);
    _controller.dispose();
    super.dispose();
  }

  List<PassportStampPage> get _stampPages => buildYearGroupedStampPages(
    widget.volume.items,
    includeNextStampSlot: widget.includeNextStampSlot,
  );

  /// +1 throughout: index 0 in the returned page list is always the data
  /// page, so every stamp page's own index in [_stampPages] sits one
  /// position later in the pager.
  int? _pageIndexWithNewStamp() {
    if (widget.newStampIds.isEmpty) return null;
    final stampPages = _stampPages;
    for (var p = 0; p < stampPages.length; p++) {
      for (final slot in stampPages[p].slots) {
        if (slot is FilledStampSlot && widget.newStampIds.contains(slot.item.id)) {
          return p + 1;
        }
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final stampPages = _stampPages;
    final totalPages = 1 + stampPages.length;
    final activeIndex = _currentPage.clamp(0, totalPages - 1);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          width: widget.size.width,
          height: widget.size.height,
          child: PageView.builder(
            controller: _controller,
            itemCount: totalPages,
            onPageChanged: (i) {
              setState(() => _currentPage = i);
              widget.onPageChanged(i);
            },
            itemBuilder: (context, i) {
              if (i == 0) {
                return PassportDataPage(
                  volume: widget.volume,
                  holderName: widget.holderName,
                  avatarUrl: widget.avatarUrl,
                  memberNumber: widget.memberNumber,
                );
              }
              final stampPage = stampPages[i - 1];
              // A subtle background drift, capped at ±24pt — "een
              // pagerende scroll met een subtiel parallax-effect."
              // Positive while a page is still arriving from the right,
              // negative once it's departing to the left; exactly 0 once
              // centered, so a page at rest never looks shifted.
              final parallaxDx = ((i - _livePage) * 24).clamp(-24.0, 24.0);
              return PassportPage(
                slots: stampPage.slots,
                headerLabel: 'ENTRIES · VISAS',
                pageNumber: i + 1,
                year: stampPage.year,
                size: widget.size,
                parallaxDx: parallaxDx,
                countryNameByCode: widget.countryNameByCode,
                newStampIds: widget.newStampIds,
                onTapStamp: widget.onTapStamp,
                onTapNextStamp: widget.onTapNextStamp,
              );
            },
          ),
        ),
        const SizedBox(height: CsSpacing.md),
        PassportPageDots(count: totalPages, activeIndex: activeIndex),
      ],
    );
  }
}
