import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants/app_colors.dart';
import '../../core/widgets/key_row.dart';
import '../../data/repositories/visited_repository.dart';
import '../../models/hotel.dart';
import '../../models/visit.dart';
import '../photos/widgets/visit_photos_section.dart';
import '../restaurants/widgets/detail_section.dart';
import '../visits/widgets/rating_display_row.dart';

const _monthNames = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

String _formatStayDate(DateTime date) =>
    '${date.day} ${_monthNames[date.month - 1]} ${date.year}';

/// Shows exactly what the user recorded during a single stay. This is
/// historical information: [stay.keysAtVisit] is the hotel's Michelin Keys
/// at the time of the stay and is shown as-is, never replaced by the
/// hotel's current Michelin Keys.
///
/// Also owns deleting this one stay — see [_confirmDelete]. Deleting pops
/// this screen with `true`, which HotelStaysCard's onTap uses to refresh
/// Hotel Detail's stay history immediately.
class StayDetailScreen extends StatefulWidget {
  final Hotel hotel;
  final Visit stay;

  const StayDetailScreen({super.key, required this.hotel, required this.stay});

  @override
  State<StayDetailScreen> createState() => _StayDetailScreenState();
}

class _StayDetailScreenState extends State<StayDetailScreen> {
  late final _visitedRepo = VisitedRepository(Supabase.instance.client);
  late Visit _stay = widget.stay;
  bool _deleting = false;
  bool _updatingVisibility = false;

  void _showSnack(String message, {bool isError = true}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: GoogleFonts.inter(color: AppColors.textPrimary),
        ),
        backgroundColor: isError ? AppColors.error : AppColors.gold,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // Mirrors VisitDetailScreen's own _toggleVisibility — same table, same
  // smallest-sensible-seam reasoning (see the Step 2 implementation
  // report).
  Future<void> _toggleVisibility() async {
    if (_updatingVisibility) return;
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null || uid.isEmpty) {
      _showSnack('Sign in required.');
      return;
    }
    final next = _stay.visibility == VisitVisibility.friends
        ? VisitVisibility.private
        : VisitVisibility.friends;
    setState(() => _updatingVisibility = true);
    try {
      final updated = await _visitedRepo.updateVisitVisibility(
        userId: uid,
        visitId: _stay.id,
        visibility: next,
      );
      if (!mounted) return;
      setState(() {
        _stay = updated;
        _updatingVisibility = false;
      });
      _showSnack(
        next == VisitVisibility.friends
            ? 'Friends can now see this stay.'
            : 'This stay is private again.',
        isError: false,
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _updatingVisibility = false);
      _showSnack('Could not update. Please try again.');
    }
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.card,
        title: Text(
          'Delete this stay?',
          style: GoogleFonts.playfairDisplay(
            color: AppColors.textPrimary,
            fontSize: 18,
          ),
        ),
        content: Text(
          'This will permanently remove:\n'
          '• this stay\n'
          '• its ratings\n'
          '• notes\n'
          '• photos linked to this stay\n\n'
          'Other stays at this hotel will NOT be affected.',
          style: GoogleFonts.inter(
            color: AppColors.textSecondary,
            fontSize: 14,
            height: 1.5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancel',
              style: GoogleFonts.inter(color: AppColors.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              'Delete stay',
              style: GoogleFonts.inter(
                color: AppColors.error,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || _deleting || !mounted) return;

    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null || uid.isEmpty) {
      _showSnack('Sign in required.');
      return;
    }

    setState(() => _deleting = true);
    try {
      await _visitedRepo.deleteVisitById(userId: uid, visitId: _stay.id);
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (_) {
      if (!mounted) return;
      setState(() => _deleting = false);
      _showSnack('Could not delete stay. Please try again.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final hotel = widget.hotel;
    final stay = _stay;
    final keys = stay.keysAtVisit;
    final notes = stay.notes;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        foregroundColor: AppColors.textPrimary,
        actions: [
          if (_deleting || _updatingVisibility)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  color: AppColors.gold,
                  strokeWidth: 2,
                ),
              ),
            )
          else
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert_rounded),
              color: AppColors.card,
              onSelected: (value) {
                if (value == 'visibility') _toggleVisibility();
                if (value == 'delete') _confirmDelete();
              },
              itemBuilder: (context) => [
                PopupMenuItem<String>(
                  value: 'visibility',
                  child: Row(
                    children: [
                      Icon(
                        stay.visibility == VisitVisibility.friends
                            ? Icons.lock_open_rounded
                            : Icons.lock_outline_rounded,
                        color: AppColors.textPrimary,
                        size: 18,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        stay.visibility == VisitVisibility.friends
                            ? 'Make private'
                            : 'Make visible to friends',
                        style: GoogleFonts.inter(color: AppColors.textPrimary),
                      ),
                    ],
                  ),
                ),
                PopupMenuItem<String>(
                  value: 'delete',
                  child: Row(
                    children: [
                      const Icon(
                        Icons.delete_outline_rounded,
                        color: AppColors.error,
                        size: 18,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Delete stay',
                        style: GoogleFonts.inter(color: AppColors.error),
                      ),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              hotel.name,
              style: GoogleFonts.playfairDisplay(
                color: AppColors.textPrimary,
                fontSize: 26,
                fontWeight: FontWeight.w700,
                height: 1.15,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Text(
                  _formatStayDate(stay.visitedOn),
                  style: GoogleFonts.inter(
                    color: AppColors.textSecondary,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (keys != null && keys > 0) ...[
                  const SizedBox(width: 10),
                  KeyRow(count: keys, size: 14),
                ],
                const SizedBox(width: 10),
                Icon(
                  stay.visibility == VisitVisibility.friends
                      ? Icons.lock_open_rounded
                      : Icons.lock_outline_rounded,
                  color: AppColors.textSecondary,
                  size: 13,
                ),
                const SizedBox(width: 3),
                Text(
                  stay.visibility == VisitVisibility.friends
                      ? 'Visible to friends'
                      : 'Private',
                  style: GoogleFonts.inter(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),

            const SectionLabel('RATINGS'),
            const SizedBox(height: 18),
            RatingDisplayRow(label: 'Overall', value: stay.rating),
            const SizedBox(height: 20),
            RatingDisplayRow(label: 'Service', value: stay.serviceRating),
            const SizedBox(height: 20),
            RatingDisplayRow(label: 'Room', value: stay.roomRating),
            const SizedBox(height: 20),
            RatingDisplayRow(label: 'Experience', value: stay.experienceRating),
            const SizedBox(height: 20),
            RatingDisplayRow(label: 'Value', value: stay.valueRating),

            if (notes != null && notes.isNotEmpty) ...[
              const SizedBox(height: 32),
              const SectionLabel('NOTES'),
              const SizedBox(height: 10),
              DetailCard(
                child: Text(
                  notes,
                  style: GoogleFonts.inter(
                    color: AppColors.textPrimary,
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),
              ),
            ],

            const SizedBox(height: 32),
            const SectionLabel('PHOTOS'),
            const SizedBox(height: 10),
            VisitPhotosSection(
              visitId: stay.id,
              entityType: stay.entityType,
              entityId: stay.entityId,
              noun: 'stay',
            ),
          ],
        ),
      ),
    );
  }
}
