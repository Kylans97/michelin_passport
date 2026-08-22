import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/cs_spacing.dart';
import '../../../core/theme/cs_typography.dart';
import '../../../models/event.dart';
import '../event_date_format.dart';

/// Events V2 Step 8B — the reverse-host-discovery "EVENTS" section shown
/// on a Restaurant/Hotel/Private Chef Detail page: the Events that entity
/// genuinely HOSTS (`is_host = true` on the corresponding relationship
/// table — see `EventsRepository.loadHostedEventsForRestaurant`/
/// `...ForHotel`/`...ForChef`, which already filter to upcoming/active,
/// non-cancelled, chronologically sorted before this widget ever sees
/// [events]). This widget renders whatever list it's given as-is — it
/// does not re-derive host/venue/participant/lifecycle eligibility
/// itself; that is exclusively the repository's job (Host Semantics is
/// non-negotiable and must have exactly one source of truth).
///
/// Renders nothing at all when [events] is empty — never a "No upcoming
/// events" placeholder (matching [VenueAboutSection]/[AtThisEventSection]'s
/// own established "omit the section entirely" convention). The section
/// title is plain "EVENTS" — the host/venue/participant distinction is
/// internal data meaning the user was never shown anywhere else on
/// Detail, and "HOSTED EVENTS" would be the one section name to leak it.
/// Never "MICHELIN EVENTS"/"STAR EVENTS" — recognition is unrelated to
/// hosting.
///
/// Text-led, no thumbnail/placeholder image per row — many Events have
/// no approved image yet, and a compact list of repeated branded
/// monograms would read as noisier than a calm, text-only row; see the
/// Step 8B pre-final doc's Compact Event Card section for the full
/// reasoning. Visually aligned with [LinkedVenueRow] (the same
/// warmWhite/bordered card treatment already used for "AT THIS HOTEL"/
/// "DINING" on these exact screens), not [EventActionsRow]'s
/// deliberately card-free treatment — that choice belongs to Event
/// Detail's own editorial aesthetic, not to Restaurant/Hotel/Private
/// Chef Detail's established related-content pattern.
///
/// Deliberately does NOT show: Step 8A relevance reasons, Friends Going,
/// member counts, or Interested/Going controls — this is a discovery/
/// navigation surface, not a mini Events feed; the user opens Event
/// Detail to actually interact with an Event. Also does not repeat the
/// viewed entity's own name — the user is already on that entity's page.
class HostedEventsSection extends StatelessWidget {
  final List<Event> events;
  final ValueChanged<Event> onTapEvent;

  const HostedEventsSection({
    super.key,
    required this.events,
    required this.onTapEvent,
  });

  @override
  Widget build(BuildContext context) {
    if (events.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'EVENTS',
          style: CsTypography.eyebrow.copyWith(color: AppColors.taupe),
        ),
        const SizedBox(height: CsSpacing.md),
        for (var i = 0; i < events.length; i++) ...[
          if (i > 0) const SizedBox(height: CsSpacing.sm),
          _HostedEventRow(event: events[i], onTap: () => onTapEvent(events[i])),
        ],
      ],
    );
  }
}

class _HostedEventRow extends StatelessWidget {
  final Event event;
  final VoidCallback onTap;

  const _HostedEventRow({required this.event, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final hasAdmission = event.admissionType != EventAdmissionType.unknown;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(CsRadius.medium),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(CsSpacing.base),
          decoration: BoxDecoration(
            color: AppColors.warmWhite,
            borderRadius: BorderRadius.circular(CsRadius.medium),
            border: Border.all(color: AppColors.subtleBorderLight),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      event.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: CsTypography.bodyMedium.copyWith(
                        color: AppColors.forestGreen,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      // Precision-aware — never a fabricated time. A
                      // date-only Event (e.g. the real Flore pilot) shows
                      // just its date, exactly as EventMetaSection does.
                      formatEventDateAndTime(event),
                      style: CsTypography.metadata,
                    ),
                    if (hasAdmission) ...[
                      const SizedBox(height: 2),
                      Text(
                        event.admissionType.label,
                        style: CsTypography.metadata.copyWith(fontSize: 12.5),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: CsSpacing.sm),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.taupe,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
