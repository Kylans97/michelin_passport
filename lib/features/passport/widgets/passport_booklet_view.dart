import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/app_colors.dart';
import '../models/passport_stamp_item.dart';
import '../passport_booklet_data.dart';
import 'passport_cover.dart';
import 'passport_open_book_pager.dart';

/// The whole booklet UI, generic over WHOSE data it shows: closed cover
/// (with yearly volumes fanned behind it) → 3D open → data page → stamp
/// pages, all self-contained state (open/closed, which volume, which
/// page, the flip animation). Extracted from `PassportCollectionBody` —
/// that widget originally owned this choreography directly, hardcoded to
/// `Supabase.instance.client.auth.currentUser`'s own data; it's now a
/// thin self-loading wrapper around this widget instead (see that file's
/// own doc comment), and the Friend Profile screen's read-only Passport
/// tab is this widget's second real caller — see
/// `friend_profile_passport_tab.dart`. Nothing in here reads
/// `currentUser` or performs any network I/O; every byte of data it shows
/// is a constructor parameter.
class PassportBookletView extends StatefulWidget {
  /// Whatever `buildPassportVolumes` returned — may legitimately be
  /// empty (no entries at all), in which case this widget renders a
  /// single synthetic empty "COMPLETE" cover with no volumes fanned
  /// behind it, matching the design spec's own "Geen bezoeken: alleen de
  /// omslag, geen volumes erachter."
  final List<PassportVolume> volumes;

  final String holderName;
  final String? avatarUrl;

  // Null renders the data page's/cover's own honest "—" fallback — never
  // guessed at here.
  final int? memberNumber;

  final Map<String, String> countryNameByCode;

  /// Ids of any visit/stay/attendance that just appeared since the last
  /// load — drives the "just stamped" entrance animation + auto-scroll.
  /// Defaults to empty (no entrance animation) for a caller with no
  /// concept of "just added" (e.g. a friend's read-only booklet).
  final Set<String> newStampIds;

  /// False removes the dashed "Add your next stamp" empty slot entirely
  /// from every stamp page — a friend's booklet isn't yours to add to.
  final bool includeNextStampSlot;

  final void Function(PassportStampItem item) onTapStamp;

  /// Never called when [includeNextStampSlot] is false (there's no slot
  /// to tap). Optional for exactly that case — a caller that never shows
  /// the slot doesn't need to supply a handler for it.
  final VoidCallback? onTapNextStamp;

  const PassportBookletView({
    super.key,
    required this.volumes,
    required this.holderName,
    required this.avatarUrl,
    required this.memberNumber,
    required this.countryNameByCode,
    this.newStampIds = const {},
    this.includeNextStampSlot = true,
    required this.onTapStamp,
    this.onTapNextStamp,
  });

  @override
  State<PassportBookletView> createState() => _PassportBookletViewState();
}

