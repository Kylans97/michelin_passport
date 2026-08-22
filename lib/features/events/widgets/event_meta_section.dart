import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/cs_spacing.dart';
import '../../../core/theme/cs_typography.dart';
import '../../../models/event.dart';
import '../event_date_format.dart';

/// "EVENT ESSENTIALS" — the compact "at a glance" facts block directly
/// beneath Event Detail's hero — event title, date/time, venue, and
/// admission — each a flat icon+text row (the title is the one
/// exception, a plain heading) on the ivory canvas (Events UI Consistency
/// Step 1 §33: "reduce unnecessary nested rounded cards... use a card
/// only where it has semantic value"). The previous generation wrapped
/// these same facts in a `DetailCard` box; there's nothing here that
/// benefits from a card boundary, so this reskin drops the box entirely
/// rather than just recoloring it. Date, venue, and admission
/// deliberately share one consistent visual system via [_MetaRow] — same
/// icon size/column, same primary/secondary text styles, same vertical
/// rhythm — so they read as one coherent group, not three unrelated
/// facts.
///
/// City/country already appears once, in the venue row below — this
/// section never repeats it twice at the same level of detail; the full
/// street address lives in the LOCATION section further down the screen
/// (§27's "avoid repeated date presentation" applied to location too).
///
/// Events V2 Time Precision Phase B — hero/Essentials title correction
/// (physical-device finding on the first genuine date-only pilot, "4
/// Hands Dinner: Bas van Kranen x Sang Hoon Degeimbre"): [Event.name]
/// moved here, as the first element, directly below the hero —
/// [EventDetailHero]'s real Event Detail usage no longer carries any
/// title text at all, so there is exactly ONE visible Event title in the
/// top hierarchy, rendered at [CsTypography.placeTitle] (the same
/// "place/event name at detail-hero scale" role token used elsewhere —
/// deliberately NOT [CsTypography.displayHero]/[screenTitle], which read
/// as a marketing banner rather than an editorial heading for a long
/// real-world title). No `maxLines`/`overflow` here — a long title wraps
/// onto as many lines as it needs; truncating or ellipsizing a real Event
/// name is never acceptable.
///
/// Editorial Hero + Essentials/Actions polish pass (a further
/// physical-device finding on the same pilot): [Event.eventType] moved
/// BACK to the hero as a subtle eyebrow over the image ([EventDetailHero]
/// now supplies it again) — it no longer renders here at all, closing
/// the gap that used to sit between the title and the first metadata row
/// (title → eyebrow → date felt fragmented on-device). The spacing below
/// the title was rebalanced accordingly ([CsSpacing.md], not the tighter
/// gap the eyebrow used to need) so the title doesn't visually collide
/// with the date row, without leaving excess empty space either.
class EventMetaSection extends StatelessWidget {
  final Event event;
  const EventMetaSection({super.key, required this.event});

  @override
  Widget build(BuildContext context) {
    final venueName = event.venueName;
    final hasVenueName = venueName != null && venueName.isNotEmpty;
    final city = event.city;
    final hasCity = city != null && city.isNotEmpty;
    final hasVenueRow = hasVenueName || hasCity;
    final hasAdmission = event.admissionType != EventAdmissionType.unknown;
    final hasNote =
        event.admissionNote != null && event.admissionNote!.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(event.name, style: CsTypography.placeTitle),
        const SizedBox(height: CsSpacing.md),
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
          // Events V2 Time Precision Phase B: one precision-aware line via
          // formatEventDateAndTime, replacing the previous two separate
          // formatEventDateTime(startAt)/formatEventDateTime(endAt) calls
          // — those assumed both instants always existed, which a
          // date-only or start-known Event no longer guarantees. Full-
          // precision Events (all 4 production Events today) render with
          // identical information, just as one combined line instead of
          // two, per the Display Rules' own single-string contract (no
          // "Time unknown"/"TBC" placeholder is ever shown for the side
          // that isn't known).
          text: formatEventDateAndTime(event),
        ),
        if (hasVenueRow) ...[
          const SizedBox(height: CsSpacing.md),
          // City now renders here (as a secondary line under the venue
          // name, or alone when no venue name exists) rather than in the
          // hero's former cityCountryLine — that line no longer exists in
          // real Event Detail usage (see EventDetailHero's own doc
          // comment), so this is the one place city still appears at all.
          // Country is deliberately not repeated here — the full address
          // (including country) lives in the LOCATION section below.
          _MetaRow(
            icon: Icons.place_outlined,
            text: hasVenueName ? venueName : city!,
            secondaryText: hasVenueName && hasCity ? city : null,
          ),
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
