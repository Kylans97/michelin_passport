import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/cs_spacing.dart';
import '../../../core/theme/cs_typography.dart';
import '../../../core/widgets/cs_content_sheet.dart';
import '../../../core/widgets/cs_search_field.dart';

typedef CatalogueCity = ({String id, String name, String? region});

/// The answer from [showTripCityPicker]: a catalogue city, or [city] null
/// for "the whole country". The sheet returning null itself means it was
/// dismissed without a choice.
class TripCityChoice {
  final CatalogueCity? city;
  const TripCityChoice(this.city);
}

/// Narrows a destination to one of the catalogue's cities in a country —
/// a city is chosen by id from `cities`, never typed, so the venue pickers
/// can scope on it (decision 1: destinations are found in the app).
Future<TripCityChoice?> showTripCityPicker(
  BuildContext context, {
  required String countryLabel,
  required Future<List<CatalogueCity>> cities,
}) {
  return showModalBottomSheet<TripCityChoice>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) =>
        _CityPickerSheet(countryLabel: countryLabel, cities: cities),
  );
}

class _CityPickerSheet extends StatefulWidget {
  final String countryLabel;
  final Future<List<CatalogueCity>> cities;
  const _CityPickerSheet({required this.countryLabel, required this.cities});

  @override
  State<_CityPickerSheet> createState() => _CityPickerSheetState();
}

class _CityPickerSheetState extends State<_CityPickerSheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) => CsContentSheet(
    backgroundColor: AppColors.greenSurface,
    maxHeightFraction: 0.85,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            CsSpacing.pageHorizontal,
            CsSpacing.md,
            CsSpacing.pageHorizontal,
            CsSpacing.base,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Where in ${widget.countryLabel}?',
                style: CsTypography.sectionTitle.copyWith(
                  color: AppColors.textOnDark,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'A city narrows the hotels and restaurants to that city.',
                style: CsTypography.metadata.copyWith(
                  color: AppColors.secondaryOnDark,
                ),
              ),
              const SizedBox(height: CsSpacing.base),
              CsSearchField(
                hintText: 'Search cities…',
                // Focused on open, like the venue pickers: the keyboard is
                // up before anything is tapped, so the list doesn't move
                // under the finger when it appears.
                autofocus: true,
                onChanged: (v) => setState(() => _query = v.trim()),
              ),
            ],
          ),
        ),
        Flexible(
          child: FutureBuilder<List<CatalogueCity>>(
            future: widget.cities,
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: CsSpacing.xxl),
                  child: Center(
                    child: CircularProgressIndicator(
                      color: AppColors.textOnDark,
                      strokeWidth: 1.5,
                    ),
                  ),
                );
              }
              final q = _query.toLowerCase();
              final cities = [
                for (final c in snap.data ?? const <CatalogueCity>[])
                  if (q.isEmpty || c.name.toLowerCase().contains(q)) c,
              ];
              return ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(
                  CsSpacing.pageHorizontal,
                  0,
                  CsSpacing.pageHorizontal,
                  CsSpacing.xl,
                ),
                children: [
                  if (q.isEmpty)
                    _CityRow(
                      title: 'The whole country',
                      subtitle: widget.countryLabel,
                      onTap: () =>
                          Navigator.pop(context, const TripCityChoice(null)),
                    ),
                  for (final city in cities)
                    _CityRow(
                      title: city.name,
                      subtitle: city.region,
                      onTap: () => Navigator.pop(context, TripCityChoice(city)),
                    ),
                  if (cities.isEmpty && q.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: CsSpacing.xl,
                      ),
                      child: Text(
                        'No city called “$_query” in the catalogue.',
                        style: CsTypography.metadata.copyWith(
                          color: AppColors.secondaryOnDark,
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ],
    ),
  );
}

class _CityRow extends StatelessWidget {
  final String title;
  final String? subtitle;
  final VoidCallback onTap;
  const _CityRow({required this.title, this.subtitle, required this.onTap});

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    splashColor: AppColors.textOnDark.withValues(alpha: 0.06),
    highlightColor: AppColors.textOnDark.withValues(alpha: 0.04),
    child: Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: CsSpacing.md),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.hairlineOnGreen)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: CsTypography.placeTitle.copyWith(
              color: AppColors.textOnDark,
              fontSize: 18,
            ),
          ),
          if (subtitle != null && subtitle!.isNotEmpty)
            Text(
              subtitle!,
              style: CsTypography.metadata.copyWith(
                color: AppColors.secondaryOnDark,
                fontSize: 13,
              ),
            ),
        ],
      ),
    ),
  );
}