class _PassportBookletViewState extends State<PassportBookletView>
    with SingleTickerProviderStateMixin {
  // "Remember whether the booklet was open, which volume, which page" —
  // in-memory only. A caller that itself survives via IndexedStack (the
  // main Passport tab) gets session-length memory for free; a caller that
  // gets rebuilt fresh each visit (a pushed Friend Profile screen) simply
  // starts closed again each time, which is the correct behavior for
  // that context, not a gap — nothing further to persist for either.
  bool _isOpen = false;
  int _openVolumeIndex = 0;

  // Reset to 0 only when [_open] targets a DIFFERENT volume than before;
  // reopening the SAME volume you last closed restores exactly where you
  // left off.
  int _bookPageIndex = 0;

  late final AnimationController _flipController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 450),
  );

  @override
  void dispose() {
    _flipController.dispose();
    super.dispose();
  }

  bool get _reduceMotion => MediaQuery.of(context).disableAnimations;

  void _open(int index) {
    setState(() {
      if (index != _openVolumeIndex) _bookPageIndex = 0;
      _isOpen = true;
      _openVolumeIndex = index;
    });
    if (_reduceMotion) {
      _flipController.value = 1;
    } else {
      _flipController.forward(from: 0);
    }
  }

  void _close() {
    if (_reduceMotion) {
      _flipController.value = 0;
      setState(() => _isOpen = false);
    } else {
      _flipController.reverse().whenComplete(() {
        if (mounted) setState(() => _isOpen = false);
      });
    }
  }

  static final _emptyVolume = PassportVolume(
    year: null,
    items: const [],
    countryCodes: const [],
    stars: 0,
    collectionFirstYear: null,
  );

  // The cover's own original design aspect ratio (270×410) — every
  // responsively-sized book (cover, data page, and every stamp page, so
  // all of them stay the same shape while paging through) derives its
  // height from this ratio times whatever width [_bookWidth] computes.
  static const _aspect = PassportCoverFace.baseHeight / PassportCoverFace.baseWidth;

  // "Bijna de volle breedte, met genoeg marge dat het nog als een boekje
  // op een tafel leest" — 92% of the space already inside the caller's
  // own page margin (not literally 100%, so there's still a visible inset
  // beyond the page edge itself), clamped so it doesn't become an
  // unreasonably large slab on a tablet/desktop/web window.
  double _bookWidth(double maxWidth) => (maxWidth * 0.92).clamp(240.0, 480.0);

  @override
  Widget build(BuildContext context) {
    final coverVolumes = widget.volumes.isEmpty ? [_emptyVolume] : widget.volumes;
    final openVolume = coverVolumes[_openVolumeIndex.clamp(0, coverVolumes.length - 1)];

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = _bookWidth(constraints.maxWidth);
        final bookSize = Size(width, width * _aspect);
        return _reduceMotion
            ? PassportCrossFadeBook(
                isOpen: _isOpen,
                coverVolumes: coverVolumes,
                openVolume: openVolume,
                memberNumber: widget.memberNumber,
                holderName: widget.holderName,
                avatarUrl: widget.avatarUrl,
                bookSize: bookSize,
                countryNameByCode: widget.countryNameByCode,
                newStampIds: widget.newStampIds,
                includeNextStampSlot: widget.includeNextStampSlot,
                initialPage: _bookPageIndex,
                onPageChanged: (i) => setState(() => _bookPageIndex = i),
                onTapStamp: widget.onTapStamp,
                onTapNextStamp: widget.onTapNextStamp ?? () {},
                onOpen: _open,
                onClose: _close,
              )
            : PassportFlipBook(
                controller: _flipController,
                isOpen: _isOpen,
                coverVolumes: coverVolumes,
                openVolume: openVolume,
                memberNumber: widget.memberNumber,
                holderName: widget.holderName,
                avatarUrl: widget.avatarUrl,
                bookSize: bookSize,
                countryNameByCode: widget.countryNameByCode,
                newStampIds: widget.newStampIds,
                includeNextStampSlot: widget.includeNextStampSlot,
                initialPage: _bookPageIndex,
                onPageChanged: (i) => setState(() => _bookPageIndex = i),
                onTapStamp: widget.onTapStamp,
                onTapNextStamp: widget.onTapNextStamp ?? () {},
                onOpen: _open,
                onClose: _close,
              );
      },
    );
  }
}

/// The 3D open/close transition: the selected cover face rotates open
/// around its own left edge while the open book (already laid out at rest
/// beneath it) is revealed. Only the single cover FACE animates — not the
/// whole peeking stack behind it — matching a real book: once one volume
/// commits to opening, what's behind it in the pile isn't part of the
/// motion. Public (not `_FlipBook`) — [PassportBookletView] is this
/// file's only real caller today, but the choreography itself has no
/// caller-specific state, so there's no reason to force it private.
class PassportFlipBook extends StatelessWidget {
  final AnimationController controller;
  final bool isOpen;
  final List<PassportVolume> coverVolumes;
  final PassportVolume openVolume;
  final int? memberNumber;
  final String holderName;
  final String? avatarUrl;
  final Size bookSize;
  final Map<String, String> countryNameByCode;
  final Set<String> newStampIds;
  final bool includeNextStampSlot;
  final int initialPage;
  final ValueChanged<int> onPageChanged;
  final void Function(PassportStampItem item) onTapStamp;
  final VoidCallback onTapNextStamp;
  final ValueChanged<int> onOpen;
  final VoidCallback onClose;

