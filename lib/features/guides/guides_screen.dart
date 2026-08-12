import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/theme/cs_spacing.dart';
import '../../core/theme/cs_typography.dart';
import '../../core/widgets/editorial_back_button.dart';
import 'fifty_best_hotel_guide_screen.dart';
import 'fifty_best_restaurant_guide_screen.dart';
import 'gault_millau_restaurant_guide_screen.dart';
import 'michelin_hotel_guide_screen.dart';
import 'michelin_restaurant_guide_screen.dart';
import 'widgets/guide_destination_row.dart';
import 'widgets/guide_family_section.dart';

/// Guides — "Help me find something." The structured, reference-driven
/// counterpart to Explore's editorial "Inspire me." An editorial index of
/// the guide families Chasing Stars currently has real data for (Michelin,
/// The World's 50 Best, Gault&Millau) — never a settings menu, never a grid
/// of generic buttons, and never a family the app can't yet back with real
/// content. Gault&Millau (Step 2D) has exactly one destination,
/// Restaurants — no Hotels entry, since production's Gault&Millau data is
/// restaurant-only (see the Step 2D data audit). Germany remains deferred
/// and is never shown, even as a placeholder — see
/// RestaurantGaultMillauRepository.getCountries, which derives its country
/// list from data actually present, not a hardcoded launch-market list.
///
/// A real [Scaffold] of its own (TRIPS+GUIDES DEVICE-FIX PASS) — reached
/// via a direct [Navigator.push] from Explore's "Browse the Guides" row
/// (Navigation Step 1), which puts this screen's whole subtree in a NEW
/// route in the [Navigator]'s [Overlay], a sibling of — never a
/// descendant of — the calling screen's own Scaffold. A bare [ColoredBox]
/// here previously left every [Text] with no [Material] ancestor
/// anywhere above it (confirmed by an on-device A/B rebuild: identical
/// widgets, wrapped in a [Scaffold] vs. not, only underline when not),
/// which is what produced the faint underline artifact under "GUIDES",
/// its intro line and each family eyebrow — [GuideDestinationRow]'s own
/// labels were never affected, since that widget wraps its own local
/// [Material]. Matches [GuideCatalogueLayout]'s own established pattern.
class GuidesScreen extends StatelessWidget {
  const GuidesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.deepGreen,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                CsSpacing.base,
                CsSpacing.xs,
                CsSpacing.base,
                0,
              ),
              child: Align(
                alignment: Alignment.centerLeft,
                child: EditorialBackButton(),
              ),
            ),
            const Expanded(child: _GuidesBody()),
          ],
        ),
      ),
    );
  }
}

class _GuidesBody extends StatelessWidget {
  const _GuidesBody();

  void _open(BuildContext context, Widget screen) =>
      Navigator.push(context, MaterialPageRoute(builder: (_) => screen));

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        CsSpacing.pageHorizontal,
        CsSpacing.sm,
        CsSpacing.pageHorizontal,
        CsSpacing.hero,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _GuidesHeader(),
          // ~12.5% less than CsSpacing.section (40) per physical-device
          // review — still generous editorial breathing room, just not
          // as wide as the gap between two guide families below.
          const SizedBox(height: 35),
          GuideFamilySection(
            title: 'MICHELIN GUIDE',
            destinations: [
              GuideDestinationRow(
                label: 'Restaurants',
                descriptor: "The world's most celebrated tables.",
                onTap: () =>
                    _open(context, const MichelinRestaurantGuideScreen()),
              ),
              GuideDestinationRow(
                label: 'Hotels',
                descriptor: 'Exceptional stays recognised with Michelin Keys.',
                onTap: () => _open(context, const MichelinHotelGuideScreen()),
              ),
            ],
          ),
          const SizedBox(height: CsSpacing.section),
          GuideFamilySection(
            title: "THE WORLD'S 50 BEST",
            destinations: [
              GuideDestinationRow(
                label: 'Restaurants',
                descriptor: 'The restaurants shaping global dining.',
                onTap: () =>
                    _open(context, const FiftyBestRestaurantGuideScreen()),
              ),
              GuideDestinationRow(
                label: 'Hotels',
                descriptor: "The world's most remarkable stays.",
                onTap: () => _open(context, const FiftyBestHotelGuideScreen()),
              ),
            ],
          ),
          const SizedBox(height: CsSpacing.section),
          GuideFamilySection(
            title: 'GAULT&MILLAU',
            destinations: [
              GuideDestinationRow(
                label: 'Restaurants',
                descriptor:
                    'Distinctive restaurants recognised by Gault&Millau.',
                onTap: () =>
                    _open(context, const GaultMillauRestaurantGuideScreen()),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Editorial header ────────────────────────────────────────────────────

class _GuidesHeader extends StatelessWidget {
  const _GuidesHeader();

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        'GUIDES',
        style: CsTypography.screenTitle.copyWith(color: AppColors.textOnDark),
      ),
      const SizedBox(height: CsSpacing.xs),
      Text(
        'Exceptional places, recognised by the world\'s leading guides.',
        style: CsTypography.body.copyWith(color: AppColors.secondaryOnDark),
      ),
    ],
  );
}
