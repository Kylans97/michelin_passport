import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/cs_spacing.dart';
import '../../../core/theme/cs_surface_context.dart';
import '../../../core/theme/cs_typography.dart';
import '../../../core/widgets/cs_primary_button.dart';
import '../../../core/widgets/subtle_text_action.dart';
import '../../../data/repositories/venue_instagram_repository.dart';
import '../../../models/venue_about_submission.dart';

/// The venue's Instagram account, on the Profile screen under the about
/// text: what the page shows now, the latest submission's status, a field
/// for a new one and a way to take it off. A new account is reviewed
/// before it shows; taking it off happens at once.
class VenueInstagramEditor extends StatefulWidget {
  final String venueType;
  final String venueId;
  final VenueInstagramRepository repository;

  const VenueInstagramEditor({
    super.key,
    required this.venueType,
    required this.venueId,
    required this.repository,
  });

  @override
  State<VenueInstagramEditor> createState() => _VenueInstagramEditorState();
}

class _VenueInstagramEditorState extends State<VenueInstagramEditor> {
  final _ctrl = TextEditingController();
  late Future<(String?, VenueInstagramSubmission?)> _future;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _load() {
    setState(() {
      _future = Future.wait([
        widget.repository.loadCurrent(
          venueType: widget.venueType,
          venueId: widget.venueId,
        ),
        widget.repository.loadMyLatest(
          venueType: widget.venueType,
          venueId: widget.venueId,
        ),
      ]).then((r) => (r[0] as String?, r[1] as VenueInstagramSubmission?));
    });
  }

  Future<void> _submit() async {
    if (_busy) return;
    final handle = normalizeInstagramHandle(_ctrl.text);
    if (handle == null) {
      setState(
        () => _error =
            'Enter your Instagram name, like @yourvenue, or a link to your profile.',
      );
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.repository.submit(
        venueType: widget.venueType,
        venueId: widget.venueId,
        handle: handle,
      );
      if (!mounted) return;
      _ctrl.clear();
      setState(() => _busy = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Submitted for review.')));
      _load();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = 'Could not submit. Please try again.';
      });
    }
  }

  Future<void> _remove() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove your Instagram?'),
        content: const Text(
          'It comes off your page now, and anything still waiting for review is withdrawn.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Keep'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text('Remove', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _busy = true);
    try {
      await widget.repository.remove(
        venueType: widget.venueType,
        venueId: widget.venueId,
      );
      if (!mounted) return;
      setState(() => _busy = false);
      _load();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = 'Could not remove. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<(String?, VenueInstagramSubmission?)>(
      future: _future,
      builder: (context, snap) {
        final current = snap.data?.$1;
        final mine = snap.data?.$2;
        final showStatus =
            mine != null &&
            mine.removedAt == null &&
            mine.status != VenueAboutSubmissionStatus.approved;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'INSTAGRAM',
              style: CsTypography.eyebrow.copyWith(color: AppColors.taupe),
            ),
            const SizedBox(height: CsSpacing.sm),
            Text(
              snap.connectionState == ConnectionState.waiting
                  ? ''
                  : current == null
                  ? 'Not on your page yet.'
                  : 'On your page: @$current',
              style: CsTypography.body.copyWith(color: AppColors.forestGreen),
            ),
            if (showStatus) ...[
              const SizedBox(height: CsSpacing.xs),
              Text(
                mine.status == VenueAboutSubmissionStatus.rejected
                    ? "@${mine.handle} wasn't approved.${(mine.reviewNote?.trim().isNotEmpty ?? false) ? ' ${mine.reviewNote!.trim()}' : ''}"
                    : '@${mine.handle} is awaiting review.',
                style: CsTypography.metadata.copyWith(color: AppColors.taupe),
              ),
            ],
            const SizedBox(height: CsSpacing.md),
            TextField(
              controller: _ctrl,
              autocorrect: false,
              keyboardType: TextInputType.url,
              style: CsTypography.body.copyWith(color: AppColors.forestGreen),
              decoration: InputDecoration(
                hintText: '@yourvenue',
                hintStyle: CsTypography.body.copyWith(color: AppColors.taupe),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppColors.subtleBorderLight),
                ),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: CsSpacing.xs),
              Text(
                _error!,
                style: CsTypography.metadata.copyWith(color: AppColors.error),
              ),
            ],
            const SizedBox(height: CsSpacing.md),
            SizedBox(
              width: double.infinity,
              child: CsPrimaryButton(
                label: 'Submit for review',
                surface: CsSurface.light,
                loading: _busy,
                onTap: _submit,
              ),
            ),
            if (current != null || (mine?.isOpen ?? false)) ...[
              const SizedBox(height: CsSpacing.xs),
              SubtleTextAction(
                label: 'Remove from page',
                onTap: _busy ? () {} : _remove,
              ),
            ],
          ],
        );
      },
    );
  }
}
