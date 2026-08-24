import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants/app_colors.dart';
import '../../core/theme/cs_spacing.dart';
import '../../core/theme/cs_typography.dart';
import '../../core/widgets/star_row.dart';
import '../../core/widgets/venue_thumbnail.dart';
import '../../data/repositories/rankings_repository.dart';
import '../../data/repositories/restaurant_repository.dart';
import '../../models/ranking_entry.dart';
import '../../models/restaurant.dart';
import '../restaurants/restaurant_detail_screen.dart';
import 'community_rankings_screen.dart';
import 'dining_together_screen.dart';

/// Community — Navigation & Information Architecture V2's fourth primary
/// destination. "What are other Chasing Stars members interested in?"
///
/// Community Typography + Dining Together Refinement: three major
/// editorial section titles — **Hottest Places**, **Community Rankings**,
/// **Dining Together** — each set in the same serif heading style
/// (`CsTypography.placeTitle`, ivory), clearly smaller than the page
/// title ("Community", `screenTitle`) and clearly larger/more prominent
/// than their own description/action content below them. Deliberately
/// NOT rendered as tiny tracked-uppercase eyebrow labels (an earlier pass
/// used `_sectionEyebrow` for these — that read as a category-label
/// hierarchy where "View rankings" ended up looking more important than
/// "Community Rankings" itself; this pass corrects that).
///
/// - **Hottest Places** (renamed from "Hot Right Now" — the previous
///   label implied a temporal trending algorithm the data doesn't
///   support; this section will eventually cover Restaurant/Hotel/Event
///   together, and reads better as an editorial/luxury framing than a
///   social-media trending widget). Audited before building anything (no
///   new backend aggregation was added): a real, already-aggregated,
///   cross-user signal exists for restaurants
///   (`RankingsRepository.getCommunityRankings()`, the same
///   `restaurant_rankings` view `CommunityRankingsTab` already uses) — the
///   community's highest-rated restaurant, captioned "Highest rated by
///   the community" (never "Trending"/"This week", which the data doesn't
///   support). No equivalent exists for hotels anywhere in the repository
///   layer, and events would need a new batched RPC/view (confirmed via
///   `docs/Architecture/EVENTS_V2_STEP_8A_PERSONALIZED_RANKING_PRE_FINAL.md`,
///   which documents this exact gap) — not a trivial reuse, and not built
///   here. Section architecture (including graceful omission — heading
///   and card together — when the query is empty/erroring) is unchanged
///   from the prior pass; only the heading's text/style changed.
/// - **Community Rankings** — real, unchanged content
///   (`CommunityRankingsTab` reused verbatim via `CommunityRankingsScreen`),
///   now reached via a small, restrained "View rankings →" action link
///   below the section title/description, rather than a full-width
///   `GuideDestinationRow` competing with the section title for
///   prominence.
/// - **Meet the Community** — still absent (unchanged). No genuine
///   editorial/user-story content exists yet. Future architecture
///   (documented, not built): News owns the Article; Community surfaces a
///   selected user-focused story under this heading once one exists,
///   linking to the canonical News Article Detail.
/// - **Dining Together** — now tappable: a "Discover the concept →"
///   action link pushes [DiningTogetherScreen], a dedicated editorial
///   concept/preview page (its own "Coming soon," not shown directly on
///   this landing page anymore — the landing page teases the concept
///   rather than stopping the user with an unavailable-state label). No
///   Dining Together functionality (matching/chat/booking/etc.) exists —
///   see [DiningTogetherScreen]'s own doc comment.
///
/// A bottom-tab body (no own `Scaffold`, matching `ExploreScreen`/
/// `PassportScreen`'s established convention).
///
/// Hot Right Now bugfix (device revalidation): [loadCommunityRankings] and
/// [getRestaurantById] are injectable — the same constructor-injection
/// seam `DeleteAccountScreen` already uses for its own destructive flow —
/// so the REAL widget can be pumped and exercised in widget tests without
/// Supabase, rather than a hand-mirrored copy of this build() method. Both
/// default to the real repositories against `Supabase.instance.client`
/// when omitted (production use, unaffected by the seam existing). This
/// was added because the previous mirror-based test for this screen could
/// never have caught the actual production defect: `getCommunityRankings()`
/// queries a `restaurant_rankings` Postgres view that does not exist in
/// production (confirmed via a live, read-only query — see
/// docs/Architecture/NAVIGATION_INFORMATION_ARCHITECTURE_V2.md's Hot Right
/// Now Bugfix section) — a missing-backend-object defect no widget test,
/// mirrored or otherwise, can detect; only a live data audit can. This
/// screen's own "hide Hot Right Now gracefully on error" behavior is
/// correct and unchanged — the defect was never in this code.
class CommunityScreen extends StatefulWidget {
  final Future<List<CommunityRankingEntry>> Function()? loadCommunityRankings;
  final Future<Restaurant?> Function(String id)? getRestaurantById;

