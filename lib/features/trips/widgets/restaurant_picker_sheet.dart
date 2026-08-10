import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/app_colors.dart';
import '../../../data/repositories/restaurant_repository.dart';
import '../../../models/restaurant.dart';

/// Searchable single-restaurant picker, live against the existing
/// restaurant catalogue (RestaurantRepository.search()). Adding several
/// restaurants to a trip means opening this sheet once per restaurant
/// (matching the single-select sheet pattern used everywhere else in this
/// app — CountryPickerSheet, HotelPickerSheet — rather than introducing a
/// one-off multi-select checklist UI); [excludeIds] hides restaurants
/// already added to the trip so the same one can't be picked twice. Used
/// by both Create Trip's "Restaurants to visit" and Trip Detail's "Add
/// restaurant" so a trip's restaurants are always normalized references
/// (planned_venues.entity_id -> restaurants_full.id), never copied data.
Future<Restaurant?> showRestaurantPickerSheet(
  BuildContext context, {
  required RestaurantRepository repo,
  Set<String> excludeIds = const {},
}) {
  return showModalBottomSheet<Restaurant>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _RestaurantPickerSheet(repo: repo, excludeIds: excludeIds),
  );
}

class _RestaurantPickerSheet extends StatefulWidget {
  final RestaurantRepository repo;
  final Set<String> excludeIds;
  const _RestaurantPickerSheet({required this.repo, required this.excludeIds});

  @override
  State<_RestaurantPickerSheet> createState() => _RestaurantPickerSheetState();
}

class _RestaurantPickerSheetState extends State<_RestaurantPickerSheet> {
  String _query = '';
  late Future<List<Restaurant>> _future = widget.repo.search('');

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
                  onChanged: _onQueryChanged,
                  style: GoogleFonts.inter(
                    color: AppColors.textPrimary,
                    fontSize: 14,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Search restaurants, cities…',
                    hintStyle: GoogleFonts.inter(
                      color: AppColors.textSecondary,
                      fontSize: 14,
                    ),
                    prefixIcon: const Icon(Icons.search_rounded),
                  ),
                ),
              ),
              Flexible(
                child: FutureBuilder<List<Restaurant>>(
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
                    final restaurants = [
                      for (final r in snap.data ?? const <Restaurant>[])
                        if (!widget.excludeIds.contains(r.id)) r,
                    ];
                    if (restaurants.isEmpty) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 32),
                        child: Center(
                          child: Text(
                            _query.isEmpty
                                ? 'No restaurants in the catalogue yet'
                                : 'No restaurants found',
                            style: GoogleFonts.inter(
                              color: AppColors.textSecondary,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      );
                    }
                    return ListView.builder(
                      shrinkWrap: true,
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 20),
                      itemCount: restaurants.length,
                      itemBuilder: (context, i) {
                        final restaurant = restaurants[i];
                        return ListTile(
                          onTap: () => Navigator.pop(context, restaurant),
                          leading: Text(
                            restaurant.flagEmoji,
                            style: const TextStyle(fontSize: 20),
                          ),
                          title: Text(
                            restaurant.name,
                            style: GoogleFonts.inter(
                              color: AppColors.textPrimary,
                              fontSize: 14.5,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          subtitle: Text(
                            '${restaurant.cityName}, ${restaurant.countryName}',
                            style: GoogleFonts.inter(
                              color: AppColors.textSecondary,
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
