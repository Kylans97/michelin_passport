import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants/app_colors.dart';
import '../../core/theme/cs_spacing.dart';
import '../../core/theme/cs_surface_context.dart';
import '../../core/theme/cs_typography.dart';
import '../../core/widgets/cs_filter_chip.dart';
import '../../core/widgets/editorial_back_button.dart';
import '../../data/repositories/journey_repository.dart';
import '../../models/journey.dart';
import 'journey_detail_screen.dart';
import 'widgets/journey_card.dart';

/// Trains & Ships — the collection of luxury trains and small ships, the
/// same masthead-over-ivory shape as [PrivateChefsScreen]. One quiet
/// filter row (All / Trains / Ships) and nothing else: the collection is
/// small and curated, so there is no search, sort or badge here.
class JourneysScreen extends StatefulWidget {
  const JourneysScreen({super.key});

  @override
  State<JourneysScreen> createState() => _JourneysScreenState();
}

class _JourneysScreenState extends State<JourneysScreen> {
  late final _repo = JourneyRepository(Supabase.instance.client);
  List<Journey>? _journeys;
  JourneyKind? _kind;
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
      final journeys = await _repo.getPublishedJourneys();
      if (!mounted) return;
      setState(() {
        _journeys = journeys;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = true;
      });
    }
  }

  void _open(Journey journey) => Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => JourneyDetailScreen(journeyId: journey.id),
    ),
  );

  @override
  Widget build(BuildContext context) => AnnotatedRegion<SystemUiOverlayStyle>(
    value: SystemUiOverlayStyle.light,
    child: Scaffold(
      backgroundColor: AppColors.deepGreen,
      body: Column(
        children: [
          SafeArea(
            bottom: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: CsSpacing.base),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: EditorialBackButton(color: AppColors.ivory),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    CsSpacing.pageHorizontal,
                    CsSpacing.xs,
                    CsSpacing.pageHorizontal,
                    CsSpacing.base,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Trains & Ships',
                        style: CsTypography.screenTitle.copyWith(
                          color: AppColors.ivory,
                        ),
                      ),
                      const SizedBox(height: CsSpacing.xs),
                      Text(
                        'Journeys worth planning a trip around.',
                        style: CsTypography.body.copyWith(
                          color: AppColors.secondaryOnDark,
                        ),
                      ),
                      const SizedBox(height: CsSpacing.base),
                      Row(
                        children: [
                          _chip('All', null),
                          const SizedBox(width: CsSpacing.sm),
                          _chip('Trains', JourneyKind.train),
                          const SizedBox(width: CsSpacing.sm),
                          _chip('Ships', JourneyKind.ship),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ColoredBox(
              color: AppColors.ivory,
              child: SafeArea(top: false, child: _body()),
            ),
          ),
        ],
      ),
    ),
  );

  Widget _chip(String label, JourneyKind? kind) => CsFilterChip(
    label: label,
    selected: _kind == kind,
    surface: CsSurface.dark,
    onTap: () => setState(() => _kind = kind),
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
    if (_error) {
      return Center(
        child: TextButton(
          onPressed: _load,
          child: Text(
            'Could not load. Tap to try again.',
            style: CsTypography.body.copyWith(color: AppColors.forestGreen),
          ),
        ),
      );
    }
    final journeys = journeysOfKind(_journeys ?? const [], _kind);
    if (journeys.isEmpty) {
      return Center(
        child: Text(
          'Nothing here yet.',
          style: CsTypography.body.copyWith(color: AppColors.taupe),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(
        CsSpacing.pageHorizontal,
        CsSpacing.lg,
        CsSpacing.pageHorizontal,
        CsSpacing.section,
      ),
      itemCount: journeys.length,
      separatorBuilder: (_, _) => const SizedBox(height: CsSpacing.base),
      itemBuilder: (_, i) =>
          JourneyCard(journey: journeys[i], onTap: () => _open(journeys[i])),
    );
  }
}
