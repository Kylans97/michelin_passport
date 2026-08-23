import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/cs_spacing.dart';
import '../../../core/theme/cs_typography.dart';
import '../../../models/restaurant.dart';
import 'event_participant_row.dart';

/// Events Recognition V2 — is a canonical [Restaurant] eligible to appear
/// in [AtThisEventSection]? True when it currently holds at least one
/// qualifying recognition: a Michelin star, a current World's 50 Best
/// rank, or Hall of Fame membership. A small, directly-unit-testable
/// predicate (task's own §5 "prefer a small testable helper... never
/// scatter separate checks throughout widgets") — the single place this
/// decision is made; [recognizedEventParticipants] and any future caller
/// both go through this one function, never a second, competing
/// definition of "recognized."
///
/// **Gault&Millau is deliberately NOT included here.** Audited before
/// writing this: `public.gault_millau_awards`/`gault_millau_special_awards`
/// exist and are live in production (41 + 58 rows), but `restaurants_full`
/// — confirmed via a live `information_schema.columns` query, not assumed
/// from historical docs — exposes no Gault&Millau column at all, and
/// [Restaurant] therefore has no canonical field to read one from. Adding
/// one would require either a `restaurants_full` view change (a migration
/// — explicitly out of this task's backend-unchanged scope) or a second,
/// Events-specific data-fetching path bypassing the canonical Restaurant
/// loading this section already receives (not "the smallest necessary
/// application-layer change" the task asked for). Per the task's own
/// explicit instruction — "It is acceptable for V2 to support fewer
/// recognition types correctly rather than three incorrectly" — Michelin
/// and World's 50 Best are implemented now; Gault&Millau is left for a
/// future pass that first extends `restaurants_full`/[Restaurant] itself.
bool isRecognizedEventParticipant(Restaurant restaurant) =>
    restaurant.hasMichelinStar ||
    restaurant.isWorlds50Best ||
    restaurant.isHallOfFame;

/// The currently-recognized subset of an event's linked restaurants
/// (Events Recognition V2 — generalizes the original
/// `michelinStarredParticipants`, preserved in git history), most
/// Michelin-decorated first (a restaurant with no current star sorts as
/// 0, i.e. after every starred one — never a fabricated cross-guide
/// prestige score comparing Michelin against World's 50 Best/Hall of
/// Fame, per the task's own explicit instruction), then alphabetically
/// within the same star count — byte-for-byte the same ordering rule as
/// before for every Michelin-starred restaurant; only the pool of
/// eligible restaurants widened, via [isRecognizedEventParticipant]. A
/// pure, top-level function (not inlined in [AtThisEventSection].build)
/// so the filter/sort rule is directly unit-testable without pumping a
/// widget. Defensively deduplicates by [Restaurant.id] — the
/// `event_restaurants` table's own `unique(event_id, restaurant_id)`
/// constraint and `restaurants_full`'s one-row-per-id shape mean a
/// duplicate should never actually reach here, but this makes that
/// guarantee explicit and directly testable rather than merely assumed.
///
/// Recognition data is read from the SAME canonical source Restaurant
/// Detail itself reads — [Restaurant.michelinStars]/[Restaurant.
/// hasMichelinStar]/[Restaurant.worlds50BestRank]/[Restaurant.
/// isWorlds50Best]/[Restaurant.isHallOfFame] off `restaurants_full` —
/// never a value duplicated onto `event_restaurants`. This deliberately
/// means what's shown here is the restaurant's CURRENT recognition, not
/// necessarily what it held on the event's own date; see this feature's
/// architecture doc for why that is an acceptable simplification for an
/// app that only surfaces upcoming/current events today. World's 50
/// Best's own "current" semantics are equally safe: `restaurants_full`
/// derives `worlds_50_best_rank` only from the most recent year that has
/// a non-null rank (confirmed by reading that view's own definition), the
/// exact same current-only guarantee Michelin stars already have — never
/// a historical/past rank presented as if it were current.
List<Restaurant> recognizedEventParticipants(List<Restaurant> restaurants) {
  final recognized = restaurants.where(isRecognizedEventParticipant).toList();
  final deduped = {for (final r in recognized) r.id: r}.values.toList();
  deduped.sort((a, b) {
    final byStars = (b.michelinStars ?? 0).compareTo(a.michelinStars ?? 0);
    if (byStars != 0) return byStars;
    return a.name.compareTo(b.name);
  });
  return deduped;
}

/// "AT THIS EVENT" — the canonical Event participant/entity section
/// (Events V2 Step 3 terminology correction; renamed from
/// `MichelinAtEventSection`/"MICHELIN AT THIS EVENT"). Event participation
/// is entity-neutral by product rule: an event may involve restaurants,
/// hotels, private chefs, and future winery/bar entities, so the section's
/// own name must never be defined by one recognition system. Recognition
/// (Michelin, World's 50 Best/Hall of Fame today; Gault&Millau once
/// `Restaurant` itself exposes it — see [isRecognizedEventParticipant]'s
/// own doc comment) is a contextual attribute *of* a participating entity,
/// shown alongside it, never the reason the section itself is named —
/// Recognition V2 is the concrete proof this Step 3 naming decision was
/// right: the heading needed zero change to accommodate a second
/// recognition source.
///
/// **Scope, explicitly**: this section renders exactly the restaurants
/// [recognizedEventParticipants] admits — no longer Michelin-only, but
/// still only restaurants, still only currently-recognized ones. A
/// restaurant linked to the event with no qualifying recognition at all
/// is still not shown here — this display filter is intentional, not a
/// gap; the underlying `event_restaurants` relationship itself is never
/// touched by any of this. Renders nothing at all when the recognized
/// subset is empty — never a "Nothing to show" placeholder (matching
/// [VenueAboutSection]'s own established "omit the section" convention
/// for an empty result).
///
/// Renders each restaurant via [EventParticipantRow] (originally
/// `MichelinParticipantRow` — renamed alongside this generalization, same
/// reasoning as this section's own Step 3 rename) rather than
/// [LinkedVenueRow], which stays untouched for Restaurant/Hotel Detail's
/// own already-approved sections. [StarRow] (inside [EventParticipantRow])
/// provides the gold — the one place gold legitimately appears on Event
/// Detail, exactly as the color rule requires (gold reserved for Michelin
/// stars/Keys only, never attendance, admission, section chrome, or the
/// World's 50 Best/Hall of Fame text label, which renders in the same
/// restrained taupe as city/flag).
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
    final recognized = recognizedEventParticipants(restaurants);
    if (recognized.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'AT THIS EVENT',
          style: CsTypography.eyebrow.copyWith(color: AppColors.taupe),
        ),
        const SizedBox(height: CsSpacing.md),
        for (var i = 0; i < recognized.length; i++) ...[
          if (i > 0)
            Divider(
              color: AppColors.taupe.withValues(alpha: 0.4),
              thickness: 0.75,
              height: CsSpacing.md,
            ),
          EventParticipantRow(
            restaurant: recognized[i],
            onTap: () => onTapRestaurant(recognized[i]),
          ),
        ],
      ],
    );
  }
}
