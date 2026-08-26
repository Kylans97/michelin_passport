import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../theme/cs_typography.dart';

/// PROFILE UI REDESIGN V1 — the ONE canonical Chasing Stars member avatar.
/// Intended to become the single mechanism every member/social surface
/// (Profile, Friends, Community, Dining Together, Meet the Community)
/// renders a person's photo through — no screen should independently
/// construct a Storage URL or build its own initials-fallback circle.
/// This pass only wires it into Profile itself (avatar creation/editing);
/// adopting it in Friends/Community is explicitly future work, not part
/// of this change (see `docs/Architecture/PROFILE_AVATAR_V1.md`).
///
/// [avatarUrl] is a fully-resolved, already-signed display URL (never a
/// raw Storage path) — resolving that is the caller's job (see
/// `ProfileRepository.resolveAvatarUrl`), matching `PhotoRepository.
/// resolveDisplayUrls`' own established "resolve once, render everywhere"
/// convention. Null renders the initials fallback; a failed network load
/// also falls back to initials, never a broken-image icon.
///
/// [displayName] drives the initials fallback (never a raw username with
/// its leading "@") — same derivation every other identity circle in
/// this app already uses (`CommunityAvatarCircle`/`IdentityRow`'s own
/// `initialsFor`), duplicated here as a private helper since this widget
/// is meant to be importable without a feature-folder dependency in
/// either direction.
class MemberAvatar extends StatelessWidget {
  final String? avatarUrl;
  final String displayName;
  final double size;

  /// Optional edit affordance — a small pencil badge, shown only when
  /// non-null. Profile's own identity hero passes this; every future
  /// read-only consumer (Friends/Community) omits it.
  final VoidCallback? onEdit;

  const MemberAvatar({
    super.key,
    required this.avatarUrl,
    required this.displayName,
    this.size = 72,
    this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final url = avatarUrl;
    final initials = _initialsFor(displayName);

    final circle = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.brandGreenLight,
        border: Border.all(color: AppColors.subtleBorderDark),
      ),
      alignment: Alignment.center,
      child: (url != null && url.isNotEmpty)
          ? ClipOval(
              child: Image.network(
                url,
                width: size,
                height: size,
                fit: BoxFit.cover,
                loadingBuilder: (context, child, progress) =>
                    progress == null
                    ? child
                    : _Initials(initials: initials, size: size),
                errorBuilder: (_, _, _) =>
                    _Initials(initials: initials, size: size),
              ),
            )
          : _Initials(initials: initials, size: size),
    );

    final semantics = Semantics(
      image: true,
      label: '$displayName\'s profile photo',
      excludeSemantics: onEdit == null,
      child: circle,
    );

    if (onEdit == null) return semantics;

    return Semantics(
      button: true,
      label: 'Change profile photo',
      excludeSemantics: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onEdit,
          customBorder: const CircleBorder(),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              semantics,
              Positioned(
                right: -2,
                bottom: -2,
                child: Container(
                  width: size * 0.32,
                  height: size * 0.32,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.forestGreen,
                    border: Border.all(
                      color: AppColors.deepGreen,
                      width: 2,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    Icons.edit_outlined,
                    color: AppColors.ivory,
                    size: size * 0.16,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Initials extends StatelessWidget {
  final String initials;
  final double size;
  const _Initials({required this.initials, required this.size});

  @override
  Widget build(BuildContext context) => Text(
    initials,
    style: CsTypography.placeTitle.copyWith(
      color: AppColors.ivory,
      fontSize: size * 0.32,
    ),
  );
}

/// "AB" from "Ada Boone" or "@adaboone" — identical derivation to
/// `CommunityAvatarCircle`'s own `initialsFor` (`community_shared.dart`),
/// duplicated intentionally rather than imported across an unrelated
/// feature folder for a two-line pure function; both must stay in sync
/// if the rule ever changes.
String _initialsFor(String label) {
  final source = label.startsWith('@') ? label.substring(1) : label;
  final words = source.trim().split(' ').where((w) => w.isNotEmpty);
  if (words.isEmpty) return '?';
  return words.map((w) => w[0]).take(2).join().toUpperCase();
}
