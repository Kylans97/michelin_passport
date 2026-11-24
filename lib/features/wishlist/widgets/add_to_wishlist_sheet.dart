import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/venue_thumbnail.dart';
import '../../../data/repositories/events_repository.dart';
import '../../../data/repositories/hotel_repository.dart';
import '../../../data/repositories/journey_repository.dart';
import '../../../data/repositories/restaurant_repository.dart';
import '../../../data/repositories/vineyard_repository.dart';
import '../../../data/repositories/wishlist_repository.dart';
import '../../../models/event.dart';
import '../../../models/journey.dart';
import '../../../models/passport_venue.dart';
import '../../../models/vineyard.dart';
import '../../events/event_date_format.dart';
import '../../events/event_detail_screen.dart';
import '../../hotels/hotel_detail_screen.dart';
import '../../journeys/journey_detail_screen.dart';
import '../../passport/widgets/venue_picker_parts.dart';
import '../../restaurants/restaurant_detail_screen.dart';
import '../../vineyards/vineyard_detail_screen.dart';
import '../../../core/analytics/analytics_properties.dart';
import '../../../core/theme/cs_fonts.dart';

/// Searches restaurants or hotels.
typedef VenueSearch = Future<List<PassportVenue>> Function(String query);

/// Searches upcoming published events.
typedef EventSearch = Future<List<Event>> Function(String query);

/// Adds or removes one venue from the member's wishlist.
typedef WishlistWrite = Future<void> Function(PassportVenue venue);

/// Adds or removes one event from the member's wishlist.
typedef EventWishlistWrite = Future<void> Function(Event event);

/// Which kind of place the sheet is searching.
enum WishlistAddType { restaurant, hotel, event, estate, train, ship }

/// Loads a whole small catalogue (wine estates, trains and ships) once;
/// the sheet filters it on the device.
typedef CatalogueLoad<T> = Future<List<T>> Function();

/// Adds or removes one wine estate or journey by id.
typedef IdWishlistWrite = Future<void> Function(String id);

