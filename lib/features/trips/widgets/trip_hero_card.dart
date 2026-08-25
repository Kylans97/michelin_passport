import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/cs_spacing.dart';
import '../../../core/theme/cs_typography.dart';
import '../../../models/event.dart';
import '../../../models/planned_trip.dart';
import '../trip_schedule.dart';
import 'trip_card.dart' show formatTripDateRange, tripVenueCountsLine;

const _monthAbbrev = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

// "27–31 Aug" — the same day/month logic as event_date_format.dart's
// formatEventDateRange, deliberately without the year: this line always
// sits directly beneath TripHeroCard's own date range, which already
// carries the year, so repeating it here would be noise rather than
// information.
String _shortEventDateRange(Event event) {
  final s = event.startDate;
  final e = event.endDate;
  if (s.year == e.year && s.month == e.month && s.day == e.day) {
    return '${s.day} ${_monthAbbrev[s.month - 1]}';
  }
  if (s.month == e.month) {
    return '${s.day}–${e.day} ${_monthAbbrev[s.month - 1]}';
  }
  return '${s.day} ${_monthAbbrev[s.month - 1]} – ${e.day} '
      '${_monthAbbrev[e.month - 1]}';
}

/// TRIPS HERO REDESIGN — the single next upcoming trip, shown as the clear
/// focal point of the Trips subsection (replacing a list of equally-sized
/// [TripCard]s). Premium through spacing/typography, not decoration:
/// generous padding, a screen-title-scale serif destination name (32px,
/// noticeably larger than [TripCard]'s 22px), and an optional subtle
/// "Starts tomorrow"/"In N days" eyebrow above it.
///
/// Ivory Hero Refinement: the card itself is an ivory surface — not
/// [TripCard]'s dark [AppColors.brandGreenLight] — deliberately the ONE
/// ivory object on an otherwise deep-green Trips page, the same
/// dark-canvas/light-object contrast Passport's own collection cards and
/// Ranking's cards already use, so the single featured trip reads as the
/// clear visual focal point rather than another green block blending
/// into the page around it. Text hierarchy follows that surface: deep
/// green for the destination title, a muted forest green for the date
/// range/eyebrow, and softer neutral taupe for supporting metadata (venue
/// counts) — never gold, never a bright accent.
///
/// [matchingEvent] is the trip's own already-established event-overlap
/// concept ([eventsMatchingTrip], the exact function [TripDetailScreen]'s
/// "WHAT'S ON" section already uses) — surfaced here, subtly, as a single
/// line rather than a repeated section, and omitted entirely (not an
/// empty-state line) when there is no match. [onTapEvent] is independently
/// tappable from the rest of the card (its own nested tap target, the same
/// nested-InkWell pattern [PassportCardBookmark] already establishes) —
/// null when there's nothing to open, in which case the line still renders
/// but isn't itself interactive.
class TripHeroCard extends StatelessWidget {
  final PlannedTrip trip;
  final int restaurantCount;
  final int hotelCount;
  final Event? matchingEvent;
  final VoidCallback onTap;
  final VoidCallback? onTapEvent;

  /// Overridable only for deterministic testing of [tripStartLabel] —
  /// production call sites never pass this, defaulting to the real
  /// current time.
  final DateTime? now;

  const TripHeroCard({
    super.key,
    required this.trip,
    required this.restaurantCount,
    required this.hotelCount,
    this.matchingEvent,
    required this.onTap,
    this.onTapEvent,
    this.now,
  });

  @override
  Widget build(BuildContext context) {
    final startLabel = tripStartLabel(trip.startDate, now: now);
    final event = matchingEvent;
    final semanticParts = [
      trip.title,
      formatTripDateRange(trip),
      tripVenueCountsLine(
        restaurantCount: restaurantCount,
        hotelCount: hotelCount,
      ),
      if (event != null) event.name,
    ];

    return Semantics(
      button: true,
      label: semanticParts.join('. '),
      excludeSemantics: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(CsRadius.card),
          splashColor: AppColors.forestGreen.withValues(alpha: 0.06),
          highlightColor: AppColors.forestGreen.withValues(alpha: 0.04),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(CsSpacing.xl),
            decoration: BoxDecoration(
              color: AppColors.ivory,
              borderRadius: BorderRadius.circular(CsRadius.card),
              border: Border.all(
                color: AppColors.subtleBorderLight,
                width: 0.5,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (startLabel != null) ...[
                  Text(
                    startLabel,
                    style: CsTypography.eyebrow.copyWith(
                      color: AppColors.forestGreen,
                    ),
                  ),
                  const SizedBox(height: CsSpacing.sm),
                ],
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        trip.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: CsTypography.screenTitle.copyWith(
                          color: AppColors.deepGreen,
                        ),
                      ),
                    ),
                    const SizedBox(width: CsSpacing.sm),
                    const Padding(
                      padding: EdgeInsets.only(top: 6),
                      child: Icon(
                        Icons.chevron_right_rounded,
                        color: AppColors.forestGreen,
                        size: 24,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: CsSpacing.xs),
                Text(
                  formatTripDateRange(trip),
                  style: CsTypography.body.copyWith(
                    color: AppColors.forestGreen,
                  ),
                ),
                const SizedBox(height: CsSpacing.sm),
                Text(
                  tripVenueCountsLine(
                    restaurantCount: restaurantCount,
                    hotelCount: hotelCount,
                  ),
                  style: CsTypography.metadata.copyWith(
                    color: AppColors.taupe,
                  ),
                ),
                if (event != null) ...[
                  const SizedBox(height: CsSpacing.md),
                  _EventLine(event: event, onTap: onTapEvent),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EventLine extends StatelessWidget {
  final Event event;
  final VoidCallback? onTap;
  const _EventLine({required this.event, this.onTap});

  @override
  Widget build(BuildContext context) {
    final text = Text(
      '${event.name} · ${_shortEventDateRange(event)}',
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: CsTypography.metadata.copyWith(
        color: AppColors.forestGreen,
        fontWeight: FontWeight.w600,
      ),
    );
    if (onTap == null) return text;
    return Semantics(
      button: true,
      label: 'View event: ${event.name}',
      excludeSemantics: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(CsRadius.small),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: text,
          ),
        ),
      ),
    );
  }
}

/// "2 more trips →" — the subtle link beneath [TripHeroCard] to every
/// other upcoming trip the featured card doesn't have room to show
/// individually. [count] is always the number of upcoming trips beyond
/// the featured one — never shown at all when that's zero (see
/// TripsBody, which only renders this when `count > 0`).
class MoreTripsLink extends StatelessWidget {
  final int count;
  final VoidCallback onTap;
  const MoreTripsLink({super.key, required this.count, required this.onTap});

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.centerLeft,
    child: Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(CsRadius.small),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            vertical: CsSpacing.sm,
            horizontal: CsSpacing.xs,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$count more ${count == 1 ? 'trip' : 'trips'}',
                style: CsTypography.bodyMedium.copyWith(
                  color: AppColors.textOnDark,
                ),
              ),
              const SizedBox(width: 4),
              const Icon(
                Icons.arrow_forward_rounded,
                color: AppColors.textOnDark,
                size: 16,
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
