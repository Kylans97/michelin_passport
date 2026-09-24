import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../theme/cs_spacing.dart';
import '../theme/cs_surface_context.dart';
import '../theme/cs_typography.dart';

/// Magazine-pass sub-navigation: text labels only, 24pt gaps, a 1px gold
/// underline under the active label, one hairline under the whole row.
/// Replaces the pill-chip sub-nav (built on [CsFilterChip]) everywhere
/// this pass touches (Passport/Community/Events); [CsFilterChip] itself
/// is untouched and keeps serving screens not yet migrated.
///
/// Generic over [T] so one widget serves every sub-nav in this pass
/// (`PassportSubsection`, a Community tab enum, a date-range enum for
/// Events) without each screen re-implementing the same row/underline/
/// hairline shell — the same role [_PassportLocalTabBar] served alone
/// before this redesign.
///
/// [labelBuilder] must already return final display text (uppercase) —
/// this widget never transforms it, matching [CsTypography.eyebrow]'s
/// established "caller supplies final text" contract.
class CsEditorialTabs<T> extends StatelessWidget {
  final List<T> items;
  final T selected;
  final String Function(T item) labelBuilder;
  final ValueChanged<T> onSelect;
  final CsSurface surface;

  const CsEditorialTabs({
    super.key,
    required this.items,
    required this.selected,
    required this.labelBuilder,
    required this.onSelect,
    this.surface = CsSurface.dark,
  });

  @override
  Widget build(BuildContext context) {
    final onDark = surface == CsSurface.dark;
    final activeColor = onDark ? AppColors.textOnDark : AppColors.textPrimary;
    final inactiveColor = onDark
        ? AppColors.stone600OnGreen
        : AppColors.stone600OnPaper;
    final hairline = onDark
        ? AppColors.hairlineOnGreen
        : AppColors.hairlineOnPaper;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (var i = 0; i < items.length; i++) ...[
                if (i > 0) const SizedBox(width: 24),
                _EditorialTabItem(
                  label: labelBuilder(items[i]),
                  active: items[i] == selected,
                  activeColor: activeColor,
                  inactiveColor: inactiveColor,
                  onTap: () => onSelect(items[i]),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: CsSpacing.sm),
        Container(height: 1, color: hairline),
      ],
    );
  }
}

class _EditorialTabItem extends StatelessWidget {
  final String label;
  final bool active;
  final Color activeColor;
  final Color inactiveColor;
  final VoidCallback onTap;

  const _EditorialTabItem({
    required this.label,
    required this.active,
    required this.activeColor,
    required this.inactiveColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final style = CsTypography.editorialLabel().copyWith(
      color: active ? activeColor : inactiveColor,
    );
    // Measured directly via TextPainter rather than `IntrinsicWidth`:
    // confirmed visually that IntrinsicWidth sizes this particular
    // style (letter-spacing scaled per font size) a hair too narrow,
    // clipping the label's own last character even with no `overflow`
    // set at all — a genuine mismatch between IntrinsicWidth's layout
    // pass and this text's real rendered width, not just an ellipsis
    // interaction. Measuring directly is the single source of truth
    // both the label and its underline size against, so the two can
    // never disagree.
    final labelWidth =
        (TextPainter(
              text: TextSpan(text: label, style: style),
              textDirection: Directionality.of(context),
            )..layout())
            .width;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Text(label, softWrap: false, style: style),
            ),
            const SizedBox(height: 6),
            Container(
              width: labelWidth,
              height: 1,
              color: active ? AppColors.gold600 : Colors.transparent,
            ),
          ],
        ),
      ),
    );
  }
}
