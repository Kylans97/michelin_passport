import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/venue_country.dart';
import 'country_picker_sheet.dart';
import '../constants/app_colors.dart';

/// Compact "Country ▾" / "Netherlands ▾" trigger that opens the existing
/// searchable country picker sheet on tap — replaces a persistent
/// horizontally-scrolling country chip row (Explore's old country row,
/// Events' country chip mixed into its date-chip row) with one small
/// control, mirroring YearFilterControl's "collapsed until tapped"
/// affordance. Filtering semantics are unchanged underneath: [selected]
/// null means "All countries", and [onChanged] receives the picked
/// country's code or null for "All countries" — exactly what the old chip
/// row already passed through.
class CountryFilterControl extends StatelessWidget {
  final VenueCountry? selected;
  final List<VenueCountry> countries;
  final ValueChanged<VenueCountry?> onChanged;

  const CountryFilterControl({
    super.key,
    required this.selected,
    required this.countries,
    required this.onChanged,
  });

  Future<void> _open(BuildContext context) async {
    final picked = await showCountryPickerSheet(
      context,
      countries: countries,
      allowAll: true,
    );
    // showCountryPickerSheet returns null both for "All countries" and for
    // "dismissed without choosing" — both already mean "no change from
    // whatever's currently selected" is wrong when a country WAS already
    // selected, so only the sheet's own explicit selection should update
    // state. It has no way to distinguish the two today, so — same as the
    // established EventFilterBar._pickCountry behavior this replaces —
    // dismiss and "All countries" are treated the same, deliberately.
    onChanged(picked);
  }

  @override
  Widget build(BuildContext context) {
    final label = selected == null ? 'All countries' : selected!.name;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _open(context),
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.cardBorder, width: 0.5),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.public_rounded,
                size: 15,
                color: selected == null
                    ? AppColors.textSecondary
                    : AppColors.gold,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: GoogleFonts.inter(
                  color: selected == null
                      ? AppColors.textPrimary
                      : AppColors.gold,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 2),
              Icon(
                Icons.arrow_drop_down_rounded,
                color: selected == null
                    ? AppColors.textSecondary
                    : AppColors.gold,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
