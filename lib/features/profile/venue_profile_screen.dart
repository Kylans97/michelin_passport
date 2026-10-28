import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants/app_colors.dart';
import '../../core/theme/cs_spacing.dart';
import '../../core/theme/cs_surface_context.dart';
import '../../core/theme/cs_typography.dart';
import '../../core/widgets/cs_primary_button.dart';
import '../../data/repositories/venue_about_repository.dart';
import '../../models/managed_venue.dart';
import '../../models/venue_about_submission.dart';

/// Profile, reached from a venue's landing page (VenueManagementScreen):
/// the venue's current approved about text, the status of its latest
/// submission, and a new version to submit for review. Split out of the
/// former one-screen VenueManagementScreen unchanged (venue events plan
/// phase 2) — the same load, prefill and submit behaviour as before.
class VenueProfileScreen extends StatefulWidget {
  final ManagedVenue venue;
  final VenueAboutRepository? aboutRepo;

  const VenueProfileScreen({super.key, required this.venue, this.aboutRepo});

  @override
  State<VenueProfileScreen> createState() => _VenueProfileScreenState();
}

class _AboutState {
  final String? currentText;
  final VenueAboutSubmission? latestSubmission;
  const _AboutState({
    required this.currentText,
    required this.latestSubmission,
  });
}

class _VenueProfileScreenState extends State<VenueProfileScreen> {
  late final _aboutRepo =
      widget.aboutRepo ?? VenueAboutRepository(Supabase.instance.client);

  late Future<_AboutState> _future;
  final _textCtrl = TextEditingController();
  bool _submitting = false;
  String? _error;

