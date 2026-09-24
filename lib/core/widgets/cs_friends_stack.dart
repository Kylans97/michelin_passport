import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../theme/cs_spacing.dart';
import '../theme/cs_typography.dart';

/// One person [FriendsStack] can show — a photo when available, initials
/// otherwise. [id] is what determines the deterministic fallback color
/// (see [FriendsStack]'s own doc) — a stable identifier (a user id), never
/// something display-derived that could collide or change.
class CsFriendAvatar {
  final String id;
  final String initials;
  final String? photoUrl;

  const CsFriendAvatar({required this.id, required this.initials, this.photoUrl});
}

/// A small, local, self-contained stable hash — deliberately NOT importing
/// passport_stamp_style.dart's `stampStableHash` (same FNV-1a algorithm):
/// that lives under `features/passport/`, and `core/widgets` reaching into
/// a feature would invert this codebase's layering. Short enough (and
/// generic enough — nothing passport-specific about hashing a string) that
/// duplicating it here is cheaper than a cross-cutting relocation this
/// task wasn't asked to do.
int _stableHash(String input) {
  const fnvPrime = 0x01000193;
  var hash = 0x811c9dc5;
  for (final unit in input.codeUnits) {
    hash ^= unit;
    hash = (hash * fnvPrime) & 0xFFFFFFFF;
  }
  return hash;
}

/// Overlapping round avatars ("Lotte & Daan going" / "2 friends going") —
/// the magazine pass's social-proof row, used wherever a list of friends
/// attending/interested/having-visited needs a compact face. Shows real
/// photos when available; falls back to initials on one of three
/// deterministic background colors (green-600/accent-700/stone-800, hashed
/// from [CsFriendAvatar.id] so the same person always gets the same
/// fallback color) so a list of several unphotographed friends still reads
/// as visually distinct people, not a wall of identical circles.
///
/// [label] is caller-composed (pluralization/naming varies too much by
/// context — "Lotte & Daan going" vs. "2 friends going" vs. "Going" — to
/// own here); this widget only lays out the avatar stack plus that text.
/// The visual stack caps at 3 avatars regardless of [friends.length] — the
/// label text is what communicates the true count beyond that.
class FriendsStack extends StatelessWidget {
  final List<CsFriendAvatar> friends;
  final String label;
  final double size;
  final Color ringColor;
  final Color labelColor;

  const FriendsStack({
    super.key,
    required this.friends,
    required this.label,
    this.size = 26,
    this.ringColor = AppColors.deepGreen,
    this.labelColor = AppColors.textOnDark,
  });

  static const _fallbackColors = [
    AppColors.green600,
    AppColors.accent700,
    AppColors.stone800,
  ];

  Color _colorFor(String id) =>
      _fallbackColors[_stableHash(id) % _fallbackColors.length];

  @override
  Widget build(BuildContext context) {
    final shown = friends.take(3).toList();
    const overlap = 8.0;

    return Semantics(
      label: label,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (shown.isNotEmpty)
            ExcludeSemantics(
              child: SizedBox(
                width: size + (shown.length - 1) * (size - overlap),
                height: size,
                child: Stack(
                  children: [
                    for (var i = 0; i < shown.length; i++)
                      Positioned(
                        left: i * (size - overlap),
                        child: _Avatar(
                          friend: shown[i],
                          size: size,
                          ringColor: ringColor,
                          color: _colorFor(shown[i].id),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          if (shown.isNotEmpty) const SizedBox(width: CsSpacing.sm),
          Flexible(
            child: ExcludeSemantics(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: CsTypography.editorialBody.copyWith(color: labelColor),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  final CsFriendAvatar friend;
  final double size;
  final Color ringColor;
  final Color color;

  const _Avatar({
    required this.friend,
    required this.size,
    required this.ringColor,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final photo = friend.photoUrl;
    return Container(
      width: size,
      height: size,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        border: Border.all(color: ringColor, width: 2),
      ),
      child: (photo != null && photo.isNotEmpty)
          ? Image.network(
              photo,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => _Initials(text: friend.initials, size: size),
            )
          : _Initials(text: friend.initials, size: size),
    );
  }
}

class _Initials extends StatelessWidget {
  final String text;
  final double size;
  const _Initials({required this.text, required this.size});

  @override
  Widget build(BuildContext context) => Center(
    child: Text(
      text,
      style: TextStyle(
        color: AppColors.textOnDark,
        fontWeight: FontWeight.w600,
        fontSize: size * 0.38,
      ),
    ),
  );
}