  const CommunityScreen({
    super.key,
    this.loadCommunityRankings,
    this.getRestaurantById,
  });

  @override
  State<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends State<CommunityScreen> {
  late final Future<CommunityRankingEntry?> _hottestPlacesFuture =
      _loadHottestPlaces();

  Future<CommunityRankingEntry?> _loadHottestPlaces() async {
    try {
      final load =
          widget.loadCommunityRankings ??
          RankingsRepository(Supabase.instance.client).getCommunityRankings;
      final entries = await load();
      return entries.isEmpty ? null : entries.first;
    } catch (_) {
      // Graceful omission, never a raw error surfaced on this hero section
      // — see this class's own doc comment.
      return null;
    }
  }

  Future<void> _openRestaurant(String restaurantId) async {
    final getById =
        widget.getRestaurantById ??
        RestaurantRepository(Supabase.instance.client).getById;
    final restaurant = await getById(restaurantId);
    if (!mounted || restaurant == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RestaurantDetailScreen(restaurant: restaurant),
      ),
    );
  }

  void _openCommunityRankings() => Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => const CommunityRankingsScreen()),
  );

  void _openDiningTogether() => Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => const DiningTogetherScreen()),
  );

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: AppColors.deepGreen,
    child: Column(
      // Header Alignment Fix: a plain Column loosens the cross-axis
      // (width) constraint it gives non-flex children, so — unlike
      // Explore/Passport, which reach their header through a
      // SliverToBoxAdapter (slivers force a TIGHT cross-axis width on
      // their child) — the SafeArea/header below would shrink-wrap to
      // its own widest line (the subtitle) and then sit centered under
      // this Column's default crossAxisAlignment.center. That shrink was
      // masked at exactly one logical width (390) because the subtitle
      // happened to wrap onto two lines filling the available width —
      // fragile, and exactly why it read as centered on the physical
      // device (a different width/text-scale not fully wrapping) despite
      // testing "fine" at one specific dimension. `stretch` forces every
      // direct child (the header AND the scrollable body below) to the
      // full tight width Explore/Passport already get for free from
      // their sliver, so the inner `crossAxisAlignment: start` Columns
      // finally left-align against real full-width bounds instead of
      // their own shrink-wrapped ones.
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              CsSpacing.pageHorizontal,
              CsSpacing.lg,
              CsSpacing.pageHorizontal,
              CsSpacing.md,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Community',
                  style: CsTypography.screenTitle.copyWith(
                    color: AppColors.ivory,
                  ),
                ),
                const SizedBox(height: CsSpacing.xs),
                Text(
                  'What people are chasing.',
                  style: CsTypography.body.copyWith(
                    color: AppColors.secondaryOnDark,
                  ),
                ),
              ],
            ),
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              CsSpacing.pageHorizontal,
              0,
              CsSpacing.pageHorizontal,
              CsSpacing.section,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FutureBuilder<CommunityRankingEntry?>(
                  future: _hottestPlacesFuture,
                  builder: (context, snap) {
                    if (snap.connectionState != ConnectionState.done ||
                        snap.data == null) {
                      // Loading or genuinely empty (new install, zero
                      // community ratings yet, or the underlying data
                      // isn't available) — omit the whole section rather
                      // than show a heading over nothing, or a
                      // placeholder claiming a feature is missing.
                      return const SizedBox.shrink();
                    }
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _sectionTitle('Hottest Places'),
                        const SizedBox(height: CsSpacing.sm),
                        _HottestPlacesRestaurantCard(
                          entry: snap.data!,
                          onTap: () => _openRestaurant(snap.data!.restaurantId),
                        ),
                        const SizedBox(height: CsSpacing.section),
                      ],
                    );
                  },
                ),
                _sectionTitle('Community Rankings'),
                const SizedBox(height: CsSpacing.xs),
                Text(
                  'See how the community rates every restaurant.',
                  style: CsTypography.body.copyWith(
                    color: AppColors.secondaryOnDark,
                  ),
                ),
                const SizedBox(height: CsSpacing.sm),
                _CommunityActionLink(
                  label: 'View rankings',
                  onTap: _openCommunityRankings,
                ),
                const SizedBox(height: CsSpacing.section),
                // "Meet the Community" is deliberately absent — see this
                // class's own doc comment.
                _sectionTitle('Dining Together'),
                const SizedBox(height: CsSpacing.xs),
                Text(
                  'Great tables are better shared.',
                  style: CsTypography.body.copyWith(
                    color: AppColors.secondaryOnDark,
                  ),
                ),
                const SizedBox(height: CsSpacing.sm),
                _CommunityActionLink(
                  label: 'Discover the concept',
                  onTap: _openDiningTogether,
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}

