import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants/app_colors.dart';
import '../../core/theme/cs_spacing.dart';
import '../../models/event_confirmed_attendance.dart';
import '../../models/visit.dart';
import 'own_passport_loader.dart';
import 'passport_booklet_data.dart';
import 'passport_stamp_source.dart';
import 'widgets/passport_booklet_view.dart';
import 'widgets/passport_cover.dart' show PassportCoverFace;
import 'widgets/stamp_ceremony_scope.dart';

/// A Passport stamp that has just been earned — constructible ONLY from a
/// row the database has already confirmed: a saved `visits` row (a
/// restaurant visit or a hotel stay) or a saved `event_confirmed_attendance`
/// row. There is deliberately no way to build one from an Interested/Going
/// intent, or from anything a flow holds before its save succeeds — the
/// "stamps come only from confirmed attendance" rule (CLAUDE.md) is carried
/// by the type, not re-checked at every call site.
class EarnedStamp {
  /// The id [PassportStampItem.id] carries for this stamp — a `visits` or
  /// `event_confirmed_attendance` uuid.
  final String id;

  EarnedStamp.visit(Visit visit) : id = visit.id;
  EarnedStamp.attendance(EventConfirmedAttendance attendance)
    : id = attendance.id;
}

/// Book-keeping for "once per stamp", across every flow in this app
/// session.
abstract final class StampCeremony {
  // Every id a ceremony was ever started for — claimed before the passport
  // loads, so two calls racing for the same stamp (a double-tap, the
  // idempotent re-confirm in EventConfirmedAttendanceRepository
  // .confirmAttendance returning the same row) can never both show.
  static final Set<String> _claimed = {};

  // The ids a ceremony was actually SHOWN for. PassportCollectionBody
  // subtracts these from its own "just stamped" diff, so a stamp pressed
  // by a ceremony isn't stamped a second time on the Passport tab.
  static final Set<String> _shown = {};

  static Set<String> get celebratedIds => Set.unmodifiable(_shown);

  @visibleForTesting
  static void resetForTesting() {
    _claimed.clear();
    _shown.clear();
  }
}

/// Loads the booklet the ceremony shows — [loadOwnPassport] in the app,
/// injectable for tests.
typedef OwnPassportLoad = Future<OwnPassport> Function();

/// The one entry point every stamp-earning flow calls once its save has
/// succeeded: opens the member's own Passport full screen over whatever
/// is showing, presses [stamp] onto its page, closes, and returns. The
/// screen underneath is never rebuilt or navigated — the ceremony is a
/// non-opaque route on top of it, popped when done.
///
/// A no-op — completing straight away, showing nothing — when:
/// * [stamp] is null (the flow was dismissed, or its save failed);
/// * a ceremony for this stamp was already started this session;
/// * the passport cannot be loaded;
/// * the stamp is not in the booklet (a back-dated visit outside
///   buildPassportVolumes' 5-year window — there is no page to press it on).
///
/// Never throws: a stamp is already saved by the time this runs, and no
/// failure here may read as the save having failed.
Future<void> celebrateNewStamp(
  BuildContext context,
  EarnedStamp? stamp, {
  OwnPassportLoad? load,
}) async {
  if (stamp == null) return;
  if (!StampCeremony._claimed.add(stamp.id)) return;

  final OwnPassport passport;
  try {
    passport = await (load ?? () => loadOwnPassport(Supabase.instance.client))();
  } catch (_) {
    return;
  }
  final volume = passport.volumes.isEmpty ? null : passport.volumes.first;
  final pageIndex = volume == null ? null : stampCeremonyPageIndex(volume, stamp.id);
  if (volume == null || pageIndex == null || !context.mounted) return;

  StampCeremony._shown.add(stamp.id);
  await Navigator.of(context, rootNavigator: true).push(
    PageRouteBuilder<void>(
      opaque: false,
      // The overlay runs its own fade in and out.
      transitionDuration: Duration.zero,
      reverseTransitionDuration: Duration.zero,
      pageBuilder: (_, _, _) => StampCeremonyOverlay(
        passport: passport,
        volume: volume,
        stampId: stamp.id,
        stampPageIndex: pageIndex,
      ),
    ),
  );
}