  const PassportFlipBook({
    super.key,
    required this.controller,
    required this.isOpen,
    required this.coverVolumes,
    required this.openVolume,
    required this.memberNumber,
    required this.holderName,
    required this.avatarUrl,
    required this.bookSize,
    required this.countryNameByCode,
    required this.newStampIds,
    required this.includeNextStampSlot,
    required this.initialPage,
    required this.onPageChanged,
    required this.onTapStamp,
    required this.onTapNextStamp,
    required this.onOpen,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final t = Curves.easeOut.transform(controller.value);
        final atRestClosed = controller.value == 0 && !isOpen;
        final atRestOpen = controller.value == 1 && isOpen;

        return SizedBox(
          height: math.max(
            bookSize.height + PassportOpenBookFrame.topbarAllowance,
            bookSize.height + 24 * 5 + 40,
          ),
          child: Stack(
            alignment: Alignment.topCenter,
            children: [
              if (!atRestClosed)
                Align(
                  alignment: Alignment.topCenter,
                  child: IgnorePointer(
                    ignoring: !atRestOpen,
                    child: PassportOpenBookFrame(
                      volume: openVolume,
                      holderName: holderName,
                      avatarUrl: avatarUrl,
                      memberNumber: memberNumber,
                      size: bookSize,
                      countryNameByCode: countryNameByCode,
                      newStampIds: newStampIds,
                      includeNextStampSlot: includeNextStampSlot,
                      initialPage: initialPage,
                      onPageChanged: onPageChanged,
                      onTapStamp: onTapStamp,
                      onTapNextStamp: onTapNextStamp,
                      onClose: onClose,
                    ),
                  ),
                ),
              if (!atRestOpen)
                Align(
                  alignment: Alignment.bottomCenter,
                  child: IgnorePointer(
                    ignoring: !atRestClosed,
                    child: atRestClosed
                        ? PassportCoverStack(
                            volumes: coverVolumes,
                            memberNumber: memberNumber,
                            faceSize: bookSize,
                            onOpen: onOpen,
                          )
                        : Transform(
                            alignment: Alignment.centerLeft,
                            transform: Matrix4.identity()
                              ..setEntry(3, 2, 0.0015)
                              ..rotateY(-math.pi / 2 * t),
                            child: Opacity(
                              opacity: (1 - t).clamp(0.0, 1.0),
                              child: PassportCoverFace(
                                volume: openVolume,
                                memberNumber: memberNumber,
                                size: bookSize,
                              ),
                            ),
                          ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// Reduce Motion fallback: a plain cross-fade between the closed stack and
/// the open book, no 3D transform, no page-curl — matching the design
/// spec's own "Reduce Motion: geen 3D-flip of page-curl, maar een
/// cross-fade." Public for the same reason as [PassportFlipBook].
class PassportCrossFadeBook extends StatelessWidget {
  final bool isOpen;
  final List<PassportVolume> coverVolumes;
  final PassportVolume openVolume;
  final int? memberNumber;
  final String holderName;
  final String? avatarUrl;
  final Size bookSize;
  final Map<String, String> countryNameByCode;
  final Set<String> newStampIds;
  final bool includeNextStampSlot;
  final int initialPage;
  final ValueChanged<int> onPageChanged;
  final void Function(PassportStampItem item) onTapStamp;
  final VoidCallback onTapNextStamp;
  final ValueChanged<int> onOpen;
  final VoidCallback onClose;

  const PassportCrossFadeBook({
    super.key,
    required this.isOpen,
    required this.coverVolumes,
    required this.openVolume,
    required this.memberNumber,
    required this.holderName,
    required this.avatarUrl,
    required this.bookSize,
    required this.countryNameByCode,
    required this.newStampIds,
    required this.includeNextStampSlot,
    required this.initialPage,
    required this.onPageChanged,
    required this.onTapStamp,
    required this.onTapNextStamp,
    required this.onOpen,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) => AnimatedSwitcher(
    duration: const Duration(milliseconds: 220),
    child: isOpen
        ? PassportOpenBookFrame(
            key: const ValueKey('open'),
            volume: openVolume,
            holderName: holderName,
            avatarUrl: avatarUrl,
            memberNumber: memberNumber,
            size: bookSize,
            countryNameByCode: countryNameByCode,
            newStampIds: newStampIds,
            includeNextStampSlot: includeNextStampSlot,
            initialPage: initialPage,
            onPageChanged: onPageChanged,
            onTapStamp: onTapStamp,
            onTapNextStamp: onTapNextStamp,
            onClose: onClose,
          )
        : PassportCoverStack(
            key: const ValueKey('closed'),
            volumes: coverVolumes,
            memberNumber: memberNumber,
            faceSize: bookSize,
            onOpen: onOpen,
          ),
  );
}

/// The open-book topbar ("‹ Close" / volume label) plus the swipeable
/// data-page-then-stamp-pages pager. "Close" only ever closes the book
/// back to ITS OWN cover — never navigates anywhere else — so a caller
/// embedding this inside another screen (the Friend Profile tab) never
/// needs to override that behavior for "back to the friend profile, not
/// my own passport" to already be true: each embedding gets its own,
/// entirely independent [PassportBookletView] instance and state: there
/// is no shared/global "which booklet is open" anywhere.
///
/// The design spec's own topbar also names a right-hand map icon —
/// omitted here: the main Passport screen's persistent outer header
/// already carries one (see `PassportScreen`'s own doc comment on why the
/// header/tab bar never leave the screen for an internal state like
/// this), and a second map icon two rows apart would read as a mistake
/// rather than a feature. A disclosed adaptation, not a silent drop.
class PassportOpenBookFrame extends StatelessWidget {
  final PassportVolume volume;
  final String holderName;
  final String? avatarUrl;
  final int? memberNumber;
  final Size size;
  final Map<String, String> countryNameByCode;
  final Set<String> newStampIds;
  final bool includeNextStampSlot;
  final int initialPage;
  final ValueChanged<int> onPageChanged;
  final void Function(PassportStampItem item) onTapStamp;
  final VoidCallback onTapNextStamp;
  final VoidCallback onClose;

  const PassportOpenBookFrame({
    super.key,
    required this.volume,
    required this.holderName,
    required this.avatarUrl,
    required this.memberNumber,
    required this.size,
    required this.countryNameByCode,
    required this.newStampIds,
    required this.includeNextStampSlot,
    required this.initialPage,
    required this.onPageChanged,
    required this.onTapStamp,
    required this.onTapNextStamp,
    required this.onClose,
  });

  /// Topbar row + the gap above the page, plus the page-dots row + its own
  /// gap below the page — added on top of the page's own [size] height
  /// when reserving room for this whole frame.
  static const double topbarAllowance = 52 + 12 + 6;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: size.width,
    height: size.height + topbarAllowance,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            GestureDetector(
              onTap: onClose,
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.chevron_left_rounded,
                      color: AppColors.textOnDark,
                      size: 20,
                    ),
                    Text(
                      'Close',
                      style: GoogleFonts.inter(
                        color: AppColors.textOnDark,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: Text(
                volume.year == null ? 'COMPLETE PASSPORT' : '${volume.year} VOLUME',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  color: AppColors.secondaryOnDark,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 11 * 0.12,
                ),
              ),
            ),
            const SizedBox(width: 52),
          ],
        ),
        const SizedBox(height: 12),
        PassportOpenBookPager(
          volume: volume,
          holderName: holderName,
          avatarUrl: avatarUrl,
          memberNumber: memberNumber,
          size: size,
          countryNameByCode: countryNameByCode,
          newStampIds: newStampIds,
          includeNextStampSlot: includeNextStampSlot,
          initialPage: initialPage,
          onPageChanged: onPageChanged,
          onTapStamp: onTapStamp,
          onTapNextStamp: onTapNextStamp,
        ),
      ],
    ),
  );
}
