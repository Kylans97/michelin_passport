import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/cs_spacing.dart';
import '../../../core/theme/cs_typography.dart';
import '../../../data/repositories/profile_repository.dart';
import '../../../data/repositories/visit_wine_repository.dart';
import '../../profile/privacy_settings_screen.dart';
import '../../vineyards/vineyard_detail_screen.dart';
import '../../visits/widgets/visit_wines.dart';
import '../models/cellar.dart';

/// The Passport's Cellar: every wine the member has logged, from visits
/// and kept without one, grouped by region and estate, with the wines not
/// linked to an estate kept apart, exactly as written. One quiet filter
/// keeps the wines the member would drink again. A wine never makes a
/// stamp; stamps come only from a confirmed visit or event.
///
/// Given a friend's [ownerId] it is that friend's Cellar, read only: the
/// Cellar tab on their profile (product owner, 2026-11-24). The same
/// screen, so it never drifts from what they see themselves. No edit
/// sheet, no Add a wine; a friend who keeps their Cellar private
/// (`can_see_cellar`, 20261101730000) shows only that.
class CellarBody extends StatefulWidget {
  const CellarBody({
    super.key,
    this.repository,
    this.ownerId,
    this.ownerFirstName,
    this.visitPlaceById = const {},
    this.loadCellarShared,
  });

  final VisitWineRepository? repository;

  /// A friend's id for their Cellar tab; null for the member's own.
  final String? ownerId;

  /// The friend's first name, for the private and empty lines.
  final String? ownerFirstName;

  /// Where each of the friend's shared visits was ("De Librije"), by
  /// visit id, for the line under a wine. Already loaded by the profile.
  final Map<String, String> visitPlaceById;

  /// The member's own Share my Cellar switch, for the line at the foot.
  /// Defaults to [ProfileRepository.getCellarShared].
  final Future<bool?> Function()? loadCellarShared;

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

  /// A friend's Cellar they keep private.
  bool _hidden = false;

  /// The member's own switch; null while unknown or before the migration.
  bool? _shared;

  String? get _userId => Supabase.instance.client.auth.currentUser?.id;

  /// A friend's Cellar: read only.
  bool get _isFriend {
    final owner = widget.ownerId;
    return owner != null && owner != _userId;
  }

  String get _friendName => widget.ownerFirstName ?? 'Your friend';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final uid = _isFriend ? widget.ownerId : _userId;
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
      if (_isFriend && !await _repo.canSeeCellar(uid)) {
        if (!mounted) return;
        setState(() {
          _hidden = true;
          _wines = const [];
          _loading = false;
        });
        return;
      }
      final wines = await _repo.loadCellar(uid);
      if (!_isFriend) _loadShared(uid);
      if (!mounted) return;
      setState(() {
        _hidden = false;
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

  Future<void> _loadShared(String uid) async {
    try {
      final load =
          widget.loadCellarShared ??
          () =>
              ProfileRepository(Supabase.instance.client).getCellarShared(uid);
      final shared = await load();
      if (mounted) setState(() => _shared = shared);
    } catch (_) {
      // The line at the foot simply stays out.
    }
  }

  Future<void> _openPrivacy() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const PrivacySettingsScreen()),
    );
    final uid = _userId;
    if (uid != null) await _loadShared(uid);
  }

  /// Where and when, under a friend's wine: the venue of the shared visit
  /// and its day, or the day a kept wine was drunk (its place is already
  /// on the line above).
  String? _detail(CellarWine w) {
    if (!_isFriend) return null;
    final day = w.date == null ? null : _shortDate(w.date!);
    final place = w.visitId == null ? null : widget.visitPlaceById[w.visitId];
    if (place != null) return day == null ? 'At $place' : 'At $place, $day';
    return day;
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
    if (_isFriend && _hidden) {
      return _FriendNote(
        icon: Icons.lock_outline_rounded,
        title: "$_friendName's Cellar is private.",
        body: 'The wines on visits they share still show on those visits.',
      );
    }
    if (_isFriend && _wines.isEmpty) {
      return _FriendNote(title: "$_friendName hasn't shared any wines yet.");
    }
    if (_wines.isEmpty) return _EmptyCellar(onAdd: _addKept);
    final onTapWine = _isFriend ? null : _edit;
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
                  onTapWine: onTapWine,
                  detail: _detail,
                ),
              ),
          ],
          if (cellar.unlinked.isNotEmpty) ...[
            _label(
              'Not linked to an estate · ${cellar.unlinked.length} '
              '${cellar.unlinked.length == 1 ? 'wine' : 'wines'}',
            ),
            _UnlinkedCard(
              wines: cellar.unlinked,
              onTapWine: onTapWine,
              detail: _detail,
              ownNotes: !_isFriend,
            ),
          ],
          if (!_isFriend) ...[
            const SizedBox(height: CsSpacing.lg),
            Align(
              alignment: Alignment.centerLeft,
              child: _AddWine(onTap: _addKept),
            ),
            if (_shared != null)
              _SharingLine(shared: _shared!, onChange: _openPrivacy),
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
  const _EstateCard({
    required this.estate,
    required this.onTap,
    required this.onTapWine,
    required this.detail,
  });

  final CellarEstate estate;
  final VoidCallback onTap;

  /// Null on a friend's Cellar: read only.
  final ValueChanged<CellarWine>? onTapWine;
  final String? Function(CellarWine) detail;

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
                onTapWine: onTapWine == null
                    ? null
                    : (i) => onTapWine!(estate.wines[i]),
                details: [for (final w in estate.wines) detail(w)],
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
  const _UnlinkedCard({
    required this.wines,
    required this.onTapWine,
    required this.detail,
    required this.ownNotes,
  });

  final List<CellarWine> wines;
  final ValueChanged<CellarWine>? onTapWine;
  final String? Function(CellarWine) detail;

  /// The member's own Cellar: says the wines can be linked to an estate.
  final bool ownNotes;

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
          onTapWine: onTapWine == null ? null : (i) => onTapWine!(wines[i]),
          details: [for (final w in wines) detail(w)],
        ),
        if (ownNotes) ...[
          const SizedBox(height: CsSpacing.sm),
          Text(
            'Your own notes stay exactly as you wrote them. Open a wine to '
            'link it to an estate whenever you like.',
            style: CsTypography.metadata.copyWith(color: AppColors.taupe),
          ),
        ],
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

