import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/cs_spacing.dart';
import '../../../core/theme/cs_typography.dart';
import '../../../core/widgets/venue_thumbnail.dart';

/// PASSPORT — RANKING UI REDESIGN V1 (Color Hierarchy Correction pass):
/// the shared horizontal, editorial ranking row built once and reused by
/// [PersonalRankingCard] (restaurants) and [HotelRankingCard] (hotels) —
/// a compact ivory card with the image flush against the full left edge
/// (no gap around it, no separate empty column) and the rank number
/// integrated into the image's own top-left corner, matching the approved
/// reference. Purely presentational, the same "shell knows nothing about
/// Restaurant/Hotel" contract [CsPlaceCard] already uses — and, since
/// this pass, the same color grammar too: an ivory personal-object card
/// floating on Ranking's deep-green Passport canvas, exactly like a
/// restaurant/hotel card under Passport's own "YOUR COLLECTION". The
/// previous pass inverted this (a dark card on a light canvas) to match
/// the reference image in isolation, but that broke Passport's own
/// established deep-green-environment/ivory-object grammar — this
/// correction restores it without discarding the geometry refinement that
/// shipped alongside it (compact proportions, flush-left photo-ready
/// image, integrated rank, two-line names, unambiguous score). [rank]
/// must always be the venue's actual position in the caller's
/// already-sorted ranking — never invented.
///
/// [imageUrl] goes straight to [VenueThumbnail] — the app's own real-photo
/// -with-branded-monogram-fallback mechanism (already used by Explore/
/// Wishlist/Friends), currently always null at every Restaurant/Hotel call
/// site: neither catalogue table carries a venue photo anywhere in this
/// app today (confirmed by a fresh, explicit re-audit of every model,
/// repository, migration and image-rendering call site — see this
/// feature's own architecture note). Passing a real URL later is the only
/// change needed to light up real photography here too, with zero changes
/// to this widget — the image frame and geometry are already built to
/// hold a photo, so the fallback monogram occupies exactly the same frame
/// a photo would rather than collapsing the layout around its absence.
class RankingEditorialCard extends StatelessWidget {
  final int rank;
  final String? imageUrl;
  final String title;
  final String subtitle;
  final Widget? recognition;
  final String scoreText;
  final String visitText;
  final VoidCallback onTap;

  const RankingEditorialCard({
    super.key,
    required this.rank,
    required this.imageUrl,
    required this.title,
    required this.subtitle,
    this.recognition,
    required this.scoreText,
    required this.visitText,
    required this.onTap,
  });

