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
import '../../core/widgets/linked_venue_row.dart';
import '../../core/widgets/subtle_text_action.dart';
import '../../data/repositories/journey_repository.dart';
import '../../data/repositories/restaurant_repository.dart';
import '../../data/repositories/wishlist_repository.dart';
import '../../models/journey.dart';
import '../passport/stamp_ceremony.dart';
import '../restaurants/restaurant_detail_screen.dart';
import 'widgets/confirm_travel_sheet.dart';
import 'widgets/journey_detail_hero.dart';

/// A train's or ship's own page: hero, what it is, its routes, life on
/// board, dining partners in the catalogue, the member's own travels with
/// "I travelled on this", and the operator's website. Everything shown is
/// the operator's published fact or our starting text; nothing is
/// inferred, and nothing here is gold.
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
  List<({String id, String name})> _partners = const [];
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
      final partners = journey == null
          ? const <({String id, String name})>[]
          : await _repo
                .getDiningPartners(journey.id)
                .catchError((Object _) => const <({String id, String name})>[]);
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
        _partners = partners;
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
    final onBoard = [
      if ((journey.cabinsText ?? '').trim().isNotEmpty) journey.cabinsText!,
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
              if (_routes.isNotEmpty) ...[
                _sectionTitle('ROUTES'),
                for (final route in _routes) _RouteRow(route: route),
              ],
              if (onBoard.isNotEmpty) ...[
                _sectionTitle('ON BOARD'),
                for (final line in onBoard) _bodyLine(line),
              ],
              if (dining.isNotEmpty) ...[
                _sectionTitle('DINING'),
                _bodyLine(dining),
              ],
              if (_partners.isNotEmpty) ...[
                const SizedBox(height: CsSpacing.md),
                for (final partner in _partners)
                  Padding(
                    padding: const EdgeInsets.only(bottom: CsSpacing.sm),
                    child: LinkedVenueRow(
                      name: partner.name,
                      onTap: () => _openRestaurant(partner.id),
                    ),
                  ),
              ],
              _sectionTitle('YOUR PASSPORT'),
              if (_travels.isEmpty)
                _bodyLine('Travelled on it? Add it to your Passport.')
              else
                for (final travel in _travels) _bodyLine(_travelLine(travel)),
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
    final loc = MaterialLocalizations.of(context);
    final route = _routes
        .where((r) => r.id == travel.routeId)
        .map((r) => r.name)
        .firstOrNull;
    final dates = travel.arrivedOn == null
        ? loc.formatMediumDate(travel.departedOn)
        : '${loc.formatMediumDate(travel.departedOn)} – '
              '${loc.formatMediumDate(travel.arrivedOn!)}';
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

class _RouteRow extends StatelessWidget {
  final JourneyRoute route;

  const _RouteRow({required this.route});

  @override
  Widget build(BuildContext context) {
    final details = [
      route.endpoints,
      ?route.lengthLabel,
      if ((route.seasonText ?? '').trim().isNotEmpty) route.seasonText!,
    ].join(' · ');
    return Padding(
      padding: const EdgeInsets.only(bottom: CsSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            route.name,
            style: CsTypography.bodyMedium.copyWith(
              color: AppColors.forestGreen,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            details,
            style: CsTypography.metadata.copyWith(color: AppColors.taupe),
          ),
        ],
      ),
    );
  }
}
