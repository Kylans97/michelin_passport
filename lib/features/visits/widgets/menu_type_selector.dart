import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/app_colors.dart';
import '../../../models/visit.dart';

/// The optional menu-type choice on a restaurant visit: tasting menu, à la
/// carte, or both. Tap a selected chip again to clear it.
class MenuTypeSelector extends StatelessWidget {
  final MenuType? value;
  final ValueChanged<MenuType?> onChanged;
  const MenuTypeSelector({
    super.key,
    required this.value,
    required this.onChanged,
  });

  static String _labelFor(MenuType type) => switch (type) {
    MenuType.tastingMenu => 'Tasting menu',
    MenuType.aLaCarte => 'À la carte',
    MenuType.both => 'Both',
  };

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        for (final type in MenuType.values)
          _MenuTypeChip(
            label: _labelFor(type),
            selected: value == type,
            // Tap again to clear — menu type is optional.
            onTap: () => onChanged(value == type ? null : type),
          ),
      ],
    );
  }
}

class _MenuTypeChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _MenuTypeChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.transparent,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      splashColor: AppColors.forestGreen.withValues(alpha: 0.06),
      highlightColor: AppColors.forestGreen.withValues(alpha: 0.04),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.forestGreen.withValues(alpha: 0.12)
              : AppColors.surface,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: selected
                ? AppColors.forestGreen.withValues(alpha: 0.5)
                : AppColors.cardBorder,
            width: selected ? 1.0 : 0.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 150),
              child: selected
                  ? const Padding(
                      key: ValueKey('check'),
                      padding: EdgeInsets.only(right: 6),
                      child: Icon(
                        Icons.check_rounded,
                        size: 15,
                        color: AppColors.forestGreen,
                      ),
                    )
                  : const SizedBox(key: ValueKey('nocheck')),
            ),
            Text(
              label,
              style: GoogleFonts.inter(
                color: selected
                    ? AppColors.forestGreen
                    : AppColors.textSecondary,
                fontSize: 13,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