  // The image column reads as ~30-32% of the card's own width at typical
  // device widths (LayoutBuilder-driven, not a fixed px value, so the
  // ratio holds from 320px up) — clamped so it never collapses to
  // nothing on an extremely narrow card or balloons on a very wide one.
  static const double _imageWidthFraction = 0.31;
  static const double _minImageWidth = 88;
  static const double _maxImageWidth = 132;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: CsSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.ivory,
        borderRadius: BorderRadius.circular(CsRadius.card),
        border: Border.all(color: AppColors.subtleBorderLight, width: 0.5),
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final imageWidth = (constraints.maxWidth * _imageWidthFraction)
                  .clamp(_minImageWidth, _maxImageWidth);
              // A Stack, not IntrinsicHeight+stretch: the branded-monogram
              // fallback (CsImagePlaceholder) sizes its logo via its own
              // LayoutBuilder, and Flutter's intrinsic-dimension protocol
              // can't be run through a LayoutBuilder — IntrinsicHeight
              // would crash the moment a card falls back to the monogram.
              // A Stack sizes itself to its one non-positioned child (the
              // content row, its own natural height), then the Positioned
              // image simply stretches to match — same visual result,
              // without ever touching the intrinsics protocol.
              return Stack(
                children: [
                  Padding(
                    padding: EdgeInsets.only(left: imageWidth),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(
                        CsSpacing.base,
                        CsSpacing.base,
                        CsSpacing.sm,
                        CsSpacing.base,
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: _CardContent(
                              title: title,
                              subtitle: subtitle,
                              recognition: recognition,
                              scoreText: scoreText,
                              visitText: visitText,
                            ),
                          ),
                          const SizedBox(width: CsSpacing.sm),
                          const _ChevronAffordance(),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    left: 0,
                    top: 0,
                    bottom: 0,
                    width: imageWidth,
                    child: _RankedImage(rank: rank, imageUrl: imageUrl),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _CardContent extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget? recognition;
  final String scoreText;
  final String visitText;

  const _CardContent({
    required this.title,
    required this.subtitle,
    required this.recognition,
    required this.scoreText,
    required this.visitText,
  });

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      // Up to two lines — a long editorial name (e.g. "8 1/2 Otto e Mezzo –
      // Bombana") should wrap onto a second line rather than ellipsize
      // early; only a name that still doesn't fit in two lines truncates.
      // Unmodified CsTypography.placeTitle — its own default (charcoal) is
      // exactly the dark serif Passport's restaurant/hotel cards already
      // use for a name on an ivory surface; reusing the token as-is rather
      // than inventing a new dark shade for this card specifically.
      Text(
        title,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: CsTypography.placeTitle,
      ),
      const SizedBox(height: CsSpacing.xs),
      Row(
        children: [
          Flexible(
            child: Text(
              subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: CsTypography.metadata,
            ),
          ),
          if (recognition != null) ...[
            const SizedBox(width: CsSpacing.sm),
            recognition!,
          ],
        ],
      ),
      const SizedBox(height: CsSpacing.sm),
      // A short, restrained line — not a full-width rule splitting the
      // card in half — separating identity from the score line below it.
      Container(width: 32, height: 1, color: AppColors.subtleBorderLight),
      const SizedBox(height: CsSpacing.sm),
      Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          // Final Score Typography Correction: both the score and the
          // visit count now read as one compact metadata line at
          // CsTypography.metadata's own size (14px, Inter — not the serif
          // used for [title], since Cormorant Garamond's period glyph
          // reads too close to a comma at this size, "10.0" misreading as
          // "10,0"). The score is still the slightly heavier of the two
          // (w700 vs. the visit count's regular weight) — that's the only
          // remaining distinction; it no longer competes with the
          // restaurant/hotel name (22px) the way its previous 19px bold
          // treatment did. Formatting itself is untouched — still exactly
          // `entry.averageScore.toStringAsFixed(1)`.
          Text(
            scoreText,
            style: CsTypography.metadata.copyWith(
              color: AppColors.forestGreen,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: CsSpacing.xs),
          Flexible(
            child: Text(
              '· $visitText',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: CsTypography.metadata.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    ],
  );
}

/// The venue photo (or branded monogram fallback, in the exact same
/// frame) filling the card's full left edge — rounded to match the
/// card's own left corners, with the rank number overlaid top-left,
/// integrated directly onto the image rather than floating above a
/// separate placeholder column.
class _RankedImage extends StatelessWidget {
  final int rank;
  final String? imageUrl;
  const _RankedImage({required this.rank, required this.imageUrl});

  static const _leftCorners = BorderRadius.only(
    topLeft: Radius.circular(CsRadius.card),
    bottomLeft: Radius.circular(CsRadius.card),
  );

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: [
      VenueThumbnail(
        imageUrl: imageUrl,
        width: double.infinity,
        height: double.infinity,
        borderRadius: _leftCorners,
      ),
      Positioned(top: 8, left: 8, child: _RankBadge(rank: rank)),
    ],
  );
}

/// A compact rank chip attached to the image — ivory numeral on a
/// dark-green backing, bordered so it stays legible against a monogram
/// fallback of the same deep green. No "#" — the position on a ranked
/// list already reads as a rank without it.
class _RankBadge extends StatelessWidget {
  final int rank;
  const _RankBadge({required this.rank});

  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(minWidth: 22),
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(
      color: AppColors.deepGreen.withValues(alpha: 0.88),
      borderRadius: BorderRadius.circular(CsRadius.small),
      border: Border.all(color: AppColors.subtleBorderDark, width: 0.75),
    ),
    alignment: Alignment.center,
    child: Text(
      '$rank',
      style: GoogleFonts.inter(
        color: AppColors.ivory,
        fontSize: 12,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}

/// A restrained, low-contrast tap affordance on the ivory card — deep-
/// green icon, a barely-there outline, never a filled/gold button, and
/// never the visual anchor of the card (smaller and quieter than the
/// restaurant name or score next to it).
class _ChevronAffordance extends StatelessWidget {
  const _ChevronAffordance();

  @override
  Widget build(BuildContext context) => Container(
    width: 24,
    height: 24,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      border: Border.all(color: AppColors.subtleBorderLight),
    ),
    alignment: Alignment.center,
    child: const Icon(
      Icons.chevron_right_rounded,
      color: AppColors.forestGreen,
      size: 14,
    ),
  );
}
