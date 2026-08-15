import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants/app_colors.dart';
import '../../core/widgets/star_row.dart';
import '../../data/repositories/visited_repository.dart';
import '../../models/restaurant.dart';
import '../../models/visit.dart';
import '../photos/widgets/visit_photos_section.dart';
import '../restaurants/widgets/detail_section.dart';
import 'widgets/rating_display_row.dart';

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

String _formatVisitDate(DateTime date) =>
    '${date.day} ${_monthNames[date.month - 1]} ${date.year}';

/// Shows exactly what the user recorded during a single visit. This is
/// historical information: [visit.starsAtVisit] is the restaurant's award at
/// the time of the visit and is shown as-is, never replaced by the
/// restaurant's current Michelin stars.
///
/// Also owns deleting this one visit — see [_confirmDelete]. Deleting pops
/// this screen with `true`, which RestaurantVisitsCard's onTap uses to
/// refresh Restaurant Detail's visit history immediately.
class VisitDetailScreen extends StatefulWidget {
  final Restaurant restaurant;
  final Visit visit;

  const VisitDetailScreen({
    super.key,
    required this.restaurant,
    required this.visit,
  });

  @override
  State<VisitDetailScreen> createState() => _VisitDetailScreenState();
}

class _VisitDetailScreenState extends State<VisitDetailScreen> {
  late final _visitedRepo = VisitedRepository(Supabase.instance.client);
  late Visit _visit = widget.visit;
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

  // The smallest sensible privacy-management seam for a table with no
  // general edit flow (see the Step 2 implementation report) — a single
  // toggle alongside the existing Delete action, not a new edit screen.
  Future<void> _toggleVisibility() async {
    if (_updatingVisibility) return;
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null || uid.isEmpty) {
      _showSnack('Sign in required.');
      return;
    }
    final next = _visit.visibility == VisitVisibility.friends
        ? VisitVisibility.private
        : VisitVisibility.friends;
    setState(() => _updatingVisibility = true);
    try {
      final updated = await _visitedRepo.updateVisitVisibility(
        userId: uid,
        visitId: _visit.id,
        visibility: next,
      );
      if (!mounted) return;
      setState(() {
        _visit = updated;
        _updatingVisibility = false;
      });
      _showSnack(
        next == VisitVisibility.friends
            ? 'Friends can now see this visit.'
            : 'This visit is private again.',
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
          'Delete this visit?',
          style: GoogleFonts.playfairDisplay(
            color: AppColors.textPrimary,
            fontSize: 18,
          ),
        ),
        content: Text(
          'This will permanently remove:\n'
          '• this visit\n'
          '• its ratings\n'
          '• notes\n'
          '• photos linked to this visit\n\n'
          'Other visits to this restaurant will NOT be affected.',
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
              'Delete visit',
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
      await _visitedRepo.deleteVisitById(userId: uid, visitId: _visit.id);
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (_) {
      if (!mounted) return;
      setState(() => _deleting = false);
      _showSnack('Could not delete visit. Please try again.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final restaurant = widget.restaurant;
    final visit = _visit;
    final stars = visit.starsAtVisit;
    final menuType = visit.menuType;
    final notes = visit.notes;

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
                        visit.visibility == VisitVisibility.friends
                            ? Icons.lock_open_rounded
                            : Icons.lock_outline_rounded,
                        color: AppColors.textPrimary,
                        size: 18,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        visit.visibility == VisitVisibility.friends
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
                        'Delete visit',
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
              restaurant.name,
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
                  _formatVisitDate(visit.visitedOn),
                  style: GoogleFonts.inter(
                    color: AppColors.textSecondary,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (stars != null && stars > 0) ...[
                  const SizedBox(width: 10),
                  StarRow(count: stars, size: 14),
                ],
                const SizedBox(width: 10),
                Icon(
                  visit.visibility == VisitVisibility.friends
                      ? Icons.lock_open_rounded
                      : Icons.lock_outline_rounded,
                  color: AppColors.textSecondary,
                  size: 13,
                ),
                const SizedBox(width: 3),
                Text(
                  visit.visibility == VisitVisibility.friends
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
            RatingDisplayRow(label: 'Overall', value: visit.rating),
            const SizedBox(height: 20),
            RatingDisplayRow(label: 'Food', value: visit.foodRating),
            const SizedBox(height: 20),
            RatingDisplayRow(label: 'Service', value: visit.serviceRating),
            const SizedBox(height: 20),
            RatingDisplayRow(label: 'Wine', value: visit.wineRating),
            const SizedBox(height: 20),
            RatingDisplayRow(label: 'Value', value: visit.valueRating),

            if (menuType != null) ...[
              const SizedBox(height: 32),
              const SectionLabel('MENU'),
              const SizedBox(height: 10),
              Text(
                menuType.label,
                style: GoogleFonts.inter(
                  color: AppColors.textPrimary,
                  fontSize: 14.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],

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
              visitId: visit.id,
              entityType: visit.entityType,
              entityId: visit.entityId,
              noun: 'visit',
            ),
          ],
        ),
      ),
    );
  }
}
