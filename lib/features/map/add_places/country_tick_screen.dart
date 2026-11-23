import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/cs_fonts.dart';
import '../../../core/theme/cs_spacing.dart';
import '../../../core/theme/cs_typography.dart';
import '../../../core/widgets/editorial_back_button.dart';
import '../../../data/repositories/undated_visit_repository.dart';
import '../../../models/venue_country.dart';
import '../../../models/visit.dart' show VisitVisibility;
import 'add_places_screen.dart' show AddPlacesSearchField;

/// "Where in {country} have you been?" (design canvas, "The globe,
/// chosen", screen 3): every restaurant and hotel in the country, starred
/// and Keyed first, to tick. Saving adds each as a visit without a date,
/// with one visibility for all of them, private unless the member turns
/// it on, as visits are. Pops with how many were added.
class CountryTickScreen extends StatefulWidget {
  final VenueCountry country;
  final Set<String> knownVenueKeys;
  final UndatedVisitRepository? repository;

  const CountryTickScreen({
    super.key,
    required this.country,
    required this.knownVenueKeys,
    this.repository,
  });

  @override
  State<CountryTickScreen> createState() => _CountryTickScreenState();
}

class _CountryTickScreenState extends State<CountryTickScreen> {
  late final UndatedVisitRepository _repo =
      widget.repository ?? UndatedVisitRepository(Supabase.instance.client);
  List<CountryVenueChoice>? _choices;
  bool _loadError = false;
  bool _saving = false;
  bool _friends = false;
  String _query = '';
  final _picked = <String>{};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final choices = await _repo.loadCountryChoices(widget.country.code);
      if (mounted) setState(() => _choices = choices);
    } catch (_) {
      if (mounted) setState(() => _loadError = true);
    }
  }

  String _key(CountryVenueChoice c) => '${c.entityType}:${c.id}';

  Future<void> _save() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    final choices = _choices;
    if (userId == null || choices == null || _picked.isEmpty) return;
    setState(() => _saving = true);
    try {
      await _repo.addMany(
        userId: userId,
        choices: [
          for (final c in choices)
            if (_picked.contains(_key(c))) c,
        ],
        visibility: _friends
            ? VisitVisibility.friends
            : VisitVisibility.private,
      );
      if (mounted) Navigator.pop(context, _picked.length);
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not add them. Please try again.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final q = _query.trim().toLowerCase();
    final shown = [
      for (final c in _choices ?? const <CountryVenueChoice>[])
        if (q.isEmpty ||
            c.name.toLowerCase().contains(q) ||
            c.city.toLowerCase().contains(q))
          c,
    ];
    final count = _picked.length;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: CsSpacing.base),
              child: EditorialBackButton(color: AppColors.textPrimary),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                CsSpacing.pageHorizontal,
                CsSpacing.xs,
                CsSpacing.pageHorizontal,
                CsSpacing.md,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Where in ${widget.country.name} have you been?',
                    style: CsTypography.screenTitle,
                  ),
                  const SizedBox(height: CsSpacing.xs),
                  Text(
                    'Starred first, then by city. Tick every one you '
                    'remember; the dates can wait.',
                    style: CsTypography.body.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: CsSpacing.base),
                  AddPlacesSearchField(
                    hint: 'Search ${widget.country.name}',
                    onChanged: (v) => setState(() => _query = v),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _loadError
                  ? Center(
                      child: TextButton(
                        onPressed: () {
                          setState(() => _loadError = false);
                          _load();
                        },
                        child: Text(
                          'Could not load the venues. Try again',
                          style: CsFonts.sans(color: AppColors.forestGreen),
                        ),
                      ),
                    )
                  : _choices == null
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: AppColors.forestGreen,
                        strokeWidth: 2,
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(
                        horizontal: CsSpacing.pageHorizontal,
                      ),
                      itemCount: shown.length,
                      itemBuilder: (context, i) {
                        final c = shown[i];
                        final known = widget.knownVenueKeys.contains(_key(c));
                        return _TickRow(
                          choice: c,
                          known: known,
                          ticked: known || _picked.contains(_key(c)),
                          onChanged: known
                              ? null
                              : (on) => setState(
                                  () => on
                                      ? _picked.add(_key(c))
                                      : _picked.remove(_key(c)),
                                ),
                        );
                      },
                    ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(
                CsSpacing.pageHorizontal,
                CsSpacing.sm,
                CsSpacing.pageHorizontal,
                CsSpacing.base,
              ),
              decoration: const BoxDecoration(
                color: AppColors.background,
                border: Border(top: BorderSide(color: AppColors.cardBorder)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Friends can see these',
                          style: CsFonts.sans(
                            color: AppColors.textPrimary,
                            fontSize: 14.5,
                          ),
                        ),
                      ),
                      Switch.adaptive(
                        value: _friends,
                        activeTrackColor: AppColors.forestGreen,
                        onChanged: (v) => setState(() => _friends = v),
                      ),
                    ],
                  ),
                  const SizedBox(height: CsSpacing.sm),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.deepGreen,
                        foregroundColor: AppColors.textOnDark,
                        disabledBackgroundColor: AppColors.cardBorder,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed: count == 0 || _saving ? null : _save,
                      child: Text(
                        count == 0
                            ? 'Tick the venues you remember'
                            : 'Add $count to your globe',
                        style: CsFonts.sans(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TickRow extends StatelessWidget {
  final CountryVenueChoice choice;
  final bool known;
  final bool ticked;
  final ValueChanged<bool>? onChanged;

  const _TickRow({
    required this.choice,
    required this.known,
    required this.ticked,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final award = choice.isHotel ? choice.keys : choice.stars;
    final awardText = award == null || award == 0
        ? null
        : choice.isHotel
        ? ' · ${award == 1 ? '1 Key' : '$award Keys'}'
        : ' ${'★' * award}';
    final sub = [
      choice.city,
      if (choice.isHotel) 'hotel',
      if (known) 'already on your globe',
    ].where((s) => s.isNotEmpty).join(' · ');

    return InkWell(
      onTap: onChanged == null ? null : () => onChanged!(!ticked),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: AppColors.cardBorder)),
        ),
        child: Row(
          children: [
            Checkbox(
              value: ticked,
              onChanged: onChanged == null ? null : (v) => onChanged!(v!),
              activeColor: AppColors.deepGreen,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(5),
              ),
            ),
            const SizedBox(width: CsSpacing.xs),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text.rich(
                    TextSpan(
                      text: choice.name,
                      children: [
                        if (awardText != null)
                          TextSpan(
                            text: awardText,
                            style: TextStyle(
                              color: AppColors.gold,
                              fontSize: choice.isHotel ? 13 : 14,
                            ),
                          ),
                      ],
                    ),
                    style: CsFonts.serif(
                      color: known
                          ? AppColors.textSecondary
                          : AppColors.textPrimary,
                      fontSize: 17,
                    ),
                  ),
                  if (sub.isNotEmpty)
                    Text(
                      sub,
                      style: CsFonts.sans(
                        color: AppColors.textSecondary,
                        fontSize: 12.5,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
