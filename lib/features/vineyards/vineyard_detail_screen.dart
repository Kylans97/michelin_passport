import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/analytics/analytics_properties.dart';
import '../../core/constants/app_colors.dart';
import '../../core/theme/cs_spacing.dart';
import '../../core/theme/cs_typography.dart';
import '../../core/theme/cs_surface_context.dart';
import '../../core/widgets/cs_primary_button.dart';
import '../../core/widgets/subtle_text_action.dart';
import '../../core/widgets/venue_visit_row.dart' show formatVenueVisitDate;
import '../../data/repositories/events_repository.dart';
import '../../data/repositories/vineyard_repository.dart';
import '../../data/repositories/visit_wine_repository.dart';
import '../../data/repositories/wishlist_repository.dart';
import '../../models/event.dart';
import '../../models/vineyard.dart';
import '../../models/vineyard_visit.dart';
import '../events/event_detail_screen.dart';
import '../events/widgets/hosted_events_section.dart';
import '../passport/widgets/own_passport_entry_row.dart';
import '../visits/widgets/visit_wines.dart';
import 'log_estate_visit.dart';
import 'widgets/log_estate_visit_sheet.dart';
import 'widgets/vineyard_detail_hero.dart';

/// A wine estate's own page: hero, its World's 50 Best Vineyards rank, the
/// member's own wines from it, the events it pours at, where it is and its
/// website. Only verified facts and the member's own notes: the estate's
/// description and photos come from the estate after review, and until
/// then that space stays quiet rather than showing text we wrote.
class VineyardDetailScreen extends StatefulWidget {
  final String vineyardId;

  const VineyardDetailScreen({super.key, required this.vineyardId});

  @override
  State<VineyardDetailScreen> createState() => _VineyardDetailScreenState();
}

class _VineyardDetailScreenState extends State<VineyardDetailScreen> {
  final _client = Supabase.instance.client;
  late final _repo = VineyardRepository(_client);
  late final _wineRepo = VisitWineRepository(_client);
  late final _eventsRepo = EventsRepository(_client);
  late final _wishlistRepo = WishlistRepository(_client);

