import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/cs_spacing.dart';
import '../../../core/theme/cs_surface_context.dart';
import '../../../core/theme/cs_typography.dart';
import '../../../core/widgets/cs_primary_button.dart';
import '../../../models/journey.dart';

/// What the member confirmed in [showConfirmTravelSheet].
class ConfirmedTravelInput {
  final JourneyRoute? route;
  final DateTime departedOn;
  final DateTime? arrivedOn;
  final JourneyTravelVisibility visibility;

  const ConfirmedTravelInput({
    required this.departedOn,
    this.route,
    this.arrivedOn,
    this.visibility = JourneyTravelVisibility.private,
  });
}

/// "I travelled on this" — the one explicit step that puts a journey in
/// the Passport, the way confirmed attendance does for an event. Route and
/// arrival are optional (a member may not remember the itinerary); the
/// departure date is required and never in the future. Returns null when
/// dismissed.
Future<ConfirmedTravelInput?> showConfirmTravelSheet(
  BuildContext context, {
  required Journey journey,
  required List<JourneyRoute> routes,
}) => showModalBottomSheet<ConfirmedTravelInput>(
  context: context,
  isScrollControlled: true,
  backgroundColor: AppColors.ivory,
  shape: const RoundedRectangleBorder(
    borderRadius: BorderRadius.vertical(top: Radius.circular(CsRadius.large)),
  ),
  builder: (_) => _ConfirmTravelSheet(journey: journey, routes: routes),
);

class _ConfirmTravelSheet extends StatefulWidget {
  final Journey journey;
  final List<JourneyRoute> routes;

  const _ConfirmTravelSheet({required this.journey, required this.routes});

  @override
  State<_ConfirmTravelSheet> createState() => _ConfirmTravelSheetState();
}

class _ConfirmTravelSheetState extends State<_ConfirmTravelSheet> {
  JourneyRoute? _route;
  late DateTime _departedOn = DateUtils.dateOnly(DateTime.now());
  DateTime? _arrivedOn;
  bool _shareWithFriends = false;

  Future<void> _pickDeparture() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _departedOn,
      firstDate: DateTime(now.year - 20),
      lastDate: now, // future dates not allowed — this app's established rule
    );
    if (picked == null) return;
    setState(() {
      _departedOn = picked;
      if (_arrivedOn != null && _arrivedOn!.isBefore(picked)) _arrivedOn = null;
    });
  }

  Future<void> _pickArrival() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _arrivedOn ?? _departedOn,
      firstDate: _departedOn,
      lastDate: now,
    );
    if (picked != null) setState(() => _arrivedOn = picked);
  }

  String _date(DateTime d) =>
      MaterialLocalizations.of(context).formatMediumDate(d);

  @override
  Widget build(BuildContext context) {
    final label = CsTypography.eyebrow.copyWith(color: AppColors.taupe);
    final value = CsTypography.body.copyWith(color: AppColors.forestGreen);
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          CsSpacing.pageHorizontal,
          CsSpacing.xl,
          CsSpacing.pageHorizontal,
          CsSpacing.xl + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'I travelled on this',
              style: CsTypography.sectionTitle.copyWith(
                color: AppColors.forestGreen,
              ),
            ),
            const SizedBox(height: CsSpacing.xs),
            Text(
              widget.journey.name,
              style: CsTypography.metadata.copyWith(color: AppColors.taupe),
            ),
            if (widget.routes.isNotEmpty) ...[
              const SizedBox(height: CsSpacing.xl),
              Text('ROUTE', style: label),
              DropdownButton<JourneyRoute?>(
                isExpanded: true,
                value: _route,
                // The ivory of the sheet, not Material's default menu tint.
                dropdownColor: AppColors.ivory,
                style: value,
                underline: const Divider(
                  height: 1,
                  color: AppColors.subtleBorderLight,
                ),
                hint: Text('Not sure', style: value),
                items: [
                  DropdownMenuItem<JourneyRoute?>(
                    value: null,
                    child: Text('Not sure', style: value),
                  ),
                  for (final route in widget.routes)
                    DropdownMenuItem<JourneyRoute?>(
                      value: route,
                      child: Text(
                        route.name == route.endpoints
                            ? route.name
                            : '${route.name} · ${route.endpoints}',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                onChanged: (route) => setState(() => _route = route),
              ),
            ],
            const SizedBox(height: CsSpacing.lg),
            Row(
              children: [
                Expanded(
                  child: _DateField(
                    label: 'DEPARTED',
                    value: _date(_departedOn),
                    onTap: _pickDeparture,
                  ),
                ),
                const SizedBox(width: CsSpacing.base),
                Expanded(
                  child: _DateField(
                    label: 'ARRIVED',
                    value: _arrivedOn == null ? 'Optional' : _date(_arrivedOn!),
                    onTap: _pickArrival,
                  ),
                ),
              ],
            ),
            const SizedBox(height: CsSpacing.base),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              value: _shareWithFriends,
              activeTrackColor: AppColors.forestGreen,
              title: Text('Visible to friends', style: value),
              onChanged: (v) => setState(() => _shareWithFriends = v),
            ),
            const SizedBox(height: CsSpacing.lg),
            CsPrimaryButton(
              label: 'Add to my Passport',
              surface: CsSurface.light,
              onTap: () => Navigator.pop(
                context,
                ConfirmedTravelInput(
                  route: _route,
                  departedOn: _departedOn,
                  arrivedOn: _arrivedOn,
                  visibility: _shareWithFriends
                      ? JourneyTravelVisibility.friends
                      : JourneyTravelVisibility.private,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DateField extends StatelessWidget {
  final String label;
  final String value;
  final VoidCallback onTap;

  const _DateField({
    required this.label,
    required this.value,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: CsTypography.eyebrow.copyWith(color: AppColors.taupe),
        ),
        const SizedBox(height: CsSpacing.sm),
        Text(
          value,
          style: CsTypography.body.copyWith(color: AppColors.forestGreen),
        ),
        const SizedBox(height: CsSpacing.sm),
        const Divider(height: 1, color: AppColors.subtleBorderLight),
      ],
    ),
  );
}
