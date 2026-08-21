import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/cs_spacing.dart';
import '../../../core/theme/cs_typography.dart';
import '../../../models/event_attendance_eligibility.dart';
import '../../../models/event_confirmed_attendance.dart';
import 'attendance_prompt_card.dart';

/// Event Detail's completed-event attendance section — Events V2 Step 4.
/// One widget, one switch over [AttendanceUiState], so the three possible
/// completed-event presentations (prompt, plain manual CTA, attended/
/// manage state) can never drift into three independently-maintained
/// pieces of UI — §7's explicit "reuse one Attendance confirmation flow"
/// applied to the section shell itself, not only the details sheet.
/// Renders nothing for [AttendanceUiState.none] — the caller (Event
/// Detail) is expected to skip this whole section, including its
/// preceding divider, in that case rather than rely on this widget
/// collapsing to zero height.
class EventAttendanceSection extends StatelessWidget {
  final AttendanceUiState state;
  final EventConfirmedAttendance? attendance;
  final String eventName;
  final bool busy;
  final VoidCallback onYes;
  final VoidCallback onNo;
  final VoidCallback onNotNow;
  final VoidCallback onManualAttend;
  final VoidCallback onEdit;
  final VoidCallback onRemove;

  const EventAttendanceSection({
    super.key,
    required this.state,
    required this.attendance,
    required this.eventName,
    required this.busy,
    required this.onYes,
    required this.onNo,
    required this.onNotNow,
    required this.onManualAttend,
    required this.onEdit,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) => switch (state) {
    AttendanceUiState.none => const SizedBox.shrink(),
    AttendanceUiState.promptable => AttendancePromptCard(
      eventName: eventName,
      busy: busy,
      onYes: onYes,
      onNo: onNo,
      onNotNow: onNotNow,
    ),
    AttendanceUiState.manualOnly => _ManualAttendCta(
      busy: busy,
      onTap: onManualAttend,
    ),
    AttendanceUiState.attended => _AttendedCard(
      attendance: attendance,
      onEdit: onEdit,
      onRemove: onRemove,
    ),
  };
}

class _ManualAttendCta extends StatelessWidget {
  final bool busy;
  final VoidCallback onTap;
  const _ManualAttendCta({required this.busy, required this.onTap});

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.transparent,
    child: InkWell(
      onTap: busy ? null : onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: CsSpacing.base,
          vertical: CsSpacing.md,
        ),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: AppColors.cardBorder.withValues(alpha: 0.55),
            width: 0.5,
          ),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.add_circle_outline_rounded,
              color: AppColors.forestGreen,
              size: 20,
            ),
            const SizedBox(width: CsSpacing.sm),
            Expanded(
              child: Text(
                'Add to Passport',
                style: CsTypography.bodyMedium.copyWith(
                  color: AppColors.forestGreen,
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _AttendedCard extends StatelessWidget {
  final EventConfirmedAttendance? attendance;
  final VoidCallback onEdit;
  final VoidCallback onRemove;
  const _AttendedCard({
    required this.attendance,
    required this.onEdit,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final rating = attendance?.rating;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: CsSpacing.base,
        vertical: CsSpacing.md,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppColors.cardBorder.withValues(alpha: 0.55),
          width: 0.5,
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.check_circle_rounded,
            color: AppColors.forestGreen,
            size: 20,
          ),
          const SizedBox(width: CsSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'In your Passport',
                  style: CsTypography.bodyMedium.copyWith(
                    color: AppColors.forestGreen,
                  ),
                ),
                if (rating != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    'Your rating: $rating/10',
                    style: CsTypography.metadata.copyWith(
                      color: AppColors.taupe,
                    ),
                  ),
                ],
              ],
            ),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_horiz_rounded, color: AppColors.taupe),
            onSelected: (value) => value == 'edit' ? onEdit() : onRemove(),
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'edit', child: Text('Edit your experience')),
              PopupMenuItem(
                value: 'remove',
                child: Text('Remove from Passport'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
