import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/cs_spacing.dart';
import '../../../core/theme/cs_surface_context.dart';
import '../../../core/theme/cs_typography.dart';
import '../../../core/widgets/cs_primary_button.dart';
import '../../../data/repositories/report_repository.dart';
import '../../../models/content_report.dart';

/// The one shared Report entry point for every reportable surface
/// (a friend profile, a rating, a photo) — a single bottom sheet rather
/// than a bespoke dialog per call site, so the reason list and the
/// post-submit promise ("we'll look into it within 24 hours") never
/// drift between places. Shows the confirmation itself via the
/// *caller's* [context] after the sheet closes, so it survives the
/// sheet's own disposal.
Future<void> showReportSheet(
  BuildContext context, {
  required ReportContentType contentType,
  required String contentId,
}) async {
  final submitted = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.warmWhite,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (sheetContext) => _ReportSheet(
      contentType: contentType,
      contentId: contentId,
    ),
  );
  if (submitted == true && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          "Received — we'll look into it within 24 hours.",
          style: CsTypography.metadata.copyWith(color: AppColors.textOnDark),
        ),
        backgroundColor: AppColors.forestGreen,
        duration: const Duration(seconds: 3),
      ),
    );
  }
}

class _ReportSheet extends StatefulWidget {
  final ReportContentType contentType;
  final String contentId;

  const _ReportSheet({required this.contentType, required this.contentId});

  @override
  State<_ReportSheet> createState() => _ReportSheetState();
}

class _ReportSheetState extends State<_ReportSheet> {
  ReportReason? _reason;
  final _detailsController = TextEditingController();
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _detailsController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_reason == null || _submitting) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await ReportRepository(Supabase.instance.client).submitReport(
        contentType: widget.contentType,
        contentId: widget.contentId,
        reason: _reason!,
        details: _detailsController.text,
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
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Report',
          style: CsTypography.placeTitle.copyWith(
            color: AppColors.forestGreen,
            fontSize: 20,
          ),
        ),
        const SizedBox(height: CsSpacing.xs),
        Text(
          'Tell us what\'s wrong. We review every report by hand.',
          style: CsTypography.body.copyWith(color: AppColors.taupe),
        ),
        const SizedBox(height: CsSpacing.md),
        for (final reason in ReportReason.values)
          _ReasonRow(
            reason: reason,
            selected: _reason == reason,
            onTap: () => setState(() => _reason = reason),
          ),
        const SizedBox(height: CsSpacing.sm),
        TextField(
          controller: _detailsController,
          maxLines: 3,
          minLines: 1,
          style: CsTypography.body.copyWith(color: AppColors.forestGreen),
          decoration: InputDecoration(
            hintText: 'Add details (optional)',
            hintStyle: CsTypography.body.copyWith(color: AppColors.taupe),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppColors.subtleBorderLight),
            ),
          ),
        ),
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
            onTap: _reason == null ? null : _submit,
          ),
        ),
      ],
    ),
  );
}

class _ReasonRow extends StatelessWidget {
  final ReportReason reason;
  final bool selected;
  final VoidCallback onTap;

  const _ReasonRow({
    required this.reason,
    required this.selected,
    required this.onTap,
  });

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
            reason.label,
            style: CsTypography.body.copyWith(color: AppColors.forestGreen),
          ),
        ],
      ),
    ),
  );
}
