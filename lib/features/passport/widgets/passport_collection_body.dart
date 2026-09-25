import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/analytics/analytics_properties.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/navigation/route_observer.dart';
import '../../../core/theme/cs_spacing.dart';
import '../../../core/widgets/cs_primary_button.dart' show CsSecondaryButton;
import '../../../data/repositories/country_lookup.dart';
import '../../../data/repositories/event_confirmed_attendance_repository.dart';
import '../../../data/repositories/profile_repository.dart';
import '../../../data/repositories/visited_repository.dart';
import '../../../models/hotel.dart';
import '../../../models/restaurant.dart';
import '../../events/event_detail_screen.dart';
import '../../explore/explore_screen.dart';
import '../../hotels/hotel_detail_screen.dart';
import '../../restaurants/restaurant_detail_screen.dart';
import '../models/passport_stamp_item.dart';
import '../passport_booklet_data.dart';
import 'passport_cover.dart';
import 'passport_open_book_pager.dart';

/// Passport's default "Passport" subsection content: a real passport
/// booklet — closed cover (with yearly volumes fanned behind it) that
/// opens, 3D, onto a bound data page, then the swipeable stamp pages
/// (Round 2 of the booklet redesign; see EDITORIAL_REDESIGN_TRACKING.md).
/// The add-a-visit flow is Round 3, not built yet. Replaces the previous
/// filter-chip + flat stamp-page-list body entirely; the header and
/// Passport/Wishlist/Ranking/Trips tab bar above this widget are
/// untouched, owned by PassportScreen.
class PassportCollectionBody extends StatefulWidget {
  const PassportCollectionBody({super.key});

  @override
  State<PassportCollectionBody> createState() => _PassportCollectionBodyState();
}

