import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../theme/cs_spacing.dart';
import '../theme/cs_typography.dart';
import '../utils/venue_lifecycle.dart';

/// Detail-screen lifecycle notice — sits directly under the hero, above
/// the location line. Renders nothing for [VenueLifecycleState.normal].
///
/// [statusNote] is the copy for a temporary closure
/// (DATA_UPDATE_PROCESS.md §7's interface contract: "renders with a
/// banner from status_note"). A permanent closure doesn't use it — the
/// state itself is the message, and status_note for a closure this old
/// may not even describe current circumstances. A pop-up's end gets a
/// lighter, informational treatment (no bordered box) since it isn't a
/// problem the way a closure is — the venue simply isn't running
/// anymore, exactly as planned.
class VenueLifecycleBanner extends StatelessWidget {
  final VenueLifecycleState state;
  final String? statusNote;

  const VenueLifecycleBanner({
    super.key,
    required this.state,
    this.statusNote,
  });

  @override
  Widget build(BuildContext context) {
    switch (state) {
      case VenueLifecycleState.normal:
        return const SizedBox.shrink();
      case VenueLifecycleState.popupEnded:
        return Padding(
          padding: const EdgeInsets.only(bottom: CsSpacing.md),
          child: Row(
            children: [
              const Icon(
                Icons.event_busy_rounded,
                size: 16,
                color: AppColors.taupe,
              ),
              const SizedBox(width: CsSpacing.xs),
              Text(
                'This pop-up has ended',
                style: CsTypography.metadata.copyWith(color: AppColors.taupe),
              ),
            ],
          ),
        );
      case VenueLifecycleState.temporarilyClosed:
        final note = (statusNote ?? '').trim();
        return _NoticeBox(
          icon: Icons.pause_circle_outline_rounded,
          title: 'Temporarily closed',
          body: note.isNotEmpty
              ? note
              : 'This venue is temporarily closed. Check back later for an update.',
        );
      case VenueLifecycleState.permanentlyClosed:
        return const _NoticeBox(
          icon: Icons.block_rounded,
          title: 'Permanently closed',
          body: 'This venue is no longer operating.',
        );
    }
  }
}

class _NoticeBox extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;

  const _NoticeBox({required this.icon, required this.title, required this.body});

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: CsSpacing.md),
    padding: const EdgeInsets.all(CsSpacing.md),
    decoration: BoxDecoration(
      color: AppColors.error.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: AppColors.error),
        const SizedBox(width: CsSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: CsTypography.bodyMedium.copyWith(
                  color: AppColors.error,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                body,
                style: CsTypography.metadata.copyWith(color: AppColors.error),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
