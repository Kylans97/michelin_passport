import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/constants/app_colors.dart';
import '../../../data/repositories/hotel_repository.dart';
import '../../../data/repositories/restaurant_repository.dart';
import '../../../data/repositories/wishlist_repository.dart';
import '../../../models/passport_venue.dart';
import '../../passport/widgets/venue_picker_parts.dart';

/// Searches restaurants or hotels.
typedef VenueSearch = Future<List<PassportVenue>> Function(String query);

/// Adds or removes one venue from the member's wishlist.
typedef WishlistWrite = Future<void> Function(PassportVenue venue);

/// Wishlist → "+ Add": find a restaurant or hotel and save it without
/// leaving the Wishlist (asked for by a tester, 2026-10-31). The same
/// green picker as Passport → + ("Where did you go?") — Restaurant/Hotel
/// chips, one search field, [VenuePickerRow] results — but each row ends
/// in a heart instead of a chevron: tap to save, tap again to remove. The
/// sheet stays open so several places can be saved in one go.
///
/// [savedIds] are the venue ids already on the wishlist, so their hearts
/// start filled. Returns true when anything was added or removed, so the
/// caller knows to reload.
Future<bool> showAddToWishlistSheet(
  BuildContext context, {
  required String userId,
  required Set<String> savedIds,
  bool startWithHotels = false,
  VenueSearch? searchRestaurants,
  VenueSearch? searchHotels,
  WishlistWrite? add,
  WishlistWrite? remove,
}) async {
  final changed = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => AddToWishlistSheet(
      userId: userId,
      savedIds: savedIds,
      startWithHotels: startWithHotels,
      searchRestaurants: searchRestaurants,
      searchHotels: searchHotels,
      add: add,
      remove: remove,
    ),
  );
  return changed ?? false;
}

class AddToWishlistSheet extends StatefulWidget {
  final String userId;
  final Set<String> savedIds;
  final bool startWithHotels;
  // Injectable for tests; default to the real repositories.
  final VenueSearch? searchRestaurants;
  final VenueSearch? searchHotels;
  final WishlistWrite? add;
  final WishlistWrite? remove;

  const AddToWishlistSheet({
    super.key,
    required this.userId,
    required this.savedIds,
    this.startWithHotels = false,
    this.searchRestaurants,
    this.searchHotels,
    this.add,
    this.remove,
  });

  @override
  State<AddToWishlistSheet> createState() => _AddToWishlistSheetState();
}

class _AddToWishlistSheetState extends State<AddToWishlistSheet> {
  late bool _hotels = widget.startWithHotels;
  late final Set<String> _saved = {...widget.savedIds};
  final Set<String> _busy = {};
  bool _changed = false;

  final _searchCtrl = TextEditingController();
  Timer? _debounce;
  String _query = '';
  bool _searching = false;
  List<PassportVenue> _results = [];
  String? _error;

