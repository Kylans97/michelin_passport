import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/sheet_dismiss_handle.dart';
import '../../../data/repositories/planned_trips_repository.dart';
import '../../../models/passport_venue.dart';
import '../../../models/planned_trip.dart';
import '../../../models/planned_venue.dart';
import '../../restaurants/widgets/detail_section.dart';
import '../../visits/widgets/date_card.dart';
import '../../visits/widgets/save_button.dart';

/// Opens the "Plan visit"/"Plan stay" bottom sheet for [venue]. Creates a
/// new `planned_venues` row on save, unless [existingPlan] is given, in
/// which case that row is updated in place instead (My Planned Trips'
/// "edit a planned venue"). This is deliberately separate from Wishlist
/// ("I want to go here someday") and from logging a real visit — a plan is
/// "I intend to go around this date", and saving one never touches the
/// venue's wishlist membership either way. Returns true once saved, or
/// null if the sheet was dismissed without saving.
Future<bool?> showPlanVenueSheet(
  BuildContext context, {
  required PassportVenue venue,
  required String userId,
  required PlannedTripsRepository plannedTripsRepository,
  PlannedVenue? existingPlan,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _PlanVenueSheet(
      venue: venue,
      userId: userId,
      repo: plannedTripsRepository,
      existingPlan: existingPlan,
    ),
  );
}

class _PlanVenueSheet extends StatefulWidget {
  final PassportVenue venue;
  final String userId;
  final PlannedTripsRepository repo;
  final PlannedVenue? existingPlan;

  const _PlanVenueSheet({
    required this.venue,
    required this.userId,
    required this.repo,
    this.existingPlan,
  });

  @override
  State<_PlanVenueSheet> createState() => _PlanVenueSheetState();
}

class _PlanVenueSheetState extends State<_PlanVenueSheet> {
  late DateTime _startDate = widget.existingPlan?.startDate ?? DateTime.now();
  late DateTime? _endDate = widget.existingPlan?.endDate;
  late String? _tripId = widget.existingPlan?.tripId;
  late final _notesCtrl = TextEditingController(
    text: widget.existingPlan?.notes ?? '',
  );

  bool _saving = false;
  String? _error;

  late final Future<List<PlannedTrip>> _tripsFuture = widget.repo.loadTrips(
    widget.userId,
  );

  bool get _isHotel => widget.venue is HotelVenue;
  bool get _isEditing => widget.existingPlan != null;

  @override
  void dispose() {
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickStartDate() async {
    final now = DateTime.now();
    // Editing an existing plan may need to keep/adjust a date that's
    // already in the past (e.g. tidying up after a trip); creating a new
    // plan only ever makes sense for today or later.
    final firstDate = _isEditing ? DateTime(now.year - 1) : now;
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: firstDate,
      lastDate: DateTime(now.year + 5),
    );
    if (picked == null) return;
    setState(() {
      _startDate = picked;
      // A check-out before the (possibly moved) check-in makes no sense —
      // nudge it forward rather than leaving an invalid state to catch at
      // save time.
      if (_endDate != null && _endDate!.isBefore(_startDate)) {
        _endDate = _startDate.add(const Duration(days: 1));
      }
    });
  }

