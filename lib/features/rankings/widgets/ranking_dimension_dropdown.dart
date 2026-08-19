import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/cs_spacing.dart';
import '../../../core/theme/cs_typography.dart';
import '../../../models/ranking_dimension.dart';

/// Compact "Overall ▾" trigger + bottom-sheet picker for My Rankings' rating
/// -dimension selector — UI Consistency pass replacement for the old
/// horizontal `DimensionFilterBar` chip row, sized and shaped to sit on one
/// row next to [YearFilterControl] ("Overall ▾  All time ▾").
///
/// Deliberately its own small widget rather than a reuse of
/// `YearFilterControl` (same trigger-then-sheet shape, mirrored on purpose
/// for visual consistency): that widget is also shared by Passport, which
/// this pass does not touch, and its picker sheet's selected-row styling is
/// gold — this pass removes decorative gold from Rankings' own controls,
/// which would have silently reskinned Passport's year picker too if done
/// by editing the shared file instead of building a parallel component.
class RankingDimensionDropdown extends StatelessWidget {
  final List<RankingDimension> dimensions;
  final RankingDimension selected;
  final ValueChanged<RankingDimension> onSelect;

  const RankingDimensionDropdown({
    super.key,
    required this.dimensions,
    required this.selected,
    required this.onSelect,
  });

  Future<void> _open(BuildContext context) async {
    final picked = await showModalBottomSheet<RankingDimension>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) =>
          _DimensionPickerSheet(dimensions: dimensions, selected: selected),
    );
    if (picked != null) onSelect(picked);
  }

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.transparent,
    child: InkWell(
      onTap: () => _open(context),
      borderRadius: BorderRadius.circular(CsRadius.pill),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: CsSpacing.md,
          vertical: CsSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(CsRadius.pill),
          border: Border.all(color: AppColors.cardBorder, width: 0.5),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              selected.label,
              style: CsTypography.smallLabel.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 2),
            const Icon(
              Icons.arrow_drop_down_rounded,
              color: AppColors.textSecondary,
              size: 20,
            ),
          ],
        ),
      ),
    ),
  );
}

class _DimensionPickerSheet extends StatelessWidget {
  final List<RankingDimension> dimensions;
  final RankingDimension selected;

  const _DimensionPickerSheet({
    required this.dimensions,
    required this.selected,
  });

  @override
  Widget build(BuildContext context) => SafeArea(
    top: false,
    child: ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.75,
      ),
      // Material, not a plain decorated Container: ListTile paints its
      // ink splashes on its nearest Material ancestor, and a Container's
      // own BoxDecoration background isn't one — without this, tapping a
      // row throws "ListTile background color or ink splashes may be
      // invisible" (a real Flutter framework assertion, not just a test
      // artifact).
      child: Material(
        color: AppColors.card,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(CsRadius.large),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: CsSpacing.md),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: CsSpacing.sm),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(
                  CsSpacing.md,
                  CsSpacing.sm,
                  CsSpacing.md,
                  CsSpacing.xl,
                ),
                itemCount: dimensions.length,
                itemBuilder: (context, i) {
                  final dimension = dimensions[i];
                  final isSelected = dimension == selected;
                  return ListTile(
                    onTap: () => Navigator.pop(context, dimension),
                    title: Text(
                      dimension.label,
                      style: CsTypography.body.copyWith(
                        color: isSelected
                            ? AppColors.forestGreen
                            : AppColors.textPrimary,
                        fontWeight: isSelected
                            ? FontWeight.w700
                            : FontWeight.w500,
                      ),
                    ),
                    trailing: isSelected
                        ? const Icon(
                            Icons.check_rounded,
                            color: AppColors.forestGreen,
                          )
                        : null,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
