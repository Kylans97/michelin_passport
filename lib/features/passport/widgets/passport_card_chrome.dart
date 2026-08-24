import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/cs_spacing.dart';
import '../../../core/theme/cs_typography.dart';

/// Passport UI Polish V2 — the bookmark/follow control shown top-right on
/// every collection card, now wired to the existing wishlist mechanism
/// ([WishlistRepository]/`wishlist` table) rather than the static,
/// non-interactive glyph the previous pass shipped deliberately (no
/// second, parallel "saved" concept — this toggles the exact same
/// wishlist a restaurant/hotel already has from Explore/its own Detail
/// screen). Its own [Material]/[InkWell] gives it a tap target isolated
/// from the card's outer tap-to-navigate InkWell — tapping the bookmark
/// never opens Restaurant/Hotel Detail, and tapping the rest of the card
/// never toggles the bookmark (nested InkWells resolve to the innermost
/// hit target; this is standard Flutter gesture-arena behavior, not a
/// workaround). Ivory/forest-green only — no gold.
class PassportCardBookmark extends StatelessWidget {
  final bool isWishlisted;
  final VoidCallback onTap;

  const PassportCardBookmark({
    super.key,
    required this.isWishlisted,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: isWishlisted ? 'Remove from wishlist' : 'Add to wishlist',
    excludeSemantics: true,
    child: Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.warmWhite,
            border: Border.all(color: AppColors.subtleBorderLight),
          ),
          alignment: Alignment.center,
          child: Icon(
            isWishlisted
                ? Icons.bookmark_rounded
                : Icons.bookmark_outline_rounded,
            color: AppColors.forestGreen,
            size: 16,
          ),
        ),
      ),
    ),
  );
}

/// Passport UI Polish V2 — the collection card footer, simplified to a
/// single line: a rating icon + [ratingText] only ("6.0 average · 1
/// visit"). The previous pass's second "Last visit DATE" column was
/// removed per explicit product direction — a card should answer what/
/// where/recognition/rating/visit-count/saved, not also date, which
/// belongs on Restaurant/Hotel Detail's own visit history. Plain
/// forest-green icon, never gold — this decorates a rating figure, not
/// Michelin recognition itself (StarRow/KeyRow, used separately for the
/// actual award, stay gold-filled and unchanged). Deliberately
/// `star_outline_rounded`, not the solid `star_rounded` StarRow uses — a
/// distinct glyph so this generic rating indicator is never mistaken for
/// (or accidentally counted as part of) the card's own Michelin star
/// recognition above it.
class PassportCardFooter extends StatelessWidget {
  final String ratingText;

  const PassportCardFooter({super.key, required this.ratingText});

  @override
  Widget build(BuildContext context) => Row(
    children: [
      const Icon(
        Icons.star_outline_rounded,
        color: AppColors.forestGreen,
        size: 14,
      ),
      const SizedBox(width: CsSpacing.xs),
      Flexible(
        child: Text(
          ratingText,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: CsTypography.metadata,
        ),
      ),
    ],
  );
}
