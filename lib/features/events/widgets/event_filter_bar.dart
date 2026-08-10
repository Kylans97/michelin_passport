import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/country_picker_sheet.dart';
import '../../../models/venue_country.dart';
import '../models/event_date_filter.dart';

const _monthNames = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

/// Events' filter stack: date-mode chips (Upcoming / This week / Month /
/// Custom range) plus a country picker. Deliberately no city filter
/// surfaced yet — the data model already carries city (see Event/events
/// table), but with only a handful of events live, a city filter would be
/// empty chrome; it can appear here later without any data change.
class EventFilterBar extends StatelessWidget {
  final EventDateFilter dateFilter;
  final ValueChanged<EventDateFilter> onDateFilterChanged;
  final VenueCountry? country;
  final List<VenueCountry> countries;
  final ValueChanged<VenueCountry?> onCountryChanged;

  const EventFilterBar({
    super.key,
    required this.dateFilter,
    required this.onDateFilterChanged,
    required this.country,
    required this.countries,
    required this.onCountryChanged,
  });

  Future<void> _pickCustomRange(BuildContext context) async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 3),
      initialDateRange: dateFilter.customRange,
    );
    if (picked != null) {
      onDateFilterChanged(
        dateFilter.copyWith(
          mode: EventDateFilterMode.custom,
          customRange: picked,
        ),
      );
    }
  }

  Future<void> _pickCountry(BuildContext context) async {
    final picked = await showCountryPickerSheet(
      context,
      countries: countries,
      allowAll: true,
    );
    // showCountryPickerSheet returns null both for "All countries" and for
    // "dismissed without choosing" — both mean "no country filter", which
    // is exactly the state onCountryChanged(null) already represents, so
    // treating them the same is correct here, not a lost distinction.
    onCountryChanged(picked);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _Chip(
                label: 'Upcoming',
                selected: dateFilter.mode == EventDateFilterMode.upcoming,
                onTap: () => onDateFilterChanged(
                  dateFilter.copyWith(mode: EventDateFilterMode.upcoming),
                ),
              ),
              const SizedBox(width: 8),
              _Chip(
                label: 'This week',
                selected: dateFilter.mode == EventDateFilterMode.thisWeek,
                onTap: () => onDateFilterChanged(
                  dateFilter.copyWith(mode: EventDateFilterMode.thisWeek),
                ),
              ),
              const SizedBox(width: 8),
              _Chip(
                label: 'Month',
                selected: dateFilter.mode == EventDateFilterMode.month,
                onTap: () => onDateFilterChanged(
                  dateFilter.copyWith(mode: EventDateFilterMode.month),
                ),
              ),
              const SizedBox(width: 8),
              _Chip(
                label:
                    dateFilter.mode == EventDateFilterMode.custom &&
                        dateFilter.customRange != null
                    ? 'Custom range'
                    : 'Pick dates…',
                selected: dateFilter.mode == EventDateFilterMode.custom,
                onTap: () => _pickCustomRange(context),
              ),
              const SizedBox(width: 8),
              _Chip(
                label: country == null ? 'All countries' : country!.name,
                icon: Icons.public_rounded,
                selected: country != null,
                onTap: () => _pickCountry(context),
              ),
            ],
          ),
        ),
        if (dateFilter.mode == EventDateFilterMode.month) ...[
          const SizedBox(height: 10),
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left_rounded),
                color: AppColors.textSecondary,
                onPressed: () => onDateFilterChanged(
                  dateFilter.copyWith(
                    monthAnchor: DateTime(
                      dateFilter.monthAnchor.year,
                      dateFilter.monthAnchor.month - 1,
                    ),
                  ),
                ),
              ),
              Text(
                '${_monthNames[dateFilter.monthAnchor.month - 1]} '
                '${dateFilter.monthAnchor.year}',
                style: GoogleFonts.inter(
                  color: AppColors.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right_rounded),
                color: AppColors.textSecondary,
                onPressed: () => onDateFilterChanged(
                  dateFilter.copyWith(
                    monthAnchor: DateTime(
                      dateFilter.monthAnchor.year,
                      dateFilter.monthAnchor.month + 1,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final IconData? icon;
  final bool selected;
  final VoidCallback onTap;
  const _Chip({
    required this.label,
    this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: selected
            ? AppColors.brandGreen.withValues(alpha: 0.08)
            : AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: selected
              ? AppColors.brandGreen.withValues(alpha: 0.4)
              : AppColors.cardBorder,
          width: selected ? 1.0 : 0.5,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(
              icon,
              size: 14,
              color: selected ? AppColors.brandGreen : AppColors.textSecondary,
            ),
            const SizedBox(width: 6),
          ],
          Text(
            label,
            style: GoogleFonts.inter(
              color: selected ? AppColors.brandGreen : AppColors.textSecondary,
              fontSize: 12.5,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ],
      ),
    ),
  );
}
