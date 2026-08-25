import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/cs_spacing.dart';
import '../../../core/theme/cs_typography.dart';

/// COMMUNITY & FRIENDS FOUNDATION V1 — the two top-level tabs inside the
/// Community bottom-nav destination. Community remains the selected
/// bottom-nav item for both; switching between them never pushes a new
/// route or leaves this screen, exactly like Passport's own
/// PASSPORT/WISHLIST/RANKING/TRIPS local subsections.
enum CommunityTopTab { community, friends }

/// The same understated local-tab-bar language `_PassportLocalTabBar`
/// already established for Passport's own four subsections — active tab
/// ivory + bold with a thin ivory underline, inactive muted
/// (`secondaryOnDark`), a faint full-width divider beneath the whole row,
/// no pills, no filled buttons. Reused here rather than reinvented so
/// switching Community ↔ Friends reads as the same established pattern a
/// user already knows from Passport.
class CommunityLocalTabBar extends StatelessWidget {
  final CommunityTopTab selected;
  final ValueChanged<CommunityTopTab> onSelect;

  const CommunityLocalTabBar({
    super.key,
    required this.selected,
    required this.onSelect,
  });

  static const _labels = {
    CommunityTopTab.community: 'Community',
    CommunityTopTab.friends: 'Friends',
  };

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          for (final tab in CommunityTopTab.values) ...[
            if (tab != CommunityTopTab.values.first)
              const SizedBox(width: CsSpacing.xl),
            _LocalTabItem(
              label: _labels[tab]!,
              active: tab == selected,
              onTap: () => onSelect(tab),
            ),
          ],
        ],
      ),
      const SizedBox(height: CsSpacing.sm),
      Container(height: 1, color: AppColors.subtleBorderDark),
    ],
  );
}

class _LocalTabItem extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _LocalTabItem({
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.transparent,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: IntrinsicWidth(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Text(
                label.toUpperCase(),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: CsTypography.navigation.copyWith(
                  fontSize: 13,
                  letterSpacing: 0,
                  color: active ? AppColors.ivory : AppColors.secondaryOnDark,
                  fontWeight: active ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(height: 6),
            Container(
              height: 2,
              color: active ? AppColors.ivory : Colors.transparent,
            ),
          ],
        ),
      ),
    ),
  );
}
