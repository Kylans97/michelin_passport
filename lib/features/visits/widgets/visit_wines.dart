import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/cs_spacing.dart';
import '../../../core/theme/cs_typography.dart';
import '../../../data/repositories/visit_wine_repository.dart';
import '../../../models/visit_wine.dart';

/// One wine as it reads on a review, like a line on a wine list: the year
/// large in the serif, the wine beside it, producer and size underneath.
class WineRow extends StatelessWidget {
  const WineRow({
    super.key,
    required this.wine,
    this.onTap,
    this.showYearColumn = true,
  });

  final VisitWine wine;
  final VoidCallback? onTap;

  /// Kept when any wine in the list has a year, so the names line up.
  final bool showYearColumn;

  @override
  Widget build(BuildContext context) {
    final subtitle = wine.subtitle;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: CsSpacing.sm),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (showYearColumn)
              SizedBox(
                width: 52,
                child: Text(
                  wine.yearLabel ?? '',
                  style: CsTypography.placeTitle.copyWith(
                    fontSize: 19,
                    color: AppColors.forestGreen,
                  ),
                ),
              ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    wine.title,
                    style: CsTypography.placeTitle.copyWith(
                      fontSize: 17,
                      color: AppColors.forestGreen,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: CsTypography.metadata.copyWith(
                        color: AppColors.taupe,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A list of [WineRow]s split by hairlines.
class WineList extends StatelessWidget {
  const WineList({super.key, required this.wines, this.onTapWine});

  final List<VisitWine> wines;
  final ValueChanged<int>? onTapWine;

  @override
  Widget build(BuildContext context) {
    final anyYear = wines.any((w) => w.yearLabel != null);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < wines.length; i++) ...[
          if (i > 0) Container(height: 1, color: AppColors.hairlineOnPaper),
          WineRow(
            wine: wines[i],
            showYearColumn: anyYear,
            onTap: onTapWine == null ? null : () => onTapWine!(i),
          ),
        ],
      ],
    );
  }
}

/// The quiet way to add one, in the review and on the visit page.
class AddWineButton extends StatelessWidget {
  const AddWineButton({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => TextButton.icon(
    onPressed: onTap,
    style: TextButton.styleFrom(
      foregroundColor: AppColors.forestGreen,
      padding: const EdgeInsets.symmetric(vertical: CsSpacing.sm),
    ),
    icon: const Icon(Icons.add_rounded, size: 18),
    label: Text(
      'Add a wine',
      style: CsTypography.bodyMedium.copyWith(color: AppColors.forestGreen),
    ),
  );
}

/// The wines on a visit page. Hidden for a friend when there are none;
/// silent while loading and on failure, like the other optional parts of
/// that page. RLS decides who gets rows at all.
class VisitWinesSection extends StatefulWidget {
  const VisitWinesSection({
    super.key,
    required this.visitId,
    required this.readOnly,
    this.repository,
  });

  final String visitId;
  final bool readOnly;
  final VisitWineRepository? repository;

  @override
  State<VisitWinesSection> createState() => _VisitWinesSectionState();
}

class _VisitWinesSectionState extends State<VisitWinesSection> {
  late final VisitWineRepository _repo =
      widget.repository ?? VisitWineRepository(Supabase.instance.client);
  List<VisitWine> _wines = const [];
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final wines = await _repo.loadForVisit(widget.visitId);
      if (!mounted) return;
      setState(() {
        _wines = wines;
        _loaded = true;
      });
    } catch (_) {
      if (mounted) setState(() => _loaded = true);
    }
  }

  String? get _userId => Supabase.instance.client.auth.currentUser?.id;

  void _failed() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Could not save that. Please try again.')),
    );
  }

  Future<void> _add() async {
    final userId = _userId;
    if (userId == null) return;
    await showWineSheet(
      context,
      suggestions: _loadSuggestions(userId),
      onSave: (wine) async {
        try {
          final saved = await _repo.add(
            userId: userId,
            visitId: widget.visitId,
            wine: wine,
            displayOrder: _wines.length,
          );
          if (mounted) setState(() => _wines = [..._wines, saved]);
          return true;
        } catch (_) {
          _failed();
          return false;
        }
      },
    );
  }

  Future<void> _edit(int index) async {
    final userId = _userId;
    final existing = _wines[index];
    if (userId == null || existing.id == null) return;
    await showWineSheet(
      context,
      initial: existing,
      suggestions: _loadSuggestions(userId),
      onSave: (wine) async {
        try {
          await _repo.update(existing.id!, wine);
          if (mounted) {
            setState(() {
              _wines = [
                for (var i = 0; i < _wines.length; i++)
                  i == index
                      ? VisitWine(
                          id: existing.id,
                          producer: wine.producer,
                          wineName: wine.wineName,
                          vintage: wine.vintage,
                          nonVintage: wine.nonVintage,
                          size: wine.size,
                        )
                      : _wines[i],
              ];
            });
          }
          return true;
        } catch (_) {
          _failed();
          return false;
        }
      },
      onDelete: () async {
        try {
          await _repo.delete(existing.id!);
          if (mounted) {
            setState(() {
              _wines = [
                for (final w in _wines)
                  if (w.id != existing.id) w,
              ];
            });
          }
        } catch (_) {
          _failed();
        }
      },
    );
  }

  Future<WineSuggestions> _loadSuggestions(String userId) => _repo
      .loadSuggestions(userId)
      .catchError((Object _) => const WineSuggestions());

  @override
  Widget build(BuildContext context) {
    if (!_loaded) return const SizedBox.shrink();
    if (_wines.isEmpty && widget.readOnly) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'WHAT WE DRANK',
            style: CsTypography.eyebrow.copyWith(color: AppColors.taupe),
          ),
          const SizedBox(height: 6),
          if (_wines.isNotEmpty)
            WineList(wines: _wines, onTapWine: widget.readOnly ? null : _edit),
          if (!widget.readOnly) AddWineButton(onTap: _add),
        ],
      ),
    );
  }
}

