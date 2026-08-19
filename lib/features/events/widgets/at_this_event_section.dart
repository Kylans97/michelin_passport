import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/cs_spacing.dart';
import '../../../core/theme/cs_typography.dart';
import '../../../models/restaurant.dart';
import 'michelin_participant_row.dart';

/// The current-starred subset of an event's linked restaurants, most
/// decorated first (3 stars before 2, before 1), then alphabetically
/// within the same star count for a stable, deterministic order — the
/// underlying `event_restaurants`/`restaurants_full` join has no natural
/// ordering of its own. A pure, top-level function (not inlined in
/// [AtThisEventSection].build) so the filter/sort rule is directly
/// unit-testable without pumping a widget.
///
/// Michelin star data is read from the SAME canonical source Restaurant
/// Detail itself reads — [Restaurant.michelinStars]/[Restaurant.
/// hasMichelinStar] off `restaurants_full` — never a value duplicated onto
/// `event_restaurants`. This deliberately means the stars shown here are
/// the restaurant's CURRENT recognition, not necessarily what it held on
/// the event's own date; see this feature's architecture doc for why that
/// is an acceptable simplification for an app that only surfaces
/// upcoming/current events today.
List<Restaurant> michelinStarredParticipants(List<Restaurant> restaurants) {
  final starred = restaurants.where((r) => r.hasMichelinStar).toList();
  starred.sort((a, b) {
    final byStars = b.michelinStars!.compareTo(a.michelinStars!);
    if (byStars != 0) return byStars;
    return a.name.compareTo(b.name);
  });
  return starred;
}

/// "AT THIS EVENT" — the canonical Event participant/entity section
/// (Events V2 Step 3 terminology correction; renamed from
/// `MichelinAtEventSection`/"MICHELIN AT THIS EVENT"). Event participation
/// is entity-neutral by product rule: an event may involve restaurants,
/// hotels, private chefs, and future winery/bar entities, so the section's
/// own name must never be defined by one recognition system. Recognition
/// (Michelin, Gault&Millau, World's 50 Best, future sources) is a
/// contextual attribute *of* a participating entity, shown alongside it,
/// never the reason the section itself is named.
///
/// **Scope of this rename, explicitly**: only the heading text and this
/// class's own identity changed. The actual content this widget renders is
/// UNCHANGED — still only the event's current-Michelin-starred linked
/// restaurants ([michelinStarredParticipants]), still via
/// [MichelinParticipantRow]. Broadening this section to genuinely show
/// every entity type (hotels, private chefs, future wineries/bars)
/// uniformly under "AT THIS EVENT" is deliberately NOT done here — that is
/// a real data/layout change, out of this correction's own scope, and
/// remains future work. A restaurant linked to the event without a
/// current Michelin star is still not shown here at all — this display
/// filter is unchanged; the underlying `event_restaurants` relationship
/// itself was never touched by any of this, either before or now. Renders
/// nothing at all when the starred subset is empty — never a "Nothing to
/// show" placeholder (matching [VenueAboutSection]'s own established
/// "omit the section" convention for an empty result).
///
/// Renders each restaurant via [MichelinParticipantRow] — Step 1A's
/// dedicated Event-participant row (name + stars inline, city + flag
/// below) rather than [LinkedVenueRow], which stays untouched for
/// Restaurant/Hotel Detail's own already-approved sections. [StarRow]
/// (inside [MichelinParticipantRow]) provides the gold — the one place
/// gold legitimately appears on Event Detail, exactly as the color rule
/// requires (gold reserved for Michelin stars/Keys only, never attendance,
/// admission, or section chrome).
///
/// Between rows: a tight hairline using [SectionDivider]'s own color/
/// thickness TOKEN (`AppColors.taupe` at 0.4 alpha, 0.75px) but not the
/// [SectionDivider] component itself — that component's generous
/// `CsSpacing.lg` vertical margin is sized for major section boundaries,
/// and would make a list of many participants feel sparse and slow to
/// scan rather than dense and elegant (Step 1A §10's explicit "avoid
/// excessive vertical padding... the list should scan quickly").
class AtThisEventSection extends StatelessWidget {
  final List<Restaurant> restaurants;
  final ValueChanged<Restaurant> onTapRestaurant;

  const AtThisEventSection({
    super.key,
    required this.restaurants,
    required this.onTapRestaurant,
  });

  @override
  Widget build(BuildContext context) {
    final starred = michelinStarredParticipants(restaurants);
    if (starred.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'AT THIS EVENT',
          style: CsTypography.eyebrow.copyWith(color: AppColors.taupe),
        ),
        const SizedBox(height: CsSpacing.md),
        for (var i = 0; i < starred.length; i++) ...[
          if (i > 0)
            Divider(
              color: AppColors.taupe.withValues(alpha: 0.4),
              thickness: 0.75,
              height: CsSpacing.md,
            ),
          MichelinParticipantRow(
            restaurant: starred[i],
            onTap: () => onTapRestaurant(starred[i]),
          ),
        ],
      ],
    );
  }
}
