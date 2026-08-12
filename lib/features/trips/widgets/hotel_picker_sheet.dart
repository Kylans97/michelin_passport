import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/app_colors.dart';
import '../../../data/repositories/hotel_repository.dart';
import '../../../models/hotel.dart';

/// Searchable single-hotel picker, live against the existing hotel
/// catalogue (HotelRepository.search()) — same search-as-you-type pattern
/// as CountryPickerSheet, but hitting the network per keystroke since the
/// hotel catalogue (unlike the ~200-row countries table) is too large to
/// hold client-side. Used by both Create Trip's "Where are you staying?"
/// and Trip Detail's "Add/change hotel" so a trip's hotel is always a
/// normalized reference (planned_venues.entity_id -> hotels_full.id),
/// never a copy of hotel data.
Future<Hotel?> showHotelPickerSheet(
  BuildContext context, {
  required HotelRepository repo,
}) {
  return showModalBottomSheet<Hotel>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _HotelPickerSheet(repo: repo),
  );
}

class _HotelPickerSheet extends StatefulWidget {
  final HotelRepository repo;
  const _HotelPickerSheet({required this.repo});

  @override
  State<_HotelPickerSheet> createState() => _HotelPickerSheetState();
}

class _HotelPickerSheetState extends State<_HotelPickerSheet> {
  String _query = '';
  late Future<List<Hotel>> _future = widget.repo.search('');

  void _onQueryChanged(String value) {
    setState(() {
      _query = value;
      _future = widget.repo.search(value);
    });
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.75,
        ),
        child: Container(
          decoration: const BoxDecoration(
            color: AppColors.brandGreenLight,
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
                  color: AppColors.textOnDark.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
                child: TextField(
                  autofocus: true,
                  onChanged: _onQueryChanged,
                  // A light-filled search field (the app's global
                  // InputDecorationTheme fills every TextField with
                  // AppColors.surface by default) reads as a quiet "island"
                  // on the sheet's dark canvas — the same treatment the
                  // date/country/venue-picker rows in CreateTripSheet use —
                  // rather than fighting the theme's default fill.
                  style: GoogleFonts.inter(
                    color: AppColors.textPrimary,
                    fontSize: 14,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Search hotels, cities…',
                    hintStyle: GoogleFonts.inter(
                      color: AppColors.textSecondary,
                      fontSize: 14,
                    ),
                    prefixIcon: const Icon(Icons.search_rounded),
                  ),
                ),
              ),
              Flexible(
                child: FutureBuilder<List<Hotel>>(
                  future: _future,
                  builder: (context, snap) {
                    if (snap.connectionState == ConnectionState.waiting) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 32),
                        child: Center(
                          child: CircularProgressIndicator(
                            color: AppColors.gold,
                            strokeWidth: 1.5,
                          ),
                        ),
                      );
                    }
                    final hotels = snap.data ?? const <Hotel>[];
                    if (hotels.isEmpty) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 32),
                        child: Center(
                          child: Text(
                            _query.isEmpty
                                ? 'No hotels in the catalogue yet'
                                : 'No hotels found',
                            style: GoogleFonts.inter(
                              color: AppColors.secondaryOnDark,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      );
                    }
                    return ListView.builder(
                      shrinkWrap: true,
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 20),
                      itemCount: hotels.length,
                      itemBuilder: (context, i) {
                        final hotel = hotels[i];
                        return ListTile(
                          onTap: () => Navigator.pop(context, hotel),
                          leading: Text(
                            hotel.flagEmoji,
                            style: const TextStyle(fontSize: 20),
                          ),
                          title: Text(
                            hotel.name,
                            style: GoogleFonts.inter(
                              color: AppColors.textOnDark,
                              fontSize: 14.5,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          subtitle: Text(
                            '${hotel.cityName}, ${hotel.countryName}',
                            style: GoogleFonts.inter(
                              color: AppColors.secondaryOnDark,
                              fontSize: 12.5,
                            ),
                          ),
                        );
                      },
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
