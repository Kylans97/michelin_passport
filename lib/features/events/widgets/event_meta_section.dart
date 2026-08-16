import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/cs_spacing.dart';
import '../../../core/theme/cs_typography.dart';
import '../../../models/event.dart';
import '../event_date_format.dart';

/// The compact "at a glance" facts block directly beneath Event Detail's
/// hero — date/time, venue, and admission — each a flat icon+text row on
/// the ivory canvas (Events UI Consistency Step 1 §33: "reduce unnecessary
/// nested rounded cards... use a card only where it has semantic value").
/// The previous generation wrapped these same three facts in a `DetailCard`
/// box; there's nothing here that benefits from a card boundary, so this
/// reskin drops the box entirely rather than just recoloring it.
///
/// City/country already appears once, in the hero — this section never
/// repeats it, only the venue name (short) and the precise date/time
/// range; the full street address lives in the LOCATION section further
/// down the screen, so no fact appears more than once at the same level of
/// detail (§27's "avoid repeated date presentation" applied to location
/// too).
class EventMetaSection extends StatelessWidget {
  final Event event;
  const EventMetaSection({super.key, required this.event});

  @override
  Widget build(BuildContext context) {
    final venueName = event.venueName;
    final hasVenueName = venueName != null && venueName.isNotEmpty;
    final hasAdmission = event.admissionType != EventAdmissionType.unknown;
    final hasNote =
        event.admissionNote != null && event.admissionNote!.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (event.isCancelled) ...[
          const _MetaRow(
            icon: Icons.cancel_outlined,
            text: 'This event has been cancelled',
            color: AppColors.error,
          ),
          const SizedBox(height: CsSpacing.md),
        ],
        _MetaRow(
          icon: Icons.calendar_today_rounded,
          text:
              '${formatEventDateTime(event.startAt)}\n'
              'to ${formatEventDateTime(event.endAt)}',
        ),
        if (hasVenueName) ...[
          const SizedBox(height: CsSpacing.md),
          _MetaRow(icon: Icons.place_outlined, text: venueName),
        ],
        if (hasAdmission) ...[
          const SizedBox(height: CsSpacing.md),
          _MetaRow(
            icon: event.isFreeEntry
                ? Icons.money_off_rounded
                : Icons.confirmation_number_outlined,
            text: event.admissionType.label,
            secondaryText: hasNote ? event.admissionNote : null,
          ),
        ],
      ],
    );
  }
}

class _MetaRow extends StatelessWidget {
  final IconData icon;
  final String text;
  final String? secondaryText;
  final Color color;

  const _MetaRow({
    required this.icon,
    required this.text,
    this.secondaryText,
    this.color = AppColors.forestGreen,
  });

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(icon, color: color, size: 17),
      const SizedBox(width: CsSpacing.sm),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              text,
              style: CsTypography.body.copyWith(color: color, fontSize: 14),
            ),
            if (secondaryText != null) ...[
              const SizedBox(height: 2),
              Text(
                secondaryText!,
                style: CsTypography.metadata.copyWith(
                  color: AppColors.taupe,
                  fontSize: 12.5,
                ),
              ),
            ],
          ],
        ),
      ),
    ],
  );
}
