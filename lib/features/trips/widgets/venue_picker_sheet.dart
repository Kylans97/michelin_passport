import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/cs_spacing.dart';
import '../../../core/theme/cs_typography.dart';
import '../../../core/widgets/cs_content_sheet.dart';
import '../../../core/widgets/cs_search_field.dart';
import '../../../core/widgets/venue_thumbnail.dart';
import '../../../models/photo_framing.dart';

/// One row's worth of display data for [showTripVenuePicker] — the
/// hotel/restaurant pickers map their own model onto this so both share
/// one sheet rather than two near-identical copies of it.
class TripVenuePickerRow {
  final String title;
  final String subtitle;
  final String? imageUrl;
  final PhotoFraming framing;
  final Widget? awardRow;

  const TripVenuePickerRow({
    required this.title,
    required this.subtitle,
    this.imageUrl,
    this.framing = PhotoFraming.center,
    this.awardRow,
  });
}

/// The searchable venue picker shared by Trips' "Add stay"/"Add restaurant".
/// [search] runs per keystroke against the catalogue and is expected to be
/// already scoped to the trip's destination (see showHotelPickerSheet/
/// showRestaurantPickerSheet, which pass the trip's country code — a code,
/// never a name); [scopeLabel] says which destination, so an empty result
/// reads as "nothing here" rather than "the search is broken".
Future<T?> showTripVenuePicker<T>(
  BuildContext context, {
  required String title,
  required String scopeLabel,
  required String hintText,
  required String emptyMessage,
  required Future<List<T>> Function(String query) search,
  required TripVenuePickerRow Function(T item) describe,
  bool Function(T item)? exclude,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _TripVenuePickerSheet<T>(
      title: title,
      scopeLabel: scopeLabel,
      hintText: hintText,
      emptyMessage: emptyMessage,
      search: search,
      describe: describe,
      exclude: exclude,
    ),
  );
}

class _TripVenuePickerSheet<T> extends StatefulWidget {
  final String title;
  final String scopeLabel;
  final String hintText;
  final String emptyMessage;
  final Future<List<T>> Function(String query) search;
  final TripVenuePickerRow Function(T item) describe;
  final bool Function(T item)? exclude;

  const _TripVenuePickerSheet({
    required this.title,
    required this.scopeLabel,
    required this.hintText,
    required this.emptyMessage,
    required this.search,
    required this.describe,
    this.exclude,
  });

  @override
  State<_TripVenuePickerSheet<T>> createState() =>
      _TripVenuePickerSheetState<T>();
}

class _TripVenuePickerSheetState<T> extends State<_TripVenuePickerSheet<T>> {
  String _query = '';
  late Future<List<T>> _future = widget.search('');

  void _onQueryChanged(String value) {
    setState(() {
      _query = value;
      _future = widget.search(value);
    });
  }

  @override
  Widget build(BuildContext context) {
    return CsContentSheet(
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
                  widget.title,
                  style: CsTypography.sectionTitle.copyWith(
                    color: AppColors.textOnDark,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  widget.scopeLabel,
                  style: CsTypography.metadata.copyWith(
                    color: AppColors.secondaryOnDark,
                  ),
                ),
                const SizedBox(height: CsSpacing.base),
                CsSearchField(
                  hintText: widget.hintText,
                  onChanged: _onQueryChanged,
                  autofocus: true,
                ),
              ],
            ),
          ),
          Flexible(
            child: FutureBuilder<List<T>>(
              future: _future,
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
                final exclude = widget.exclude;
                final items = [
                  for (final item in snap.data ?? <T>[])
                    if (exclude == null || !exclude(item)) item,
                ];
                if (items.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: CsSpacing.pageHorizontal,
                      vertical: CsSpacing.xxl,
                    ),
                    child: Center(
                      child: Text(
                        snap.hasError
                            ? 'Could not load the catalogue. Please try again.'
                            : _query.isEmpty
                            ? widget.emptyMessage
                            : 'Nothing found for “$_query”.',
                        textAlign: TextAlign.center,
                        style: CsTypography.metadata.copyWith(
                          color: AppColors.secondaryOnDark,
                        ),
                      ),
                    ),
                  );
                }
                return ListView.separated(
                  shrinkWrap: true,
                  padding: const EdgeInsets.fromLTRB(
                    CsSpacing.pageHorizontal,
                    0,
                    CsSpacing.pageHorizontal,
                    CsSpacing.xl,
                  ),
                  itemCount: items.length,
                  separatorBuilder: (_, _) => const Divider(
                    height: 1,
                    color: AppColors.hairlineOnGreen,
                  ),
                  itemBuilder: (context, i) => _PickerRow(
                    row: widget.describe(items[i]),
                    onTap: () => Navigator.pop(context, items[i]),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _PickerRow extends StatelessWidget {
  final TripVenuePickerRow row;
  final VoidCallback onTap;
  const _PickerRow({required this.row, required this.onTap});

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: '${row.title}, ${row.subtitle}',
    excludeSemantics: true,
    child: InkWell(
      onTap: onTap,
      splashColor: AppColors.textOnDark.withValues(alpha: 0.06),
      highlightColor: AppColors.textOnDark.withValues(alpha: 0.04),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: CsSpacing.md),
        child: Row(
          children: [
            VenueThumbnail(
              imageUrl: row.imageUrl,
              framing: row.framing,
              size: 52,
              borderRadius: BorderRadius.circular(CsRadius.small),
            ),
            const SizedBox(width: CsSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    row.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: CsTypography.placeTitle.copyWith(
                      color: AppColors.textOnDark,
                      fontSize: 18,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    row.subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: CsTypography.metadata.copyWith(
                      color: AppColors.secondaryOnDark,
                      fontSize: 13,
                    ),
                  ),
                  if (row.awardRow != null) ...[
                    const SizedBox(height: 4),
                    row.awardRow!,
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