class _PassportCollectionBodyState extends State<PassportCollectionBody>
    with SingleTickerProviderStateMixin, RouteAware {
  late final _visitedRepo = VisitedRepository(Supabase.instance.client);
  late final _eventAttendanceRepo = EventConfirmedAttendanceRepository(
    Supabase.instance.client,
  );
  late final _profileRepo = ProfileRepository(Supabase.instance.client);

  List<PassportVolume> _volumes = [];
  String _holderName = 'Member';
  String? _avatarUrl;
  Map<String, String> _countryNameByCode = {};

  // Null only for the handful of pre-existing test accounts
  // 20260925120000_add_profiles_member_number.sql deliberately left
  // unnumbered — never expected for a real member.
  int? _memberNumber;

  bool _loading = true;
  bool _loadError = false;

  // Stamp-animation bookkeeping, reinstated from the pre-booklet
  // PassportCollectionBody: every stamp id seen as of the last completed
  // load, and — once at least one prior load has happened — the ids new
  // since then. The very first load of the app session never has
  // anything to diff against, so it never animates anything.
  Set<String> _knownStampIds = {};
  Set<String> _newStampIds = {};
  bool _hasLoadedOnce = false;

  // "Remember whether the booklet was open, which volume, which page" —
  // in-memory, not persisted to disk: PassportScreen keeps this whole
  // widget alive via IndexedStack for the life of the app session, which
  // is exactly "per session" — an app restart clearing it is the correct
  // behavior, not a gap.
  bool _isOpen = false;
  int _openVolumeIndex = 0;

  // Which page within the open volume was last showing — reset to 0 only
  // when [_open] targets a DIFFERENT volume than before; reopening the
  // SAME volume you last closed restores exactly where you left off.
  int _bookPageIndex = 0;

  late final AnimationController _flipController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 450),
  );

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route is PageRoute) {
      appRouteObserver.subscribe(this, route);
    }
  }

  @override
  void dispose() {
    appRouteObserver.unsubscribe(this);
    _flipController.dispose();
    super.dispose();
  }

  @override
  void didPopNext() => _load();

  Set<String> _allStampIds(List<PassportVolume> volumes) {
    // Index 0 is always the complete volume — see buildPassportVolumes'
    // own contract — so its items alone already cover every stamp across
    // every year, with nothing double-counted.
    if (volumes.isEmpty) return {};
    return {for (final item in volumes.first.items) item.id};
  }

  Future<void> _load() async {
    try {
      final uid = Supabase.instance.client.auth.currentUser?.id ?? '';
      final entries = await _visitedRepo.loadPassportVenues(uid);
      var eventEntries = <EventAttendanceEntry>[];
      try {
        eventEntries = await _eventAttendanceRepo.loadPassportEventAttendance(
          uid,
        );
      } catch (_) {
        // Never fails the rest of Passport — same precedent as before.
      }

      var name = 'Member';
      String? avatarUrl;
      int? memberNumber;
      try {
        // `visited` only feeds UserProfile's own current-award stats,
        // which this screen never reads (it computes ENTRIES/COUNTRIES/
        // STARS itself from stars-at-visit, not current award) — so an
        // empty list here avoids a second restaurant load for fields
        // that would go unused.
        final profile = await _profileRepo.getProfile(
          userId: uid,
          visited: const [],
        );
        name = profile.name;
        avatarUrl = await _profileRepo.resolveAvatarUrl(profile.avatarPath);
        memberNumber = profile.memberNumber;
      } catch (_) {
        // Cover/data page still render with the 'Member' + initials
        // fallback — a profile-load failure never blocks Passport itself.
      }

      var countryNameByCode = <String, String>{};
      try {
        final countries = await getAllCountries(Supabase.instance.client);
        countryNameByCode = {for (final c in countries) c.code: c.name};
      } catch (_) {
        // Never fails the rest of Passport — stamp semantics labels fall
        // back to the bare country code (see stampSemanticLabel).
      }

      if (!mounted) return;
      final volumes = buildPassportVolumes(
        entries: entries,
        eventEntries: eventEntries,
      );
      final allIds = _allStampIds(volumes);
      final newIds = _hasLoadedOnce ? allIds.difference(_knownStampIds) : <String>{};

      setState(() {
        _volumes = volumes;
        _holderName = name;
        _avatarUrl = avatarUrl;
        _memberNumber = memberNumber;
        _countryNameByCode = countryNameByCode;
        _newStampIds = newIds;
        _knownStampIds = allIds;
        _hasLoadedOnce = true;
        _loading = false;
        _loadError = false;
        if (_openVolumeIndex >= volumes.length) _openVolumeIndex = 0;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError = _volumes.isEmpty;
      });
    }
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

  void _openRestaurant(Restaurant restaurant) => Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => RestaurantDetailScreen(restaurant: restaurant),
    ),
  );

  void _openHotel(Hotel hotel) => Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => HotelDetailScreen(hotel: hotel)),
  );

  void _openEvent(String eventId) => Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => EventDetailScreen(
        eventId: eventId,
        sourceSurface: AnalyticsSourceSurface.passport,
      ),
    ),
  );

  void _onTapStamp(PassportStampItem item) => switch (item) {
    RestaurantStampItem(:final restaurant) => _openRestaurant(restaurant),
    HotelStampItem(:final hotel) => _openHotel(hotel),
    EventStampItem(:final entry) => _openEvent(entry.event.id),
  };

  // Round 3 (not built yet) replaces this with the real "add a visit"
  // sheet. Interim behavior matches the pre-booklet Passport's own
  // fallback for the exact same tap target — open Explore rather than
  // leaving the empty slot inert.
  void _openExplore() => Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => const ExploreScreen()),
  );

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
  // op een tafel leest" — 92% of the space already inside this screen's
  // own page margin (not literally 100%, so there's still a visible inset
  // beyond the page edge itself), clamped so it doesn't become an
  // unreasonably large slab on a tablet/desktop/web window.
  double _bookWidth(double maxWidth) => (maxWidth * 0.92).clamp(240.0, 480.0);

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const ColoredBox(
        color: AppColors.deepGreen,
        child: Center(
          child: CircularProgressIndicator(
            color: AppColors.textOnDark,
            strokeWidth: 1.5,
          ),
        ),
      );
    }
    if (_loadError) {
      return ColoredBox(
        color: AppColors.deepGreen,
        child: Center(child: _ErrorState(onRetry: _load)),
      );
    }

    final coverVolumes = _volumes.isEmpty ? [_emptyVolume] : _volumes;
    final openVolume = coverVolumes[_openVolumeIndex.clamp(0, coverVolumes.length - 1)];

    return ColoredBox(
      color: AppColors.deepGreen,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          CsSpacing.pageHorizontal,
          CsSpacing.md,
          CsSpacing.pageHorizontal,
          CsSpacing.xl,
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = _bookWidth(constraints.maxWidth);
            final bookSize = Size(width, width * _aspect);
            return SingleChildScrollView(
              child: Center(
                child: _reduceMotion
                    ? _CrossFadeBook(
                        isOpen: _isOpen,
                        coverVolumes: coverVolumes,
                        openVolume: openVolume,
                        memberNumber: _memberNumber,
                        holderName: _holderName,
                        avatarUrl: _avatarUrl,
                        bookSize: bookSize,
                        countryNameByCode: _countryNameByCode,
                        newStampIds: _newStampIds,
                        initialPage: _bookPageIndex,
                        onPageChanged: (i) => setState(() => _bookPageIndex = i),
                        onTapStamp: _onTapStamp,
                        onTapNextStamp: _openExplore,
                        onOpen: _open,
                        onClose: _close,
                      )
                    : _FlipBook(
                        controller: _flipController,
                        isOpen: _isOpen,
                        coverVolumes: coverVolumes,
                        openVolume: openVolume,
                        memberNumber: _memberNumber,
                        holderName: _holderName,
                        avatarUrl: _avatarUrl,
                        bookSize: bookSize,
                        countryNameByCode: _countryNameByCode,
                        newStampIds: _newStampIds,
                        initialPage: _bookPageIndex,
                        onPageChanged: (i) => setState(() => _bookPageIndex = i),
                        onTapStamp: _onTapStamp,
                        onTapNextStamp: _openExplore,
                        onOpen: _open,
                        onClose: _close,
                      ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// The 3D open/close transition: the selected cover face rotates open
/// around its own left edge while the open book (already laid out at rest
/// beneath it) is revealed. Only the single cover FACE animates — not the
/// whole peeking stack behind it — matching a real book: once one volume
/// commits to opening, what's behind it in the pile isn't part of the
/// motion.
class _FlipBook extends StatelessWidget {
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
  final int initialPage;
  final ValueChanged<int> onPageChanged;
  final void Function(PassportStampItem item) onTapStamp;
  final VoidCallback onTapNextStamp;
  final ValueChanged<int> onOpen;
  final VoidCallback onClose;

  const _FlipBook({
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
            bookSize.height + _OpenBookFrame.topbarAllowance,
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
                    child: _OpenBookFrame(
                      volume: openVolume,
                      holderName: holderName,
                      avatarUrl: avatarUrl,
                      memberNumber: memberNumber,
                      size: bookSize,
                      countryNameByCode: countryNameByCode,
                      newStampIds: newStampIds,
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
/// the open book, no 3D transform, no page-curl — matching this task's own
/// "Reduce Motion: geen 3D-flip of page-curl, maar een cross-fade."
class _CrossFadeBook extends StatelessWidget {
  final bool isOpen;
  final List<PassportVolume> coverVolumes;
  final PassportVolume openVolume;
  final int? memberNumber;
  final String holderName;
  final String? avatarUrl;
  final Size bookSize;
  final Map<String, String> countryNameByCode;
  final Set<String> newStampIds;
  final int initialPage;
  final ValueChanged<int> onPageChanged;
  final void Function(PassportStampItem item) onTapStamp;
  final VoidCallback onTapNextStamp;
  final ValueChanged<int> onOpen;
  final VoidCallback onClose;

  const _CrossFadeBook({
    required this.isOpen,
    required this.coverVolumes,
    required this.openVolume,
    required this.memberNumber,
    required this.holderName,
    required this.avatarUrl,
    required this.bookSize,
    required this.countryNameByCode,
    required this.newStampIds,
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
        ? _OpenBookFrame(
            key: const ValueKey('open'),
            volume: openVolume,
            holderName: holderName,
            avatarUrl: avatarUrl,
            memberNumber: memberNumber,
            size: bookSize,
            countryNameByCode: countryNameByCode,
            newStampIds: newStampIds,
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
/// data-page-then-stamp-pages pager. The design spec's own topbar also
/// names a right-hand map icon — omitted here: PassportScreen's persistent
/// outer header already carries one (see that class's own doc comment on
/// why the header/tab bar never leave the screen for an internal state
/// like this), and a second map icon two rows apart would read as a
/// mistake rather than a feature. A disclosed adaptation, not a silent
/// drop.
class _OpenBookFrame extends StatelessWidget {
  final PassportVolume volume;
  final String holderName;
  final String? avatarUrl;
  final int? memberNumber;
  final Size size;
  final Map<String, String> countryNameByCode;
  final Set<String> newStampIds;
  final int initialPage;
  final ValueChanged<int> onPageChanged;
  final void Function(PassportStampItem item) onTapStamp;
  final VoidCallback onTapNextStamp;
  final VoidCallback onClose;

  const _OpenBookFrame({
    super.key,
    required this.volume,
    required this.holderName,
    required this.avatarUrl,
    required this.memberNumber,
    required this.size,
    required this.countryNameByCode,
    required this.newStampIds,
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
          initialPage: initialPage,
          onPageChanged: onPageChanged,
          onTapStamp: onTapStamp,
          onTapNextStamp: onTapNextStamp,
        ),
      ],
    ),
  );
}

class _ErrorState extends StatelessWidget {
  final VoidCallback onRetry;
  const _ErrorState({required this.onRetry});

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      const Icon(
        Icons.wifi_off_rounded,
        color: AppColors.secondaryOnDark,
        size: 40,
      ),
      const SizedBox(height: CsSpacing.base),
      Text(
        'Could not load data',
        style: GoogleFonts.inter(color: AppColors.secondaryOnDark, fontSize: 14),
      ),
      const SizedBox(height: CsSpacing.md),
      SizedBox(
        width: 160,
        child: CsSecondaryButton(label: 'Retry', onTap: onRetry, height: 44),
      ),
    ],
  );
}
