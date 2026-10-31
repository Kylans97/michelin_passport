import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/venue_thumbnail.dart';
import '../../../data/repositories/events_repository.dart';
import '../../../data/repositories/hotel_repository.dart';
import '../../../data/repositories/restaurant_repository.dart';
import '../../../data/repositories/wishlist_repository.dart';
import '../../../models/event.dart';
import '../../../models/passport_venue.dart';
import '../../events/event_date_format.dart';
import '../../events/event_detail_screen.dart';
import '../../hotels/hotel_detail_screen.dart';
import '../../passport/widgets/venue_picker_parts.dart';
import '../../restaurants/restaurant_detail_screen.dart';

/// Searches restaurants or hotels.
typedef VenueSearch = Future<List<PassportVenue>> Function(String query);

/// Searches upcoming published events.
typedef EventSearch = Future<List<Event>> Function(String query);

/// Adds or removes one venue from the member's wishlist.
typedef WishlistWrite = Future<void> Function(PassportVenue venue);

/// Adds or removes one event from the member's wishlist.
typedef EventWishlistWrite = Future<void> Function(Event event);

/// Which kind of place the sheet is searching.
enum WishlistAddType { restaurant, hotel, event }

/// Wishlist → "+ Add": find a restaurant or hotel and save it without
/// leaving the Wishlist (asked for by a tester, 2026-10-31). The same
/// green picker as Passport → + ("Where did you go?") — type chips, one
/// search field, the same rows — searching restaurants, hotels or
/// upcoming events. Tapping a row opens that place's own page; the heart
/// at the end of the row saves it (tap again to remove). The sheet stays
/// open so several places can be saved in one go.
///
/// [savedIds] are the venue and event ids already on the wishlist, so
/// their hearts start filled. Returns true when anything was added or
/// removed, so the caller knows to reload.
Future<bool> showAddToWishlistSheet(
  BuildContext context, {
  required String userId,
  required Set<String> savedIds,
  WishlistAddType startWith = WishlistAddType.restaurant,
  VenueSearch? searchRestaurants,
  VenueSearch? searchHotels,
  EventSearch? searchEvents,
  WishlistWrite? add,
  WishlistWrite? remove,
  EventWishlistWrite? addEvent,
  EventWishlistWrite? removeEvent,
}) async {
  final changed = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => AddToWishlistSheet(
      userId: userId,
      savedIds: savedIds,
      startWith: startWith,
      searchRestaurants: searchRestaurants,
      searchHotels: searchHotels,
      searchEvents: searchEvents,
      add: add,
      remove: remove,
      addEvent: addEvent,
      removeEvent: removeEvent,
    ),
  );
  return changed ?? false;
}

class AddToWishlistSheet extends StatefulWidget {
  final String userId;
  final Set<String> savedIds;
  final WishlistAddType startWith;
  // Injectable for tests; default to the real repositories.
  final VenueSearch? searchRestaurants;
  final VenueSearch? searchHotels;
  final EventSearch? searchEvents;
  final WishlistWrite? add;
  final WishlistWrite? remove;
  final EventWishlistWrite? addEvent;
  final EventWishlistWrite? removeEvent;

  const AddToWishlistSheet({
    super.key,
    required this.userId,
    required this.savedIds,
    this.startWith = WishlistAddType.restaurant,
    this.searchRestaurants,
    this.searchHotels,
    this.searchEvents,
    this.add,
    this.remove,
    this.addEvent,
    this.removeEvent,
  });

  @override
  State<AddToWishlistSheet> createState() => _AddToWishlistSheetState();
}

class _AddToWishlistSheetState extends State<AddToWishlistSheet> {
  late WishlistAddType _type = widget.startWith;
  late final Set<String> _saved = {...widget.savedIds};
  final Set<String> _busy = {};
  bool _changed = false;

  final _searchCtrl = TextEditingController();
  Timer? _debounce;
  String _query = '';
  bool _searching = false;
  List<PassportVenue> _results = [];
  List<Event> _eventResults = [];
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
  late final EventSearch _searchEvents =
      widget.searchEvents ??
      // Upcoming or still running only: a past event can't be planned.
      (q) => EventsRepository(
        Supabase.instance.client,
      ).loadEvents(query: q, from: DateTime.now());
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

