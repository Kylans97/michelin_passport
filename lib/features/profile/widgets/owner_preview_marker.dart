import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/cs_typography.dart';

/// Wraps [child] with a small, restrained "PREVIEW" marker — the one
/// signal that this is not the live page a visitor sees. Deliberately not
/// a banner: one small pill floating over the hero, not competing with
/// the content underneath it. Applied at the screen level (wrapping the
/// whole `Scaffold`, from outside), not built into any one hero — so it
/// renders identically regardless of whether the hero underneath has its
/// own SliverAppBar title (`PrivateChefHero` deliberately doesn't, unlike
/// `VenueDetailHero`) — this sits above the hero entirely, never inside
/// one of the three separate hero implementations.
///
/// Only ever wraps a `Positioned` pill sized to its own content, never
/// `StackFit.expand` — it must never repeat today's own hit-test lesson
/// (a widget stretched to fill its Stack silently absorbing taps meant
/// for what's underneath it).
///
/// The pill's own `Positioned` sits as a *sibling* of [child] (the whole
/// `Scaffold`) inside this widget's own `Stack` — deliberately, so the
/// marker renders above every one of the three screens' own heroes
/// identically (see this class's own doc comment above). That placement
/// has a real cost: it means the pill's text has no `Material` ancestor
/// of its own. `Material` widgets are what establish a sane
/// `DefaultTextStyle` in a Material app (`Scaffold` provides one, which
/// is why ordinary in-page text never needs to think about this) —
/// without one, `DefaultTextStyle.of(context)` falls all the way back to
/// `MaterialApp`'s OWN deliberately glaring fallback style
/// (`_errorTextStyle` in `material/app.dart`: 48px monospace red text
/// with a double yellow underline, `debugLabel: 'fallback style;
/// consider putting your text in a Material'`), and `Text.style` MERGES
/// against that ambient style rather than replacing it outright — so any
/// field this pill's own style doesn't explicitly set (here:
/// `decoration`/`decorationColor`/`decorationStyle`, which typography
/// tokens meant for normal body text have no reason to set) leaks
/// through from the fallback. `Material(type: MaterialType.transparency,
/// ...)` is this codebase's own established idiom for "needs a real
/// `Material` ancestor, no visual surface of its own" (see
/// guide_year_selector.dart/event_date_control.dart for the same idiom
/// used for a different reason — a valid ink-splash paint surface) — used
/// here to give the pill's text a real ambient style to merge against
/// (`Theme.textTheme.bodyMedium`, ordinary and undecorated) instead of
/// the intentionally-broken one.
class OwnerPreviewMarker extends StatelessWidget {
  final Widget child;

  /// Set only when the preview's fresh venue re-fetch failed and it fell
  /// back to the cached model VenueManagementScreen already had — e.g.
  /// "Showing your last saved details". Falling back is acceptable;
  /// showing stale data as if it were fresh is not, so this is how that
  /// fallback says so on the one screen the manager is actually looking
  /// at, rather than a toast they may have missed before this screen
  /// opened. `null` (the ordinary case — the re-fetch succeeded) renders
  /// just the plain "PREVIEW" pill, unchanged.
  final String? subtitle;

  const OwnerPreviewMarker({super.key, required this.child, this.subtitle});

  @override
  Widget build(BuildContext context) => Stack(
    children: [
      child,
      Positioned(
        top: 0,
        left: 0,
        right: 0,
        child: SafeArea(
          child: Align(
            alignment: Alignment.topCenter,
            child: Container(
              margin: const EdgeInsets.only(top: 8),
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 4,
              ),
              decoration: BoxDecoration(
                color: AppColors.deepGreen.withValues(alpha: 0.85),
                borderRadius: BorderRadius.circular(999),
              ),
              // See this class's own doc comment above for why this is
              // required, not decorative: without it, both Text widgets
              // below merge their style against MaterialApp's glaring
              // fallback DefaultTextStyle rather than a real one.
              child: Material(
                type: MaterialType.transparency,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'PREVIEW',
                      style: CsTypography.eyebrow.copyWith(
                        color: AppColors.textOnDark,
                        letterSpacing: 1.2,
                      ),
                    ),
                    if (subtitle != null)
                      Text(
                        subtitle!,
                        style: CsTypography.metadata.copyWith(
                          color: AppColors.textOnDark,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ],
  );
}