/// The short sheet that adds or edits one wine. [onSave] returns true when
/// the wine was taken. A new wine can be followed by another without
/// leaving the sheet.
Future<void> showWineSheet(
  BuildContext context, {
  VisitWine? initial,
  Future<WineSuggestions>? suggestions,
  required Future<bool> Function(VisitWine wine) onSave,
  Future<void> Function()? onDelete,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  backgroundColor: AppColors.surface,
  shape: const RoundedRectangleBorder(
    borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
  ),
  builder: (_) => WineSheet(
    initial: initial,
    suggestions: suggestions,
    onSave: onSave,
    onDelete: onDelete,
  ),
);

class WineSheet extends StatefulWidget {
  const WineSheet({
    super.key,
    this.initial,
    this.suggestions,
    required this.onSave,
    this.onDelete,
  });

  final VisitWine? initial;
  final Future<WineSuggestions>? suggestions;
  final Future<bool> Function(VisitWine wine) onSave;
  final Future<void> Function()? onDelete;

  @override
  State<WineSheet> createState() => _WineSheetState();
}

class _WineSheetState extends State<WineSheet> {
  final _producer = TextEditingController();
  final _name = TextEditingController();
  final _year = TextEditingController();
  final _producerFocus = FocusNode();
  bool _nonVintage = false;
  WineSize? _size;
  bool _saving = false;
  int _added = 0;
  WineSuggestions _suggestions = const WineSuggestions();

  bool get _editing => widget.initial != null;

  @override
  void initState() {
    super.initState();
    final w = widget.initial;
    if (w != null) {
      _producer.text = w.producer ?? '';
      _name.text = w.wineName ?? '';
      _year.text = w.vintage?.toString() ?? '';
      _nonVintage = w.nonVintage;
      _size = w.size;
    }
    unawaited(
      widget.suggestions?.then((s) {
        if (mounted) setState(() => _suggestions = s);
      }),
    );
  }

  @override
  void dispose() {
    _producer.dispose();
    _name.dispose();
    _year.dispose();
    _producerFocus.dispose();
    super.dispose();
  }

  String? _clean(TextEditingController c) {
    final t = c.text.trim();
    return t.isEmpty ? null : t;
  }

  VisitWine get _draft => VisitWine(
    producer: _clean(_producer),
    wineName: _clean(_name),
    vintage: int.tryParse(_year.text.trim()),
    nonVintage: _nonVintage,
    size: _size,
  );

  bool get _yearOk => isValidWineYear(_draft.vintage);
  bool get _canSave => !_saving && !_draft.isEmpty && _yearOk;

  Future<void> _save({required bool another}) async {
    if (!_canSave) return;
    setState(() => _saving = true);
    final ok = await widget.onSave(_draft);
    if (!mounted) return;
    setState(() => _saving = false);
    if (!ok) return;
    if (!another) {
      Navigator.pop(context);
      return;
    }
    setState(() {
      _added++;
      _producer.clear();
      _name.clear();
      _year.clear();
      _nonVintage = false;
      _size = null;
    });
    _producerFocus.requestFocus();
  }

  Widget _field(
    String label,
    TextEditingController controller, {
    String? hint,
    FocusNode? focusNode,
    TextInputType? keyboardType,
    List<TextInputFormatter>? formatters,
    ValueChanged<String>? onChanged,
  }) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: CsTypography.metadata.copyWith(color: AppColors.taupe),
      ),
      const SizedBox(height: 4),
      TextField(
        controller: controller,
        focusNode: focusNode,
        keyboardType: keyboardType,
        inputFormatters: formatters,
        textCapitalization: keyboardType == null
            ? TextCapitalization.words
            : TextCapitalization.none,
        maxLength: keyboardType == null ? 120 : null,
        buildCounter:
            (_, {required currentLength, required isFocused, maxLength}) =>
                null,
        onChanged: onChanged ?? (_) => setState(() {}),
        style: CsTypography.body.copyWith(color: AppColors.textPrimary),
        decoration: InputDecoration(
          isDense: true,
          hintText: hint,
          filled: true,
          fillColor: AppColors.background,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 12,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: AppColors.cardBorder),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: AppColors.cardBorder),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: AppColors.forestGreen),
          ),
        ),
      ),
    ],
  );

  Widget _suggestionRow(List<String> options, TextEditingController target) {
    if (options.isEmpty) return const SizedBox(height: CsSpacing.md);
    return Padding(
      padding: const EdgeInsets.only(top: 6, bottom: CsSpacing.md),
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          for (final option in options)
            _Chip(
              label: option,
              selected: false,
              onTap: () => setState(() {
                target.text = option;
                target.selection = TextSelection.collapsed(
                  offset: option.length,
                );
              }),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            CsSpacing.pageHorizontal,
            CsSpacing.lg,
            CsSpacing.pageHorizontal,
            CsSpacing.lg,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _editing ? 'Edit wine' : 'Add a wine',
                style: CsTypography.placeTitle.copyWith(
                  fontSize: 22,
                  color: AppColors.forestGreen,
                ),
              ),
              const SizedBox(height: CsSpacing.md),
              _field('Producer', _producer, focusNode: _producerFocus),
              _suggestionRow(
                matchingWineNames(_suggestions.producers, _producer.text),
                _producer,
              ),
              _field('Wine', _name),
              _suggestionRow(
                matchingWineNames(
                  _suggestions.namesFor(_producer.text),
                  _name.text,
                ),
                _name,
              ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  SizedBox(
                    width: 110,
                    child: _field(
                      'Year',
                      _year,
                      keyboardType: TextInputType.number,
                      formatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(4),
                      ],
                      onChanged: (v) => setState(() {
                        if (v.isNotEmpty) _nonVintage = false;
                      }),
                    ),
                  ),
                  const SizedBox(width: CsSpacing.sm),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _Chip(
                      label: 'No year',
                      selected: _nonVintage,
                      onTap: () => setState(() {
                        _nonVintage = !_nonVintage;
                        if (_nonVintage) _year.clear();
                      }),
                    ),
                  ),
                ],
              ),
              if (!_yearOk)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    "That year doesn't look right.",
                    style: CsTypography.metadata.copyWith(
                      color: AppColors.error,
                    ),
                  ),
                ),
              const SizedBox(height: CsSpacing.md),
              Text(
                'Size',
                style: CsTypography.metadata.copyWith(color: AppColors.taupe),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final size in WineSize.values)
                    _Chip(
                      label: size.label,
                      selected: _size == size,
                      onTap: () =>
                          setState(() => _size = _size == size ? null : size),
                    ),
                ],
              ),
              const SizedBox(height: CsSpacing.md),
              Text(
                _added > 0
                    ? '$_added added. Fill in what you remember; all of it is optional.'
                    : 'Fill in what you remember. All of it is optional.',
                style: CsTypography.metadata.copyWith(color: AppColors.taupe),
              ),
              const SizedBox(height: CsSpacing.md),
              SizedBox(
                height: 48,
                child: ElevatedButton(
                  onPressed: _canSave ? () => _save(another: false) : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.forestGreen,
                    foregroundColor: AppColors.textOnDark,
                    disabledBackgroundColor: AppColors.forestGreen.withValues(
                      alpha: 0.4,
                    ),
                    disabledForegroundColor: AppColors.textOnDark,
                    shape: const StadiumBorder(),
                  ),
                  child: Text(_editing ? 'Save' : 'Add'),
                ),
              ),
              if (!_editing)
                TextButton(
                  onPressed: _canSave ? () => _save(another: true) : null,
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.forestGreen,
                  ),
                  child: const Text('Add and another'),
                ),
              if (widget.onDelete != null)
                TextButton(
                  onPressed: _saving
                      ? null
                      : () async {
                          await widget.onDelete!();
                          if (context.mounted) Navigator.pop(context);
                        },
                  style: TextButton.styleFrom(foregroundColor: AppColors.error),
                  child: const Text('Remove this wine'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: selected,
    child: GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.forestGreen : Colors.transparent,
          borderRadius: BorderRadius.circular(99),
          border: Border.all(
            color: selected
                ? AppColors.forestGreen
                : AppColors.subtleBorderLight,
          ),
        ),
        child: Text(
          label,
          style: CsTypography.metadata.copyWith(
            color: selected ? AppColors.ivory : AppColors.forestGreen,
          ),
        ),
      ),
    ),
  );
}