  Vineyard? _vineyard;
  List<CellarWine> _myWines = const [];
  List<VineyardVisit> _myVisits = const [];
  bool _wishlisted = false;
  bool _wishlistBusy = false;
  List<Event> _events = const [];
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
      final vineyard = await _repo.getById(widget.vineyardId);
      // The member's wines and the events are enhancements: a failed
      // lookup leaves its section out, never the whole page in error.
      final uid = _client.auth.currentUser?.id;
      final myWines = (vineyard == null || uid == null)
          ? const <CellarWine>[]
          : await _wineRepo
                .loadForVineyard(userId: uid, vineyardId: vineyard.id)
                .catchError((Object _) => const <CellarWine>[]);
      final events = vineyard == null
          ? const <Event>[]
          : await _eventsRepo
                .loadEventsForVineyard(vineyard.id)
                .catchError((Object _) => const <Event>[]);
      // Both read tables the estates-wishlist migration adds; before it is
      // applied they fail, and the page shows no visits and an empty heart.
      final myVisits = (vineyard == null || uid == null)
          ? const <VineyardVisit>[]
          : await _repo
                .getMyVisits(userId: uid, vineyardId: vineyard.id)
                .catchError((Object _) => const <VineyardVisit>[]);
      final wishlisted = (vineyard == null || uid == null)
          ? false
          : await _wishlistRepo
                .isVineyardWishlisted(userId: uid, vineyardId: vineyard.id)
                .catchError((Object _) => false);
      if (!mounted) return;
      setState(() {
        _vineyard = vineyard;
        _myWines = myWines;
        _myVisits = myVisits;
        _wishlisted = wishlisted;
        _events = events;
        _loading = false;
        _error = vineyard == null;
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
  // journey, restaurant and event wishlist toggles.
  Future<void> _toggleWishlist() async {
    final vineyard = _vineyard;
    final uid = _client.auth.currentUser?.id;
    if (vineyard == null) return;
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
        await _wishlistRepo.removeVineyard(
          userId: uid,
          vineyardId: vineyard.id,
        );
      } else {
        await _wishlistRepo.addVineyard(userId: uid, vineyardId: vineyard.id);
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

  Future<void> _logVisit() async {
    final vineyard = _vineyard;
    if (vineyard == null) return;
    final saved = await logEstateVisit(context, vineyard: vineyard);
    if (saved == null || !mounted) return;
    setState(() => _myVisits = [saved, ..._myVisits]);
  }

  Future<void> _editVisit(VineyardVisit visit) async {
    final vineyard = _vineyard;
    if (vineyard == null) return;
    final input = await showLogEstateVisitSheet(
      context,
      vineyard: vineyard,
      initial: visit,
    );
    if (input == null || !mounted) return;
    try {
      final saved = await _repo.updateVisit(
        visitId: visit.id,
        visitedOn: input.visitedOn,
        activities: input.activities,
        comment: input.comment,
        friendsVisible: input.friendsVisible,
      );
      if (!mounted) return;
      setState(() {
        _myVisits = [for (final v in _myVisits) v.id == saved.id ? saved : v]
          ..sort((a, b) => b.visitedOn.compareTo(a.visitedOn));
      });
    } catch (_) {
      _snack('Could not save. Please try again.', isError: true);
    }
  }

  Future<void> _deleteVisit(VineyardVisit visit) async {
    final confirmed = await confirmDeletePassportEntry(
      context,
      title: 'Delete this visit?',
      body:
          'This visit and its stamp leave your Passport, with your note. '
          'Other visits to this estate and the wines you noted stay.',
      actionLabel: 'Delete visit',
    );
    if (!confirmed || !mounted) return;
    try {
      await _repo.deleteVisit(visit.id);
      if (!mounted) return;
      setState(
        () => _myVisits = [
          for (final v in _myVisits)
            if (v.id != visit.id) v,
        ],
      );
    } catch (_) {
      _snack('Could not delete visit. Please try again.', isError: true);
    }
  }

  String _visitLine(VineyardVisit visit) {
    // With the year: a visit can be years back.
    final date = formatVenueVisitDate(visit.visitedOn);
    final did = [
      for (final a in VineyardActivity.values)
        if (visit.activities.contains(a)) a.label.toLowerCase(),
    ];
    return did.isEmpty ? date : '$date · ${did.join(', ')}';
  }

  void _openEvent(Event event) => Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => EventDetailScreen(
        eventId: event.id,
        openSource: AnalyticsOpenSource.venue,
      ),
    ),
  );

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
    final vineyard = _vineyard;
    if (_error || vineyard == null) {
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

    final rank = vineyard.rankLabel;
    final address = (vineyard.address ?? '').trim();
    final url = (vineyard.websiteUrl ?? '').trim();

    return ListView(
      padding: EdgeInsets.zero,
      children: [
        VineyardDetailHero(
          vineyard: vineyard,
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
              if (rank != null)
                Text(
                  rank,
                  style: CsTypography.bodyMedium.copyWith(
                    color: AppColors.claret,
                  ),
                ),
              if (vineyard.isPermanentlyClosed) ...[
                const SizedBox(height: CsSpacing.sm),
                Text(
                  'Permanently closed',
                  style: CsTypography.metadata.copyWith(color: AppColors.taupe),
                ),
              ],
              _sectionTitle('IN YOUR PASSPORT'),
              if (_myVisits.isEmpty)
                Text(
                  'Visited the estate? Add it to your Passport.',
                  style: CsTypography.body.copyWith(
                    color: AppColors.textPrimary,
                  ),
                )
              else
                for (final visit in _myVisits)
                  OwnPassportEntryRow(
                    text: _visitLine(visit),
                    editLabel: 'Edit visit',
                    deleteLabel: 'Delete visit',
                    onEdit: () => _editVisit(visit),
                    onDelete: () => _deleteVisit(visit),
                  ),
              const SizedBox(height: CsSpacing.base),
              CsPrimaryButton(
                label: 'I visited this estate',
                surface: CsSurface.light,
                onTap: _logVisit,
              ),
              if (_myWines.isNotEmpty) ...[
                const SizedBox(height: CsSpacing.lg),
                _MyWinesCard(wines: _myWines),
              ],
              if (_events.isNotEmpty) ...[
                const SizedBox(height: CsSpacing.section),
                HostedEventsSection(events: _events, onTapEvent: _openEvent),
              ],
              if (address.isNotEmpty) ...[
                _sectionTitle('LOCATION'),
                Text(
                  address,
                  style: CsTypography.body.copyWith(
                    color: AppColors.forestGreen,
                  ),
                ),
              ],
              if (url.isNotEmpty) ...[
                _sectionTitle('THE ESTATE'),
                SubtleTextAction(
                  label: 'Estate website',
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
}

/// The member's own wines from this estate, newest first, how many there
/// are and, when there are any, how many they would drink again: the line
/// that later leads to the estate's own shop.
class _MyWinesCard extends StatelessWidget {
  final List<CellarWine> wines;

  const _MyWinesCard({required this.wines});

  @override
  Widget build(BuildContext context) {
    final again = wines.where((w) => w.wine.wouldDrinkAgain).length;
    final latest = wines
        .map((w) => w.date)
        .nonNulls
        .fold<DateTime?>(null, (a, b) => a == null || b.isAfter(a) ? b : a);
    final count = [
      '${wines.length} ${wines.length == 1 ? 'wine' : 'wines'}',
      if (latest != null)
        'last on ${MaterialLocalizations.of(context).formatMediumDate(latest)}',
    ].join(' · ');
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(CsSpacing.base),
      decoration: BoxDecoration(
        color: AppColors.warmWhite,
        borderRadius: BorderRadius.circular(CsRadius.medium),
        border: Border.all(color: AppColors.subtleBorderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (again > 0) ...[
            Text(
              wouldDrinkAgainLine(again),
              style: CsTypography.placeTitle.copyWith(color: AppColors.claret),
            ),
            const SizedBox(height: 2),
          ],
          Text(
            count,
            style: CsTypography.metadata.copyWith(
              color: again > 0 ? AppColors.taupe : AppColors.claret,
              fontWeight: again > 0 ? FontWeight.w400 : FontWeight.w600,
            ),
          ),
          const SizedBox(height: CsSpacing.sm),
          WineList(wines: [for (final w in wines) w.wine]),
        ],
      ),
    );
  }
}

/// "You'd drink 2 of their wines again", for an estate's page.
String wouldDrinkAgainLine(int count) => count == 1
    ? "You'd drink one of their wines again"
    : "You'd drink $count of their wines again";
