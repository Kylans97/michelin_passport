import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/country_picker_sheet.dart';
import '../../../data/repositories/planned_trips_repository.dart';
import '../../../models/planned_trip.dart';
import '../../../models/venue_country.dart';
import '../../restaurants/widgets/detail_section.dart';
import '../../visits/widgets/date_card.dart';
import '../../visits/widgets/save_button.dart';

/// Opens the "Create trip"/"Edit trip" bottom sheet. Passing [existingTrip]
/// switches to edit mode (pre-filled fields, updates in place); omitting it
/// creates a new trip. Returns true once saved, or null if dismissed.
Future<bool?> showCreateTripSheet(
  BuildContext context, {
  required String userId,
  required PlannedTripsRepository repo,
  PlannedTrip? existingTrip,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _CreateTripSheet(
      userId: userId,
      repo: repo,
      existingTrip: existingTrip,
    ),
  );
}

class _CreateTripSheet extends StatefulWidget {
  final String userId;
  final PlannedTripsRepository repo;
  final PlannedTrip? existingTrip;

  const _CreateTripSheet({
    required this.userId,
    required this.repo,
    this.existingTrip,
  });

  @override
  State<_CreateTripSheet> createState() => _CreateTripSheetState();
}

class _CreateTripSheetState extends State<_CreateTripSheet> {
  late final _titleCtrl = TextEditingController(
    text: widget.existingTrip?.title ?? '',
  );
  late final _cityCtrl = TextEditingController(
    text: widget.existingTrip?.city ?? '',
  );
  late final _notesCtrl = TextEditingController(
    text: widget.existingTrip?.notes ?? '',
  );

  late DateTime _startDate =
      widget.existingTrip?.startDate ??
      DateTime.now().add(const Duration(days: 30));
  late DateTime _endDate =
      widget.existingTrip?.endDate ??
      DateTime.now().add(const Duration(days: 33));
  VenueCountry? _country;

  bool _saving = false;
  String? _error;

  late final Future<List<VenueCountry>> _countriesFuture = widget.repo
      .loadAllCountries()
      .then((countries) {
        // Pre-select the existing trip's country once the list resolves —
        // done here (not in initState) since it depends on this future.
        final existingCode = widget.existingTrip?.countryCode;
        if (existingCode != null && mounted) {
          final match = countries.where((c) => c.code == existingCode);
          if (match.isNotEmpty) setState(() => _country = match.first);
        }
        return countries;
      });

  bool get _isEditing => widget.existingTrip != null;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _cityCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickStartDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: now,
      lastDate: DateTime(now.year + 6),
    );
    if (picked == null) return;
    setState(() {
      _startDate = picked;
      if (_endDate.isBefore(_startDate)) {
        _endDate = _startDate.add(const Duration(days: 1));
      }
    });
  }

  Future<void> _pickEndDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _endDate.isBefore(_startDate) ? _startDate : _endDate,
      firstDate: _startDate,
      lastDate: DateTime(_startDate.year + 6),
    );
    if (picked != null) setState(() => _endDate = picked);
  }

  Future<void> _pickCountry(List<VenueCountry> countries) async {
    final picked = await showCountryPickerSheet(context, countries: countries);
    if (picked != null) setState(() => _country = picked);
  }

  Future<void> _save() async {
    final title = _titleCtrl.text.trim();
    if (title.isEmpty) {
      setState(() => _error = 'Give this trip a name.');
      return;
    }
    if (_country == null) {
      setState(() => _error = 'Choose a country.');
      return;
    }
    if (_endDate.isBefore(_startDate)) {
      setState(() => _error = 'End date must be on or after the start date.');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final city = _cityCtrl.text.trim();
      final notes = _notesCtrl.text.trim();
      if (_isEditing) {
        await widget.repo.updateTrip(
          userId: widget.userId,
          tripId: widget.existingTrip!.id,
          title: title,
          startDate: _startDate,
          endDate: _endDate,
          countryCode: _country!.code,
          city: city.isEmpty ? null : city,
          notes: notes.isEmpty ? null : notes,
        );
      } else {
        await widget.repo.createTrip(
          userId: widget.userId,
          title: title,
          startDate: _startDate,
          endDate: _endDate,
          countryCode: _country!.code,
          city: city.isEmpty ? null : city,
          notes: notes.isEmpty ? null : notes,
        );
      }
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = 'Could not save trip: $error';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final maxHeight = MediaQuery.of(context).size.height * 0.92;

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
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.divider,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  SectionLabel(_isEditing ? 'EDIT TRIP' : 'CREATE TRIP'),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _titleCtrl,
                    style: GoogleFonts.playfairDisplay(
                      color: AppColors.textPrimary,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Trip name, e.g. Maastricht',
                      hintStyle: GoogleFonts.playfairDisplay(
                        color: AppColors.textSecondary,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),

                  DateCard(
                    label: 'START DATE',
                    date: _startDate,
                    onTap: _pickStartDate,
                  ),
                  const SizedBox(height: 12),
                  DateCard(
                    label: 'END DATE',
                    date: _endDate,
                    onTap: _pickEndDate,
                  ),
                  const SizedBox(height: 28),

                  const SectionLabel('COUNTRY'),
                  const SizedBox(height: 12),
                  FutureBuilder<List<VenueCountry>>(
                    future: _countriesFuture,
                    builder: (context, snap) {
                      final countries = snap.data ?? [];
                      return Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: countries.isEmpty
                              ? null
                              : () => _pickCountry(countries),
                          borderRadius: BorderRadius.circular(18),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 16,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                color: AppColors.cardBorder,
                                width: 0.5,
                              ),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    _country == null
                                        ? (snap.connectionState ==
                                                  ConnectionState.waiting
                                              ? 'Loading countries…'
                                              : 'Choose a country')
                                        : '${_country!.flag}  ${_country!.name}',
                                    style: GoogleFonts.inter(
                                      color: _country == null
                                          ? AppColors.textSecondary
                                          : AppColors.textPrimary,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                                const Icon(
                                  Icons.chevron_right_rounded,
                                  color: AppColors.textSecondary,
                                  size: 20,
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 28),

                  const SectionLabel('CITY (OPTIONAL)'),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _cityCtrl,
                    style: GoogleFonts.inter(
                      color: AppColors.textPrimary,
                      fontSize: 14,
                    ),
                    decoration: InputDecoration(
                      hintText: 'e.g. Maastricht',
                      hintStyle: GoogleFonts.inter(
                        color: AppColors.textSecondary,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),

                  const SectionLabel('NOTES (OPTIONAL)'),
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
                      hintText: 'Anything to remember for this trip…',
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
                    label: _isEditing ? 'Save changes' : 'Create trip',
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
