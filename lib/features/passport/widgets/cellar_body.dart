import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/cs_spacing.dart';
import '../../../core/theme/cs_typography.dart';
import '../../../data/repositories/visit_wine_repository.dart';
import '../../vineyards/vineyard_detail_screen.dart';
import '../../visits/widgets/visit_wines.dart';
import '../models/cellar.dart';

/// The Passport's Cellar: every wine the member has logged, grouped by
/// region and estate, with the wines not linked to an estate kept apart,
/// exactly as written. A wine never makes a stamp; stamps come only from a
/// confirmed visit or event.
class CellarBody extends StatefulWidget {
  const CellarBody({super.key, this.repository});

  final VisitWineRepository? repository;

  @override
  State<CellarBody> createState() => _CellarBodyState();
}

class _CellarBodyState extends State<CellarBody> {
  late final VisitWineRepository _repo =
      widget.repository ?? VisitWineRepository(Supabase.instance.client);

  Cellar? _cellar;
  bool _loading = true;
  bool _error = false;

  String? get _userId => Supabase.instance.client.auth.currentUser?.id;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final uid = _userId;
    setState(() {
      _loading = true;
      _error = false;
    });
    if (uid == null) {
      setState(() {
        _cellar = const Cellar(regions: [], unlinked: []);
        _loading = false;
      });
      return;
    }
    try {
      final wines = await _repo.loadCellar(uid);
      if (!mounted) return;
      setState(() {
        _cellar = buildCellar(wines);
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

  void _openEstate(CellarEstate estate) => Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => VineyardDetailScreen(vineyardId: estate.vineyard.id),
    ),
  );

  @override
  Widget build(BuildContext context) =>
      ColoredBox(color: AppColors.deepGreen, child: _body());

  Widget _body() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(
          color: AppColors.textOnDark,
          strokeWidth: 1.5,
        ),
      );
    }
    final cellar = _cellar;
    if (_error || cellar == null) {
      return Center(
        child: TextButton(
          onPressed: _load,
          child: Text(
            'Could not load. Tap to try again.',
            style: CsTypography.body.copyWith(color: AppColors.textOnDark),
          ),
        ),
      );
    }
    if (cellar.isEmpty) return const _EmptyCellar();

    return RefreshIndicator(
      color: AppColors.textOnDark,
      backgroundColor: AppColors.greenSurface,
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
          CsSpacing.pageHorizontal,
          CsSpacing.base,
          CsSpacing.pageHorizontal,
          CsSpacing.section,
        ),
        children: [
          _CellarStats(cellar: cellar),
          for (final region in cellar.regions) ...[
            _label(
              '${region.label} · ${region.wineCount} '
              '${region.wineCount == 1 ? 'wine' : 'wines'}',
            ),
            for (final estate in region.estates)
              Padding(
                padding: const EdgeInsets.only(bottom: CsSpacing.md),
                child: _EstateCard(
                  estate: estate,
                  onTap: () => _openEstate(estate),
                ),
              ),
          ],
          if (cellar.unlinked.isNotEmpty) ...[
            _label(
              'Not linked to an estate · ${cellar.unlinked.length} '
              '${cellar.unlinked.length == 1 ? 'wine' : 'wines'}',
            ),
            _UnlinkedCard(wines: cellar.unlinked),
          ],
        ],
      ),
    );
  }

  Widget _label(String text) => Padding(
    padding: const EdgeInsets.only(top: CsSpacing.xl, bottom: CsSpacing.md),
    child: Text(
      text.toUpperCase(),
      style: CsTypography.eyebrow.copyWith(color: AppColors.secondaryOnDark),
    ),
  );
}

class _CellarStats extends StatelessWidget {
  const _CellarStats({required this.cellar});

  final Cellar cellar;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: _Stat(value: cellar.wineCount, unit: 'wines'),
      ),
      const SizedBox(width: CsSpacing.sm),
      Expanded(
        child: _Stat(value: cellar.estateCount, unit: 'estates'),
      ),
      const SizedBox(width: CsSpacing.sm),
      Expanded(
        child: _Stat(value: cellar.regionCount, unit: 'regions'),
      ),
    ],
  );
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.unit});

  final int value;
  final String unit;

  @override
  Widget build(BuildContext context) => Semantics(
    label: '$value $unit',
    excludeSemantics: true,
    child: Container(
      padding: const EdgeInsets.all(CsSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.greenSurface,
        borderRadius: BorderRadius.circular(CsRadius.medium),
        border: Border.all(color: AppColors.subtleBorderDark),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$value',
            style: CsTypography.largeMetric.copyWith(
              color: AppColors.textOnDark,
            ),
          ),
          Text(
            unit,
            style: CsTypography.metadata.copyWith(
              color: AppColors.secondaryOnDark,
            ),
          ),
        ],
      ),
    ),
  );
}

class _EstateCard extends StatelessWidget {
  const _EstateCard({required this.estate, required this.onTap});

  final CellarEstate estate;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final place = estate.vineyard.city;
    return Material(
      color: AppColors.warmWhite,
      borderRadius: BorderRadius.circular(CsRadius.card),
      child: InkWell(
        borderRadius: BorderRadius.circular(CsRadius.card),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(CsSpacing.base),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          estate.vineyard.name,
                          style: CsTypography.placeTitle.copyWith(
                            color: AppColors.forestGreen,
                          ),
                        ),
                        if ((place ?? '').isNotEmpty)
                          Text(
                            place!,
                            style: CsTypography.metadata.copyWith(
                              color: AppColors.taupe,
                            ),
                          ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: AppColors.taupe,
                    size: 20,
                  ),
                ],
              ),
              const SizedBox(height: CsSpacing.sm),
              WineList(wines: [for (final w in estate.wines) w.wine]),
            ],
          ),
        ),
      ),
    );
  }
}

/// The wines kept as written: shown as the member wrote them, on a quieter
/// dashed-feeling card, with a line saying they can be linked any time.
class _UnlinkedCard extends StatelessWidget {
  const _UnlinkedCard({required this.wines});

  final List<CellarWine> wines;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(CsSpacing.base),
    decoration: BoxDecoration(
      color: AppColors.warmWhite.withValues(alpha: 0.92),
      borderRadius: BorderRadius.circular(CsRadius.card),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        WineList(wines: [for (final w in wines) w.wine]),
        const SizedBox(height: CsSpacing.sm),
        Text(
          'Your own notes stay exactly as you wrote them. Open a wine on its '
          'visit to link it to an estate whenever you like.',
          style: CsTypography.metadata.copyWith(color: AppColors.taupe),
        ),
      ],
    ),
  );
}

class _EmptyCellar extends StatelessWidget {
  const _EmptyCellar();

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: CsSpacing.pageHorizontal),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Your cellar is empty',
            textAlign: TextAlign.center,
            style: CsTypography.sectionTitle.copyWith(
              color: AppColors.textOnDark,
            ),
          ),
          const SizedBox(height: CsSpacing.sm),
          Text(
            'Add the wines you drank to a visit, and they gather here by '
            'region and estate.',
            textAlign: TextAlign.center,
            style: CsTypography.body.copyWith(color: AppColors.secondaryOnDark),
          ),
        ],
      ),
    ),
  );
}
