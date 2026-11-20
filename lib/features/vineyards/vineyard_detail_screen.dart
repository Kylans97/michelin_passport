import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/analytics/analytics_properties.dart';
import '../../core/constants/app_colors.dart';
import '../../core/theme/cs_spacing.dart';
import '../../core/theme/cs_typography.dart';
import '../../core/widgets/subtle_text_action.dart';
import '../../data/repositories/events_repository.dart';
import '../../data/repositories/vineyard_repository.dart';
import '../../data/repositories/visit_wine_repository.dart';
import '../../models/event.dart';
import '../../models/vineyard.dart';
import '../events/event_detail_screen.dart';
import '../events/widgets/hosted_events_section.dart';
import '../visits/widgets/visit_wines.dart';
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

  Vineyard? _vineyard;
  List<CellarWine> _myWines = const [];
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
      if (!mounted) return;
      setState(() {
        _vineyard = vineyard;
        _myWines = myWines;
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
        VineyardDetailHero(vineyard: vineyard),
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
              if (_myWines.isNotEmpty) ...[
                _sectionTitle('IN YOUR PASSPORT'),
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

/// The member's own wines from this estate, newest first, and how many
/// evenings they came from.
class _MyWinesCard extends StatelessWidget {
  final List<CellarWine> wines;

  const _MyWinesCard({required this.wines});

  @override
  Widget build(BuildContext context) {
    final evenings = {for (final w in wines) w.visitId}.length;
    final count =
        '${wines.length} ${wines.length == 1 ? 'wine' : 'wines'} · '
        '$evenings ${evenings == 1 ? 'evening' : 'evenings'}';
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
          Text(
            count,
            style: CsTypography.metadata.copyWith(
              color: AppColors.claret,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: CsSpacing.sm),
          WineList(wines: [for (final w in wines) w.wine]),
        ],
      ),
    );
  }
}
