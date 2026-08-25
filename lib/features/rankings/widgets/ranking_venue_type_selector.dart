import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/cs_spacing.dart';
import '../../../models/ranking_venue_type.dart';

/// "Restaurants / Hotels" segmented selector for My Rankings — deliberately
/// two options only (no "All"): a restaurant ranking and a hotel ranking
/// are separate contexts with different valid dimensions, unlike Explore/
/// Passport's combined browsing view.
///
/// PASSPORT — RANKING UI REDESIGN V1: restyled to the reference's wide,
/// pill-shaped control (replacing the previous gold-accented treatment
/// mirrored from Explore's VenueTypeSelector — gold is reserved for
/// Michelin star/Key recognition only, the same settled decision already
/// applied to Passport UI Polish V2). Color Hierarchy Correction pass:
/// this selector now lives on Ranking's deep-green canvas — selected =
/// ivory fill + deep-green label (unchanged), unselected = transparent
/// dark treatment + subtle outline + ivory label (was ivory fill +
/// deep-green label, correct only for the abandoned light-canvas
/// version). Mirrors [CsFilterChip]'s own `CsSurface.dark` selected/
/// unselected token pairing rather than inventing a new one. Same
/// [RankingVenueType] state and [onSelect] callback as before; only the
/// visuals changed.
class RankingVenueTypeSelector extends StatelessWidget {
  final RankingVenueType selected;
  final ValueChanged<RankingVenueType> onSelect;

  const RankingVenueTypeSelector({
    super.key,
    required this.selected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < RankingVenueType.values.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          Expanded(
            child: _Segment(
              label: RankingVenueType.values[i].label,
              selected: RankingVenueType.values[i] == selected,
              onTap: () => onSelect(RankingVenueType.values[i]),
            ),
          ),
        ],
      ],
    );
  }
}

class _Segment extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _Segment({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.transparent,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(CsRadius.pill),
      splashColor: AppColors.forestGreen.withValues(alpha: 0.08),
      highlightColor: AppColors.forestGreen.withValues(alpha: 0.06),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(vertical: 10),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? AppColors.ivory : Colors.transparent,
          borderRadius: BorderRadius.circular(CsRadius.pill),
          border: Border.all(
            color: selected ? AppColors.ivory : AppColors.subtleBorderDark,
            width: 0.75,
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.cormorantGaramond(
            color: selected ? AppColors.deepGreen : AppColors.textOnDark,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    ),
  );
}
