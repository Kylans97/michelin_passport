import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/cs_editorial_glyphs.dart' show CsCountryLabel;
import '../../../core/widgets/key_row.dart';
import '../../../core/widgets/star_row.dart';
import '../../../core/widgets/venue_thumbnail.dart';
import '../../../data/repositories/event_confirmed_attendance_repository.dart';
import '../../../data/repositories/events_repository.dart';
import '../../../data/repositories/hotel_repository.dart';
import '../../../data/repositories/restaurant_repository.dart';
import '../../../data/repositories/visited_repository.dart';
import '../../../data/repositories/wishlist_repository.dart';
import '../../../models/passport_venue.dart';
import '../../../models/visit.dart';
import '../../visits/widgets/rating_meter.dart';
import '../models/passport_stamp_item.dart';
import '../utils/passport_stamp_style.dart';
import 'passport_stamp.dart';

// Cormorant Garamond falls back to oldstyle figures (varying height/
// baseline) unless this feature is explicitly enabled — the same fix
// already applied in passport_data_page.dart/passport_cover.dart/
// passport_page.dart, confirmed necessary here too by this round's own
// preview harness screenshot (the date row and score picker both showed
// visibly uneven digits before this was added).
const _liningFigures = [FontFeature.enable('lnum')];

/// The Passport booklet's "add a visit" flow — two steps inside ONE
/// persistent bottom sheet (not two separate `showModalBottomSheet` calls
/// stacked on top of each other): "Where did you go?" (a venue picker —
/// wishlist shortcuts + live search, type-scoped by a Restaurant/Hotel
/// toggle), then the visit's own details with a live stamp preview. One
/// sheet, an internal step switch, so "‹ Back" on step 2 returns to step
/// 1's own still-warm search results rather than needing to re-show
/// anything.
///
/// Returns true once a visit has actually been saved — the caller (see
/// `PassportCollectionBody._addVisit`) reloads on true and lets the
/// already-built new-stamp entrance animation/auto-scroll
/// (`PassportOpenBookPager`'s own `newStampIds` diffing) pick it up from
/// there; nothing new needed for "jumps to the right page, stamps in."
/// False if the sheet was dismissed at any point without saving.
///
/// "From your events" (step 1's other shortcut section, alongside "From
/// your wishlist") resolves through `event_restaurants`/`event_hotels`
/// (`is_venue = true`) — corrected after an initial, wrong claim that
/// `Event` had no venue link at all; those join tables exist and are
/// exactly the same shape `news_article_restaurants`/`news_article_hotels`
/// mirrored this same week. See [EventsRepository.loadVenuesForEvents]
/// and EDITORIAL_REDESIGN_TRACKING.md for the full note.
Future<bool> showAddVisitFlow(
  BuildContext context, {
  required String userId,
}) async {
  final result = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _AddVisitSheet(userId: userId),
  );
  return result ?? false;
}

enum _VenueType { restaurant, hotel }

String _venueId(PassportVenue v) => switch (v) {
  RestaurantVenue(:final restaurant) => restaurant.id,
  HotelVenue(:final hotel) => hotel.id,
};

String _venueName(PassportVenue v) => switch (v) {
  RestaurantVenue(:final restaurant) => restaurant.name,
  HotelVenue(:final hotel) => hotel.name,
};

class _AddVisitSheet extends StatefulWidget {
  final String userId;
  const _AddVisitSheet({required this.userId});

  @override
  State<_AddVisitSheet> createState() => _AddVisitSheetState();
}

class _AddVisitSheetState extends State<_AddVisitSheet> {
  late final _restaurantRepo = RestaurantRepository(Supabase.instance.client);
  late final _hotelRepo = HotelRepository(Supabase.instance.client);
  late final _wishlistRepo = WishlistRepository(Supabase.instance.client);
  late final _visitedRepo = VisitedRepository(Supabase.instance.client);
  late final _eventAttendanceRepo = EventConfirmedAttendanceRepository(
    Supabase.instance.client,
  );
  late final _eventsRepo = EventsRepository(Supabase.instance.client);

