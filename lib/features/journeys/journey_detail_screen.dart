import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/analytics/analytics_properties.dart';
import '../../core/constants/app_colors.dart';
import '../../core/theme/cs_spacing.dart';
import '../../core/theme/cs_surface_context.dart';
import '../../core/theme/cs_typography.dart';
import '../../core/widgets/cs_primary_button.dart';
import '../../core/widgets/subtle_text_action.dart';
import '../../core/widgets/venue_visit_row.dart' show formatVenueVisitDate;
import '../../data/repositories/country_lookup.dart';
import '../../data/repositories/journey_repository.dart';
import '../../data/repositories/restaurant_repository.dart';
import '../../data/repositories/wishlist_repository.dart';
import '../../models/journey.dart';
import '../passport/stamp_ceremony.dart';
import '../passport/widgets/own_passport_entry_row.dart';
import '../restaurants/restaurant_detail_screen.dart';
import 'journey_visuals.dart';
import 'widgets/confirm_travel_sheet.dart';
import 'widgets/journey_cabin_manifest.dart';
import 'widgets/journey_detail_hero.dart';
import 'widgets/journey_dining.dart';
import 'widgets/journey_figures.dart';
import 'widgets/journey_itinerary.dart';
import 'widgets/journey_passport_stamps.dart';
import 'widgets/journey_route_globe.dart';

/// A train's or ship's own page: hero, what it is, its figures, where it
/// goes on the globe with the selected route stop by stop, its routes,
/// life on board (a cabin manifest when the cabins text counts its
/// types), the table aboard (the dining text and the dining partners in
/// the catalogue), the member's own Passport stamps with "I travelled on
/// this", and the operator's website. Everything shown is the operator's
/// published fact or our starting text; nothing is inferred. The only
/// gold is a partner restaurant's own MICHELIN stars.
class JourneyDetailScreen extends StatefulWidget {
  final String journeyId;

  const JourneyDetailScreen({super.key, required this.journeyId});

  @override
  State<JourneyDetailScreen> createState() => _JourneyDetailScreenState();
}

class _JourneyDetailScreenState extends State<JourneyDetailScreen> {
  final _client = Supabase.instance.client;
  late final _repo = JourneyRepository(_client);
  late final _wishlistRepo = WishlistRepository(_client);

  String? get _userId => _client.auth.currentUser?.id;

