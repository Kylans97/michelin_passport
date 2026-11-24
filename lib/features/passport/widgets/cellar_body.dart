import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/cs_spacing.dart';
import '../../../core/theme/cs_typography.dart';
import '../../../data/repositories/visit_wine_repository.dart';
import '../../vineyards/vineyard_detail_screen.dart';
import '../../visits/widgets/visit_wines.dart';
import '../models/cellar.dart';

/// The Passport's Cellar: every wine the member has logged, from visits
/// and kept without one, grouped by region and estate, with the wines not
/// linked to an estate kept apart, exactly as written. One quiet filter
/// keeps the wines the member would drink again. A wine never makes a
/// stamp; stamps come only from a confirmed visit or event.
class CellarBody extends StatefulWidget {
  const CellarBody({super.key, this.repository});

  final VisitWineRepository? repository;

  @override
  State<CellarBody> createState() => _CellarBodyState();
}

class _CellarBodyState extends State<CellarBody> {
  late final VisitWineRepository _repo =
      widget.repository ?? VisitWineRepository(Supabase.instance.client);

  List<CellarWine> _wines = const [];
  bool _againOnly = false;
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
        _wines = const [];
        _loading = false;
      });
      return;
    }
    try {
      final wines = await _repo.loadCellar(uid);
      if (!mounted) return;
      setState(() {
        _wines = wines;
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

  void _failed() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Could not save that. Please try again.')),
    );
  }

  Future<WineSuggestions> _suggestions(String userId) => _repo
      .loadSuggestions(userId)
      .catchError((Object _) => const WineSuggestions());

  /// A wine drunk without a restaurant visit: at home, at an estate,
  /// somewhere else.
  Future<void> _addKept() async {
    final uid = _userId;
    if (uid == null) return;
    var added = false;
    await showWineSheet(
      context,
      keptWithoutVisit: true,
      suggestions: _suggestions(uid),
      searchVineyards: searchVineyardsForWineSheet,
      onSave: (wine) async {
        try {
          await _repo.addKept(userId: uid, wine: wine);
          added = true;
          return true;
        } catch (_) {
          _failed();
          return false;
        }
      },
    );
    if (added) await _load();
  }

  /// Opens a wine to change it: its verdict and note, or anything else.
  Future<void> _edit(CellarWine entry) async {
    final uid = _userId;
    final existing = entry.wine;
    final id = existing.id;
    if (uid == null || id == null) return;
    final kept = entry.isKeptWithoutVisit;
    var changed = false;
    await showWineSheet(
      context,
      initial: existing,
      keptWithoutVisit: kept,
      suggestions: _suggestions(uid),
      searchVineyards: searchVineyardsForWineSheet,
      onSave: (wine) async {
        try {
          if (kept) {
            await _repo.updateKept(id, wine);
          } else {
            await _repo.update(id, wine, previous: existing);
          }
          changed = true;
          return true;
        } catch (_) {
          _failed();
          return false;
        }
      },
      onDelete: () async {
        try {
          await (kept ? _repo.deleteKept(id) : _repo.delete(id));
          changed = true;
        } catch (_) {
          _failed();
        }
      },
    );
    if (changed) await _load();
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
    if (_error) {
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
    if (_wines.isEmpty) return _EmptyCellar(onAdd: _addKept);
    final whole = buildCellar(_wines);
    final again = [
      for (final w in _wines)
        if (w.wine.wouldDrinkAgain) w,
    ];
    final cellar = _againOnly ? buildCellar(again) : whole;

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
          _CellarStats(cellar: whole),
          const SizedBox(height: CsSpacing.lg),
          Align(
            alignment: Alignment.centerLeft,
            child: _CellarFilter(
              againOnly: _againOnly,
              againCount: again.length,
              onChanged: (v) => setState(() => _againOnly = v),
            ),
          ),
          if (_againOnly && again.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: CsSpacing.xl),
              child: Text(
                'Open a wine and choose Would drink again, and it shows here.',
                style: CsTypography.body.copyWith(
                  color: AppColors.secondaryOnDark,
                ),
              ),
            ),
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
                  onTapWine: _edit,
                ),
              ),
          ],
          if (cellar.unlinked.isNotEmpty) ...[
            _label(
              'Not linked to an estate · ${cellar.unlinked.length} '
              '${cellar.unlinked.length == 1 ? 'wine' : 'wines'}',
            ),
            _UnlinkedCard(wines: cellar.unlinked, onTapWine: _edit),
          ],
          const SizedBox(height: CsSpacing.lg),
          Align(
            alignment: Alignment.centerLeft,
            child: _AddWine(onTap: _addKept),
          ),
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
  const _EstateCard({
    required this.estate,
    required this.onTap,
    required this.onTapWine,
  });

  final CellarEstate estate;
  final VoidCallback onTap;
  final ValueChanged<CellarWine> onTapWine;

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
              WineList(
                wines: [for (final w in estate.wines) w.wine],
                onTapWine: (i) => onTapWine(estate.wines[i]),
              ),
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
  const _UnlinkedCard({required this.wines, required this.onTapWine});

  final List<CellarWine> wines;
  final ValueChanged<CellarWine> onTapWine;

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
        WineList(
          wines: [for (final w in wines) w.wine],
          onTapWine: (i) => onTapWine(wines[i]),
        ),
        const SizedBox(height: CsSpacing.sm),
        Text(
          'Your own notes stay exactly as you wrote them. Open a wine to link '
          'it to an estate whenever you like.',
          style: CsTypography.metadata.copyWith(color: AppColors.taupe),
        ),
      ],
    ),
  );
}

class _EmptyCellar extends StatelessWidget {
  const _EmptyCellar({required this.onAdd});

  final VoidCallback onAdd;

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
            'Add the wines you drank to a visit, or one you had at home, and '
            'they gather here by region and estate.',
            textAlign: TextAlign.center,
            style: CsTypography.body.copyWith(color: AppColors.secondaryOnDark),
          ),
          const SizedBox(height: CsSpacing.lg),
          _AddWine(onTap: onAdd),
        ],
      ),
    ),
  );
}

/// The Cellar's one filter: every wine, or the ones the member would
/// drink again. A filter, never a different sort.
class _CellarFilter extends StatelessWidget {
  const _CellarFilter({
    required this.againOnly,
    required this.againCount,
    required this.onChanged,
  });

  final bool againOnly;
  final int againCount;
  final ValueChanged<bool> onChanged;

  Widget _option(String label, bool selected, VoidCallback onTap) => Semantics(
    button: true,
    selected: selected,
    child: GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? AppColors.ivory : Colors.transparent,
          borderRadius: BorderRadius.circular(99),
        ),
        child: Text(
          label,
          style: CsTypography.metadata.copyWith(
            color: selected ? AppColors.deepGreen : AppColors.secondaryOnDark,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(3),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(99),
      border: Border.all(color: AppColors.subtleBorderDark),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _option('All wines', !againOnly, () => onChanged(false)),
        _option(
          againCount > 0
              ? 'Would drink again · $againCount'
              : 'Would drink again',
          againOnly,
          () => onChanged(true),
        ),
      ],
    ),
  );
}

/// Adding a wine from the Cellar itself, without a visit.
class _AddWine extends StatelessWidget {
  const _AddWine({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => TextButton.icon(
    onPressed: onTap,
    style: TextButton.styleFrom(foregroundColor: AppColors.textOnDark),
    icon: const Icon(Icons.add_rounded, size: 18),
    label: Text(
      'Add a wine',
      style: CsTypography.bodyMedium.copyWith(color: AppColors.textOnDark),
    ),
  );
}