  int _step = 1;
  _VenueType _type = _VenueType.restaurant;

  final _searchCtrl = TextEditingController();
  Timer? _debounce;
  String _query = '';
  bool _searching = false;
  List<PassportVenue> _searchResults = [];
  List<PassportVenue>? _wishlist; // null = still loading
  List<PassportVenue>? _eventVenues; // null = still loading

  PassportVenue? _selectedVenue;
  DateTime _visitedOn = DateTime.now();
  int? _score;
  final _notesCtrl = TextEditingController();
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadWishlist();
    _loadEventVenues();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadWishlist() async {
    try {
      final venues = await _wishlistRepo.loadWishlistVenues(widget.userId);
      if (mounted) setState(() => _wishlist = venues);
    } catch (_) {
      if (mounted) setState(() => _wishlist = const []);
    }
  }

  Future<void> _loadEventVenues() async {
    try {
      final entries = await _eventAttendanceRepo.loadPassportEventAttendance(
        widget.userId,
      );
      final eventIds = {for (final e in entries) e.event.id}.toList();
      final venues = await _eventsRepo.loadVenuesForEvents(eventIds);
      if (!mounted) return;
      setState(
        () => _eventVenues = [
          ...venues.restaurants.map(RestaurantVenue.new),
          ...venues.hotels.map(HotelVenue.new),
        ],
      );
    } catch (_) {
      if (mounted) setState(() => _eventVenues = const []);
    }
  }

