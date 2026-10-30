import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../theme/cs_spacing.dart';
import '../theme/cs_typography.dart';

/// The venue's own pages on the guides that recognise it — MICHELIN
/// Guide, World's 50 Best, Gault&Millau — as quiet text links beside
/// "Award history" on Restaurant and Hotel Detail.
///
/// They used to sit in VenueUtilityActions' icon row, which on a venue
/// like De Librije grew to six actions side by side. That row now holds
/// only the practical ones (Directions · Website · Call); these are
/// background on the awards, so they live with the awards instead.
///
/// Each link is shown only when its URL is real, as before — never a dead
/// link. Renders nothing when none is available. The north-east arrow
/// marks them as leaving the app, distinct from Award history's chevron
/// (which pushes an in-app screen). Forest-green, never gold.
class VenueGuideLinks extends StatelessWidget {
  final VoidCallback? onOpenMichelin;
  final VoidCallback? onOpenWorlds50Best;
  final VoidCallback? onOpenGaultMillau;

  const VenueGuideLinks({
    super.key,
    this.onOpenMichelin,
    this.onOpenWorlds50Best,
    this.onOpenGaultMillau,
  });

  bool get hasAny =>
      onOpenMichelin != null ||
      onOpenWorlds50Best != null ||
      onOpenGaultMillau != null;

  @override
  Widget build(BuildContext context) {
    final links = [
      if (onOpenMichelin != null)
        _GuideLink(label: 'MICHELIN Guide', onTap: onOpenMichelin!),
      if (onOpenWorlds50Best != null)
        _GuideLink(label: "World's 50 Best", onTap: onOpenWorlds50Best!),
      if (onOpenGaultMillau != null)
        _GuideLink(label: 'Gault&Millau', onTap: onOpenGaultMillau!),
    ];
    if (links.isEmpty) return const SizedBox.shrink();
    return Wrap(spacing: CsSpacing.md, children: links);
  }
}

class _GuideLink extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _GuideLink({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.transparent,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      splashColor: AppColors.forestGreen.withValues(alpha: 0.08),
      highlightColor: AppColors.forestGreen.withValues(alpha: 0.08),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: CsTypography.smallLabel.copyWith(
                color: AppColors.forestGreen,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(
              Icons.north_east_rounded,
              color: AppColors.forestGreen,
              size: 13,
            ),
          ],
        ),
      ),
    ),
  );
}
