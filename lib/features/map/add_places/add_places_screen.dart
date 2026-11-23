import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/cs_fonts.dart';
import '../../../core/theme/cs_spacing.dart';
import '../../../core/theme/cs_typography.dart';
import '../../../core/widgets/editorial_back_button.dart';
import '../../../data/repositories/undated_visit_repository.dart';
import '../../../models/venue_country.dart';
import 'country_tick_screen.dart';

/// What Add places added, so My Map can fly to the country and say so.
class AddPlacesResult {
  final String countryCode;
  final String countryName;
  final int added;

  const AddPlacesResult({
    required this.countryCode,
    required this.countryName,
    required this.added,
  });
}

/// "Where have you been?" from My Map (design canvas, "The globe, chosen",
/// screen 2): the member's own countries first, then every other country
/// in the catalogue. Choosing one opens [CountryTickScreen]. Pops with an
/// [AddPlacesResult] once something was added, else with nothing.
class AddPlacesScreen extends StatefulWidget {
  /// Venues per country already on the member's globe, by country code.
  final Map<String, int> yourCountries;

  /// `restaurant:id` / `hotel:id` of every venue already on the globe,
  /// dated or not, so the tick list can show them as already there.
  final Set<String> knownVenueKeys;

  final UndatedVisitRepository? repository;

  const AddPlacesScreen({
    super.key,
    required this.yourCountries,
    required this.knownVenueKeys,
    this.repository,
  });

  @override
  State<AddPlacesScreen> createState() => _AddPlacesScreenState();
}

class _AddPlacesScreenState extends State<AddPlacesScreen> {
  late final UndatedVisitRepository _repo =
      widget.repository ?? UndatedVisitRepository(Supabase.instance.client);
  List<VenueCountry>? _countries;
  bool _error = false;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final countries = await _repo.loadCatalogueCountries();
      if (mounted) setState(() => _countries = countries);
    } catch (_) {
      if (mounted) setState(() => _error = true);
    }
  }

  Future<void> _open(VenueCountry country) async {
    final added = await Navigator.push<int>(
      context,
      MaterialPageRoute(
        builder: (_) => CountryTickScreen(
          country: country,
          knownVenueKeys: widget.knownVenueKeys,
          repository: _repo,
        ),
      ),
    );
    if (!mounted || added == null || added == 0) return;
    Navigator.pop(
      context,
      AddPlacesResult(
        countryCode: country.code,
        countryName: country.name,
        added: added,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final countries = _countries;
    final q = _query.trim().toLowerCase();
    final matching = [
      for (final c in countries ?? const <VenueCountry>[])
        if (q.isEmpty || c.name.toLowerCase().contains(q)) c,
    ];
    final yours =
        [
          for (final c in matching)
            if (widget.yourCountries.containsKey(c.code)) c,
        ]..sort(
          (a, b) => widget.yourCountries[b.code]!.compareTo(
            widget.yourCountries[a.code]!,
          ),
        );
    final others = [
      for (final c in matching)
        if (!widget.yourCountries.containsKey(c.code)) c,
    ];

    // Dark status bar on the ivory page, whatever the green map set.
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
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
                  CsSpacing.base,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Where have you been?',
                      style: CsTypography.screenTitle,
                    ),
                    const SizedBox(height: CsSpacing.xs),
                    Text(
                      'Choose a country and tick the venues you remember. '
                      'Dates can follow later.',
                      style: CsTypography.body.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: CsSpacing.base),
                    AddPlacesSearchField(
                      hint: 'Search a country',
                      onChanged: (v) => setState(() => _query = v),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: _error
                    ? Center(
                        child: TextButton(
                          onPressed: () {
                            setState(() => _error = false);
                            _load();
                          },
                          child: Text(
                            'Could not load the countries. Try again',
                            style: CsFonts.sans(color: AppColors.forestGreen),
                          ),
                        ),
                      )
                    : countries == null
                    ? const Center(
                        child: CircularProgressIndicator(
                          color: AppColors.forestGreen,
                          strokeWidth: 2,
                        ),
                      )
                    : ListView(
                        padding: const EdgeInsets.fromLTRB(
                          CsSpacing.pageHorizontal,
                          0,
                          CsSpacing.pageHorizontal,
                          CsSpacing.section,
                        ),
                        children: [
                          if (yours.isNotEmpty) ...[
                            _heading('Your countries'),
                            for (final c in yours)
                              _CountryRow(
                                name: c.name,
                                trailing: '${widget.yourCountries[c.code]}',
                                onTap: () => _open(c),
                              ),
                            const SizedBox(height: CsSpacing.xl),
                          ],
                          if (others.isNotEmpty) ...[
                            _heading(
                              yours.isEmpty && q.isEmpty
                                  ? 'Every country'
                                  : 'Not on your globe yet',
                            ),
                            for (final c in others)
                              _CountryRow(name: c.name, onTap: () => _open(c)),
                          ],
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _heading(String text) => Padding(
    padding: const EdgeInsets.only(bottom: CsSpacing.xs),
    child: Text(text.toUpperCase(), style: CsTypography.eyebrow),
  );
}

class _CountryRow extends StatelessWidget {
  final String name;
  final String? trailing;
  final VoidCallback onTap;

  const _CountryRow({required this.name, this.trailing, required this.onTap});

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.cardBorder)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              name,
              style: CsFonts.serif(color: AppColors.textPrimary, fontSize: 18),
            ),
          ),
          if (trailing != null)
            Padding(
              padding: const EdgeInsets.only(right: CsSpacing.sm),
              child: Text(
                trailing!,
                style: CsFonts.sans(
                  color: AppColors.textSecondary,
                  fontSize: 13.5,
                ),
              ),
            ),
          const Icon(
            Icons.chevron_right_rounded,
            color: AppColors.textSecondary,
            size: 20,
          ),
        ],
      ),
    ),
  );
}

/// The rounded search field both Add places screens use.
class AddPlacesSearchField extends StatelessWidget {
  final String hint;
  final ValueChanged<String> onChanged;

  const AddPlacesSearchField({
    super.key,
    required this.hint,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) => TextField(
    onChanged: onChanged,
    textInputAction: TextInputAction.search,
    style: CsFonts.sans(color: AppColors.textPrimary, fontSize: 15),
    decoration: InputDecoration(
      hintText: hint,
      hintStyle: CsFonts.sans(color: AppColors.taupe, fontSize: 15),
      prefixIcon: const Icon(
        Icons.search_rounded,
        color: AppColors.taupe,
        size: 20,
      ),
      filled: true,
      fillColor: AppColors.surfaceElevated,
      contentPadding: const EdgeInsets.symmetric(vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(24),
        borderSide: const BorderSide(color: AppColors.cardBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(24),
        borderSide: const BorderSide(color: AppColors.cardBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(24),
        borderSide: const BorderSide(color: AppColors.forestGreen),
      ),
    ),
  );
}
