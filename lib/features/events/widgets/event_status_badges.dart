// The "Sold out" and "Expected" labels an event card shows beside its name.
// One definition for every card that lists events (EventCard, the Explore
// result tile and the Explore discovery card), so the three cannot drift.
//
// Restrained on purpose: a muted outline in the secondary text colour,
// never gold (reserved for MICHELIN stars and Keys) and never the error red
// that CANCELLED uses — sold out and expected are facts about an event that
// is still happening, not a warning.
//
// A cancelled event shows only its CANCELLED badge: the cards check
// isCancelled first and leave these out.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/app_colors.dart';
import '../../../models/event.dart';

/// The labels [event] carries, in a fixed order: Sold out, then Expected.
/// Empty for a cancelled event and for an ordinary one.
List<String> eventStatusLabels(Event event) {
  if (event.isCancelled) return const [];
  return [if (event.isSoldOut) 'SOLD OUT', if (event.isExpected) 'EXPECTED'];
}

class EventStatusBadge extends StatelessWidget {
  const EventStatusBadge({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: AppColors.textSecondary.withValues(alpha: 0.4)),
    ),
    child: Text(
      label,
      style: GoogleFonts.inter(
        color: AppColors.textSecondary,
        fontSize: 9.5,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.5,
      ),
    ),
  );
}

/// The badges for [event] as a wrapping row, or nothing when it has none.
class EventStatusBadges extends StatelessWidget {
  const EventStatusBadges({super.key, required this.event});

  final Event event;

  @override
  Widget build(BuildContext context) {
    final labels = eventStatusLabels(event);
    if (labels.isEmpty) return const SizedBox.shrink();
    return Wrap(
      spacing: 6,
      runSpacing: 4,
      children: [for (final l in labels) EventStatusBadge(label: l)],
    );
  }
}
