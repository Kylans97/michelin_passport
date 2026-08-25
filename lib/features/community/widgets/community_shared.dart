import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/cs_spacing.dart';
import '../../../core/theme/cs_typography.dart';

/// COMMUNITY & FRIENDS FOUNDATION V1 — the shared editorial section-title
/// style every major Community/Friends section uses, promoted from
/// `CommunityScreen`'s own previous private `_sectionTitle` (Community
/// Typography + Dining Together Refinement's own deliberate choice: a
/// proper serif heading, clearly smaller than the page title and clearly
/// larger than its own description/content below it — NOT a
/// tracked-uppercase eyebrow, which an earlier pass tried and reverted).
/// Reused here rather than reinvented so every new section (Community
/// Ranking, Trending Now, Upcoming Events, Recently Discovered, Your
/// Circle, Friends' Activity, Friends' Top Visited) reads as part of the
/// same page, not a bolted-on redesign.
class CommunitySectionTitle extends StatelessWidget {
  final String label;
  const CommunitySectionTitle(this.label, {super.key});

  @override
  Widget build(BuildContext context) =>
      Text(label, style: CsTypography.placeTitle.copyWith(color: AppColors.ivory));
}

/// The shared restrained "Label →" action link — promoted from
/// `CommunityScreen`'s own previous private `_CommunityActionLink`.
/// Deliberately secondary to [CommunitySectionTitle] (smaller type, no
/// card/row chrome). Ivory on the deep-green canvas by default; pass
/// [light]: true for the same link sitting inside a [CommunityIvoryCard]
/// instead, where forestGreen (this app's established "actionable ink on
/// ivory" color — see IdentityRow/AddFriendScreen) reads correctly against
/// the ivory background. Never gold either way — gold stays reserved for
/// Michelin stars/Keys.
class CommunityActionLink extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final bool light;

  const CommunityActionLink({
    super.key,
    required this.label,
    required this.onTap,
    this.light = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = light ? AppColors.forestGreen : AppColors.ivory;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Flexible, not a bare Text: a Row's non-flex children get
              // unbounded main-axis constraints to measure their own
              // natural single-line width, so an unwrapped Text here would
              // overflow (never wrap) at narrow widths.
              Flexible(
                child: Text(
                  label,
                  style: CsTypography.bodyMedium.copyWith(color: color),
                ),
              ),
              const SizedBox(width: 6),
              Icon(Icons.arrow_forward_rounded, color: color, size: 16),
            ],
          ),
        ),
      ),
    );
  }
}

/// COMMUNITY V1 UI REFINEMENT — the one shared "important content surface"
/// card: ivory background, deep-green-family ink, used deliberately and
/// selectively (Community Ranking's feature card, Your Circle's
/// zero-state onboarding card, Find Friends' result cards) rather than as
/// a general background — the deep-green canvas around it stays the
/// dominant page surface. Same corner-radius/border language as every
/// other card in the app ([CsRadius.card], [AppColors.subtleBorderLight]).
class CommunityIvoryCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  const CommunityIvoryCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(CsSpacing.cardPadding),
  });

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: padding,
    decoration: BoxDecoration(
      color: AppColors.ivory,
      borderRadius: BorderRadius.circular(CsRadius.card),
      border: Border.all(color: AppColors.subtleBorderLight),
    ),
    child: child,
  );
}

/// COMMUNITY & FRIENDS FOUNDATION V1 — the one shared, restrained
/// empty-state shape for every section that has no real data to show yet
/// (Community Ranking with zero qualifying restaurants, Trending Now,
/// Upcoming Events with none scheduled, Recently Discovered, Friends'
/// Activity, Friends' Top Visited, Your Circle). Deliberately NOT a card,
/// NOT an illustration, NOT a "Coming soon" block — a single restrained
/// line (plus an optional two-tier title+message and an optional action)
/// directly on the deep-green canvas, so four-plus empty sections on one
/// page never read as four-plus repeated dashboard-empty-card widgets.
class CommunityEmptyNote extends StatelessWidget {
  /// A short headline above [message] — used only where the copy genuinely
  /// needs two tiers (e.g. Your Circle's "Your circle is still empty.").
  /// Omitted entirely (message renders alone) for every single-line case.
  final String? title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  const CommunityEmptyNote({
    super.key,
    this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      if (title != null) ...[
        Text(
          title!,
          style: CsTypography.bodyMedium.copyWith(color: AppColors.ivory),
        ),
        const SizedBox(height: CsSpacing.xs),
      ],
      Text(
        message,
        style: CsTypography.body.copyWith(color: AppColors.secondaryOnDark),
      ),
      if (actionLabel != null && onAction != null) ...[
        const SizedBox(height: CsSpacing.sm),
        CommunityActionLink(label: actionLabel!, onTap: onAction!),
      ],
    ],
  );
}

/// A dark-canvas avatar circle — mirrors Profile's own `_Avatar` gold-audit
/// treatment (`brandGreenLight` fill, `subtleBorderDark` hairline, ivory
/// initials/photo) rather than [IdentityRow]'s light-surface avatar, since
/// this renders directly on Community's deep-green canvas, not an ivory
/// body.
class CommunityAvatarCircle extends StatelessWidget {
  final String initials;
  final String? avatarUrl;
  final double size;

  const CommunityAvatarCircle({
    super.key,
    required this.initials,
    this.avatarUrl,
    this.size = 56,
  });

  @override
  Widget build(BuildContext context) {
    final url = avatarUrl;
    return Container(
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
                errorBuilder: (_, _, _) => _Initials(initials),
              ),
            )
          : _Initials(initials),
    );
  }
}

class _Initials extends StatelessWidget {
  final String initials;
  const _Initials(this.initials);

  @override
  Widget build(BuildContext context) => Text(
    initials,
    style: CsTypography.bodyMedium.copyWith(color: AppColors.ivory),
  );
}

/// "AB" from "Ada Boone" or "@adaboone" — the exact same derivation
/// [IdentityRow] already uses, extracted here so [CommunityAvatarCircle]
/// callers don't have to duplicate it.
String initialsFor(String label) {
  final source = label.startsWith('@') ? label.substring(1) : label;
  final words = source.trim().split(' ').where((w) => w.isNotEmpty);
  if (words.isEmpty) return '?';
  return words.map((w) => w[0]).take(2).join().toUpperCase();
}
