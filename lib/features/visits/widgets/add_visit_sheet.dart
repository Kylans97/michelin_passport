import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/app_colors.dart';
import '../../../data/repositories/visited_repository.dart';
import '../../../models/restaurant.dart';
import '../../../models/visit.dart';
import '../../restaurants/widgets/detail_section.dart';
import 'rating_meter.dart';

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

String _formatDate(DateTime date) =>
    '${_monthNames[date.month - 1]} ${date.day}, ${date.year}';

/// Opens the "log a visit" bottom sheet for [restaurant] and inserts a new
/// row via [visitedRepository] on save. Returns true once a visit has been
/// saved, or null if the sheet was dismissed without saving.
Future<bool?> showAddVisitSheet(
  BuildContext context, {
  required Restaurant restaurant,
  required String userId,
  required VisitedRepository visitedRepository,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _AddVisitSheet(
      restaurant: restaurant,
      userId: userId,
      visitedRepository: visitedRepository,
    ),
  );
}

class _AddVisitSheet extends StatefulWidget {
  final Restaurant restaurant;
  final String userId;
  final VisitedRepository visitedRepository;

  const _AddVisitSheet({
    required this.restaurant,
    required this.userId,
    required this.visitedRepository,
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

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final notes = _notesCtrl.text.trim();
      await widget.visitedRepository.markVisited(
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
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (error, stackTrace) {
      debugPrint('SAVE VISIT ERROR: $error');
      debugPrintStack(
        label: 'SAVE VISIT STACK',
        stackTrace: stackTrace,
      );

      if (!mounted) return;

      setState(() {
        _saving = false;
        _error = 'Could not save visit: $error';
      });
    }
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

                  _DateCard(date: _visitedOn, onTap: _pickDate),
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
                  _SaveButton(saving: _saving, onTap: _save),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Date card ──────────────────────────────────────────────────────────────

class _DateCard extends StatelessWidget {
  final DateTime date;
  final VoidCallback onTap;
  const _DateCard({required this.date, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        splashColor: AppColors.goldAlpha10,
        highlightColor: AppColors.goldAlpha10,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.cardBorder, width: 0.5),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.goldAlpha10,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.goldBorder40, width: 0.5),
                ),
                child: const Icon(
                  Icons.calendar_today_rounded,
                  color: AppColors.gold,
                  size: 17,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SectionLabel('VISIT DATE'),
                    const SizedBox(height: 3),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 180),
                      child: Text(
                        _formatDate(date),
                        key: ValueKey(date),
                        style: GoogleFonts.inter(
                          color: AppColors.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.textSecondary,
                size: 22,
              ),
            ],
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

// ── Save button ────────────────────────────────────────────────────────────

class _SaveButton extends StatelessWidget {
  final bool saving;
  final VoidCallback onTap;
  const _SaveButton({required this.saving, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      width: double.infinity,
      height: 56,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.gold.withValues(alpha: saving ? 0.12 : 0.28),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: FilledButton(
        onPressed: saving ? null : onTap,
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.gold,
          foregroundColor: Colors.black,
          disabledBackgroundColor: AppColors.goldMuted,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          child: saving
              ? const SizedBox(
                  key: ValueKey('saving'),
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    color: Colors.black,
                    strokeWidth: 2,
                  ),
                )
              : Text(
                  'Save visit',
                  key: const ValueKey('label'),
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                    letterSpacing: 0.2,
                  ),
                ),
        ),
      ),
    );
  }
}
