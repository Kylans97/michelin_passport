import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

/// One edge of a multi-photo hero gallery's navigation — a small glyph
/// directly over the scrim, deliberately not a circular button or a
/// floating control. Shared by [VenueDetailHero] and [PrivateChefHero]:
/// unlike those two heroes themselves (which genuinely differ — wishlist,
/// recognition badges and the closed-venue treatment on one side; the
/// portrait crop and the photo-report action on the other, so they stay
/// two separate widgets), a chevron carries no domain logic at all. It's
/// identical by intention in both places, so it's the one piece of that
/// duplication with no reason to exist twice.
///
/// The caller decides when each edge renders (never on the edge that has
/// no photo to go to — no wrap-around — and never at all for a single
/// photo) and drives [onTap] from its own PageController. The tap target
/// is a comfortably larger box (44×44, a practical minimum) than the
/// glyph itself; a subtle drop shadow keeps the glyph legible over a
/// bright photo without needing a background chip.
class HeroPhotoChevron extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const HeroPhotoChevron({super.key, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    behavior: HitTestBehavior.opaque,
    onTap: onTap,
    child: SizedBox(
      width: 44,
      height: 44,
      child: Center(
        child: Icon(
          icon,
          size: 20,
          color: AppColors.textOnDark,
          shadows: const [Shadow(blurRadius: 6, color: Colors.black45)],
        ),
      ),
    ),
  );
}
