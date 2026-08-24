import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants/app_colors.dart';
import '../../core/theme/cs_spacing.dart';
import '../../core/theme/cs_typography.dart';
import '../map/visited_map_screen.dart';
import '../rankings/widgets/personal_rankings_tab.dart';
import '../trips/planned_trips_screen.dart' show TripsBody;
import '../wishlist/wishlist_screen.dart' show WishlistBody;
import 'widgets/passport_collection_body.dart';

/// Passport Unified Experience V1 — one continuous personal space with
/// four subsections (Passport / Wishlist / Ranking / Trips), not four
/// separate screens. The header, the local tab bar, and the surrounding
/// bottom navigation all stay on screen and unchanged while switching
/// between them; only the content region below the tab bar swaps. This
/// replaces the previous architecture (Navigation & Information
/// Architecture V2's "quick-access row" that `Navigator.push`ed each of
/// Wishlist/My Ranking/Trips as its own pushed, independently scaffolded
/// screen) — that pattern read as leaving Passport entirely, not
/// switching a mode within it.
///
/// Subsection bodies are built lazily and then cached for the lifetime of
/// this screen (`_bodies`): the first visit to a subsection constructs
/// its widget once; every later visit reuses the same instance via
/// [IndexedStack], so its own internal state (filters, scroll position)
/// survives switching away and back, and repeated switching never grows
/// a navigation stack, never re-fetches, and never rebuilds a duplicate
/// header. Passport's own subsection is built eagerly (the default,
/// always-visible-first tab); Wishlist/Ranking/Trips are not fetched at
/// all until the user actually taps that tab.
///
/// Deep detail navigation (Restaurant/Hotel/Event/Trip Detail, My Map) is
/// unaffected by this — those remain normal pushed screens with their own
/// back arrow, exactly as before. The "same page" rule applies only to
/// these four subsections.
///
/// Each subsection body is injectable ([passportBody]/[wishlistBody]/
/// [rankingBody]/[tripsBody]) — the same constructor-injection seam used
/// throughout this app's other Supabase-eager screens (`CommunityScreen`,
/// `DeleteAccountScreen`, `CommunityRankingsTab`). All four default to the
/// real, Supabase-backed bodies when omitted (production use, unaffected
/// by the seam existing); tests can supply lightweight fakes instead, so
/// the real shell — header persistence, tab switching, IndexedStack
/// caching — is exercised directly rather than through a hand-mirrored
/// copy of this class's own logic.
class PassportScreen extends StatefulWidget {
  final Widget? passportBody;
  final Widget? wishlistBody;
  final Widget? rankingBody;
  final Widget? tripsBody;

  const PassportScreen({
    super.key,
    this.passportBody,
    this.wishlistBody,
    this.rankingBody,
    this.tripsBody,
  });

  @override
  State<PassportScreen> createState() => _PassportScreenState();
}

enum PassportSubsection { passport, wishlist, ranking, trips }

class _PassportScreenState extends State<PassportScreen> {
  PassportSubsection _subsection = PassportSubsection.passport;

  // Lazily populated as each subsection is first visited — see this
  // class's own doc comment.
  late final Map<PassportSubsection, Widget> _bodies = {
    PassportSubsection.passport: _buildBody(PassportSubsection.passport),
  };

  void _selectSubsection(PassportSubsection subsection) {
    setState(() {
      _subsection = subsection;
      _bodies.putIfAbsent(subsection, () => _buildBody(subsection));
    });
  }

  Widget _buildBody(PassportSubsection subsection) => switch (subsection) {
    PassportSubsection.passport =>
      widget.passportBody ?? const PassportCollectionBody(),
    PassportSubsection.wishlist => widget.wishlistBody ?? const WishlistBody(),
    PassportSubsection.ranking =>
      widget.rankingBody ??
          _RankingBody(
            userId: Supabase.instance.client.auth.currentUser?.id ?? '',
          ),
    PassportSubsection.trips => widget.tripsBody ?? const TripsBody(),
  };

  void _openMap() => Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => const VisitedMapScreen()),
  );

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: AppColors.deepGreen,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SafeArea(
          bottom: false,
          child: _PassportExperienceHeader(onTapMap: _openMap),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            CsSpacing.pageHorizontal,
            0,
            CsSpacing.pageHorizontal,
            CsSpacing.md,
          ),
          child: _PassportLocalTabBar(
            selected: _subsection,
            onSelect: _selectSubsection,
          ),
        ),
        Expanded(
          child: IndexedStack(
            index: _subsection.index,
            children: [
              for (final subsection in PassportSubsection.values)
                _bodies[subsection] ?? const SizedBox.shrink(),
            ],
          ),
        ),
      ],
    ),
  );
}

// ── Ranking subsection ──────────────────────────────────────────────────