/// The pager index (the data page is 0) of the stamp page holding
/// [stampId] in [volume] — laid out exactly as the Passport tab lays it
/// out, next-stamp slot included — or null when it isn't in the booklet.
int? stampCeremonyPageIndex(PassportVolume volume, String stampId) {
  final pages = buildYearGroupedStampPages(volume.items);
  for (var p = 0; p < pages.length; p++) {
    for (final slot in pages[p].slots) {
      if (slot is FilledStampSlot && slot.item.id == stampId) return p + 1;
    }
  }
  return null;
}

/// The ceremony itself, on the real booklet ([PassportFlipBook] with the
/// real cover, pages and stamp painters):
///
/// 1. the green backdrop fades in over the current screen;
/// 2. the cover swings open onto the page before the stamp's page;
/// 3. one page turn to the stamp's page;
/// 4. the stamp presses in (see [StampCeremonyScope.pressed]), with one
///    medium haptic on contact;
/// 5. a short hold, the cover closes, the backdrop fades out, and the
///    route pops.
///
/// About 2.7s in all; a tap anywhere (or a back gesture) skips straight
/// to a quick fade out. Under reduce motion there is no flip and no page
/// turn: the open booklet fades in already on the stamp's page, the stamp
/// fades in, a hold, a fade out.
class StampCeremonyOverlay extends StatefulWidget {
  final OwnPassport passport;
  final PassportVolume volume;
  final String stampId;
  final int stampPageIndex;

  const StampCeremonyOverlay({
    super.key,
    required this.passport,
    required this.volume,
    required this.stampId,
    required this.stampPageIndex,
  });

  static const backdropDuration = Duration(milliseconds: 200);
  static const skipFadeDuration = Duration(milliseconds: 150);
  static const pageTurnDuration = Duration(milliseconds: 380);
  static const pressDuration = Duration(milliseconds: 450);
  static const holdDuration = Duration(milliseconds: 550);
  static const reducedPressDuration = Duration(milliseconds: 400);
  static const reducedHoldDuration = Duration(milliseconds: 1000);

  @override
  State<StampCeremonyOverlay> createState() => _StampCeremonyOverlayState();
}

