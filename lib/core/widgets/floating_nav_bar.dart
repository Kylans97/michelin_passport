import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../theme/cs_spacing.dart';
import '../theme/cs_surfaces.dart';

/// The pill's own content height, vertically centering each icon —
/// deliberately shorter than the old docked `NavigationBar`'s 68 + full
/// bottom-safe-area footprint (~100pt on a modern iPhone). Matches
/// CsNavStyle.iconSize (22) plus comfortable tap-target padding, landing
/// close to the established 44pt compact-control precedent this app
/// already uses elsewhere (CsFilterChip). Exposed so [floatingNavClearance]
/// can compute exactly how much a scrolling screen needs to reserve,
/// rather than every screen guessing its own magic number (the state this
/// replaced: six different hardcoded bottom-padding values —
/// 24/40/48/76/88/100 — across ten scroll bodies, none derived from the
/// nav bar's real size).
const double kFloatingNavBarHeight = 44;

/// Gap between the pill's bottom edge and the device's own safe-area inset.
const double kFloatingNavBarBottomMargin = CsSpacing.md;

/// Gap between the pill's side edges and the screen edges.
const double kFloatingNavBarSideMargin = CsSpacing.base;

/// Breathing room between a scrolling screen's last item and the pill's
/// top edge — the pill floats over content, so this is the only thing
/// stopping a list's last row from sitting flush behind it.
const double _kFloatingNavBarBreathingRoom = CsSpacing.base;

/// The total bottom clearance every scrolling tab screen must reserve so
/// its content never disappears under the floating pill — safe-area inset
/// (varies per device, e.g. ~34pt with a home indicator, 0 without) plus
/// the pill's own margin, height, and a little breathing room above it.
/// Every scrollable body reachable from the five main tabs (Explore,
/// Passport's four sub-bodies, News, Community's two sub-bodies, Profile)
/// uses this — see NAVIGATION_INFORMATION_ARCHITECTURE_V2 findings: there
/// was no single source of truth for this before.
double floatingNavClearance(BuildContext context) =>
    MediaQuery.paddingOf(context).bottom +
    kFloatingNavBarBottomMargin +
    kFloatingNavBarHeight +
    _kFloatingNavBarBreathingRoom;

class FloatingNavDestination {
  final IconData icon;
  final IconData selectedIcon;

  /// Never rendered as visible text (see this class's own doc comment on
  /// why the bar is fully icon-only) — kept purely for the accessibility
  /// semantics label a screen-reader user needs regardless of what's
  /// painted on screen.
  final String label;

  const FloatingNavDestination({
    required this.icon,
    required this.selectedIcon,
    required this.label,
  });
}

/// The app's root tab switcher — a floating pill, not a docked full-width
/// bar: rounded ends, inset from both side edges and the bottom, sitting
/// on top of scrollable content (the caller positions this over its body,
/// it doesn't reserve its own Scaffold slot). Fully icon-only — no label
/// anywhere, including the active tab: an earlier version kept a label
/// under the active icon as a middle ground, corrected away from
/// explicitly once seen rendered (Passport was the only destination still
/// carrying text, which read as inconsistent rather than as a deliberate
/// emphasis).
///
/// Never gold — selection reads through ivory/secondaryOnDark icon tone
/// alone, same rule the docked bar it replaces already followed (gold
/// stays reserved for MICHELIN stars/Keys, see CLAUDE.md).
class FloatingNavBar extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final List<FloatingNavDestination> destinations;

  const FloatingNavBar({
    super.key,
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.destinations,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: kFloatingNavBarSideMargin,
        right: kFloatingNavBarSideMargin,
        bottom: MediaQuery.paddingOf(context).bottom + kFloatingNavBarBottomMargin,
      ),
      // A plain fixed SizedBox is safe here specifically because there is
      // no text inside an item any more — an Icon's size is logical
      // pixels, not affected by the device's text-scale setting, so
      // there's no accessibility-text-scale overflow case left to guard
      // against (an earlier label-carrying version of this widget needed
      // a ConstrainedBox+IntrinsicHeight combination to avoid exactly that
      // — removed as unnecessary complexity once the label itself was
      // removed, not just left in place unused).
      child: SizedBox(
        height: kFloatingNavBarHeight,
        child: DecoratedBox(
          decoration: BoxDecoration(
            // A panel floating ON the green canvas behind it, not the
            // canvas itself — forestGreen (CsSurfaces.greenElevated), not
            // deepGreen, is the semantically correct token here (see
            // app_colors.dart's own role documentation); the docked bar it
            // replaces used deepGreen deliberately because it read as a
            // primary surface, not a panel — a floating pill is
            // architecturally a panel.
            color: AppColors.forestGreen,
            borderRadius: BorderRadius.circular(CsRadius.pill),
            border: Border.all(color: AppColors.hairlineOnGreen),
            boxShadow: CsSurfaces.elevatedShadow,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(CsRadius.pill),
            child: Row(
              children: [
                for (var i = 0; i < destinations.length; i++)
                  Expanded(
                    child: _FloatingNavItem(
                      destination: destinations[i],
                      selected: i == selectedIndex,
                      onTap: () => onDestinationSelected(i),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FloatingNavItem extends StatelessWidget {
  final FloatingNavDestination destination;
  final bool selected;
  final VoidCallback onTap;

  const _FloatingNavItem({
    required this.destination,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.ivory : AppColors.secondaryOnDark;
    return Semantics(
      button: true,
      enabled: true,
      selected: selected,
      label: destination.label,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Center(
            child: ExcludeSemantics(
              child: Icon(
                selected ? destination.selectedIcon : destination.icon,
                color: color,
                size: 22,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