/// Wraps the existing, unchanged [PersonalRankingsTab] (My Ranking's real
/// content — filters, dimension picker, ranked list) in the light canvas
/// it already assumes, matching its previous host (the deleted
/// `RankingsScreen`, `Scaffold(backgroundColor: AppColors.background)`).
/// This is "My Ranking" only — Community's own ranking never appears
/// here; see `community_rankings_screen.dart` for that, reached only from
/// the Community tab.
class _RankingBody extends StatelessWidget {
  final String userId;
  const _RankingBody({required this.userId});

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: AppColors.background,
    child: PersonalRankingsTab(userId: userId),
  );
}

// ── Editorial header ──────────────────────────────────────────────────────

/// Persistent across every subsection — see [PassportScreen]'s own doc
/// comment. Unchanged copy/position from before the unified-experience
/// redesign; only ever built once (it isn't part of any subsection body).
class _PassportExperienceHeader extends StatelessWidget {
  final VoidCallback onTapMap;
  const _PassportExperienceHeader({required this.onTapMap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        CsSpacing.pageHorizontal,
        CsSpacing.lg,
        CsSpacing.pageHorizontal,
        CsSpacing.xl,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Passport',
                  style: CsTypography.screenTitle.copyWith(
                    color: AppColors.ivory,
                  ),
                ),
                const SizedBox(height: CsSpacing.xs),
                Text(
                  'Your collection of remarkable places.',
                  style: CsTypography.body.copyWith(
                    color: AppColors.secondaryOnDark,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: CsSpacing.sm),
          _MapButton(onTap: onTapMap),
        ],
      ),
    );
  }
}

/// Passport Unified Experience V1 — a restrained, rounded-outline
/// container around the map icon, matching the approved visual
/// reference. Real, existing functionality preserved unchanged: opens
/// [VisitedMapScreen], exactly as the previous plain [IconButton] did —
/// this is a styling change only, not a new or fake affordance.
class _MapButton extends StatelessWidget {
  final VoidCallback onTap;
  const _MapButton({required this.onTap});

  @override
  Widget build(BuildContext context) => Tooltip(
    message: 'My Map',
    child: Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(CsRadius.medium),
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(CsRadius.medium),
            border: Border.all(color: AppColors.subtleBorderDark),
          ),
          alignment: Alignment.center,
          child: const Icon(
            Icons.map_outlined,
            color: AppColors.textOnDark,
            size: 20,
          ),
        ),
      ),
    ),
  );
}

// ── Local tab bar ─────────────────────────────────────────────────────

/// Passport Unified Experience V1 — the persistent "PASSPORT WISHLIST
/// RANKING TRIPS" local tab bar (replacing the previous
/// `_PassportSecondaryNav`, which pushed a new screen per item). Selecting
/// an item now updates [PassportScreen]'s own local subsection state —
/// never `Navigator.push`, never a back arrow between these four. Active
/// state reads through color/weight plus a thin ivory underline matching
/// the approved reference; a fainter full-width baseline divider runs
/// beneath the whole row.
class _PassportLocalTabBar extends StatelessWidget {
  final PassportSubsection selected;
  final ValueChanged<PassportSubsection> onSelect;

  const _PassportLocalTabBar({required this.selected, required this.onSelect});

  static const _labels = {
    PassportSubsection.passport: 'Passport',
    PassportSubsection.wishlist: 'Wishlist',
    PassportSubsection.ranking: 'Ranking',
    PassportSubsection.trips: 'Trips',
  };

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      // Passport UI Polish V2 — spaceBetween distributes the four items
      // across the full available width ("generous horizontal breathing
      // room", replacing the previous fixed 8px gaps that read as too
      // close together). Each item is wrapped in Flexible (not a fixed
      // width) so that under real narrow-width/large-text-scale pressure
      // it can still shrink/ellipsize rather than hard-overflow — the
      // same defensive pattern used everywhere else in this codebase for
      // a row of labels sharing tight space, without needing a
      // horizontal-scroll safety net (confirmed via a 320/375/390/430px
      // widget test sweep).
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          for (final subsection in PassportSubsection.values)
            Flexible(
              child: _LocalTabItem(
                label: _labels[subsection]!,
                active: subsection == selected,
                onTap: () => onSelect(subsection),
              ),
            ),
        ],
      ),
      const SizedBox(height: CsSpacing.sm),
      Container(height: 1, color: AppColors.subtleBorderDark),
    ],
  );
}

/// A single item in [_PassportLocalTabBar]. [IntrinsicWidth] makes the
/// underline bar below the label match that label's own rendered width
/// (rather than stretching to the Row's shared column width) — the
/// standard pattern for a tab underline that hugs its own text.
class _LocalTabItem extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _LocalTabItem({
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.transparent,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: IntrinsicWidth(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Text(
                label.toUpperCase(),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: CsTypography.navigation.copyWith(
                  fontSize: 13,
                  letterSpacing: 0,
                  color: active ? AppColors.ivory : AppColors.secondaryOnDark,
                  fontWeight: active ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(height: 6),
            Container(
              height: 2,
              color: active ? AppColors.ivory : Colors.transparent,
            ),
          ],
        ),
      ),
    ),
  );
}