class _StampCeremonyOverlayState extends State<StampCeremonyOverlay>
    with TickerProviderStateMixin {
  late final _backdrop = AnimationController(
    vsync: this,
    duration: StampCeremonyOverlay.backdropDuration,
  );
  // PassportFlipBook's own open/close duration, matching the Passport tab.
  late final _flip = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 450),
  );
  late final _press = AnimationController(vsync: this)
    ..addListener(_hapticOnContact);

  bool _started = false;
  bool _finishing = false;
  bool _hapticFired = false;
  late bool _reduceMotion;

  // Empty until the cover is open; then holds the stamp's id, which is
  // what makes PassportOpenBookPager turn to its page by itself.
  Set<String> _turnTo = const {};

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    _reduceMotion = MediaQuery.disableAnimationsOf(context);
    _press.duration = _reduceMotion
        ? StampCeremonyOverlay.reducedPressDuration
        : StampCeremonyOverlay.pressDuration;
    unawaited(_run());
  }

  @override
  void dispose() {
    _backdrop.dispose();
    _flip.dispose();
    _press.dispose();
    super.dispose();
  }

  void _hapticOnContact() {
    if (_hapticFired || _press.value < 0.5) return;
    _hapticFired = true;
    HapticFeedback.mediumImpact();
  }

  /// False once the ceremony was skipped (or torn down) mid-step.
  Future<bool> _play(TickerFuture step) async {
    try {
      await step.orCancel;
    } on TickerCanceled {
      return false;
    }
    return !_finishing && mounted;
  }

  Future<bool> _wait(Duration d) async {
    await Future<void>.delayed(d);
    return !_finishing && mounted;
  }

  Future<void> _run() async {
    if (!await _play(_backdrop.forward())) return;
    if (_reduceMotion) {
      if (!await _play(_press.forward())) return;
      if (!await _wait(StampCeremonyOverlay.reducedHoldDuration)) return;
    } else {
      if (!await _play(_flip.forward())) return;
      setState(() => _turnTo = {widget.stampId});
      if (!await _wait(StampCeremonyOverlay.pageTurnDuration)) return;
      if (!await _play(_press.forward())) return;
      if (!await _wait(StampCeremonyOverlay.holdDuration)) return;
      if (!await _play(_flip.reverse())) return;
    }
    await _finish(skipped: false);
  }

  Future<void> _finish({required bool skipped}) async {
    if (_finishing) return;
    _finishing = true;
    _flip.stop();
    _press.stop();
    try {
      await _backdrop
          .animateBack(
            0,
            duration: skipped
                ? StampCeremonyOverlay.skipFadeDuration
                : StampCeremonyOverlay.backdropDuration,
          )
          .orCancel;
    } on TickerCanceled {
      // Torn down mid-fade — nothing left to pop.
      return;
    }
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final passport = widget.passport;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _finish(skipped: true);
      },
      child: Semantics(
        button: true,
        liveRegion: true,
        label: 'New Passport stamp. Tap to continue.',
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => _finish(skipped: true),
          child: FadeTransition(
            opacity: _backdrop,
            // A pushed route has no Scaffold above it: without a Material
            // here every Text in the booklet falls back to the debug
            // yellow-underlined style (caught in the simulator, not by the
            // widget tests).
            child: Material(
              color: AppColors.deepGreen,
              child: SafeArea(
                child: Center(
                  child: IgnorePointer(
                    child: ExcludeSemantics(
                      child: StampCeremonyScope(
                        stampId: widget.stampId,
                        press: _press,
                        reducedMotion: _reduceMotion,
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final bookSize = _bookSize(constraints);
                            return _reduceMotion
                                ? PassportOpenBookFrame(
                                    volume: widget.volume,
                                    holderName: passport.holderName,
                                    avatarUrl: passport.avatarUrl,
                                    memberNumber: passport.memberNumber,
                                    size: bookSize,
                                    countryNameByCode: passport.countryNameByCode,
                                    newStampIds: const {},
                                    includeNextStampSlot: true,
                                    includeBackCoverPage: true,
                                    initialPage: widget.stampPageIndex,
                                    onPageChanged: _ignore,
                                    onTapStamp: _ignore,
                                    onTapNextStamp: _noop,
                                    onOpenAllVisits: _ignore,
                                    onClose: _noop,
                                  )
                                : PassportFlipBook(
                                    controller: _flip,
                                    isOpen: true,
                                    coverVolumes: [widget.volume],
                                    openVolume: widget.volume,
                                    memberNumber: passport.memberNumber,
                                    holderName: passport.holderName,
                                    avatarUrl: passport.avatarUrl,
                                    bookSize: bookSize,
                                    countryNameByCode: passport.countryNameByCode,
                                    newStampIds: _turnTo,
                                    includeNextStampSlot: true,
                                    includeBackCoverPage: true,
                                    initialPage: widget.stampPageIndex - 1,
                                    onPageChanged: _ignore,
                                    onTapStamp: _ignore,
                                    onTapNextStamp: _noop,
                                    onOpenAllVisits: _ignore,
                                    onOpen: _ignore,
                                    onClose: _noop,
                                  );
                          },
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  static void _ignore(Object? _) {}
  static void _noop() {}

  // The Passport tab's own sizing (PassportBookletView._bookWidth — 92% of
  // the width inside the page margin, clamped), additionally capped so
  // the whole open book plus its topbar and page dots fits the height.
  static const _aspect = PassportCoverFace.baseHeight / PassportCoverFace.baseWidth;
  static const _pageDotsAllowance = 40.0;

  Size _bookSize(BoxConstraints constraints) {
    final byWidth = ((constraints.maxWidth - 2 * CsSpacing.pageHorizontal) * 0.92)
        .clamp(240.0, 480.0);
    final byHeight =
        (constraints.maxHeight -
            PassportOpenBookFrame.topbarAllowance -
            _pageDotsAllowance) /
        _aspect;
    final width = byWidth < byHeight ? byWidth : byHeight;
    return Size(width, width * _aspect);
  }
}
