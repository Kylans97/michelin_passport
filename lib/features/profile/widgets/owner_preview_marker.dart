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
class OwnerPreviewMarker extends StatelessWidget {
  final Widget child;

  const OwnerPreviewMarker({super.key, required this.child});

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
              child: Text(
                'PREVIEW',
                style: CsTypography.eyebrow.copyWith(
                  color: AppColors.textOnDark,
                  letterSpacing: 1.2,
                ),
              ),
            ),
          ),
        ),
      ),
    ],
  );
}
