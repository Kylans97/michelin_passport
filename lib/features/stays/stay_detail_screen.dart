import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants/app_colors.dart';
import '../../core/theme/cs_spacing.dart';
import '../../core/theme/cs_typography.dart';
import '../../core/widgets/venue_score_strip.dart';
import '../../core/widgets/key_row.dart';
import '../../data/repositories/visited_repository.dart';
import '../../models/hotel.dart';
import '../../models/passport_venue.dart';
import '../../models/visit.dart';
import '../passport/widgets/add_visit_flow.dart';
import '../photos/widgets/visit_photos_section.dart';
import '../hotels/hotel_detail_screen.dart';

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

  /// Whether the hotel name opens its detail page (2026-10-31, product
  /// owner: from Friends' Activity / a friend's verdict you continue to the
  /// venue). False when this screen was opened from that venue page
  /// itself, so a tap never stacks the same page again.
  final bool linkToVenue;
  final Visit stay;

  const StayDetailScreen({
    super.key,
    required this.hotel,
    required this.stay,
    this.linkToVenue = true,
  });

  @override
  State<StayDetailScreen> createState() => _StayDetailScreenState();
}

class _StayDetailScreenState extends State<StayDetailScreen> {
  late final _visitedRepo = VisitedRepository(Supabase.instance.client);
  late Visit _stay = widget.stay;
  bool _deleting = false;
  bool _updatingVisibility = false;

  // Mirrors VisitDetailScreen's own _isOwner — same reasoning: Friend
  // Profile now opens this screen for a friend's stay too, and RLS alone
  // blocking the mutation isn't enough — the controls themselves must
  // not render for a non-owner.
  bool get _isOwner =>
      Supabase.instance.client.auth.currentUser?.id == _stay.userId;

  void _showSnack(String message, {bool isError = true}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: GoogleFonts.inter(color: AppColors.textPrimary),
        ),
        backgroundColor: isError ? AppColors.error : AppColors.forestGreen,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // True once this stay was edited here, so leaving the screen hands
  // `true` back the way a delete does and the list behind it refreshes.
  bool _edited = false;

  Future<void> _openEdit() async {
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null || uid.isEmpty) {
      _showSnack('Sign in required.');
      return;
    }
    final result = await showAddVisitFlow(
      context,
      userId: uid,
      initialVenue: HotelVenue(widget.hotel),
      existingVisit: _stay,
    );
    if (result == null || !mounted) return;
    setState(() {
      _stay = result.visit;
      _edited = true;
    });
    _showSnack('Stay updated.', isError: false);
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

    return PopScope(
      canPop: !_edited,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.of(context).pop(true);
      },
      child: Scaffold(
        backgroundColor: AppColors.ivory,
        appBar: AppBar(
          backgroundColor: AppColors.ivory,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          foregroundColor: AppColors.forestGreen,
          actions: [
            if (!_isOwner)
              const SizedBox.shrink()
            else if (_deleting || _updatingVisibility)
              const Padding(
                padding: EdgeInsets.all(16),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    color: AppColors.forestGreen,
                    strokeWidth: 2,
                  ),
                ),
              )
            else
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert_rounded),
                color: AppColors.card,
                onSelected: (value) {
                  if (value == 'edit') _openEdit();
                  if (value == 'visibility') _toggleVisibility();
                  if (value == 'delete') _confirmDelete();
                },
                itemBuilder: (context) => [
                  PopupMenuItem<String>(
                    value: 'edit',
                    child: Row(
                      children: [
                        const Icon(
                          Icons.edit_outlined,
                          color: AppColors.textPrimary,
                          size: 18,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'Edit stay',
                          style: GoogleFonts.inter(
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
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
                          style: GoogleFonts.inter(
                            color: AppColors.textPrimary,
                          ),
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
          padding: const EdgeInsets.fromLTRB(
            CsSpacing.pageHorizontal,
            0,
            CsSpacing.pageHorizontal,
            CsSpacing.xxl,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _VenueTitle(
                name: hotel.name,
                onTap: widget.linkToVenue
                    ? () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => HotelDetailScreen(hotel: hotel),
                        ),
                      )
                    : null,
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Text(
                    _formatStayDate(stay.visitedOn),
                    style: CsTypography.metadata.copyWith(
                      color: AppColors.taupe,
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
                    color: AppColors.taupe,
                    size: 13,
                  ),
                  const SizedBox(width: 3),
                  Text(
                    stay.visibility == VisitVisibility.friends
                        ? 'Visible to friends'
                        : 'Private',
                    style: CsTypography.metadata.copyWith(
                      color: AppColors.taupe,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),

              Text(
                'SCORES',
                style: CsTypography.eyebrow.copyWith(color: AppColors.taupe),
              ),
              const SizedBox(height: CsSpacing.md),
              // The same forest-green rings as the venue page's own
              // "SCORES (Your latest stay)" strip — never gold, which is for
              // MICHELIN stars and Keys only.
              VenueScoreStrip(
                dimensions: [
                  ScoreDimension(label: 'Overall', value: stay.rating),
                  ScoreDimension(label: 'Service', value: stay.serviceRating),
                  ScoreDimension(label: 'Room', value: stay.roomRating),
                  ScoreDimension(
                    label: 'Experience',
                    value: stay.experienceRating,
                  ),
                  ScoreDimension(label: 'Value', value: stay.valueRating),
                ],
              ),

              if (notes != null && notes.isNotEmpty) ...[
                const SizedBox(height: 32),
                Text(
                  'NOTES',
                  style: CsTypography.eyebrow.copyWith(color: AppColors.taupe),
                ),
                const SizedBox(height: 10),
                Text(
                  notes,
                  style: CsTypography.body.copyWith(
                    color: AppColors.forestGreen,
                  ),
                ),
              ],

              const SizedBox(height: 32),
              Text(
                'PHOTOS',
                style: CsTypography.eyebrow.copyWith(color: AppColors.taupe),
              ),
              const SizedBox(height: 10),
              VisitPhotosSection(
                visitId: stay.id,
                entityType: stay.entityType,
                entityId: stay.entityId,
                noun: 'stay',
                readOnly: !_isOwner,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The hotel name as the screen title. With [onTap], it opens the hotel's
/// own page: a quiet chevron beside the name, no button chrome.
class _VenueTitle extends StatelessWidget {
  final String name;
  final VoidCallback? onTap;
  const _VenueTitle({required this.name, this.onTap});

  @override
  Widget build(BuildContext context) {
    final title = Text(
      name,
      style: CsTypography.screenTitle.copyWith(color: AppColors.forestGreen),
    );
    if (onTap == null) return title;
    return Semantics(
      button: true,
      label: 'Open $name',
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(CsRadius.small),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Flexible(child: title),
            const SizedBox(width: CsSpacing.xs),
            const Icon(
              Icons.chevron_right_rounded,
              color: AppColors.taupe,
              size: 26,
            ),
          ],
        ),
      ),
    );
  }
}