  late final VenueSearch _searchRestaurants =
      widget.searchRestaurants ??
      (q) async => (await RestaurantRepository(
        Supabase.instance.client,
      ).search(q)).map(RestaurantVenue.new).toList();
  late final VenueSearch _searchHotels =
      widget.searchHotels ??
      (q) async => (await HotelRepository(
        Supabase.instance.client,
      ).search(q)).map(HotelVenue.new).toList();
  late final WishlistRepository _repo = WishlistRepository(
    Supabase.instance.client,
  );
  late final WishlistWrite _add =
      widget.add ??
      (v) => switch (v) {
        RestaurantVenue(:final restaurant) => _repo.add(
          userId: widget.userId,
          restaurantId: restaurant.id,
        ),
        HotelVenue(:final hotel) => _repo.addHotel(
          userId: widget.userId,
          hotelId: hotel.id,
        ),
      };
  late final WishlistWrite _remove =
      widget.remove ??
      (v) => switch (v) {
        RestaurantVenue(:final restaurant) => _repo.remove(
          userId: widget.userId,
          restaurantId: restaurant.id,
        ),
        HotelVenue(:final hotel) => _repo.removeHotel(
          userId: widget.userId,
          hotelId: hotel.id,
        ),
      };

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onQueryChanged(String value) {
    _debounce?.cancel();
    final trimmed = value.trim();
    setState(() => _query = trimmed);
    if (trimmed.length < 2) {
      setState(() => _results = []);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 300), _runSearch);
  }

  Future<void> _runSearch() async {
    final query = _query;
    if (query.length < 2 || !mounted) return;
    setState(() => _searching = true);
    try {
      final results = _hotels
          ? await _searchHotels(query)
          : await _searchRestaurants(query);
      if (!mounted || query != _query) return;
      setState(() {
        _results = results;
        _searching = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _searching = false);
    }
  }

  void _setHotels(bool hotels) {
    if (hotels == _hotels) return;
    setState(() {
      _hotels = hotels;
      _results = [];
    });
    if (_query.length >= 2) _runSearch();
  }

  String _id(PassportVenue v) => switch (v) {
    RestaurantVenue(:final restaurant) => restaurant.id,
    HotelVenue(:final hotel) => hotel.id,
  };

  // Optimistic, like the heart on a venue page: flip first, write, and
  // flip back with a short message if the write fails.
  Future<void> _toggle(PassportVenue venue) async {
    final id = _id(venue);
    if (_busy.contains(id)) return;
    final wasSaved = _saved.contains(id);
    setState(() {
      _busy.add(id);
      _error = null;
      wasSaved ? _saved.remove(id) : _saved.add(id);
    });
    try {
      await (wasSaved ? _remove(venue) : _add(venue));
      _changed = true;
    } catch (_) {
      if (!mounted) return;
      setState(() {
        wasSaved ? _saved.add(id) : _saved.remove(id);
        _error = 'Could not update your wishlist. Please try again.';
      });
    } finally {
      if (mounted) setState(() => _busy.remove(id));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.92,
        ),
        child: DecoratedBox(
          decoration: const BoxDecoration(
            color: AppColors.deepGreen,
            borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 10),
                Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.hairlineOnGreen,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 14),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 72,
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton(
                            onPressed: () => Navigator.pop(context, _changed),
                            style: TextButton.styleFrom(
                              foregroundColor: AppColors.textOnDark,
                              padding: const EdgeInsets.symmetric(
                                vertical: 6,
                                horizontal: 4,
                              ),
                              minimumSize: Size.zero,
                              textStyle: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            child: const Text('Done'),
                          ),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          'ADD TO WISHLIST',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(
                            color: AppColors.secondaryOnDark,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 10.5 * 0.14,
                          ),
                        ),
                      ),
                      const SizedBox(width: 72),
                    ],
                  ),
                ),
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Where would you like to go?',
                          style: GoogleFonts.cormorantGaramond(
                            color: AppColors.textOnDark,
                            fontSize: 34,
                            fontWeight: FontWeight.w600,
                            height: 1.05,
                          ),
                        ),
                        const SizedBox(height: 18),
                        Row(
                          children: [
                            VenueTypeChip(
                              label: 'Restaurant',
                              selected: !_hotels,
                              onTap: () => _setHotels(false),
                            ),
                            const SizedBox(width: 10),
                            VenueTypeChip(
                              label: 'Hotel',
                              selected: _hotels,
                              onTap: () => _setHotels(true),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        TextField(
                          controller: _searchCtrl,
                          onChanged: _onQueryChanged,
                          autofocus: true,
                          style: GoogleFonts.inter(
                            color: AppColors.textOnDark,
                            fontSize: 15,
                          ),
                          cursorColor: AppColors.textOnDark,
                          decoration: InputDecoration(
                            isDense: true,
                            // Unfilled: the theme's ivory fill would put
                            // ivory text on an ivory box on this green.
                            filled: false,
                            hintText: 'Search by name or city',
                            hintStyle: GoogleFonts.cormorantGaramond(
                              color: AppColors.secondaryOnDark,
                              fontStyle: FontStyle.italic,
                              fontSize: 16,
                            ),
                            enabledBorder: const UnderlineInputBorder(
                              borderSide: BorderSide(
                                color: AppColors.hairlineOnGreen,
                              ),
                            ),
                            focusedBorder: const UnderlineInputBorder(
                              borderSide: BorderSide(
                                color: AppColors.textOnDark,
                              ),
                            ),
                          ),
                        ),
                        if (_error != null) ...[
                          const SizedBox(height: 12),
                          Text(
                            _error!,
                            style: GoogleFonts.inter(
                              color: AppColors.textOnDark,
                              fontSize: 13,
                            ),
                          ),
                        ],
                        const SizedBox(height: 8),
                        _body(),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _body() {
    if (_query.length < 2) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: Text(
            _hotels
                ? 'Search for a hotel to save.'
                : 'Search for a restaurant to save.',
            style: GoogleFonts.inter(
              color: AppColors.secondaryOnDark,
              fontSize: 13,
            ),
          ),
        ),
      );
    }
    if (_searching) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              color: AppColors.textOnDark,
              strokeWidth: 1.5,
            ),
          ),
        ),
      );
    }
    if (_results.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: Text(
            'No matches.',
            style: GoogleFonts.inter(
              color: AppColors.secondaryOnDark,
              fontSize: 13,
            ),
          ),
        ),
      );
    }
    return Column(
      children: [
        for (final v in _results)
          VenuePickerRow(
            venue: v,
            onTap: () => _toggle(v),
            trailing: Icon(
              _saved.contains(_id(v))
                  ? Icons.favorite_rounded
                  : Icons.favorite_border_rounded,
              color: AppColors.textOnDark,
              size: 22,
              semanticLabel: _saved.contains(_id(v))
                  ? 'Saved — tap to remove from wishlist'
                  : 'Tap to save to wishlist',
            ),
          ),
      ],
    );
  }
}
