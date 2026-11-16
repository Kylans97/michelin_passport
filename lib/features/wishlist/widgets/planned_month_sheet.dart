import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/cs_spacing.dart';
import '../../../core/theme/cs_surface_context.dart';
import '../../../core/theme/cs_typography.dart';
import '../../../core/widgets/cs_primary_button.dart';
import '../../../core/widgets/sheet_dismiss_handle.dart';
import '../../../core/widgets/subtle_text_action.dart';
import '../../../models/booking_window.dart';

/// What the member chose in [showPlannedMonthSheet].
sealed class PlannedMonthChoice {
  const PlannedMonthChoice();
}

/// A month (its 1st).
class PlannedMonthSet extends PlannedMonthChoice {
  final DateTime month;
  const PlannedMonthSet(this.month);
}

/// The month taken off.
class PlannedMonthCleared extends PlannedMonthChoice {
  const PlannedMonthCleared();
}

/// "When would you like to go?" — asked once a restaurant is saved, and
/// from the wishlist card to change or clear it (20261101400000). Always
/// optional: "Not sure yet", the close button and a swipe all return null
/// and change nothing. Month and year only, from this month up to three
/// years ahead — the same range set_wishlist_planned_month accepts.
Future<PlannedMonthChoice?> showPlannedMonthSheet(
  BuildContext context, {
  required String restaurantName,
  DateTime? initial,
  DateTime? now,
}) => showModalBottomSheet<PlannedMonthChoice>(
  context: context,
  isScrollControlled: true,
  backgroundColor: Colors.transparent,
  builder: (_) => PlannedMonthSheet(
    restaurantName: restaurantName,
    initial: initial,
    now: now ?? DateTime.now(),
  ),
);

class PlannedMonthSheet extends StatefulWidget {
  final String restaurantName;
  final DateTime? initial;
  final DateTime now;

  const PlannedMonthSheet({
    super.key,
    required this.restaurantName,
    this.initial,
    required this.now,
  });

  @override
  State<PlannedMonthSheet> createState() => _PlannedMonthSheetState();
}

class _PlannedMonthSheetState extends State<PlannedMonthSheet> {
  late final DateTime _first = DateTime(widget.now.year, widget.now.month);
  late final DateTime _last = DateTime(widget.now.year + 3, widget.now.month);
  late int _year = widget.initial?.year ?? widget.now.year;
  late DateTime? _selected = widget.initial == null
      ? null
      : DateTime(widget.initial!.year, widget.initial!.month);

  bool _allowed(DateTime month) =>
      !month.isBefore(_first) && !month.isAfter(_last);

  @override
  Widget build(BuildContext context) {
    final years = [for (var y = _first.year; y <= _last.year; y++) y];
    return SafeArea(
      top: false,
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.92,
        ),
        decoration: const BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 14, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SheetDismissHandle(
                color: AppColors.textPrimary,
                onClose: () => Navigator.pop(context),
              ),
              const SizedBox(height: CsSpacing.lg),
              Text(
                'WHEN WOULD YOU LIKE TO GO?',
                style: CsTypography.eyebrow.copyWith(color: AppColors.taupe),
              ),
              const SizedBox(height: CsSpacing.sm),
              Text(
                widget.restaurantName,
                style: CsTypography.placeTitle.copyWith(
                  color: AppColors.forestGreen,
                  fontSize: 24,
                ),
              ),
              const SizedBox(height: CsSpacing.sm),
              Text(
                'Optional. If we know when its bookings open, we’ll tell you '
                'the day before.',
                style: CsTypography.body.copyWith(
                  color: AppColors.textSecondary,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: CsSpacing.lg),
              Wrap(
                spacing: CsSpacing.sm,
                runSpacing: CsSpacing.sm,
                children: [
                  for (final y in years)
                    _Choice(
                      label: '$y',
                      selected: y == _year,
                      onTap: () => setState(() => _year = y),
                    ),
                ],
              ),
              const SizedBox(height: CsSpacing.md),
              GridView.count(
                crossAxisCount: 4,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: CsSpacing.sm,
                crossAxisSpacing: CsSpacing.sm,
                childAspectRatio: 2.1,
                children: [
                  for (var m = 1; m <= 12; m++)
                    Builder(
                      builder: (context) {
                        final month = DateTime(_year, m);
                        final enabled = _allowed(month);
                        return _Choice(
                          label: monthNames[m - 1].substring(0, 3),
                          semanticLabel: monthYear(month),
                          selected: _selected == month,
                          enabled: enabled,
                          onTap: () => setState(() => _selected = month),
                        );
                      },
                    ),
                ],
              ),
              const SizedBox(height: CsSpacing.lg),
              SizedBox(
                width: double.infinity,
                child: CsPrimaryButton(
                  label: _selected == null
                      ? 'Choose a month'
                      : 'Save ${monthYear(_selected!)}',
                  surface: CsSurface.light,
                  onTap: _selected == null
                      ? null
                      : () =>
                            Navigator.pop(context, PlannedMonthSet(_selected!)),
                ),
              ),
              const SizedBox(height: CsSpacing.xs),
              Center(
                child: widget.initial == null
                    ? SubtleTextAction(
                        label: 'Not sure yet',
                        onTap: () => Navigator.pop(context),
                      )
                    : SubtleTextAction(
                        label: 'Clear the month',
                        onTap: () =>
                            Navigator.pop(context, const PlannedMonthCleared()),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Choice extends StatelessWidget {
  final String label;
  final String? semanticLabel;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  const _Choice({
    required this.label,
    this.semanticLabel,
    required this.selected,
    this.enabled = true,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: selected,
    enabled: enabled,
    label: semanticLabel ?? label,
    child: InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(CsRadius.pill),
      child: Container(
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.forestGreen : Colors.transparent,
          border: Border.all(
            color: selected
                ? AppColors.forestGreen
                : AppColors.subtleBorderLight,
          ),
          borderRadius: BorderRadius.circular(CsRadius.pill),
        ),
        child: ExcludeSemantics(
          child: Text(
            label,
            style: CsTypography.bodyMedium.copyWith(
              color: selected
                  ? AppColors.warmWhite
                  : enabled
                  ? AppColors.forestGreen
                  : AppColors.subtleBorderLight,
            ),
          ),
        ),
      ),
    ),
  );
}
