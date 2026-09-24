import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/cs_spacing.dart';
import '../../../core/theme/cs_typography.dart';

/// Photo, or an initial in Cormorant — this screen's own small identity
/// component (distinct from [FriendsStack]'s multi-avatar stack).
/// [fallbackBackground]/[fallbackTextColor] are exposed rather than fixed
/// because the header needs two different fallback treatments side by
/// side (the friend "op ivoor met ink-green", the viewer "op donker
/// goud") — a single hardcoded pair would only ever fit one of the two.
class FriendProfileAvatar extends StatelessWidget {
  final String? photoUrl;
  final String label;
  final double size;
  final Color ringColor;
  final Color fallbackBackground;
  final Color fallbackTextColor;
  final bool italic;

  const FriendProfileAvatar({
    super.key,
    required this.photoUrl,
    required this.label,
    this.size = 84,
    this.ringColor = AppColors.gold600,
    this.fallbackBackground = AppColors.green800,
    this.fallbackTextColor = AppColors.textOnDark,
    this.italic = true,
  });

  String get _initial {
    final trimmed = label.trim();
    return trimmed.isEmpty ? '?' : trimmed[0].toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final photo = photoUrl;
    return Container(
      width: size,
      height: size,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: fallbackBackground,
        border: Border.all(color: ringColor, width: 1),
      ),
      child: (photo != null && photo.isNotEmpty)
          ? Image.network(
              photo,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => _InitialGlyph(
                text: _initial,
                size: size,
                color: fallbackTextColor,
                italic: italic,
              ),
            )
          : _InitialGlyph(
              text: _initial,
              size: size,
              color: fallbackTextColor,
              italic: italic,
            ),
    );
  }
}

class _InitialGlyph extends StatelessWidget {
  final String text;
  final double size;
  final Color color;
  final bool italic;
  const _InitialGlyph({
    required this.text,
    required this.size,
    required this.color,
    required this.italic,
  });

  @override
  Widget build(BuildContext context) => Center(
    child: Text(
      text,
      style: CsTypography.editorialTitle(
        size: size * 0.4,
        italic: italic,
      ).copyWith(color: color),
    ),
  );
}

/// One column of [FriendProfileStatsRow]. No gold variant — this
/// redesign's own rule is "no gold text, ever"; every numeral here is
/// plain ivory/ink regardless of which stat it is.
class FriendProfileStat {
  final String value;
  final String label;
  const FriendProfileStat({required this.value, required this.label});
}

/// Columns separated by vertical hairlines, with a hairline above and
/// below the whole row — the "Stamps / Countries / Avg. score" stats
/// block. Dual-surface aware ([onDark]) even though every current call
/// site is on the green canvas, matching this codebase's established
/// pattern for anything that might reasonably sit on paper later.
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
                        style: CsTypography.editorialTitle(
                          size: 26,
                        ).copyWith(color: valueColor),
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

/// A photo, or a dark-green fallback tile with a 1px gold border and the
/// venue's own initial in Cormorant italic ivory (never gold — that would
/// be gold TEXT, which this redesign forbids; the border is ornament, the
/// initial is text) — this screen's own photo fallback, never the old "M"
/// placeholder.
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
          color: AppColors.textOnDark,
        ),
      ),
    );
  }
}

/// A small round photo-or-initial thumbnail — Overview's "N in common"
/// bar uses two of these, overlapped. Distinct from [FriendProfileAvatar]
/// (round but venue-flavoured, not person-flavoured) and from
/// [PhotoOrTile] (round, not the squared-off venue-row tile).
class RoundVenueThumbnail extends StatelessWidget {
  final String? photoUrl;
  final String venueName;
  final double size;

  const RoundVenueThumbnail({
    super.key,
    required this.photoUrl,
    required this.venueName,
    this.size = 34,
  });

  @override
  Widget build(BuildContext context) {
    final photo = photoUrl;
    final trimmed = venueName.trim();
    final initial = trimmed.isEmpty ? '?' : trimmed[0].toUpperCase();
    return Container(
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
              errorBuilder: (_, _, _) => Center(
                child: Text(
                  initial,
                  style: CsTypography.editorialTitle(
                    size: size * 0.42,
                    italic: true,
                  ).copyWith(color: AppColors.textOnDark),
                ),
              ),
            )
          : Center(
              child: Text(
                initial,
                style: CsTypography.editorialTitle(
                  size: size * 0.42,
                  italic: true,
                ).copyWith(color: AppColors.textOnDark),
              ),
            ),
    );
  }
}
