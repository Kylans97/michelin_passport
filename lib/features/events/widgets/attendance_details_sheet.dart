import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/cs_spacing.dart';
import '../../visits/widgets/rating_meter.dart';
import 'attendance_photos_section.dart';
import 'recommendation_selector.dart';

/// What the sheet collected, or null if the user backed out without
/// saving. Purely an edit of an ALREADY-confirmed attendance row (see this
/// file's own header comment) — there is no "cancel confirmation" outcome
/// here, only "save these optional details" or "leave it as-is." Photos
/// are uploaded/deleted live as the user interacts with the photo section
/// (not staged, unlike Add Visit/Add Stay's pre-save picker — attendance
/// already exists by the time this sheet opens, so there's no "wait for
/// save" step photos need to work around) — [photosChanged] just tells
/// the caller whether to refresh its own attendance photo count/cover
/// image, it never carries photo data itself.
///
/// [wouldRecommend] (Events V2 Step 4.1) is the sheet's current Yes/No/
/// unanswered selection at Save time — always sent explicitly (including
/// `null`, meaning "no answer" or "answer cleared"), unlike [rating]/
/// [comment], which the repository leaves untouched when left `null`. The
/// caller is expected to always wrap it in a `WouldRecommendUpdate` when
/// calling `updateAttendanceDetails` — see that class's own doc comment.
class AttendanceDetailsResult {
  final int? rating;
  final bool? wouldRecommend;
  final String? comment;
  final bool photosChanged;
  const AttendanceDetailsResult({
    this.rating,
    this.wouldRecommend,
    this.comment,
    this.photosChanged = false,
  });
}

/// One "you attended → rating → photos → note → save" experience-
/// completion flow for an already-confirmed Event attendance — Events V2
/// Step 4 §9/§10/§12. Deliberately shown AFTER `event_confirmed_attendance`
/// has already been written (see event_detail_screen.dart's
/// `_confirmAttendance`): tapping Yes/"I attended this" is the actual
/// state transition; this sheet only ever edits details on a row that
/// already exists, so dismissing it without saving has zero effect on
/// whether attendance is recorded — never a "cancel confirmation" control.
/// The same sheet serves both the immediately-after-confirming flow and
/// Event Detail's own "Edit your experience" management action — one
/// experience, not two (§13/§7's explicit "avoid two separate management
/// experiences").
Future<AttendanceDetailsResult?> showAttendanceDetailsSheet({
  required BuildContext context,
  required String eventName,
  required String attendanceId,
  required String eventId,
  int? initialRating,
  bool? initialWouldRecommend,
  String? initialComment,
  VoidCallback? onPhotoUploaded,
}) {
  return showModalBottomSheet<AttendanceDetailsResult>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _AttendanceDetailsSheet(
      eventName: eventName,
      attendanceId: attendanceId,
      eventId: eventId,
      initialRating: initialRating,
      initialWouldRecommend: initialWouldRecommend,
      initialComment: initialComment,
      onPhotoUploaded: onPhotoUploaded,
    ),
  );
}

class _AttendanceDetailsSheet extends StatefulWidget {
  final String eventName;
  final String attendanceId;
  final String eventId;
  final int? initialRating;
  final bool? initialWouldRecommend;
  final String? initialComment;
  final VoidCallback? onPhotoUploaded;

  const _AttendanceDetailsSheet({
    required this.eventName,
    required this.attendanceId,
    required this.eventId,
    this.initialRating,
    this.initialWouldRecommend,
    this.initialComment,
    this.onPhotoUploaded,
  });

  @override
  State<_AttendanceDetailsSheet> createState() =>
      _AttendanceDetailsSheetState();
}

class _AttendanceDetailsSheetState extends State<_AttendanceDetailsSheet> {
  late int? _rating = widget.initialRating;
  late bool? _wouldRecommend = widget.initialWouldRecommend;
  late final _commentCtrl = TextEditingController(text: widget.initialComment);
  bool _photosChanged = false;

  @override
  void dispose() {
    _commentCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        padding: const EdgeInsets.fromLTRB(
          CsSpacing.base,
          CsSpacing.lg,
          CsSpacing.base,
          CsSpacing.lg,
        ),
        decoration: const BoxDecoration(
          color: AppColors.ivory,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.eventName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.playfairDisplay(
                  color: AppColors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: CsSpacing.lg),
              RatingMeter(
                label: 'Your rating',
                value: _rating,
                onChanged: (v) => setState(() => _rating = v),
              ),
              const SizedBox(height: CsSpacing.lg),
              RecommendationSelector(
                value: _wouldRecommend,
                onChanged: (v) => setState(() => _wouldRecommend = v),
              ),
              const SizedBox(height: CsSpacing.lg),
              Text(
                'Photos',
                style: GoogleFonts.inter(
                  color: AppColors.textPrimary,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              AttendancePhotosSection(
                attendanceId: widget.attendanceId,
                eventId: widget.eventId,
                onPhotoUploaded: () {
                  _photosChanged = true;
                  widget.onPhotoUploaded?.call();
                },
              ),
              const SizedBox(height: CsSpacing.lg),
              Text(
                'Notes',
                style: GoogleFonts.inter(
                  color: AppColors.textPrimary,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _commentCtrl,
                maxLines: 3,
                maxLength: 280,
                style: GoogleFonts.inter(color: AppColors.textPrimary),
                decoration: InputDecoration(
                  hintText: 'A short note for yourself (optional)',
                  hintStyle: GoogleFonts.inter(color: AppColors.textSecondary),
                  filled: true,
                  fillColor: AppColors.surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: CsSpacing.md),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.forestGreen,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: () {
                    final comment = _commentCtrl.text.trim();
                    Navigator.of(context).pop(
                      AttendanceDetailsResult(
                        rating: _rating,
                        wouldRecommend: _wouldRecommend,
                        comment: comment.isEmpty ? null : comment,
                        photosChanged: _photosChanged,
                      ),
                    );
                  },
                  child: Text(
                    'Save',
                    style: GoogleFonts.inter(
                      color: AppColors.textOnDark,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