  Journey? _journey;
  List<JourneyRoute> _routes = const [];
  List<JourneyRouteStop> _stops = const [];
  String? _selectedRouteId;
  final _globeKey = GlobalKey();
  List<JourneyDiningPartner> _partners = const [];
  Map<String, String> _countryNames = const {};
  List<JourneyTravel> _travels = const [];
  bool _wishlisted = false;
  bool _wishlistBusy = false;
  bool _loading = true;
  bool _error = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = false;
    });
    try {
      final journey = await _repo.getById(widget.journeyId);
      // Routes, partners and personal state are enhancements: a failed
      // lookup leaves its section empty, never the whole page in error.
      final routes = journey == null
          ? const <JourneyRoute>[]
          : await _repo
                .getRoutes(journey.id)
                .catchError((Object _) => const <JourneyRoute>[]);
      final stops = routes.isEmpty
          ? const <JourneyRouteStop>[]
          : await _repo
                .getRouteStops([for (final r in routes) r.id])
                .catchError((Object _) => const <JourneyRouteStop>[]);
      final partners = journey == null
          ? const <JourneyDiningPartner>[]
          : await _repo
                .getDiningPartners(journey.id)
                .catchError((Object _) => const <JourneyDiningPartner>[]);
      // Names only for the borders a route crosses; one country needs none.
      final stopCountries = {for (final s in stops) s.countryCode};
      final countryNames = stopCountries.length < 2
          ? const <String, String>{}
          : await resolveVenueCountries(_client, stopCountries)
                .then((list) => {for (final c in list) c.code: c.name})
                .catchError((Object _) => const <String, String>{});
      final uid = _userId;
      final wishlisted = (journey == null || uid == null)
          ? false
          : await _wishlistRepo
                .isJourneyWishlisted(userId: uid, journeyId: journey.id)
                .catchError((Object _) => false);
      final travels = (journey == null || uid == null)
          ? const <JourneyTravel>[]
          : await _repo
                .getMyTravels(userId: uid, journeyId: journey.id)
                .catchError((Object _) => const <JourneyTravel>[]);
      if (!mounted) return;
      setState(() {
        _journey = journey;
        _routes = routes;
        _stops = stops;
        _partners = partners;
        _countryNames = countryNames;
        _wishlisted = wishlisted;
        _travels = travels;
        _loading = false;
        _error = journey == null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = true;
      });
    }
  }

  void _snack(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: CsTypography.metadata.copyWith(color: AppColors.textOnDark),
        ),
        backgroundColor: isError ? AppColors.error : AppColors.forestGreen,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // Optimistic, reverted if the write fails — the same shape as the
  // restaurant and event wishlist toggles.
  Future<void> _toggleWishlist() async {
    final journey = _journey;
    final uid = _userId;
    if (journey == null) return;
    if (uid == null) {
      _snack('Sign in to save to your wishlist.', isError: true);
      return;
    }
    if (_wishlistBusy) return;
    final was = _wishlisted;
    setState(() {
      _wishlisted = !was;
      _wishlistBusy = true;
    });
    try {
      if (was) {
        await _wishlistRepo.removeJourney(userId: uid, journeyId: journey.id);
      } else {
        await _wishlistRepo.addJourney(userId: uid, journeyId: journey.id);
      }
      if (!mounted) return;
      setState(() => _wishlistBusy = false);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _wishlisted = was;
        _wishlistBusy = false;
      });
      _snack('Could not update. Please try again.', isError: true);
    }
  }

  Future<void> _confirmTravel() async {
    final journey = _journey;
    final uid = _userId;
    if (journey == null) return;
    if (uid == null) {
      _snack('Sign in to add this to your Passport.', isError: true);
      return;
    }
    final input = await showConfirmTravelSheet(
      context,
      journey: journey,
      routes: _routes,
    );
    if (input == null || !mounted) return;
    final JourneyTravel saved;
    try {
      saved = await _repo.confirmTravel(
        userId: uid,
        journeyId: journey.id,
        routeId: input.route?.id,
        departedOn: input.departedOn,
        arrivedOn: input.arrivedOn,
        visibility: input.visibility,
      );
    } catch (_) {
      if (!mounted) return;
      _snack('Could not save. Please try again.', isError: true);
      return;
    }
    if (!mounted) return;
    setState(() => _travels = [saved, ..._travels]);
    HapticFeedback.mediumImpact();
    await celebrateNewStamp(context, EarnedStamp.travel(saved));
  }

  Future<void> _editTravel(JourneyTravel travel) async {
    final journey = _journey;
    if (journey == null) return;
    final input = await showConfirmTravelSheet(
      context,
      journey: journey,
      routes: _routes,
      initial: travel,
    );
    if (input == null || !mounted) return;
    try {
      final saved = await _repo.updateTravel(
        travelId: travel.id,
        routeId: input.route?.id,
        departedOn: input.departedOn,
        arrivedOn: input.arrivedOn,
        visibility: input.visibility,
      );
      if (!mounted) return;
      setState(() {
        _travels = [for (final t in _travels) t.id == saved.id ? saved : t]
          ..sort((a, b) => b.departedOn.compareTo(a.departedOn));
      });
    } catch (_) {
      _snack('Could not save. Please try again.', isError: true);
    }
  }

  Future<void> _deleteTravel(JourneyTravel travel) async {
    final confirmed = await confirmDeletePassportEntry(
      context,
      title: 'Delete this journey?',
      body:
          'This journey and its stamp leave your Passport. '
          'Other times you travelled on it stay.',
      actionLabel: 'Delete journey',
    );
    if (!confirmed || !mounted) return;
    try {
      await _repo.deleteTravel(travel.id);
      if (!mounted) return;
      setState(
        () => _travels = [
          for (final t in _travels)
            if (t.id != travel.id) t,
        ],
      );
    } catch (_) {
      _snack('Could not delete journey. Please try again.', isError: true);
    }
  }

  // Shows the tapped route on the globe, bringing the globe back into view
  // when the list has scrolled it away.
  void _selectRoute(String routeId) {
    setState(() => _selectedRouteId = routeId);
    final globe = _globeKey.currentContext;
    if (globe != null) {
      Scrollable.ensureVisible(
        globe,
        // Clear of the status bar: the page scrolls under it.
        alignment: 0.12,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOutCubic,
      );
    }
  }

  Future<void> _openRestaurant(String id) async {
    final restaurant = await RestaurantRepository(
      _client,
    ).getById(id).catchError((Object _) => null);
    if (restaurant == null || !mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RestaurantDetailScreen(
          restaurant: restaurant,
          openSource: AnalyticsOpenSource.venue,
        ),
      ),
    );
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) => AnnotatedRegion<SystemUiOverlayStyle>(
    value: SystemUiOverlayStyle.light,
    child: Scaffold(backgroundColor: AppColors.ivory, body: _body()),
  );

  Widget _body() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(
          color: AppColors.forestGreen,
          strokeWidth: 1.5,
        ),
      );
    }
    final journey = _journey;
    if (_error || journey == null) {
      return SafeArea(
        child: Center(
          child: TextButton(
            onPressed: _load,
            child: Text(
              'Could not load. Tap to try again.',
              style: CsTypography.body.copyWith(color: AppColors.forestGreen),
            ),
          ),
        ),
      );
    }

    final summary = (journey.summary ?? '').trim();
    final drawable = drawableRouteStops(_stops);
    final drawnRoutes = [
      for (final route in _routes)
        if (drawable[route.id] != null) route,
    ];
    final selectedIndex = math.max(
      0,
      drawnRoutes.indexWhere((r) => r.id == _selectedRouteId),
    );
    final countryCodes = journeyCountryCodes(journey, _stops);
    final cabins = parseCabins(journey.cabinsText);
    final figures = journeyFigures(
      journey: journey,
      routes: _routes,
      cabins: cabins,
      countryCount: countryCodes.length,
    );
    // Named, counted cabin types make a manifest; any other cabins text
    // stays the operator's own sentence.
    final manifest = (cabins?.groups.any((g) => g.name != null) ?? false)
        ? cabins
        : null;
    final onBoard = [
      if ((journey.cabinsText ?? '').trim().isNotEmpty && manifest == null)
        journey.cabinsText!,
      if (journey.guestCapacity != null) '${journey.guestCapacity} guests',
    ];
    final dining = (journey.diningText ?? '').trim();
    final url = (journey.officialUrl ?? '').trim();

    return ListView(
      padding: EdgeInsets.zero,
      children: [
        JourneyDetailHero(
          journey: journey,
          wishlisted: _wishlisted,
          onToggleWishlist: _toggleWishlist,
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            CsSpacing.pageHorizontal,
            CsSpacing.xl,
            CsSpacing.pageHorizontal,
            CsSpacing.section,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (summary.isNotEmpty)
                Text(
                  summary,
                  style: CsTypography.editorialLead().copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),
              if (figures.isNotEmpty) ...[
                const SizedBox(height: CsSpacing.section),
                JourneyFigures(figures: figures),
              ],
              if (countryCodes.isNotEmpty || drawnRoutes.isNotEmpty) ...[
                _sectionTitle(
                  journey.kind == JourneyKind.ship
                      ? 'WHERE IT SAILS'
                      : 'WHERE IT RUNS',
                ),
                JourneyRouteGlobe(
                  key: _globeKey,
                  routes: [for (final r in drawnRoutes) drawable[r.id]!],
                  selectedIndex: selectedIndex,
                  countryCodes: countryCodes,
                ),
                if (drawnRoutes.isNotEmpty) ...[
                  const SizedBox(height: CsSpacing.xl),
                  JourneyItinerary(
                    route: drawnRoutes[selectedIndex],
                    stops: drawable[drawnRoutes[selectedIndex].id]!,
                    countryNames: _countryNames,
                  ),
                ],
              ],
              // A single drawn route is already named and laid out above.
              if (_routes.length > 1 ||
                  (_routes.isNotEmpty && drawnRoutes.isEmpty)) ...[
                _sectionTitle('ROUTES'),
                for (final route in _routes)
                  _RouteRow(
                    route: route,
                    // Markers only when there is a choice to make: more
                    // than one route, at least one of them drawn.
                    marker: drawnRoutes.isEmpty || _routes.length < 2
                        ? _RouteMarker.none
                        : drawable[route.id] == null
                        ? _RouteMarker.notDrawn
                        : route.id == drawnRoutes[selectedIndex].id
                        ? _RouteMarker.selected
                        : _RouteMarker.drawn,
                    onTap: drawable[route.id] == null || _routes.length < 2
                        ? null
                        : () => _selectRoute(route.id),
                  ),
              ],
              if (onBoard.isNotEmpty || manifest != null) ...[
                _sectionTitle('ON BOARD'),
                if (manifest != null) ...[
                  JourneyCabinManifest(layout: manifest, title: journey.name),
                  const SizedBox(height: CsSpacing.base),
                ],
                for (final line in onBoard) _bodyLine(line),
              ],
              if (dining.isNotEmpty || _partners.isNotEmpty) ...[
                _sectionTitle('THE TABLE ABOARD'),
                JourneyDining(
                  diningText: dining,
                  partners: _partners,
                  onOpenRestaurant: _openRestaurant,
                ),
              ],
              _sectionTitle('YOUR PASSPORT'),
              const SizedBox(height: CsSpacing.sm),
              JourneyPassportStamps(
                journey: journey,
                routes: _routes,
                travels: _travels,
              ),
              const SizedBox(height: CsSpacing.base),
              if (_travels.isEmpty)
                Center(
                  child: Text(
                    'Not yet in your Passport.',
                    style: CsTypography.editorialLead(
                      size: 16,
                    ).copyWith(color: AppColors.taupe),
                  ),
                )
              else
                for (final travel in _travels)
                  OwnPassportEntryRow(
                    text: _travelLine(travel),
                    editLabel: 'Edit journey',
                    deleteLabel: 'Delete journey',
                    onEdit: () => _editTravel(travel),
                    onDelete: () => _deleteTravel(travel),
                  ),
              const SizedBox(height: CsSpacing.base),
              CsPrimaryButton(
                label: 'I travelled on this',
                surface: CsSurface.light,
                onTap: _confirmTravel,
              ),
              if (url.isNotEmpty) ...[
                _sectionTitle('OPERATOR'),
                SubtleTextAction(
                  label: '${journey.operatorName} website',
                  onTap: () => _openUrl(url),
                  labelStyle: CsTypography.metadata.copyWith(
                    color: AppColors.forestGreen,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  String _travelLine(JourneyTravel travel) {
    final route = _routes
        .where((r) => r.id == travel.routeId)
        .map((r) => r.name)
        .firstOrNull;
    // With the year: a journey can be years back.
    final dates = travel.arrivedOn == null
        ? formatVenueVisitDate(travel.departedOn)
        : '${formatVenueVisitDate(travel.departedOn)} to '
              '${formatVenueVisitDate(travel.arrivedOn!)}';
    return route == null ? dates : '$route · $dates';
  }

  Widget _sectionTitle(String text) => Padding(
    padding: const EdgeInsets.only(
      top: CsSpacing.section,
      bottom: CsSpacing.md,
    ),
    child: Text(
      text,
      style: CsTypography.eyebrow.copyWith(color: AppColors.taupe),
    ),
  );

  Widget _bodyLine(String text) => Padding(
    padding: const EdgeInsets.only(bottom: CsSpacing.xs),
    child: Text(
      text,
      style: CsTypography.body.copyWith(color: AppColors.textPrimary),
    ),
  );
}

/// Whether a route row shows on the globe: the one drawn now, one that can
/// be drawn on a tap, one with no stops on record (text only), or no
/// marker at all when there is nothing to choose between.
enum _RouteMarker { none, selected, drawn, notDrawn }

class _RouteRow extends StatelessWidget {
  final JourneyRoute route;
  final _RouteMarker marker;
  final VoidCallback? onTap;

  const _RouteRow({
    required this.route,
    this.marker = _RouteMarker.none,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final details = [
      route.endpoints,
      ?route.lengthLabel,
      if ((route.seasonText ?? '').trim().isNotEmpty) route.seasonText!,
    ].join(' · ');
    final text = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          route.name,
          style: CsTypography.bodyMedium.copyWith(
            color: marker == _RouteMarker.notDrawn
                ? AppColors.textPrimary
                : AppColors.forestGreen,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          details,
          style: CsTypography.metadata.copyWith(color: AppColors.taupe),
        ),
      ],
    );
    if (marker == _RouteMarker.none) {
      return Padding(
        padding: const EdgeInsets.only(bottom: CsSpacing.md),
        child: text,
      );
    }
    return Semantics(
      button: onTap != null,
      selected: marker == _RouteMarker.selected,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: CsSpacing.sm),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: CsSpacing.lg,
                child: Padding(
                  padding: const EdgeInsets.only(top: 7),
                  child: _dot(),
                ),
              ),
              Expanded(child: text),
            ],
          ),
        ),
      ),
    );
  }

  // Filled: on the globe now. Ring: tap to show it. Nothing: no stops on
  // record, so it stays text.
  Widget _dot() => switch (marker) {
    _RouteMarker.selected => Container(
      width: 8,
      height: 8,
      decoration: const BoxDecoration(
        color: AppColors.forestGreen,
        shape: BoxShape.circle,
      ),
    ),
    _RouteMarker.drawn => Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.forestGreen),
      ),
    ),
    _ => const SizedBox(width: 8, height: 8),
  };
}