  void _onQueryChanged(String value) {
    _debounce?.cancel();
    final trimmed = value.trim();
    setState(() => _query = trimmed);
    if (trimmed.length < 2) {
      setState(() => _searchResults = []);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 300), _runSearch);
  }

  Future<void> _runSearch() async {
    final query = _query;
    if (query.length < 2 || !mounted) return;
    setState(() => _searching = true);
    try {
      final List<PassportVenue> results = _type == _VenueType.restaurant
          ? (await _restaurantRepo.search(query)).map(RestaurantVenue.new).toList()
          : (await _hotelRepo.search(query)).map(HotelVenue.new).toList();
      if (!mounted || query != _query) return;
      setState(() {
        _searchResults = results;
        _searching = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _searching = false);
    }
  }

  void _setType(_VenueType type) {
    if (type == _type) return;
    setState(() {
      _type = type;
      _searchResults = [];
    });
    if (_query.length >= 2) _runSearch();
  }

  void _selectVenue(PassportVenue venue) {
    setState(() {
      _selectedVenue = venue;
      _step = 2;
      _error = null;
    });
  }

  void _backToStep1() => setState(() => _step = 1);

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _visitedOn,
      firstDate: DateTime(now.year - 20),
      lastDate: now, // future dates not allowed — this app's established rule
    );
    if (picked != null) setState(() => _visitedOn = picked);
  }

  Future<void> _save() async {
    final venue = _selectedVenue;
    if (venue == null || _saving) return;
    setState(() {
      _saving = true;
      _error = null;
    });

    final entityType = _type == _VenueType.restaurant ? 'restaurant' : 'hotel';
    final entityId = _venueId(venue);

    try {
      final duplicate = await _visitedRepo.hasVisitOnDate(
        userId: widget.userId,
        entityType: entityType,
        entityId: entityId,
        date: _visitedOn,
      );
      if (duplicate) {
        if (!mounted) return;
        setState(() {
          _saving = false;
          _error = 'You already logged a visit here on this date.';
        });
        return;
      }

      switch (venue) {
        case RestaurantVenue(:final restaurant):
          await _visitedRepo.markVisited(
            userId: widget.userId,
            restaurantId: restaurant.id,
            visitedOn: _visitedOn,
            rating: _score,
            notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
            starsAtVisit: restaurant.michelinStars,
          );
        case HotelVenue(:final hotel):
          await _visitedRepo.markHotelStay(
            userId: widget.userId,
            hotelId: hotel.id,
            visitedOn: _visitedOn,
            rating: _score,
            notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
            keysAtVisit: hotel.michelinKeys,
          );
      }
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = 'Could not save. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final onGreen = _step == 1;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.92,
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: onGreen ? AppColors.deepGreen : AppColors.background,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
          ),
          child: ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
            child: Stack(
              children: [
                if (!onGreen)
                  const Positioned.fill(
                    child: RepaintBoundary(child: CustomPaint(painter: _SheetGuillochePainter())),
                  ),
                SafeArea(
                  top: false,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(height: 10),
                      Container(
                        width: 36,
                        height: 4,
                        decoration: BoxDecoration(
                          color: onGreen ? AppColors.hairlineOnGreen : AppColors.hairlineOnPaper,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(height: 14),
                      _TopRow(
                        onGreen: onGreen,
                        stepLabel: _step == 1 ? 'STEP 1 OF 2' : 'STEP 2 OF 2',
                        leading: _step == 1
                            ? _SheetTextButton(
                                label: 'Cancel',
                                onGreen: onGreen,
                                onTap: () => Navigator.pop(context, false),
                              )
                            : _SheetTextButton(
                                label: '‹ Back',
                                onGreen: onGreen,
                                onTap: _backToStep1,
                              ),
                      ),
                      Flexible(
                        child: _step == 1
                            ? _Step1(
                                type: _type,
                                onTypeChanged: _setType,
                                searchCtrl: _searchCtrl,
                                onQueryChanged: _onQueryChanged,
                                query: _query,
                                searching: _searching,
                                results: _searchResults,
                                wishlist: _wishlist,
                                eventVenues: _eventVenues,
                                onSelect: _selectVenue,
                              )
                            : _Step2(
                                venue: _selectedVenue!,
                                visitedOn: _visitedOn,
                                onPickDate: _pickDate,
                                score: _score,
                                onScoreChanged: (v) => setState(() => _score = v),
                                notesCtrl: _notesCtrl,
                                saving: _saving,
                                error: _error,
                                onSave: _save,
                              ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TopRow extends StatelessWidget {
  final bool onGreen;
  final String stepLabel;
  final Widget leading;
  const _TopRow({required this.onGreen, required this.stepLabel, required this.leading});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
    child: Row(
      children: [
        SizedBox(width: 72, child: Align(alignment: Alignment.centerLeft, child: leading)),
        Expanded(
          child: Text(
            stepLabel,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              color: onGreen ? AppColors.secondaryOnDark : AppColors.textSecondary,
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
              letterSpacing: 10.5 * 0.14,
            ),
          ),
        ),
        const SizedBox(width: 72),
      ],
    ),
  );
}

class _SheetTextButton extends StatelessWidget {
  final String label;
  final bool onGreen;
  final VoidCallback onTap;
  const _SheetTextButton({required this.label, required this.onGreen, required this.onTap});

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.transparent,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        child: Text(
          label,
          style: GoogleFonts.inter(
            color: onGreen ? AppColors.textOnDark : AppColors.forestGreen,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    ),
  );
}

// ── Step 1: "Where did you go?" ─────────────────────────────────────────

class _Step1 extends StatelessWidget {
  final _VenueType type;
  final ValueChanged<_VenueType> onTypeChanged;
  final TextEditingController searchCtrl;
  final ValueChanged<String> onQueryChanged;
  final String query;
  final bool searching;
  final List<PassportVenue> results;
  final List<PassportVenue>? wishlist;
  final List<PassportVenue>? eventVenues;
  final ValueChanged<PassportVenue> onSelect;

  const _Step1({
    required this.type,
    required this.onTypeChanged,
    required this.searchCtrl,
    required this.onQueryChanged,
    required this.query,
    required this.searching,
    required this.results,
    required this.wishlist,
    required this.eventVenues,
    required this.onSelect,
  });

  bool _matchesType(PassportVenue v) =>
      type == _VenueType.restaurant ? v is RestaurantVenue : v is HotelVenue;

  @override
  Widget build(BuildContext context) {
    final isSearching = query.length >= 2;
    final wishlistForType = (wishlist ?? const []).where(_matchesType).toList();
    final wishlistIds = wishlistForType.map(_venueId).toSet();
    // Skips anything already shown under "FROM YOUR WISHLIST" — a venue
    // that's both wishlisted and the site of an attended event should
    // still only appear once on this screen.
    final eventVenuesForType = (eventVenues ?? const [])
        .where(_matchesType)
        .where((v) => !wishlistIds.contains(_venueId(v)))
        .toList();
    final hasShortcuts = wishlistForType.isNotEmpty || eventVenuesForType.isNotEmpty;
    final shortcutsLoaded = wishlist != null && eventVenues != null;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Where did you go?',
            style: GoogleFonts.cormorantGaramond(
              color: AppColors.textOnDark,
              fontSize: 36,
              fontWeight: FontWeight.w600,
              height: 1.05,
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              _TypeChip(
                label: 'Restaurant',
                selected: type == _VenueType.restaurant,
                onTap: () => onTypeChanged(_VenueType.restaurant),
              ),
              const SizedBox(width: 10),
              _TypeChip(
                label: 'Hotel',
                selected: type == _VenueType.hotel,
                onTap: () => onTypeChanged(_VenueType.hotel),
              ),
            ],
          ),
          const SizedBox(height: 20),
          TextField(
            controller: searchCtrl,
            onChanged: onQueryChanged,
            style: GoogleFonts.inter(color: AppColors.textOnDark, fontSize: 15),
            cursorColor: AppColors.textOnDark,
            decoration: InputDecoration(
              isDense: true,
              hintText: 'Search by name or city',
              hintStyle: GoogleFonts.cormorantGaramond(
                color: AppColors.secondaryOnDark,
                fontStyle: FontStyle.italic,
                fontSize: 16,
              ),
              enabledBorder: const UnderlineInputBorder(
                borderSide: BorderSide(color: AppColors.hairlineOnGreen),
              ),
              focusedBorder: const UnderlineInputBorder(
                borderSide: BorderSide(color: AppColors.textOnDark),
              ),
            ),
          ),
          const SizedBox(height: 8),
          if (isSearching)
            _SearchResultsSection(searching: searching, results: results, onSelect: onSelect)
          else ...[
            if (wishlistForType.isNotEmpty) ...[
              const SizedBox(height: 16),
              const _SectionLabel('FROM YOUR WISHLIST'),
              const SizedBox(height: 8),
              for (final v in wishlistForType) _VenueRow(venue: v, onTap: () => onSelect(v)),
            ],
            if (eventVenuesForType.isNotEmpty) ...[
              SizedBox(height: wishlistForType.isNotEmpty ? 24 : 16),
              const _SectionLabel('FROM YOUR EVENTS'),
              const SizedBox(height: 8),
              for (final v in eventVenuesForType) _VenueRow(venue: v, onTap: () => onSelect(v)),
            ],
            if (!hasShortcuts && shortcutsLoaded) ...[
              const SizedBox(height: 32),
              Center(
                child: Text(
                  'Nothing here yet — search above.',
                  style: GoogleFonts.inter(color: AppColors.secondaryOnDark, fontSize: 13),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _SearchResultsSection extends StatelessWidget {
  final bool searching;
  final List<PassportVenue> results;
  final ValueChanged<PassportVenue> onSelect;
  const _SearchResultsSection({required this.searching, required this.results, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    if (searching) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(color: AppColors.textOnDark, strokeWidth: 1.5),
          ),
        ),
      );
    }
    if (results.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: Text(
            'No matches.',
            style: GoogleFonts.inter(color: AppColors.secondaryOnDark, fontSize: 13),
          ),
        ),
      );
    }
    return Column(
      children: [
        const SizedBox(height: 8),
        for (final v in results) _VenueRow(venue: v, onTap: () => onSelect(v)),
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: GoogleFonts.inter(
      color: AppColors.secondaryOnDark,
      fontSize: 10.5,
      fontWeight: FontWeight.w600,
      letterSpacing: 10.5 * 0.1,
    ),
  );
}

class _TypeChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _TypeChip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) => Material(
    color: selected ? AppColors.ivory : Colors.transparent,
    borderRadius: BorderRadius.circular(999),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          border: selected ? null : Border.all(color: AppColors.hairlineOnGreen),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            color: selected ? AppColors.forestGreen : AppColors.textOnDark,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    ),
  );
}

/// [52pt foto of initiaal-tile | naam + sterren/sleutels + Stad · LC | ›]
/// — shared row shape for both the wishlist shortcuts and search results.
class _VenueRow extends StatelessWidget {
  final PassportVenue venue;
  final VoidCallback onTap;
  const _VenueRow({required this.venue, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final award = switch (venue) {
      RestaurantVenue(:final restaurant) =>
        (restaurant.michelinStars ?? 0) > 0 ? StarRow(count: restaurant.michelinStars!, size: 12) : null,
      HotelVenue(:final hotel) =>
        (hotel.michelinKeys ?? 0) > 0 ? KeyRow(count: hotel.michelinKeys!, size: 12) : null,
    };
    final cityName = switch (venue) {
      RestaurantVenue(:final restaurant) => restaurant.cityName,
      HotelVenue(:final hotel) => hotel.cityName,
    };
    final countryCode = venue.countryCode;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              const VenueThumbnail(imageUrl: null, size: 52, borderRadius: BorderRadius.all(Radius.circular(4))),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _venueName(venue),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.cormorantGaramond(
                        color: AppColors.textOnDark,
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        if (award != null) ...[award, const SizedBox(width: 6)],
                        Flexible(
                          child: CsCountryLabel(
                            cityName: cityName,
                            countryCode: countryCode,
                            style: GoogleFonts.inter(color: AppColors.secondaryOnDark, fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: AppColors.secondaryOnDark, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Step 2: details + live stamp preview ────────────────────────────────

class _Step2 extends StatelessWidget {
  final PassportVenue venue;
  final DateTime visitedOn;
  final VoidCallback onPickDate;
  final int? score;
  final ValueChanged<int?> onScoreChanged;
  final TextEditingController notesCtrl;
  final bool saving;
  final String? error;
  final VoidCallback onSave;

  const _Step2({
    required this.venue,
    required this.visitedOn,
    required this.onPickDate,
    required this.score,
    required this.onScoreChanged,
    required this.notesCtrl,
    required this.saving,
    required this.error,
    required this.onSave,
  });

  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  PassportStampItem _previewItem() {
    final id = 'preview:${_venueId(venue)}';
    return switch (venue) {
      RestaurantVenue(:final restaurant) => RestaurantStampItem(
        restaurant: restaurant,
        visit: Visit(
          id: id,
          userId: '',
          entityType: 'restaurant',
          entityId: restaurant.id,
          visitedOn: visitedOn,
          starsAtVisit: restaurant.michelinStars,
        ),
      ),
      HotelVenue(:final hotel) => HotelStampItem(
        hotel: hotel,
        visit: Visit(
          id: id,
          userId: '',
          entityType: 'hotel',
          entityId: hotel.id,
          visitedOn: visitedOn,
          keysAtVisit: hotel.michelinKeys,
        ),
      ),
    };
  }

  @override
  Widget build(BuildContext context) {
    final item = _previewItem();
    final cityName = switch (venue) {
      RestaurantVenue(:final restaurant) => restaurant.cityName,
      HotelVenue(:final hotel) => hotel.cityName,
    };

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            height: 200,
            child: Center(
              child: PassportStampWidget(
                item: item,
                variant: pickStampVariant(item.id),
                ink: pickStampInk(item.id),
                rotationDegrees: pickStampRotationDegrees(item.id),
                semanticLabel: 'Preview of the stamp this visit will get',
                isNew: false,
                onTap: () {},
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _venueName(venue),
            textAlign: TextAlign.center,
            style: GoogleFonts.cormorantGaramond(
              color: AppColors.forestGreen,
              fontSize: 32,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          CsCountryLabel(
            cityName: cityName,
            countryCode: venue.countryCode,
            style: GoogleFonts.inter(color: AppColors.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 24),
          Align(
            alignment: Alignment.centerLeft,
            child: _FieldLabel('DATE'),
          ),
          const SizedBox(height: 6),
          _DateTapRow(date: visitedOn, months: _months, onTap: onPickDate),
          const SizedBox(height: 24),
          // The SAME RatingMeter every other visit-rating input in this app
          // already uses (add_visit_sheet.dart/add_stay_sheet.dart) — same
          // 1-10 range, same tap behavior, same "Not rated" affordance for
          // this optional field. The stamp flow is a new way to add a
          // visit, not a new way to score one; explicitly corrected away
          // from this file's own first draft, which had invented a
          // different-looking picker instead of reusing this.
          RatingMeter(label: 'Your score', value: score, onChanged: onScoreChanged),
          const SizedBox(height: 24),
          Container(height: 1, color: AppColors.hairlineOnPaper),
          TextField(
            controller: notesCtrl,
            maxLines: 3,
            minLines: 1,
            style: GoogleFonts.inter(color: AppColors.textPrimary, fontSize: 14),
            decoration: InputDecoration(
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
              border: InputBorder.none,
              hintText: 'A note for your passport…',
              hintStyle: GoogleFonts.cormorantGaramond(
                color: AppColors.textSecondary,
                fontStyle: FontStyle.italic,
                fontSize: 15,
              ),
            ),
          ),
          Container(height: 1, color: AppColors.hairlineOnPaper),
          const SizedBox(height: 20),
          if (error != null) ...[
            Text(
              error!,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(color: AppColors.error, fontSize: 13),
            ),
            const SizedBox(height: 12),
          ],
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: saving ? null : onSave,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.forestGreen,
                foregroundColor: AppColors.textOnDark,
                disabledBackgroundColor: AppColors.forestGreen.withValues(alpha: 0.5),
                shape: const StadiumBorder(),
                textStyle: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600),
              ),
              child: saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(color: AppColors.textOnDark, strokeWidth: 2),
                    )
                  : const Text('Press the stamp'),
            ),
          ),
        ],
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel(this.text);

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: GoogleFonts.inter(
      color: AppColors.textSecondary,
      fontSize: 9,
      fontWeight: FontWeight.w600,
      letterSpacing: 9 * 0.12,
    ),
  );
}

class _DateTapRow extends StatelessWidget {
  final DateTime date;
  final List<String> months;
  final VoidCallback onTap;
  const _DateTapRow({required this.date, required this.months, required this.onTap});

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(
            '${date.day} ${months[date.month - 1]} ${date.year}',
            style: GoogleFonts.cormorantGaramond(
              color: AppColors.textPrimary,
              fontSize: 20,
              fontWeight: FontWeight.w600,
              fontFeatures: _liningFigures,
            ),
          ),
          const SizedBox(width: 8),
          const Icon(Icons.expand_more_rounded, color: AppColors.textSecondary, size: 20),
        ],
      ),
    ),
  );
}


/// The details step's own paper background texture — fine concentric
/// rings, matching the stamp pages' own guilloché motif (this step is
/// where a stamp visually forms, so it pairs with the stamp-page
/// background rather than the data page's diagonal one). A small new
/// painter rather than promoting either existing one — both are private
/// to their own files (passport_page.dart / passport_data_page.dart), and
/// re-deriving 15 lines here is cheaper than un-privating either for one
/// more caller with its own, differently-sized canvas.
class _SheetGuillochePainter extends CustomPainter {
  const _SheetGuillochePainter();

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;
    final center = Offset(size.width / 2, -40);
    final maxRadius = (center - Offset(0, size.height)).distance + size.width;
    final paint = Paint()
      ..color = AppColors.stampGuillocheLine
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    const spacing = 8.0;
    var radius = spacing;
    while (radius < maxRadius) {
      canvas.drawCircle(center, radius, paint);
      radius += spacing;
    }
  }

  @override
  bool shouldRepaint(covariant _SheetGuillochePainter oldDelegate) => false;
}
