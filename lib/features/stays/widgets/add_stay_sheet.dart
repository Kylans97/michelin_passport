import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/app_colors.dart';
import '../../../data/repositories/photo_repository.dart';
import '../../../data/repositories/visited_repository.dart';
import '../../../models/hotel.dart';
import '../../../models/save_outcome.dart';
import '../../../models/visit.dart';
import '../../photos/staged_photo.dart';
import '../../photos/widgets/staged_photo_picker.dart';
import '../../restaurants/widgets/detail_section.dart';
import '../../visits/widgets/date_card.dart';
import '../../visits/widgets/rating_meter.dart';
import '../../visits/widgets/save_button.dart';

/// Opens the "log a stay" bottom sheet for [hotel] and inserts a new hotel
/// stay row via [visitedRepository] on save, uploading any staged photos
/// against the newly created stay id via [photoRepository] once the stay
/// itself is safely saved. Returns a [SaveOutcome] once saved, or null if
/// the sheet was dismissed without saving.
///
/// Deliberately narrower than restaurant Add Visit: hotel stays only cover
/// Overall/Service/Value + Notes — no Food, Wine, or Menu Type, which are
/// restaurant concepts that don't apply to a hotel stay.
Future<SaveOutcome?> showAddStaySheet(
  BuildContext context, {
  required Hotel hotel,
  required String userId,
  required VisitedRepository visitedRepository,
  required PhotoRepository photoRepository,
}) {
  return showModalBottomSheet<SaveOutcome>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _AddStaySheet(
      hotel: hotel,
      userId: userId,
      visitedRepository: visitedRepository,
      photoRepository: photoRepository,
    ),
  );
}

class _AddStaySheet extends StatefulWidget {
  final Hotel hotel;
  final String userId;
  final VisitedRepository visitedRepository;
  final PhotoRepository photoRepository;

  const _AddStaySheet({
    required this.hotel,
    required this.userId,
    required this.visitedRepository,
    required this.photoRepository,
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
  final List<StagedPhoto> _stagedPhotos = [];
  bool _pickingPhotos = false;

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

  Future<void> _addPhotos() async {
    if (_pickingPhotos) return;
    setState(() => _pickingPhotos = true);
    try {
      final picked = await pickStagedPhotos();
      if (!mounted) return;
      setState(() => _stagedPhotos.addAll(picked));
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Could not open photo library.');
    } finally {
      if (mounted) setState(() => _pickingPhotos = false);
    }
  }

  void _removeStagedPhoto(StagedPhoto photo) {
    setState(() => _stagedPhotos.remove(photo));
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });

    // Step 1: the stay itself. A public.photos row can't safely reference
    // a stay that doesn't exist yet, so this must succeed, and only this,
    // before any staged photo is touched. If it fails, zero photos are
    // uploaded, the sheet stays open, and every entered value/staged photo
    // is preserved for the user to retry.
    final Visit stay;
    try {
      final notes = _notesCtrl.text.trim();
      stay = await widget.visitedRepository.markHotelStay(
        userId: widget.userId,
        hotelId: widget.hotel.id,
        visitedOn: _stayedOn,
        rating: _rating,
        serviceRating: _serviceRating,
        valueRating: _valueRating,
        notes: notes.isEmpty ? null : notes,
        keysAtVisit: widget.hotel.michelinKeys,
      );
    } catch (error, stackTrace) {
      debugPrint('SAVE STAY ERROR: $error');
      debugPrintStack(label: 'SAVE STAY STACK', stackTrace: stackTrace);
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = 'Could not save stay: $error';
      });
      return;
    }

    // Step 2: upload whatever staged photos we can against the now-real
    // stay.id. The stay is already saved and stays saved regardless of
    // what happens here — a photo failure is reported, never hidden, but
    // never undoes the historical record.
    var photoFailures = 0;
    for (final staged in _stagedPhotos) {
      try {
        await widget.photoRepository.uploadPhoto(
          userId: widget.userId,
          visitId: stay.id,
          entityType: stay.entityType,
          entityId: stay.entityId,
          bytes: staged.bytes,
          fileExtension: extensionOfXFile(staged.file),
        );
      } catch (error, stackTrace) {
        debugPrint('SAVE STAY PHOTO UPLOAD ERROR: $error');
        debugPrintStack(label: 'SAVE STAY PHOTO STACK', stackTrace: stackTrace);
        photoFailures++;
      }
    }

    if (!mounted) return;
    Navigator.pop(
      context,
      photoFailures > 0 ? SaveOutcome.savedWithPhotoErrors : SaveOutcome.saved,
    );
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
                  const SizedBox(height: 32),

                  // ── Photos ─────────────────────────────────────────────
                  const SectionLabel('PHOTOS'),
                  const SizedBox(height: 12),
                  StagedPhotoPicker(
                    photos: _stagedPhotos,
                    picking: _pickingPhotos,
                    onAdd: _addPhotos,
                    onRemove: _removeStagedPhoto,
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
