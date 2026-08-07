import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/app_colors.dart';
import '../../../data/repositories/photo_repository.dart';
import '../../../data/repositories/visited_repository.dart';
import '../../../models/restaurant.dart';
import '../../../models/save_outcome.dart';
import '../../../models/visit.dart';
import '../../photos/staged_photo.dart';
import '../../photos/widgets/staged_photo_picker.dart';
import '../../restaurants/widgets/detail_section.dart';
import 'date_card.dart';
import 'rating_meter.dart';
import 'save_button.dart';

/// Opens the "log a visit" bottom sheet for [restaurant] and inserts a new
/// row via [visitedRepository] on save, uploading any staged photos against
/// the newly created visit id via [photoRepository] once the visit itself
/// is safely saved. Returns a [SaveOutcome] once saved, or null if the
/// sheet was dismissed without saving.
Future<SaveOutcome?> showAddVisitSheet(
  BuildContext context, {
  required Restaurant restaurant,
  required String userId,
  required VisitedRepository visitedRepository,
  required PhotoRepository photoRepository,
}) {
  return showModalBottomSheet<SaveOutcome>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _AddVisitSheet(
      restaurant: restaurant,
      userId: userId,
      visitedRepository: visitedRepository,
      photoRepository: photoRepository,
    ),
  );
}

class _AddVisitSheet extends StatefulWidget {
  final Restaurant restaurant;
  final String userId;
  final VisitedRepository visitedRepository;
  final PhotoRepository photoRepository;

  const _AddVisitSheet({
    required this.restaurant,
    required this.userId,
    required this.visitedRepository,
    required this.photoRepository,
  });

  @override
  State<_AddVisitSheet> createState() => _AddVisitSheetState();
}

class _AddVisitSheetState extends State<_AddVisitSheet> {
  DateTime _visitedOn = DateTime.now();
  int? _rating;
  int? _foodRating;
  int? _serviceRating;
  int? _wineRating;
  int? _valueRating;
  MenuType? _menuType;
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
      initialDate: _visitedOn,
      firstDate: DateTime(now.year - 20),
      lastDate: now, // future dates not allowed
    );
    if (picked != null) setState(() => _visitedOn = picked);
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

    // Step 1: the visit itself. A public.photos row can't safely reference
    // a visit that doesn't exist yet, so this must succeed, and only this,
    // before any staged photo is touched. If it fails, zero photos are
    // uploaded, the sheet stays open, and every entered value/staged photo
    // is preserved for the user to retry.
    final Visit visit;
    try {
      final notes = _notesCtrl.text.trim();
      visit = await widget.visitedRepository.markVisited(
        userId: widget.userId,
        restaurantId: widget.restaurant.id,
        visitedOn: _visitedOn,
        rating: _rating,
        foodRating: _foodRating,
        serviceRating: _serviceRating,
        wineRating: _wineRating,
        valueRating: _valueRating,
        menuType: _menuType,
        notes: notes.isEmpty ? null : notes,
        starsAtVisit: widget.restaurant.michelinStars,
        // keysAtVisit intentionally omitted: this is a restaurant visit,
        // and Michelin Keys are a hotel award.
      );
    } catch (error, stackTrace) {
      debugPrint('SAVE VISIT ERROR: $error');
      debugPrintStack(label: 'SAVE VISIT STACK', stackTrace: stackTrace);
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = 'Could not save visit: $error';
      });
      return;
    }

    // Step 2: upload whatever staged photos we can against the now-real
    // visit.id. The visit is already saved and stays saved regardless of
    // what happens here — a photo failure is reported, never hidden, but
    // never undoes the historical record.
    var photoFailures = 0;
    for (final staged in _stagedPhotos) {
      try {
        await widget.photoRepository.uploadPhoto(
          userId: widget.userId,
          visitId: visit.id,
          entityType: visit.entityType,
          entityId: visit.entityId,
          bytes: staged.bytes,
          fileExtension: extensionOfXFile(staged.file),
        );
      } catch (error, stackTrace) {
        debugPrint('SAVE VISIT PHOTO UPLOAD ERROR: $error');
        debugPrintStack(
          label: 'SAVE VISIT PHOTO STACK',
          stackTrace: stackTrace,
        );
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
    final restaurant = widget.restaurant;
    final location = [
      restaurant.cityName,
      restaurant.countryName,
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
                  const SectionLabel('LOG YOUR VISIT'),
                  const SizedBox(height: 8),
                  Text(
                    restaurant.name,
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
                    label: 'VISIT DATE',
                    date: _visitedOn,
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
                    label: 'Food',
                    value: _foodRating,
                    onChanged: (v) => setState(() => _foodRating = v),
                  ),
                  const SizedBox(height: 22),
                  RatingMeter(
                    label: 'Service',
                    value: _serviceRating,
                    onChanged: (v) => setState(() => _serviceRating = v),
                  ),
                  const SizedBox(height: 22),
                  RatingMeter(
                    label: 'Wine',
                    value: _wineRating,
                    onChanged: (v) => setState(() => _wineRating = v),
                  ),
                  const SizedBox(height: 22),
                  RatingMeter(
                    label: 'Value',
                    value: _valueRating,
                    onChanged: (v) => setState(() => _valueRating = v),
                  ),
                  const SizedBox(height: 32),

                  // ── Menu type ──────────────────────────────────────────
                  const SectionLabel('MENU TYPE'),
                  const SizedBox(height: 12),
                  _MenuTypeSelector(
                    value: _menuType,
                    onChanged: (v) => setState(() => _menuType = v),
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
                      hintText: 'Add a note about your evening…',
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
                  SaveButton(
                    saving: _saving,
                    label: 'Save visit',
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

// ── Menu type ────────────────────────────────────────────────────────────────

class _MenuTypeSelector extends StatelessWidget {
  final MenuType? value;
  final ValueChanged<MenuType?> onChanged;
  const _MenuTypeSelector({required this.value, required this.onChanged});

  static String _labelFor(MenuType type) => switch (type) {
    MenuType.tastingMenu => 'Tasting menu',
    MenuType.aLaCarte => 'À la carte',
    MenuType.both => 'Both',
  };

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        for (final type in MenuType.values)
          _MenuTypeChip(
            label: _labelFor(type),
            selected: value == type,
            // Tap again to clear — menu type is optional.
            onTap: () => onChanged(value == type ? null : type),
          ),
      ],
    );
  }
}

class _MenuTypeChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _MenuTypeChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.transparent,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      splashColor: AppColors.goldAlpha10,
      highlightColor: AppColors.goldAlpha10,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? AppColors.goldMuted : AppColors.surface,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: selected ? AppColors.goldBorder60 : AppColors.cardBorder,
            width: selected ? 1.0 : 0.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 150),
              child: selected
                  ? const Padding(
                      key: ValueKey('check'),
                      padding: EdgeInsets.only(right: 6),
                      child: Icon(
                        Icons.check_rounded,
                        size: 15,
                        color: AppColors.gold,
                      ),
                    )
                  : const SizedBox(key: ValueKey('nocheck')),
            ),
            Text(
              label,
              style: GoogleFonts.inter(
                color: selected ? AppColors.gold : AppColors.textSecondary,
                fontSize: 13,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
