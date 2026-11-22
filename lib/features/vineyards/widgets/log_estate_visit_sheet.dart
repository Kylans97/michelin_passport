import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/cs_spacing.dart';
import '../../../core/theme/cs_surface_context.dart';
import '../../../core/theme/cs_typography.dart';
import '../../../core/widgets/cs_filter_chip.dart';
import '../../../core/widgets/cs_primary_button.dart';
import '../../../core/widgets/venue_visit_row.dart' show formatVenueVisitDate;
import '../../../models/vineyard.dart';
import '../../../models/vineyard_visit.dart';

/// What the member entered in [showLogEstateVisitSheet].
class EstateVisitInput {
  final DateTime visitedOn;
  final Set<VineyardActivity> activities;
  final String? comment;
  final bool friendsVisible;

  const EstateVisitInput({
    required this.visitedOn,
    this.activities = const {},
    this.comment,
    this.friendsVisible = false,
  });
}

/// "I visited this estate" — the one explicit step that puts a wine estate
/// in the Passport, the shape of "I travelled on this" for a journey. The
/// date is required and never in the future; what the member did there is
/// a few fixed activities, all optional. Returns null when dismissed.
///
/// With [initial] it edits that visit instead: filled in, "Save changes".
Future<EstateVisitInput?> showLogEstateVisitSheet(
  BuildContext context, {
  required Vineyard vineyard,
  VineyardVisit? initial,
}) => showModalBottomSheet<EstateVisitInput>(
  context: context,
  isScrollControlled: true,
  backgroundColor: AppColors.ivory,
  shape: const RoundedRectangleBorder(
    borderRadius: BorderRadius.vertical(top: Radius.circular(CsRadius.large)),
  ),
  builder: (_) => _LogEstateVisitSheet(vineyard: vineyard, initial: initial),
);

class _LogEstateVisitSheet extends StatefulWidget {
  final Vineyard vineyard;
  final VineyardVisit? initial;

  const _LogEstateVisitSheet({required this.vineyard, this.initial});

  @override
  State<_LogEstateVisitSheet> createState() => _LogEstateVisitSheetState();
}

class _LogEstateVisitSheetState extends State<_LogEstateVisitSheet> {
  late DateTime _visitedOn = DateUtils.dateOnly(
    widget.initial?.visitedOn ?? DateTime.now(),
  );
  late final Set<VineyardActivity> _activities = {
    ...?widget.initial?.activities,
  };
  late final _commentCtrl = TextEditingController(
    text: widget.initial?.comment ?? '',
  );
  late bool _shareWithFriends = widget.initial?.friendsVisible ?? false;

  @override
  void dispose() {
    _commentCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _visitedOn,
      // An older entry being edited keeps its own year reachable.
      firstDate: _visitedOn.year < now.year - 20
          ? _visitedOn
          : DateTime(now.year - 20),
      lastDate: now, // future dates not allowed — this app's established rule
    );
    if (picked != null) setState(() => _visitedOn = picked);
  }

  void _toggle(VineyardActivity activity) => setState(() {
    if (!_activities.remove(activity)) _activities.add(activity);
  });

  @override
  Widget build(BuildContext context) {
    final label = CsTypography.eyebrow.copyWith(color: AppColors.taupe);
    final value = CsTypography.body.copyWith(color: AppColors.forestGreen);
    return SafeArea(
      child: SingleChildScrollView(
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
              widget.initial == null ? 'I visited this estate' : 'Your visit',
              style: CsTypography.sectionTitle.copyWith(
                color: AppColors.forestGreen,
              ),
            ),
            const SizedBox(height: CsSpacing.xs),
            Text(
              widget.vineyard.name,
              style: CsTypography.metadata.copyWith(color: AppColors.taupe),
            ),
            const SizedBox(height: CsSpacing.xl),
            InkWell(
              onTap: _pickDate,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('WHEN', style: label),
                  const SizedBox(height: CsSpacing.sm),
                  Text(formatVenueVisitDate(_visitedOn), style: value),
                  const SizedBox(height: CsSpacing.sm),
                  const Divider(height: 1, color: AppColors.subtleBorderLight),
                ],
              ),
            ),
            const SizedBox(height: CsSpacing.lg),
            Text('WHAT YOU DID', style: label),
            const SizedBox(height: CsSpacing.md),
            Wrap(
              spacing: CsSpacing.sm,
              runSpacing: CsSpacing.sm,
              children: [
                for (final activity in VineyardActivity.values)
                  CsFilterChip(
                    label: activity.label,
                    selected: _activities.contains(activity),
                    surface: CsSurface.light,
                    onTap: () => _toggle(activity),
                  ),
              ],
            ),
            const SizedBox(height: CsSpacing.lg),
            TextField(
              controller: _commentCtrl,
              maxLines: 3,
              minLines: 1,
              style: value,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: 'A note for yourself',
                labelStyle: CsTypography.metadata.copyWith(
                  color: AppColors.taupe,
                ),
                enabledBorder: const UnderlineInputBorder(
                  borderSide: BorderSide(color: AppColors.subtleBorderLight),
                ),
                focusedBorder: const UnderlineInputBorder(
                  borderSide: BorderSide(color: AppColors.forestGreen),
                ),
              ),
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
              label: widget.initial == null
                  ? 'Add to my Passport'
                  : 'Save changes',
              surface: CsSurface.light,
              onTap: () => Navigator.pop(
                context,
                EstateVisitInput(
                  visitedOn: _visitedOn,
                  activities: Set.of(_activities),
                  comment: _commentCtrl.text,
                  friendsVisible: _shareWithFriends,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
