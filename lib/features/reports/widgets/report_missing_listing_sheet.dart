import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/cs_spacing.dart';
import '../../../core/theme/cs_surface_context.dart';
import '../../../core/theme/cs_typography.dart';
import '../../../core/widgets/cs_primary_button.dart';
import '../../../core/widgets/cs_text_field.dart';
import '../../../data/repositories/missing_listing_repository.dart';

/// "Report a missing restaurant, hotel or event" — reached from Explore's
/// and Events' own "no results" empty states, never a permanent nav
/// destination of its own. Same bottom-sheet chrome as
/// [showReportSheet]/`report_content_sheet.dart` (the closest existing
/// analog), and the same "show the confirmation via the CALLER's context"
/// pattern, so it survives this sheet's own disposal.
///
/// [initialQuery] pre-fills Name with whatever the person typed in the
/// search box that came up empty — the most likely thing to already be
/// the venue/event's actual name. Deliberately not split into name/city
/// heuristically (e.g. "Flore Amsterdam" isn't parsed into a guess at
/// which part is the city) — left as one editable field for the person to
/// correct themselves rather than risk a wrong automatic split.
///
/// [submitReport] is an optional DI seam forwarded straight to the
/// private sheet widget below — it lives on this public function
/// (not only the private widget) specifically so a test file, which can
/// never reference `_ReportMissingListingSheet` directly across Dart's
/// per-file privacy boundary, still has a way to inject a fake.
Future<void> showReportMissingListingSheet(
  BuildContext context, {
  required String initialQuery,
  Future<void> Function({
    required MissingListingSubjectType subjectType,
    required String name,
    required String city,
    required String message,
    String? reporterRole,
    String? reporterContact,
  })?
  submitReport,
}) async {
  final submitted = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.warmWhite,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => _ReportMissingListingSheet(
      initialQuery: initialQuery,
      submitReport: submitReport,
    ),
  );
  if (submitted == true && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          "Thank you — we'll take a look.",
          style: CsTypography.metadata.copyWith(color: AppColors.textOnDark),
        ),
        backgroundColor: AppColors.forestGreen,
        duration: const Duration(seconds: 3),
      ),
    );
  }
}

/// [submitReport] is an optional DI seam (same constructor-injection
/// convention as every other Supabase-backed screen built this session)
/// defaulting to the real [MissingListingRepository]-backed call.
class _ReportMissingListingSheet extends StatefulWidget {
  final String initialQuery;
  final Future<void> Function({
    required MissingListingSubjectType subjectType,
    required String name,
    required String city,
    required String message,
    String? reporterRole,
    String? reporterContact,
  })?
  submitReport;

  const _ReportMissingListingSheet({
    required this.initialQuery,
    this.submitReport,
  });

  @override
  State<_ReportMissingListingSheet> createState() =>
      _ReportMissingListingSheetState();
}

