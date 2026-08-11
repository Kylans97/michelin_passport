import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/theme/cs_spacing.dart';
import '../../core/theme/cs_typography.dart';
import 'fifty_best_hotel_guide_screen.dart';
import 'fifty_best_restaurant_guide_screen.dart';
import 'michelin_hotel_guide_screen.dart';
import 'michelin_restaurant_guide_screen.dart';
import 'widgets/guide_destination_row.dart';
import 'widgets/guide_family_section.dart';

/// Guides — "Help me find something." The structured, reference-driven
/// counterpart to Explore's editorial "Inspire me." An editorial index of
/// the guide families Chasing Stars currently has real data for
/// (Michelin, The World's 50 Best) — never a settings menu, never a grid
/// of generic buttons, and never a family the app can't yet back with
/// real content (see the deliberate absence of Gault&Millau — Guides Step
/// 1's audit confirmed there is no such data today, and none is faked
/// here).
///
/// A bare canvas (no [Scaffold] of its own), matching Passport/Explore's
/// pattern rather than Login/Sign up's: this screen is built to live
/// inside `_MainNavigation`'s IndexedStack once Guides is wired into
/// bottom navigation (a later, separate step — not this one), where a
/// Scaffold already exists above it. It is not wired into navigation in
/// this step; see the Step 2A report for how it's reached for device
/// review instead.
class GuidesScreen extends StatelessWidget {
  const GuidesScreen({super.key});

  void _open(BuildContext context, Widget screen) =>
      Navigator.push(context, MaterialPageRoute(builder: (_) => screen));

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.deepGreen,
      child: SafeArea(
        child: SingleChildScrollView(
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
                    descriptor:
                        'Exceptional stays recognised with Michelin Keys.',
                    onTap: () =>
                        _open(context, const MichelinHotelGuideScreen()),
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
                    onTap: () =>
                        _open(context, const FiftyBestHotelGuideScreen()),
                  ),
                ],
              ),
            ],
          ),
        ),
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
