import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/cs_spacing.dart';
import '../../../core/theme/cs_typography.dart';
import '../../../core/widgets/cs_editorial_glyphs.dart';
import '../../../models/passport_venue.dart';

/// Photo, or an initial in Cormorant italic — this screen's own small
/// identity component (distinct from [FriendsStack]'s multi-avatar
/// stack). One 1px gold ring, plus a second thin outline ring 4pt further
/// out — the "gouden rand... en daaromheen een tweede dunne outline"
/// treatment layout A's header asks for.
class FriendProfileAvatar extends StatelessWidget {
  final String? photoUrl;
  final String label;
  final double size;
  final bool doubleRing;

  const FriendProfileAvatar({
    super.key,
    required this.photoUrl,
    required this.label,
    this.size = 84,
    this.doubleRing = true,
  });

  String get _initial {
    final trimmed = label.trim();
    return trimmed.isEmpty ? '?' : trimmed[0].toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final photo = photoUrl;
    final core = Container(
      width: size,
      height: size,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.green800,
        border: Border.all(color: AppColors.gold600, width: 1),
      ),
      child: (photo != null && photo.isNotEmpty)
          ? Image.network(
              photo,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => _InitialGlyph(text: _initial, size: size),
            )
          : _InitialGlyph(text: _initial, size: size),
    );

    if (!doubleRing) return core;
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.gold600.withValues(alpha: 0.4), width: 1),
      ),
      child: core,
    );
  }
}

class _InitialGlyph extends StatelessWidget {
  final String text;
  final double size;
  const _InitialGlyph({required this.text, required this.size});

  @override
  Widget build(BuildContext context) => Center(
    child: Text(
      text,
      style: CsTypography.editorialTitle(
        size: size * 0.4,
        italic: true,
      ).copyWith(color: AppColors.gold300),
    ),
  );
}

/// One column of [FriendProfileStatsRow].
class FriendProfileStat {
  final String value;
  final String label;
  final bool gold;
  const FriendProfileStat({
    required this.value,
    required this.label,
    this.gold = false,
  });
}

/// Columns separated by vertical hairlines, with a hairline above and
/// below the whole row — the "Stamps / Countries / Stars" stats block
/// every one of the three friend-profile layouts uses. Dual-surface aware
/// ([onDark]) since layout C sits on paper, not green.
class FriendProfileStatsRow extends StatelessWidget {
  final List<FriendProfileStat> stats;
  final bool onDark;

  const FriendProfileStatsRow({
    super.key,
    required this.stats,
    this.onDark = true,
  });

  @override
  Widget build(BuildContext context) {
    final hairline = onDark ? AppColors.hairlineOnGreen : AppColors.hairlineOnPaper;
    final valueColor = onDark ? AppColors.textOnDark : AppColors.textPrimary;
    final labelColor = onDark ? AppColors.stone600OnGreen : AppColors.stone600OnPaper;

    return Column(
      children: [
        Container(height: 1, color: hairline),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: CsSpacing.md),
          child: Row(
            children: [
              for (var i = 0; i < stats.length; i++) ...[
                if (i > 0)
                  Container(
                    width: 1,
                    height: 32,
                    margin: const EdgeInsets.symmetric(horizontal: CsSpacing.md),
                    color: hairline,
                  ),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        stats[i].value,
                        style: CsTypography.editorialTitle(size: 26).copyWith(
                          color: stats[i].gold ? AppColors.gold600 : valueColor,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        stats[i].label,
                        style: CsTypography.editorialLabel().copyWith(color: labelColor),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        Container(height: 1, color: hairline),
      ],
    );
  }
}

/// A photo, or a tile-green fallback with a 1px gold border and the
/// venue's own initial in Cormorant italic gold — this screen's own
/// photo fallback (mirrors [CsEditorialImageFallback]'s "never the old M
/// placeholder" rule, sized/shaped for this screen's own rows rather than
/// imported wholesale, per the brief's own component list).
class PhotoOrTile extends StatelessWidget {
  final String? photoUrl;
  final String venueName;
  final double? width;
  final double? height;
  final BorderRadius borderRadius;

  const PhotoOrTile({
    super.key,
    required this.photoUrl,
    required this.venueName,
    this.width,
    this.height,
    this.borderRadius = const BorderRadius.all(Radius.circular(2)),
  });

  @override
  Widget build(BuildContext context) {
    final photo = photoUrl;
    return ClipRRect(
      borderRadius: borderRadius,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: AppColors.green800,
          border: Border.all(color: AppColors.gold600, width: 1),
        ),
        child: (photo != null && photo.isNotEmpty)
            ? Image.network(
                photo,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => _TileInitial(venueName: venueName),
              )
            : _TileInitial(venueName: venueName),
      ),
    );
  }
}

class _TileInitial extends StatelessWidget {
  final String venueName;
  const _TileInitial({required this.venueName});

  @override
  Widget build(BuildContext context) {
    final trimmed = venueName.trim();
    final initial = trimmed.isEmpty ? '?' : trimmed[0].toUpperCase();
    return Center(
      child: Text(
        initial,
        style: CsTypography.editorialTitle(size: 24, italic: true).copyWith(
          color: AppColors.gold300,
        ),
      ),
    );
  }
}

/// One wishlist row: name + stars/Keys, "City · CC" — a hairline above,
/// an optional gold "YOU TOO" pill on the right when [sharedWithViewer].
class WishlistRow extends StatelessWidget {
  final PassportVenue venue;
  final bool sharedWithViewer;
  final VoidCallback onTap;

  const WishlistRow({
    super.key,
    required this.venue,
    required this.sharedWithViewer,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final (cityName, award) = switch (venue) {
      RestaurantVenue(:final restaurant) => (
        restaurant.cityName,
        restaurant.hasMichelinStar
            ? CsEditorialStarRow(count: restaurant.michelinStars!)
            : null,
      ),
      HotelVenue(:final hotel) => (
        hotel.cityName,
        hotel.hasMichelinKeys
            ? CsEditorialKeyRow(count: hotel.michelinKeys!)
            : null,
      ),
    };

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(height: 1, color: AppColors.hairlineOnPaper),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: CsSpacing.sm),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          venue.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: CsTypography.editorialTitle(
                            size: 21,
                          ).copyWith(color: AppColors.textPrimary),
                        ),
                        const SizedBox(height: 2),
                        if (award != null) ...[award, const SizedBox(height: 2)],
                        CsCountryLabel(
                          cityName: cityName,
                          countryCode: venue.countryCode,
                          style: CsTypography.editorialBody.copyWith(
                            color: AppColors.taupe,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (sharedWithViewer) ...[
                    const SizedBox(width: CsSpacing.sm),
                    const _YouTooLabel(),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _YouTooLabel extends StatelessWidget {
  const _YouTooLabel();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: AppColors.gold600,
      borderRadius: BorderRadius.circular(3),
    ),
    child: Text(
      'YOU TOO',
      style: CsTypography.editorialLabel(size: 9).copyWith(
        color: AppColors.forestGreen,
      ),
    ),
  );
}
