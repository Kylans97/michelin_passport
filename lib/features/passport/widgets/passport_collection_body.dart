import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/analytics/analytics_properties.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/navigation/route_observer.dart';
import '../../../core/theme/cs_spacing.dart';
import '../../../core/widgets/cs_primary_button.dart' show CsSecondaryButton;
import '../../../core/widgets/floating_nav_bar.dart';
import '../../../data/repositories/event_confirmed_attendance_repository.dart';
import '../../../models/hotel.dart';
import '../../../models/restaurant.dart';
import '../../../models/venue_entry.dart';
import '../../events/event_detail_screen.dart';
import '../../hotels/hotel_detail_screen.dart';
import '../../restaurants/restaurant_detail_screen.dart';
import '../models/passport_stamp_item.dart';
import '../passport_all_visits_screen.dart';
import '../passport_booklet_data.dart';
import '../passport_filter_type.dart';
import '../own_passport_loader.dart';
import '../stamp_ceremony.dart';
import 'add_visit_flow.dart';
import 'passport_booklet_view.dart';

/// Passport's default "Passport" subsection content: loads the CURRENT
/// user's own visits/stays/events/identity, then hands them to
/// [PassportBookletView] — the actual cover→data-page→stamp-pages
/// choreography lives there now, generic over whose data it's showing
/// (see that file's own doc comment; the Friend Profile screen's
/// read-only Passport tab is its other caller). This widget's only job is
/// the loading/error states and the current-user-specific navigation
/// (tapping a stamp opens the VENUE'S detail screen; tapping the empty
/// slot opens the "add a visit" flow — both specific to "this is MY OWN
/// passport", unlike the friend booklet's "tapping a stamp opens THAT
/// VISIT's own detail, there is no empty slot").
class PassportCollectionBody extends StatefulWidget {
  const PassportCollectionBody({super.key});

  @override
  State<PassportCollectionBody> createState() => _PassportCollectionBodyState();
}

class _PassportCollectionBodyState extends State<PassportCollectionBody>
    with RouteAware {
  List<PassportVolume> _volumes = [];

  // The raw, un-capped loads _volumes is built from (see OwnPassport) —
  // kept alongside it for PassportAllVisitsScreen (point 5's "volledige lijst van alle
  // bezoeken"), which deliberately shows the user's WHOLE history, not
  // just what buildPassportVolumes keeps inside the booklet's 5-year
  // window. See _openAllVisits below.
  List<VenueEntry> _entries = [];
  List<EventAttendanceEntry> _eventEntries = [];

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
      final passport = await loadOwnPassport(Supabase.instance.client);
      if (!mounted) return;
      final volumes = passport.volumes;
      final allIds = _allStampIds(volumes);
      // A stamp a ceremony already pressed in (see stamp_ceremony.dart)
      // isn't stamped in a second time here.
      final newIds = _hasLoadedOnce
          ? allIds
                .difference(_knownStampIds)
                .difference(StampCeremony.celebratedIds)
          : <String>{};

      setState(() {
        _volumes = volumes;
        _entries = passport.entries;
        _eventEntries = passport.eventEntries;
        _holderName = passport.holderName;
        _avatarUrl = passport.avatarUrl;
        _memberNumber = passport.memberNumber;
        _countryNameByCode = passport.countryNameByCode;
        _newStampIds = newIds;
        _knownStampIds = allIds;
        _hasLoadedOnce = true;
        _loading = false;
        _loadError = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError = _volumes.isEmpty;
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

  void _openAllVisits(PassportFilterType? filter) => Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => PassportAllVisitsScreen(
        entries: _entries,
        eventEntries: _eventEntries,
        initialFilter: filter,
        onTapItem: _onTapStamp,
      ),
    ),
  );

  Future<void> _addVisit() async {
    final uid = Supabase.instance.client.auth.currentUser?.id ?? '';
    final saved = await showAddVisitFlow(context, userId: uid);
    if (saved == null || !mounted) return;
    // The ceremony first, then the reload. Neither resets `_isOpen`/
    // `_openVolumeIndex`/`_bookPageIndex` (those live inside
    // PassportBookletView's own State, untouched by this widget's
    // setState), so the member comes back to the same open page they
    // tapped "Add your next stamp" on, with the new stamp now in the book.
    await celebrateNewStamp(context, EarnedStamp.visit(saved.visit));
    if (mounted) _load();
  }

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

    return ColoredBox(
      color: AppColors.deepGreen,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          CsSpacing.pageHorizontal,
          CsSpacing.md,
          CsSpacing.pageHorizontal,
          floatingNavClearance(context),
        ),
        child: SingleChildScrollView(
          child: Center(
            child: PassportBookletView(
              volumes: _volumes,
              holderName: _holderName,
              avatarUrl: _avatarUrl,
              memberNumber: _memberNumber,
              countryNameByCode: _countryNameByCode,
              newStampIds: _newStampIds,
              includeBackCoverPage: true,
              onTapStamp: _onTapStamp,
              onTapNextStamp: _addVisit,
              onOpenAllVisits: _openAllVisits,
            ),
          ),
        ),
      ),
    );
  }
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