  Future<void> _pickEndDate() async {
    final initial = _endDate ?? _startDate.add(const Duration(days: 1));
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: _startDate,
      lastDate: DateTime(_startDate.year + 5),
    );
    if (picked != null) setState(() => _endDate = picked);
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final notes = _notesCtrl.text.trim();
      if (_isEditing) {
        await widget.repo.updatePlannedVenue(
          userId: widget.userId,
          plannedVenueId: widget.existingPlan!.id,
          tripId: _tripId,
          startDate: _startDate,
          endDate: _isHotel ? _endDate : null,
          notes: notes.isEmpty ? null : notes,
          status: widget.existingPlan!.status,
        );
      } else {
        final entityType = widget.venue is HotelVenue ? 'hotel' : 'restaurant';
        final entityId = switch (widget.venue) {
          RestaurantVenue(:final restaurant) => restaurant.id,
          HotelVenue(:final hotel) => hotel.id,
        };
        await widget.repo.createPlannedVenue(
          userId: widget.userId,
          entityType: entityType,
          entityId: entityId,
          tripId: _tripId,
          startDate: _startDate,
          endDate: _isHotel ? _endDate : null,
          notes: notes.isEmpty ? null : notes,
        );
      }
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = 'Could not save plan: $error';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final maxHeight = MediaQuery.of(context).size.height * 0.92;
    final venue = widget.venue;
    final location = switch (venue) {
      RestaurantVenue(:final restaurant) =>
        '${restaurant.cityName}, ${restaurant.countryName}',
      HotelVenue(:final hotel) => '${hotel.cityName}, ${hotel.countryName}',
    };

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SafeArea(
        top: false,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxHeight),
          child: Container(
            decoration: const BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 14, 24, 28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Matches Log Visit's own explicit, always-visible dismiss
                  // control — UI Consistency pass: previously a bare drag
                  // handle with no close affordance, the one concrete
                  // inconsistency between these two sheets.
                  SheetDismissHandle(
                    color: AppColors.textPrimary,
                    onClose: () => Navigator.pop(context),
                  ),
                  const SizedBox(height: 24),

                  SectionLabel(
                    _isEditing
                        ? (_isHotel
                              ? 'EDIT PLANNED STAY'
                              : 'EDIT PLANNED VISIT')
                        : (_isHotel ? 'PLAN STAY' : 'PLAN VISIT'),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    venue.name,
                    style: GoogleFonts.playfairDisplay(
                      color: AppColors.textPrimary,
                      fontSize: 25,
                      fontWeight: FontWeight.w700,
                      height: 1.15,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    location,
                    style: GoogleFonts.inter(
                      color: AppColors.textSecondary,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 32),

                  DateCard(
                    label: _isHotel ? 'CHECK-IN' : 'VISIT DATE',
                    date: _startDate,
                    onTap: _pickStartDate,
                  ),
                  if (_isHotel) ...[
                    const SizedBox(height: 12),
                    DateCard(
                      label: 'CHECK-OUT',
                      date: _endDate ?? _startDate.add(const Duration(days: 1)),
                      onTap: _pickEndDate,
                    ),
                  ],
                  const SizedBox(height: 32),

                  const SectionLabel('TRIP (OPTIONAL)'),
                  const SizedBox(height: 12),
                  FutureBuilder<List<PlannedTrip>>(
                    future: _tripsFuture,
                    builder: (context, snap) {
                      final trips = snap.data ?? [];
                      if (snap.connectionState == ConnectionState.waiting) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8),
                          child: SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              color: AppColors.forestGreen,
                              strokeWidth: 1.5,
                            ),
                          ),
                        );
                      }
                      if (trips.isEmpty) {
                        return Text(
                          'No planned trips yet — this will be a '
                          'standalone plan.',
                          style: GoogleFonts.inter(
                            color: AppColors.textSecondary,
                            fontSize: 13,
                          ),
                        );
                      }
                      return Column(
                        children: [
                          _TripOption(
                            title: 'No trip',
                            subtitle: 'Standalone plan',
                            selected: _tripId == null,
                            onTap: () => setState(() => _tripId = null),
                          ),
                          for (final trip in trips) ...[
                            const SizedBox(height: 8),
                            _TripOption(
                              title: trip.title,
                              subtitle: _formatTripRange(trip),
                              selected: _tripId == trip.id,
                              onTap: () => setState(() => _tripId = trip.id),
                            ),
                          ],
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 32),

                  const SectionLabel('NOTES'),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _notesCtrl,
                    style: GoogleFonts.inter(
                      color: AppColors.textPrimary,
                      fontSize: 14,
                      height: 1.5,
                    ),
                    maxLines: 3,
                    minLines: 2,
                    decoration: InputDecoration(
                      hintText: 'Anything to remember for this plan…',
                      hintStyle: GoogleFonts.inter(
                        color: AppColors.textSecondary,
                        fontSize: 14,
                        height: 1.5,
                      ),
                    ),
                  ),

                  AnimatedSize(
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeOutCubic,
                    child: _error == null
                        ? const SizedBox(width: double.infinity)
                        : Padding(
                            padding: const EdgeInsets.only(top: 16),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.error_outline_rounded,
                                  color: AppColors.error,
                                  size: 16,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _error!,
                                    style: GoogleFonts.inter(
                                      color: AppColors.error,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                  ),

                  const SizedBox(height: 28),
                  SaveButton(
                    saving: _saving,
                    label: _isEditing ? 'Save changes' : 'Save plan',
                    onTap: _save,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

const _monthNames = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

String _formatTripRange(PlannedTrip trip) {
  final s = trip.startDate;
  final e = trip.endDate;
  if (s.month == e.month && s.year == e.year) {
    return '${s.day}–${e.day} ${_monthNames[s.month - 1]} ${s.year}';
  }
  return '${s.day} ${_monthNames[s.month - 1]} – ${e.day} '
      '${_monthNames[e.month - 1]} ${e.year}';
}

class _TripOption extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  const _TripOption({
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.transparent,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      splashColor: AppColors.brandGreen.withValues(alpha: 0.06),
      highlightColor: AppColors.brandGreen.withValues(alpha: 0.04),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.brandGreen.withValues(alpha: 0.08)
              : AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected
                ? AppColors.brandGreen.withValues(alpha: 0.35)
                : AppColors.cardBorder,
            width: 0.5,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.inter(
                      color: AppColors.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: GoogleFonts.inter(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            if (selected)
              const Icon(
                Icons.check_circle_rounded,
                color: AppColors.brandGreen,
                size: 20,
              ),
          ],
        ),
      ),
    ),
  );
}