class _ReportMissingListingSheetState
    extends State<_ReportMissingListingSheet> {
  MissingListingSubjectType? _type;
  late final _nameCtrl = TextEditingController(text: widget.initialQuery);
  final _cityCtrl = TextEditingController();
  final _messageCtrl = TextEditingController();
  bool _worksHere = false;
  final _roleCtrl = TextEditingController();
  final _contactCtrl = TextEditingController();
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _cityCtrl.dispose();
    _messageCtrl.dispose();
    _roleCtrl.dispose();
    _contactCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitting) return;
    if (_type == null) {
      setState(() => _error = 'Choose a type');
      return;
    }
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Enter a name');
      return;
    }
    final city = _cityCtrl.text.trim();
    if (city.isEmpty) {
      setState(() => _error = 'Enter a city');
      return;
    }
    final message = _messageCtrl.text.trim();
    if (message.isEmpty) {
      setState(() => _error = "Tell us why it belongs — that's the part "
          "we can't find out ourselves");
      return;
    }
    String? role;
    String? contact;
    if (_worksHere) {
      role = _roleCtrl.text.trim();
      contact = _contactCtrl.text.trim();
      if (role.isEmpty || contact.isEmpty) {
        setState(() => _error = 'Enter your role and a way to reach you');
        return;
      }
    }

    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final submit =
          widget.submitReport ??
          MissingListingRepository(Supabase.instance.client).submitReport;
      await submit(
        subjectType: _type!,
        name: name,
        city: city,
        message: message,
        reporterRole: role,
        reporterContact: contact,
      );
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = 'Could not send this report. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(
      left: CsSpacing.pageHorizontal,
      right: CsSpacing.pageHorizontal,
      top: CsSpacing.lg,
      bottom: MediaQuery.of(context).viewInsets.bottom + CsSpacing.lg,
    ),
    child: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Report a missing listing",
            style: CsTypography.placeTitle.copyWith(
              color: AppColors.forestGreen,
              fontSize: 20,
            ),
          ),
          const SizedBox(height: CsSpacing.xs),
          Text(
            "Tell us what we're missing.",
            style: CsTypography.body.copyWith(color: AppColors.taupe),
          ),
          const SizedBox(height: CsSpacing.md),
          for (final type in MissingListingSubjectType.values)
            _TypeRow(
              type: type,
              selected: _type == type,
              onTap: () => setState(() => _type = type),
            ),
          const SizedBox(height: CsSpacing.sm),
          CsTextField(
            label: 'Name',
            controller: _nameCtrl,
            surface: CsSurface.light,
          ),
          const SizedBox(height: CsSpacing.md),
          CsTextField(
            label: 'City',
            controller: _cityCtrl,
            surface: CsSurface.light,
          ),
          const SizedBox(height: CsSpacing.md),
          Text(
            'Why does it belong?',
            style: CsTypography.eyebrow.copyWith(color: AppColors.taupe),
          ),
          const SizedBox(height: CsSpacing.sm),
          TextField(
            key: const Key('missingListingMessageField'),
            controller: _messageCtrl,
            maxLines: 5,
            minLines: 3,
            style: CsTypography.body.copyWith(color: AppColors.forestGreen),
            decoration: InputDecoration(
              hintText:
                  'What makes this worth adding — a four-hands dinner, a '
                  'guest chef, a new opening…',
              hintStyle: CsTypography.body.copyWith(color: AppColors.taupe),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppColors.subtleBorderLight),
              ),
            ),
          ),
          const SizedBox(height: CsSpacing.md),
          InkWell(
            onTap: () => setState(() => _worksHere = !_worksHere),
            borderRadius: BorderRadius.circular(10),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  Icon(
                    _worksHere
                        ? Icons.check_box_rounded
                        : Icons.check_box_outline_blank_rounded,
                    size: 20,
                    color: AppColors.forestGreen,
                  ),
                  const SizedBox(width: CsSpacing.sm),
                  Expanded(
                    child: Text(
                      'I work here',
                      style: CsTypography.body.copyWith(
                        color: AppColors.forestGreen,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_worksHere) ...[
            const SizedBox(height: CsSpacing.sm),
            CsTextField(
              label: 'Your role',
              controller: _roleCtrl,
              surface: CsSurface.light,
            ),
            const SizedBox(height: CsSpacing.md),
            CsTextField(
              label: 'Email or phone',
              controller: _contactCtrl,
              surface: CsSurface.light,
            ),
            const SizedBox(height: CsSpacing.xs),
            Text(
              "We'll only use this to contact you about this report.",
              style: CsTypography.metadata.copyWith(color: AppColors.taupe),
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: CsSpacing.sm),
            Text(
              _error!,
              style: CsTypography.metadata.copyWith(color: AppColors.error),
            ),
          ],
          const SizedBox(height: CsSpacing.md),
          SizedBox(
            width: double.infinity,
            child: CsPrimaryButton(
              label: 'Send report',
              surface: CsSurface.light,
              loading: _submitting,
              onTap: _submit,
            ),
          ),
        ],
      ),
    ),
  );
}

class _TypeRow extends StatelessWidget {
  final MissingListingSubjectType type;
  final bool selected;
  final VoidCallback onTap;

  const _TypeRow({
    required this.type,
    required this.selected,
    required this.onTap,
  });

  String get _label => switch (type) {
    MissingListingSubjectType.restaurant => 'Restaurant',
    MissingListingSubjectType.hotel => 'Hotel',
    MissingListingSubjectType.event => 'Event',
  };

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(10),
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Icon(
            selected
                ? Icons.radio_button_checked_rounded
                : Icons.radio_button_unchecked_rounded,
            size: 20,
            color: selected ? AppColors.forestGreen : AppColors.taupe,
          ),
          const SizedBox(width: CsSpacing.sm),
          Text(
            _label,
            style: CsTypography.body.copyWith(color: AppColors.forestGreen),
          ),
        ],
      ),
    ),
  );
}
