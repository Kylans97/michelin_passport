import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/app_colors.dart';
import '../../../data/repositories/visited_repository.dart';
import '../../../models/hotel.dart';
import '../../restaurants/widgets/detail_section.dart';
import '../../visits/widgets/date_card.dart';
import '../../visits/widgets/rating_meter.dart';
import '../../visits/widgets/save_button.dart';

/// Opens the "log a stay" bottom sheet for [hotel] and inserts a new hotel
/// stay row via [visitedRepository] on save. Returns true once a stay has
/// been saved, or null if the sheet was dismissed without saving.
///
/// Deliberately narrower than restaurant Add Visit: hotel stays only cover
/// Overall/Service/Value + Notes — no Food, Wine, or Menu Type, which are
/// restaurant concepts that don't apply to a hotel stay.
Future<bool?> showAddStaySheet(
  BuildContext context, {
  required Hotel hotel,
  required String userId,
  required VisitedRepository visitedRepository,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _AddStaySheet(
      hotel: hotel,
      userId: userId,
      visitedRepository: visitedRepository,
    ),
  );
}

class _AddStaySheet extends StatefulWidget {
  final Hotel hotel;
  final String userId;
  final VisitedRepository visitedRepository;

  const _AddStaySheet({
    required this.hotel,
    required this.userId,
    required this.visitedRepository,
  });

  @override
  State<_AddStaySheet> createState() => _AddStaySheetState();
}

class _AddStaySheetState extends State<_AddStaySheet> {
  DateTime _stayedOn = DateTime.now();
  int? _rating;
  int? _serviceRating;
  int? _valueRating;
  final _notesCtrl = TextEditingController();

  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _stayedOn,
      firstDate: DateTime(now.year - 20),
      lastDate: now, // future dates not allowed
    );
    if (picked != null) setState(() => _stayedOn = picked);
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final notes = _notesCtrl.text.trim();
      await widget.visitedRepository.markHotelStay(
        userId: widget.userId,
        hotelId: widget.hotel.id,
        visitedOn: _stayedOn,
        rating: _rating,
        serviceRating: _serviceRating,
        valueRating: _valueRating,
        notes: notes.isEmpty ? null : notes,
        keysAtVisit: widget.hotel.michelinKeys,
      );
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (error, stackTrace) {
      debugPrint('SAVE STAY ERROR: $error');
      debugPrintStack(label: 'SAVE STAY STACK', stackTrace: stackTrace);

      if (!mounted) return;

      setState(() {
        _saving = false;
        _error = 'Could not save stay: $error';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final maxHeight = MediaQuery.of(context).size.height * 0.92;
    final hotel = widget.hotel;
    final location = [
      hotel.cityName,
      hotel.countryName,
    ].where((s) => s.isNotEmpty).join(', ');

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

                  // ── Header ─────────────────────────────────────────────
                  const SectionLabel('LOG YOUR STAY'),
                  const SizedBox(height: 8),
                  Text(
                    hotel.name,
                    style: GoogleFonts.playfairDisplay(
                      color: AppColors.textPrimary,
                      fontSize: 25,
                      fontWeight: FontWeight.w700,
                      height: 1.15,
                    ),
                  ),
                  if (location.isNotEmpty) ...[
                    const SizedBox(height: 5),
                    Text(
                      location,
                      style: GoogleFonts.inter(
                        color: AppColors.textSecondary,
                        fontSize: 14,
                      ),
                    ),
                  ],
                  const SizedBox(height: 32),

                  DateCard(
                    label: 'STAY DATE',
                    date: _stayedOn,
                    onTap: _pickDate,
                  ),
                  const SizedBox(height: 32),

                  // ── Ratings ────────────────────────────────────────────
                  const SectionLabel('RATINGS'),
                  const SizedBox(height: 18),
                  RatingMeter(
                    label: 'Overall',
                    value: _rating,
                    onChanged: (v) => setState(() => _rating = v),
                  ),
                  const SizedBox(height: 22),
                  RatingMeter(
                    label: 'Service',
                    value: _serviceRating,
                    onChanged: (v) => setState(() => _serviceRating = v),
                  ),
                  const SizedBox(height: 22),
                  RatingMeter(
                    label: 'Value',
                    value: _valueRating,
                    onChanged: (v) => setState(() => _valueRating = v),
                  ),
                  const SizedBox(height: 32),

                  // ── Notes ──────────────────────────────────────────────
                  const SectionLabel('NOTES'),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _notesCtrl,
                    style: GoogleFonts.inter(
                      color: AppColors.textPrimary,
                      fontSize: 14,
                      height: 1.5,
                    ),
                    maxLines: 4,
                    minLines: 3,
                    decoration: InputDecoration(
                      hintText: 'Add a note about your stay…',
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
                  SaveButton(saving: _saving, label: 'Save stay', onTap: _save),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