  late final EventWishlistWrite _addEvent =
      widget.addEvent ??
      (e) => _repo.addEvent(userId: widget.userId, eventId: e.id);
  late final EventWishlistWrite _removeEvent =
      widget.removeEvent ??
      (e) => _repo.removeEvent(userId: widget.userId, eventId: e.id);

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
      setState(() {
        _results = [];
        _eventResults = [];
      });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 300), _runSearch);
  }

  Future<void> _runSearch() async {
    final query = _query;
    if (query.length < 2 || !mounted) return;
    final type = _type;
    setState(() => _searching = true);
    try {
      final venues = switch (type) {
        WishlistAddType.restaurant => await _searchRestaurants(query),
        WishlistAddType.hotel => await _searchHotels(query),
        WishlistAddType.event => const <PassportVenue>[],
      };
      final events = type == WishlistAddType.event
          ? await _searchEvents(query)
          : const <Event>[];
      if (!mounted || query != _query || type != _type) return;
      setState(() {
        _results = venues;
        _eventResults = events;
        _searching = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _searching = false);
    }
  }

  void _setType(WishlistAddType type) {
    if (type == _type) return;
    setState(() {
      _type = type;
      _results = [];
      _eventResults = [];
    });
    if (_query.length >= 2) _runSearch();
  }

  String _id(PassportVenue v) => switch (v) {
    RestaurantVenue(:final restaurant) => restaurant.id,
    HotelVenue(:final hotel) => hotel.id,
  };

  void _openVenue(PassportVenue venue) => Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => switch (venue) {
        RestaurantVenue(:final restaurant) => RestaurantDetailScreen(
          restaurant: restaurant,
        ),
        HotelVenue(:final hotel) => HotelDetailScreen(hotel: hotel),
      },
    ),
  );

  void _openEvent(Event event) => Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => EventDetailScreen(eventId: event.id)),
  );

  // Optimistic, like the heart on a venue page: flip first, write, and
  // flip back with a short message if the write fails.
  Future<void> _toggle(PassportVenue venue) => _toggleId(
    _id(venue),
    add: () => _add(venue),
    remove: () => _remove(venue),
  );

  Future<void> _toggleEvent(Event event) => _toggleId(
    event.id,
    add: () => _addEvent(event),
    remove: () => _removeEvent(event),
  );

  Future<void> _toggleId(
    String id, {
    required Future<void> Function() add,
    required Future<void> Function() remove,
  }) async {
    if (_busy.contains(id)) return;
    final wasSaved = _saved.contains(id);
    setState(() {
      _busy.add(id);
      _error = null;
      wasSaved ? _saved.remove(id) : _saved.add(id);
    });
    try {
      await (wasSaved ? remove() : add());
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
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                            VenueTypeChip(
                              label: 'Restaurant',
                              selected: _type == WishlistAddType.restaurant,
                              onTap: () => _setType(WishlistAddType.restaurant),
                            ),
                            VenueTypeChip(
                              label: 'Hotel',
                              selected: _type == WishlistAddType.hotel,
                              onTap: () => _setType(WishlistAddType.hotel),
                            ),
                            VenueTypeChip(
                              label: 'Event',
                              selected: _type == WishlistAddType.event,
                              onTap: () => _setType(WishlistAddType.event),
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
            switch (_type) {
              WishlistAddType.restaurant => 'Search for a restaurant to save.',
              WishlistAddType.hotel => 'Search for a hotel to save.',
              WishlistAddType.event => 'Search for an upcoming event to save.',
            },
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
    if (_results.isEmpty && _eventResults.isEmpty) {
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
    return PickerRowList(
      children: [
        for (final v in _results)
          VenuePickerRow(
            venue: v,
            onTap: () => _openVenue(v),
            trailing: _heart(_id(v), onTap: () => _toggle(v)),
          ),
        for (final e in _eventResults)
          PickerRow(
            title: e.name,
            onTap: () => _openEvent(e),
            thumbnail: VenueThumbnail(
              imageUrl: e.imageUrl,
              size: 52,
              borderRadius: const BorderRadius.all(Radius.circular(4)),
            ),
            detail: Text(
              [
                formatEventDateRange(e),
                if (e.city != null && e.city!.isNotEmpty) e.city!,
              ].join(' · '),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                color: AppColors.secondaryOnDark,
                fontSize: 12,
              ),
            ),
            trailing: _heart(e.id, onTap: () => _toggleEvent(e)),
          ),
      ],
    );
  }

  // Its own tap target, apart from the row, which opens the place.
  Widget _heart(String id, {required VoidCallback onTap}) {
    final saved = _saved.contains(id);
    return IconButton(
      onPressed: onTap,
      icon: Icon(
        saved ? Icons.favorite_rounded : Icons.favorite_border_rounded,
        size: 22,
      ),
      color: AppColors.textOnDark,
      tooltip: saved ? 'Remove from wishlist' : 'Save to wishlist',
    );
  }
}