  // Prefill the field from the venue's current text exactly once, on
  // first load — never on a later reload (after a successful submit, or
  // a manual pull-to-refresh), which would otherwise silently overwrite
  // whatever the manager is mid-typing, or just submitted, with the
  // OLD (still-current, since their submission is still pending)
  // approved text.
  bool _hasPrefilledText = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _textCtrl.dispose();
    super.dispose();
  }

  void _load() {
    setState(() {
      _future =
          Future.wait([
            _aboutRepo.loadCurrentText(
              venueType: widget.venue.venueTypeWireValue,
              venueId: widget.venue.id,
            ),
            _aboutRepo.loadMyLatestSubmission(
              venueType: widget.venue.venueTypeWireValue,
              venueId: widget.venue.id,
            ),
          ]).then((results) {
            final currentText = results[0] as String?;
            if (!_hasPrefilledText) {
              _textCtrl.text = currentText ?? '';
              _hasPrefilledText = true;
            }
            return _AboutState(
              currentText: currentText,
              latestSubmission: results[1] as VenueAboutSubmission?,
            );
          });
    });
  }

  Future<void> _submit() async {
    if (_submitting) return;
    final text = _textCtrl.text.trim();
    if (text.isEmpty) {
      setState(() => _error = 'Write something before submitting.');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await _aboutRepo.submit(
        venueType: widget.venue.venueTypeWireValue,
        venueId: widget.venue.id,
        aboutText: text,
      );
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Submitted for review.')));
      _load();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = e is StateError
            ? e.message
            : 'Could not submit. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.warmWhite,
      appBar: AppBar(
        title: Text(
          'Profile',
          style: CsTypography.placeTitle.copyWith(
            color: AppColors.forestGreen,
            fontSize: 20,
          ),
        ),
        backgroundColor: AppColors.warmWhite,
        surfaceTintColor: Colors.transparent,
        iconTheme: const IconThemeData(color: AppColors.forestGreen),
      ),
      body: FutureBuilder<_AboutState>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(
                color: AppColors.forestGreen,
                strokeWidth: 1.5,
              ),
            );
          }
          if (snap.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(CsSpacing.xl),
                child: Text(
                  'Something went wrong. Pull down to try again.',
                  textAlign: TextAlign.center,
                  style: CsTypography.body.copyWith(color: AppColors.taupe),
                ),
              ),
            );
          }
          final state = snap.data!;
          return RefreshIndicator(
            color: AppColors.forestGreen,
            backgroundColor: AppColors.warmWhite,
            onRefresh: () async => _load(),
            child: _form(state),
          );
        },
      ),
    );
  }

  Widget _form(_AboutState state) {
    final submission = state.latestSubmission;
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(
        horizontal: CsSpacing.pageHorizontal,
        vertical: CsSpacing.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'CURRENT TEXT',
            style: CsTypography.eyebrow.copyWith(color: AppColors.taupe),
          ),
          const SizedBox(height: CsSpacing.sm),
          Text(
            (state.currentText == null || state.currentText!.isEmpty)
                ? 'Nothing published yet.'
                : state.currentText!,
            style: CsTypography.body.copyWith(
              color: AppColors.forestGreen,
              height: 1.5,
            ),
          ),

          if (submission != null &&
              submission.status != VenueAboutSubmissionStatus.approved) ...[
            const SizedBox(height: CsSpacing.md),
            _StatusBanner(
              status: submission.status,
              reviewNote: submission.reviewNote,
            ),
          ],

          const SizedBox(height: CsSpacing.lg),
          Container(
            padding: const EdgeInsets.all(CsSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.cardBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'BEFORE YOU SUBMIT',
                  style: CsTypography.eyebrow.copyWith(color: AppColors.taupe),
                ),
                const SizedBox(height: CsSpacing.sm),
                Text(
                  "Your text does not appear on the venue's page right away. "
                  "We review every change by hand first, and you'll see the "
                  "outcome here — either way.",
                  style: CsTypography.body.copyWith(
                    color: AppColors.forestGreen,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: CsSpacing.lg),
          Text(
            'WRITE A NEW VERSION',
            style: CsTypography.eyebrow.copyWith(color: AppColors.taupe),
          ),
          const SizedBox(height: CsSpacing.sm),
          TextField(
            controller: _textCtrl,
            maxLines: 8,
            minLines: 4,
            maxLength: venueAboutTextMaxLength,
            style: CsTypography.body.copyWith(color: AppColors.forestGreen),
            decoration: InputDecoration(
              hintText: 'What should someone know about this place?',
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

          const SizedBox(height: CsSpacing.lg),
          SizedBox(
            width: double.infinity,
            child: CsPrimaryButton(
              label: 'Submit for review',
              surface: CsSurface.light,
              loading: _submitting,
              onTap: _submit,
            ),
          ),
          const SizedBox(height: CsSpacing.xxl),
        ],
      ),
    );
  }
}

class _StatusBanner extends StatelessWidget {
  final VenueAboutSubmissionStatus status;
  final String? reviewNote;
  const _StatusBanner({required this.status, this.reviewNote});

  @override
  Widget build(BuildContext context) {
    final (icon, text) = switch (status) {
      VenueAboutSubmissionStatus.pending => (
        Icons.hourglass_top_outlined,
        'Your latest submission is awaiting review.',
      ),
      VenueAboutSubmissionStatus.rejected => (
        Icons.storefront_outlined,
        "Your latest submission wasn't approved. The text below is your last "
            "submitted version — feel free to revise it.",
      ),
      VenueAboutSubmissionStatus.approved => (Icons.verified_outlined, ''),
    };
    // Same shape as _OpenSubmissionRow's own photo review_note line
    // (icon+status row, then the reviewer's note plainly below it when
    // one exists) — a rejection with no reason reaches the manager as a
    // bare status and nothing to act on.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: AppColors.forestGreen, size: 18),
            const SizedBox(width: CsSpacing.sm),
            Expanded(
              child: Text(
                text,
                style: CsTypography.metadata.copyWith(color: AppColors.taupe),
              ),
            ),
          ],
        ),
        if (status == VenueAboutSubmissionStatus.rejected &&
            (reviewNote ?? '').trim().isNotEmpty) ...[
          const SizedBox(height: 2),
          Text(
            reviewNote!,
            style: CsTypography.metadata.copyWith(color: AppColors.taupe),
          ),
        ],
      ],
    );
  }
}