/// What friends see of the member's Cellar, at its foot, opening the
/// switch in Privacy.
const _shortMonths = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

/// "11 Nov 2025", as the friend profile's verdicts read.
String _shortDate(DateTime d) =>
    '${d.day} ${_shortMonths[d.month - 1]} ${d.year}';

class _SharingLine extends StatelessWidget {
  const _SharingLine({required this.shared, required this.onChange});

  final bool shared;
  final VoidCallback onChange;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(top: CsSpacing.lg),
    padding: const EdgeInsets.only(top: CsSpacing.md),
    decoration: const BoxDecoration(
      border: Border(top: BorderSide(color: AppColors.subtleBorderDark)),
    ),
    child: Row(
      children: [
        Expanded(
          child: Text(
            shared
                ? 'Friends can see your Cellar.'
                : 'Your Cellar is only for you.',
            style: CsTypography.metadata.copyWith(
              color: AppColors.secondaryOnDark,
              fontStyle: FontStyle.italic,
            ),
          ),
        ),
        TextButton(
          onPressed: onChange,
          style: TextButton.styleFrom(foregroundColor: AppColors.textOnDark),
          child: Text(
            'Change',
            style: CsTypography.metadata.copyWith(
              color: AppColors.textOnDark,
              decoration: TextDecoration.underline,
              decorationColor: AppColors.textOnDark,
            ),
          ),
        ),
      ],
    ),
  );
}

/// A friend's Cellar with nothing to show: kept to themself, or empty.
class _FriendNote extends StatelessWidget {
  const _FriendNote({required this.title, this.body, this.icon});

  final String title;
  final String? body;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: CsSpacing.pageHorizontal),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, color: AppColors.secondaryOnDark, size: 22),
            const SizedBox(height: CsSpacing.sm),
          ],
          Text(
            title,
            textAlign: TextAlign.center,
            style: CsTypography.editorialLead().copyWith(
              color: AppColors.textOnDark,
            ),
          ),
          if (body != null) ...[
            const SizedBox(height: CsSpacing.sm),
            Text(
              body!,
              textAlign: TextAlign.center,
              style: CsTypography.body.copyWith(
                color: AppColors.secondaryOnDark,
              ),
            ),
          ],
        ],
      ),
    ),
  );
}