/// One of Community's three major editorial section titles (Hottest
/// Places / Community Rankings / Dining Together) — the same serif
/// heading style for all three, clearly smaller than the "Community" page
/// title and clearly larger than the description/action content beneath
/// it. Deliberately NOT the tiny tracked-uppercase eyebrow style used
/// elsewhere in this app for minor labels — see this file's own class
/// doc comment for why.
Widget _sectionTitle(String label) => Text(
  label,
  style: CsTypography.placeTitle.copyWith(color: AppColors.ivory),
);

/// A restrained "Label →" action link — deliberately secondary to
/// [_sectionTitle] (smaller type, no card/row chrome), used for both
/// "View rankings" (Community Rankings) and "Discover the concept"
/// (Dining Together) so the two read identically. Ivory, never gold —
/// gold stays reserved for Michelin stars/Keys.
class _CommunityActionLink extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _CommunityActionLink({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.transparent,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Flexible, not a bare Text: a Row's non-flex children get
            // unbounded main-axis constraints to measure their own
            // natural single-line width, so an unwrapped Text here would
            // overflow (never wrap) at narrow widths — confirmed via a
            // 320px-wide test failure on "Discover the concept".
            Flexible(
              child: Text(
                label,
                style: CsTypography.bodyMedium.copyWith(
                  color: AppColors.ivory,
                ),
              ),
            ),
            const SizedBox(width: 6),
            const Icon(
              Icons.arrow_forward_rounded,
              color: AppColors.ivory,
              size: 16,
            ),
          ],
        ),
      ),
    ),
  );
}

/// Community's editorial hero — the community's highest-rated restaurant,
/// via the same real `restaurant_rankings` view `CommunityRankingsTab`
/// already reads. Deliberately not styled as a generic Material dashboard
/// card: dark-canvas editorial treatment (VenueThumbnail, serif name,
/// StarRow — gold there is correct, it's the Michelin-star signal —
/// everything else ivory/secondaryOnDark, never gold on the rating
/// numeral itself).
class _HottestPlacesRestaurantCard extends StatelessWidget {
  final CommunityRankingEntry entry;
  final VoidCallback onTap;

  const _HottestPlacesRestaurantCard({
    required this.entry,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label:
        '${entry.name}, ${entry.city}. Highest rated by the community, '
        '${entry.communityRating.toStringAsFixed(1)}.',
    excludeSemantics: true,
    child: Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(CsRadius.medium),
        child: Container(
          padding: const EdgeInsets.all(CsSpacing.base),
          decoration: BoxDecoration(
            color: AppColors.brandGreenLight,
            borderRadius: BorderRadius.circular(CsRadius.medium),
            border: Border.all(color: AppColors.subtleBorderDark),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const VenueThumbnail(imageUrl: null, size: 64),
              const SizedBox(width: CsSpacing.base),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'RESTAURANT',
                      style: CsTypography.eyebrow.copyWith(
                        color: AppColors.secondaryOnDark,
                        fontSize: 10,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      entry.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: CsTypography.placeTitle.copyWith(
                        color: AppColors.textOnDark,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        if (entry.michelinStars > 0) ...[
                          StarRow(count: entry.michelinStars, size: 12),
                          const SizedBox(width: CsSpacing.xs),
                        ],
                        Flexible(
                          child: Text(
                            '${entry.countryFlag} ${entry.city}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: CsTypography.metadata.copyWith(
                              color: AppColors.secondaryOnDark,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: CsSpacing.xs),
                    Text(
                      'Highest rated by the community',
                      style: CsTypography.metadata.copyWith(
                        color: AppColors.secondaryOnDark,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: CsSpacing.sm),
              Text(
                entry.communityRating.toStringAsFixed(1),
                style: CsTypography.largeMetric.copyWith(
                  color: AppColors.ivory,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
