import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/cs_spacing.dart';
import '../../../core/theme/cs_typography.dart';
import '../../../core/widgets/cs_editorial_glyphs.dart';
import '../../../data/repositories/hotel_repository.dart';
import '../../../data/repositories/restaurant_repository.dart';
import '../../../models/passport_venue.dart';
import '../friend_profile_data.dart';
import '../widgets/friend_profile_widgets.dart';

/// "Change place" (7d) — shared wishlist items first, then the viewer's
/// own wishlist, then live catalogue search (RestaurantRepository/
/// HotelRepository.search, the exact same combined name+location search
/// Explore already uses — not a separate implementation).
Future<PassportVenue?> showVenuePickerSheet(
  BuildContext context, {
  required List<PassportVenue> sharedWishlist,
  required List<PassportVenue> myWishlist,
}) {
  return showModalBottomSheet<PassportVenue>(
    context: context,
    backgroundColor: AppColors.background,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
    ),
    builder: (context) => _VenuePickerSheet(
      sharedWishlist: sharedWishlist,
      myWishlist: myWishlist,
    ),
  );
}

class _VenuePickerSheet extends StatefulWidget {
  final List<PassportVenue> sharedWishlist;
  final List<PassportVenue> myWishlist;

  const _VenuePickerSheet({required this.sharedWishlist, required this.myWishlist});

  @override
  State<_VenuePickerSheet> createState() => _VenuePickerSheetState();
}

class _VenuePickerSheetState extends State<_VenuePickerSheet> {
  late final _restaurantRepo = RestaurantRepository(Supabase.instance.client);
  late final _hotelRepo = HotelRepository(Supabase.instance.client);
  final _searchCtrl = TextEditingController();
  Timer? _debounce;
  String _query = '';
  bool _searching = false;
  List<PassportVenue> _results = const [];

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onQueryChanged(String value) {
    _debounce?.cancel();
    setState(() => _query = value.trim());
    if (_query.length < 2) {
      setState(() => _results = const []);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 300), () async {
      setState(() => _searching = true);
      try {
        final restaurants = await _restaurantRepo.search(_query);
        final hotels = await _hotelRepo.search(_query);
        if (!mounted) return;
        setState(() {
          _results = [
            for (final r in restaurants) RestaurantVenue(r),
            for (final h in hotels) HotelVenue(h),
          ];
          _searching = false;
        });
      } catch (_) {
        if (!mounted) return;
        setState(() => _searching = false);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final showingSearch = _query.length >= 2;
    final myOnly = widget.myWishlist
        .where((v) => !widget.sharedWishlist.any((s) => wishlistVenueKey(s) == wishlistVenueKey(v)))
        .toList();

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 10),
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.hairlineOnPaper,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              CsSpacing.pageHorizontal,
              CsSpacing.md,
              CsSpacing.pageHorizontal,
              CsSpacing.sm,
            ),
            child: TextField(
              controller: _searchCtrl,
              onChanged: _onQueryChanged,
              style: CsTypography.editorialBody.copyWith(color: AppColors.textPrimary),
              decoration: InputDecoration(
                hintText: 'Search restaurants, hotels…',
                hintStyle: CsTypography.editorialBody.copyWith(color: AppColors.taupe),
                prefixIcon: const Icon(Icons.search, color: AppColors.taupe, size: 20),
                filled: true,
                fillColor: AppColors.card,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          Expanded(
            child: ListView(
              controller: scrollController,
              padding: const EdgeInsets.symmetric(
                horizontal: CsSpacing.pageHorizontal,
              ).copyWith(bottom: CsSpacing.xxl),
              children: showingSearch
                  ? [
                      if (_searching)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: CsSpacing.lg),
                          child: Center(
                            child: CircularProgressIndicator(
                              strokeWidth: 1.5,
                              color: AppColors.forestGreen,
                            ),
                          ),
                        )
                      else if (_results.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: CsSpacing.lg),
                          child: Text(
                            'No results for "$_query".',
                            style: CsTypography.editorialLead().copyWith(color: AppColors.taupe),
                          ),
                        )
                      else
                        for (final v in _results) _PickerRow(venue: v),
                    ]
                  : [
                      if (widget.sharedWishlist.isNotEmpty) ...[
                        _SectionLabel('ON BOTH YOUR WISHLISTS'),
                        for (final v in widget.sharedWishlist) _PickerRow(venue: v),
                      ],
                      if (myOnly.isNotEmpty) ...[
                        _SectionLabel('YOUR WISHLIST'),
                        for (final v in myOnly) _PickerRow(venue: v),
                      ],
                      if (widget.sharedWishlist.isEmpty && myOnly.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: CsSpacing.lg),
                          child: Text(
                            'Search for a place above.',
                            style: CsTypography.editorialLead().copyWith(color: AppColors.taupe),
                          ),
                        ),
                    ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: CsSpacing.sm),
    child: Text(
      text,
      style: CsTypography.editorialLabel().copyWith(color: AppColors.taupe),
    ),
  );
}

class _PickerRow extends StatelessWidget {
  final PassportVenue venue;
  const _PickerRow({required this.venue});

  @override
  Widget build(BuildContext context) {
    final (cityName, award) = switch (venue) {
      RestaurantVenue(:final restaurant) => (
        restaurant.cityName,
        restaurant.hasMichelinStar
            ? CsEditorialStarRow(count: restaurant.michelinStars!, size: 12)
            : null,
      ),
      HotelVenue(:final hotel) => (
        hotel.cityName,
        hotel.hasMichelinKeys ? CsEditorialKeyRow(count: hotel.michelinKeys!, size: 12) : null,
      ),
    };

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => Navigator.pop(context, venue),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: CsSpacing.sm),
          child: Row(
            children: [
              PhotoOrTile(photoUrl: null, venueName: venue.name, width: 48, height: 48),
              const SizedBox(width: CsSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      venue.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: CsTypography.editorialTitle(size: 17).copyWith(
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Flexible(
                          child: CsCountryLabel(
                            cityName: cityName,
                            countryCode: venue.countryCode,
                            style: CsTypography.editorialBody.copyWith(
                              color: AppColors.taupe,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        if (award != null) ...[const SizedBox(width: 6), award],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
