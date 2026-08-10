import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/venue_country.dart';
import '../constants/app_colors.dart';

/// A searchable country picker bottom sheet, shared by trip creation and
/// Events' country filter rather than duplicated per call site. Pass
/// [allowAll] to prepend an "All countries" option (returns null) — used
/// by filters, never by trip creation, which always needs one specific
/// country.
Future<VenueCountry?> showCountryPickerSheet(
  BuildContext context, {
  required List<VenueCountry> countries,
  bool allowAll = false,
}) {
  return showModalBottomSheet<VenueCountry>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) =>
        _CountryPickerSheet(countries: countries, allowAll: allowAll),
  );
}

class _CountryPickerSheet extends StatefulWidget {
  final List<VenueCountry> countries;
  final bool allowAll;
  const _CountryPickerSheet({required this.countries, required this.allowAll});

  @override
  State<_CountryPickerSheet> createState() => _CountryPickerSheetState();
}

class _CountryPickerSheetState extends State<_CountryPickerSheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final filtered = _query.isEmpty
        ? widget.countries
        : widget.countries
              .where((c) => c.name.toLowerCase().contains(_query.toLowerCase()))
              .toList();

    return SafeArea(
      top: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.75,
        ),
        child: Container(
          decoration: const BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 14),
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.divider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
                child: TextField(
                  autofocus: true,
                  onChanged: (v) => setState(() => _query = v),
                  style: GoogleFonts.inter(
                    color: AppColors.textPrimary,
                    fontSize: 14,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Search countries…',
                    hintStyle: GoogleFonts.inter(
                      color: AppColors.textSecondary,
                      fontSize: 14,
                    ),
                    prefixIcon: const Icon(Icons.search_rounded),
                  ),
                ),
              ),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 20),
                  itemCount: filtered.length + (widget.allowAll ? 1 : 0),
                  itemBuilder: (context, i) {
                    if (widget.allowAll && i == 0) {
                      return ListTile(
                        onTap: () => Navigator.pop(context, null),
                        leading: const Icon(
                          Icons.public_rounded,
                          color: AppColors.textSecondary,
                        ),
                        title: Text(
                          'All countries',
                          style: GoogleFonts.inter(
                            color: AppColors.textPrimary,
                            fontSize: 14.5,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      );
                    }
                    final country = filtered[i - (widget.allowAll ? 1 : 0)];
                    return ListTile(
                      onTap: () => Navigator.pop(context, country),
                      leading: Text(
                        country.flag,
                        style: const TextStyle(fontSize: 20),
                      ),
                      title: Text(
                        country.name,
                        style: GoogleFonts.inter(
                          color: AppColors.textPrimary,
                          fontSize: 14.5,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
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
}