/// Whether a train or ship matches what was typed: its name or its
/// operator, accents folded the way the estate search folds them.
bool journeyMatchesQuery(Journey journey, String typed) {
  final q = foldForSearch(typed.trim());
  if (q.length < 2) return false;
  return foldForSearch(journey.name).contains(q) ||
      foldForSearch(journey.operatorName).contains(q);
}

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
  CatalogueLoad<Vineyard>? loadVineyards,
  CatalogueLoad<Journey>? loadJourneys,
  IdWishlistWrite? addVineyard,
  IdWishlistWrite? removeVineyard,
  IdWishlistWrite? addJourney,
  IdWishlistWrite? removeJourney,
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
      loadVineyards: loadVineyards,
      loadJourneys: loadJourneys,
      addVineyard: addVineyard,
      removeVineyard: removeVineyard,
      addJourney: addJourney,
      removeJourney: removeJourney,
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
  final CatalogueLoad<Vineyard>? loadVineyards;
  final CatalogueLoad<Journey>? loadJourneys;
  final IdWishlistWrite? addVineyard;
  final IdWishlistWrite? removeVineyard;
  final IdWishlistWrite? addJourney;
  final IdWishlistWrite? removeJourney;

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
    this.loadVineyards,
    this.loadJourneys,
    this.addVineyard,
    this.removeVineyard,
    this.addJourney,
    this.removeJourney,
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
  List<Vineyard> _vineyardResults = [];
  List<Journey> _journeyResults = [];
  // The estates and journeys catalogues, read once on first use.
  List<Vineyard>? _allVineyards;
  List<Journey>? _allJourneys;
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

  /// Estates are searched on the server ([VineyardRepository.search]); a
  /// test may hand in a fixed catalogue through [widget.loadVineyards],
  /// which is then matched on the device.
  VineyardRepository? _vineyardRepo;
  Future<List<Vineyard>> _searchVineyards(String query) async {
    final load = widget.loadVineyards;
    if (load != null) {
      return matchingVineyards(
        _allVineyards ??= await load(),
        query,
        limit: 20,
      );
    }
    return (_vineyardRepo ??= VineyardRepository(Supabase.instance.client))
        .search(query, limit: 20);
  }
  late final CatalogueLoad<Journey> _loadJourneys =
      widget.loadJourneys ??
      () => JourneyRepository(Supabase.instance.client).getPublishedJourneys();
  late final IdWishlistWrite _addVineyard =
      widget.addVineyard ??
      (id) => _repo.addVineyard(userId: widget.userId, vineyardId: id);
  late final IdWishlistWrite _removeVineyard =
      widget.removeVineyard ??
      (id) => _repo.removeVineyard(userId: widget.userId, vineyardId: id);
  late final IdWishlistWrite _addJourney =
      widget.addJourney ??
      (id) => _repo.addJourney(userId: widget.userId, journeyId: id);
  late final IdWishlistWrite _removeJourney =
      widget.removeJourney ??
      (id) => _repo.removeJourney(userId: widget.userId, journeyId: id);

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
        _vineyardResults = [];
        _journeyResults = [];
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
        _ => const <PassportVenue>[],
      };
      final events = type == WishlistAddType.event
          ? await _searchEvents(query)
          : const <Event>[];
      var vineyards = const <Vineyard>[];
      if (type == WishlistAddType.estate) {
        vineyards = await _searchVineyards(query);
      }
      var journeys = const <Journey>[];
      if (type == WishlistAddType.train || type == WishlistAddType.ship) {
        final all = _allJourneys ??= await _loadJourneys();
        final kind = type == WishlistAddType.train
            ? JourneyKind.train
            : JourneyKind.ship;
        journeys = [
          for (final j in all)
            if (j.kind == kind && journeyMatchesQuery(j, query)) j,
        ];
      }
      if (!mounted || query != _query || type != _type) return;
      setState(() {
        _results = venues;
        _eventResults = events;
        _vineyardResults = vineyards;
        _journeyResults = journeys;
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
      _vineyardResults = [];
      _journeyResults = [];
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
          openSource: AnalyticsOpenSource.wishlist,
        ),
        HotelVenue(:final hotel) => HotelDetailScreen(
          hotel: hotel,
          openSource: AnalyticsOpenSource.wishlist,
        ),
      },
    ),
  );

  void _openEvent(Event event) => Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => EventDetailScreen(
        eventId: event.id,
        openSource: AnalyticsOpenSource.wishlist,
      ),
    ),
  );

  void _openVineyard(Vineyard vineyard) => Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => VineyardDetailScreen(vineyardId: vineyard.id),
    ),
  );

  void _openJourney(Journey journey) => Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => JourneyDetailScreen(journeyId: journey.id),
    ),
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
                              textStyle: CsFonts.sans(
                                fontSize: 13.5,
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
                          style: CsFonts.sans(
                            color: AppColors.secondaryOnDark,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 11 * 0.14,
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
                          style: CsFonts.serif(
                            color: AppColors.textOnDark,
                            fontSize: 31,
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
                            VenueTypeChip(
                              label: 'Wine estate',
                              selected: _type == WishlistAddType.estate,
                              onTap: () => _setType(WishlistAddType.estate),
                            ),
                            VenueTypeChip(
                              label: 'Train',
                              selected: _type == WishlistAddType.train,
                              onTap: () => _setType(WishlistAddType.train),
                            ),
                            VenueTypeChip(
                              label: 'Ship',
                              selected: _type == WishlistAddType.ship,
                              onTap: () => _setType(WishlistAddType.ship),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        TextField(
                          controller: _searchCtrl,
                          onChanged: _onQueryChanged,
                          autofocus: true,
                          style: CsFonts.sans(
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
                            hintStyle: CsFonts.serif(
                              color: AppColors.secondaryOnDark,
                              fontStyle: FontStyle.italic,
                              fontSize: 14.5,
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
                            style: CsFonts.sans(
                              color: AppColors.textOnDark,
                              fontSize: 13.5,
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
              WishlistAddType.estate => 'Search for a wine estate to save.',
              WishlistAddType.train => 'Search for a train to save.',
              WishlistAddType.ship => 'Search for a ship to save.',
            },
            style: CsFonts.sans(
              color: AppColors.secondaryOnDark,
              fontSize: 13.5,
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
    if (_results.isEmpty &&
        _eventResults.isEmpty &&
        _vineyardResults.isEmpty &&
        _journeyResults.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: Text(
            'No matches.',
            style: CsFonts.sans(
              color: AppColors.secondaryOnDark,
              fontSize: 13.5,
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
              style: CsFonts.sans(
                color: AppColors.secondaryOnDark,
                fontSize: 12.5,
              ),
            ),
            trailing: _heart(e.id, onTap: () => _toggleEvent(e)),
          ),
        for (final v in _vineyardResults)
          VineyardPickerRow(
            vineyard: v,
            onTap: () => _openVineyard(v),
            trailing: _heart(
              v.id,
              onTap: () => _toggleId(
                v.id,
                add: () => _addVineyard(v.id),
                remove: () => _removeVineyard(v.id),
              ),
            ),
          ),
        for (final j in _journeyResults)
          JourneyPickerRow(
            journey: j,
            onTap: () => _openJourney(j),
            trailing: _heart(
              j.id,
              onTap: () => _toggleId(
                j.id,
                add: () => _addJourney(j.id),
                remove: () => _removeJourney(j.id),
              ),
            ),
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
