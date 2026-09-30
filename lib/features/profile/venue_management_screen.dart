import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants/app_colors.dart';
import '../../core/theme/cs_spacing.dart';
import '../../core/theme/cs_surface_context.dart';
import '../../core/theme/cs_typography.dart';
import '../../core/widgets/cs_primary_button.dart';
import '../../data/repositories/venue_about_repository.dart';
import '../../data/repositories/venue_photo_submission_repository.dart';
import '../../models/managed_venue.dart';
import '../../models/published_venue_photo.dart';
import '../../models/venue_about_submission.dart';
import '../../models/venue_photo_submission_status.dart';
import 'upload_venue_photo_screen.dart';

/// The management view a claim is supposed to unlock — reached from My
/// Venues, separate from the venue's own public detail page (which stays
/// exactly where it is; this is a different screen, not a mode of that
/// one). About-text editing (Phase 1) and photo management (this pass)
/// both live on this one screen — reordering/listing/status happen
/// inline here; the pick -> validate -> frame-preview -> submit sequence
/// for a NEW photo is its own pushed screen (UploadVenuePhotoScreen),
/// since that content genuinely needs the room a scrolling section on
/// this screen wouldn't comfortably give it, not because it's a
/// different feature. Event submission and problem reporting are each
/// their own later task — deliberately not scaffolded here, not even as
/// disabled buttons.
///
/// PHOTOS build on the existing venue_photo_submissions review queue and
/// storage bucket (both already RLS-gated onto venue_managers_* — see
/// this feature's own chat report) and the existing, previously-unused
/// VenuePhotoSubmissionRepository/venue_photo_pipeline.dart pipeline
/// (validate -> strip EXIF -> hash -> upload -> insert). Ordering reads
/// restaurant_photos/hotel_photos/private_chef_photos' own display_order
/// directly and writes ONLY through reorder_venue_photos() — never a
/// direct display_order UPDATE from this client. There is deliberately
/// NO interactive "position within the frame" control anywhere in this
/// feature: no schema field exists to persist one into (venue_photo_
/// submissions has no focus_x/focus_y at all, and the APPROVED tables'
/// own focus_x/focus_y is never read by any rendering code today — see
/// UploadVenuePhotoScreen/VenuePhotoFramePreview's own doc comments) —
/// that's a schema decision left to be made deliberately, not one this
/// UI task should make by building around it.
///
/// What this screen does NOT show, and why: address, coordinates, Place
/// ID, phone, website, MICHELIN stars/Keys, cuisine, and opening status
/// are all verified catalogue data a manager must never be able to
/// overwrite. Rather than render them read-only with an explanatory line
/// (the task's own fallback for "if the screen shows those fields at
/// all"), this phase simply doesn't show them — there is nothing to edit
/// or explain yet, so there's nothing to display. That read-only
/// treatment is the right shape once a report-a-problem flow exists to
/// point the explanatory line at; building it now would be a line
/// explaining a feature that doesn't exist.
class VenueManagementScreen extends StatefulWidget {
  final ManagedVenue venue;

  // Optional DI seams, matching every other screen in this feature.
  final VenueAboutRepository? aboutRepo;
  final VenuePhotoSubmissionRepository? photoRepo;

  const VenueManagementScreen({
    super.key,
    required this.venue,
    this.aboutRepo,
    this.photoRepo,
  });

  @override
  State<VenueManagementScreen> createState() => _VenueManagementScreenState();
}

class _AboutState {
  final String? currentText;
  final VenueAboutSubmission? latestSubmission;
  const _AboutState({required this.currentText, required this.latestSubmission});
}

class _PhotosState {
  final List<PublishedVenuePhoto> published;
  final List<VenuePhotoSubmissionSummary> openSubmissions;
  final Map<String, String> submissionPhotoUrls;
  const _PhotosState({
    required this.published,
    required this.openSubmissions,
    required this.submissionPhotoUrls,
  });
}

class _VenueManagementScreenState extends State<VenueManagementScreen> {
  late final _aboutRepo = widget.aboutRepo ?? VenueAboutRepository(Supabase.instance.client);
  late final _photoRepo =
      widget.photoRepo ?? VenuePhotoSubmissionRepository(Supabase.instance.client);

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

  late Future<_PhotosState> _photosFuture;
  bool _reordering = false;
  String? _photosError;

  @override
  void initState() {
    super.initState();
    _load();
    _loadPhotos();
  }

  @override
  void dispose() {
    _textCtrl.dispose();
    super.dispose();
  }

  void _loadPhotos() {
    setState(() {
      _photosFuture = () async {
        final published = await _photoRepo.loadPublishedPhotos(
          venueType: widget.venue.venueTypeWireValue,
          venueId: widget.venue.id,
        );
        final open = await _photoRepo.loadMyOpenSubmissions(
          venueType: widget.venue.venueTypeWireValue,
          venueId: widget.venue.id,
        );
        final urls = await _photoRepo.resolveDisplayUrls([
          for (final s in open) s.storagePath,
        ]);
        return _PhotosState(published: published, openSubmissions: open, submissionPhotoUrls: urls);
      }();
    });
  }

  Future<void> _movePhoto(List<PublishedVenuePhoto> current, int index, int delta) async {
    final target = index + delta;
    if (target < 0 || target >= current.length || _reordering) return;
    final reordered = List<PublishedVenuePhoto>.from(current);
    final moved = reordered.removeAt(index);
    reordered.insert(target, moved);
    setState(() {
      _reordering = true;
      _photosError = null;
    });
    try {
      await _photoRepo.reorderPhotos(
        venueType: widget.venue.venueTypeWireValue,
        venueId: widget.venue.id,
        photoIds: [for (final p in reordered) p.id],
      );
      if (!mounted) return;
      setState(() => _reordering = false);
      _loadPhotos();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _reordering = false;
        _photosError = 'Could not reorder photos. Please try again.';
      });
    }
  }

  Future<void> _addPhoto(List<PublishedVenuePhoto> published) async {
    final added = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => UploadVenuePhotoScreen(venue: widget.venue, publishedPhotos: published),
      ),
    );
    if (added == true) _loadPhotos();
  }

  void _load() {
    setState(() {
      _future = Future.wait([
        _aboutRepo.loadCurrentText(venueType: widget.venue.venueTypeWireValue, venueId: widget.venue.id),
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
        return _AboutState(currentText: currentText, latestSubmission: results[1] as VenueAboutSubmission?);
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
        _error = e is StateError ? e.message : 'Could not submit. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.warmWhite,
      appBar: AppBar(
        title: Text(
          'Manage venue',
          style: CsTypography.placeTitle.copyWith(color: AppColors.forestGreen, fontSize: 20),
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
              child: CircularProgressIndicator(color: AppColors.forestGreen, strokeWidth: 1.5),
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
            onRefresh: () async {
              _load();
              _loadPhotos();
            },
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
      padding: const EdgeInsets.symmetric(horizontal: CsSpacing.pageHorizontal, vertical: CsSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.venue.name,
            style: CsTypography.placeTitle.copyWith(color: AppColors.forestGreen, fontSize: 22),
          ),
          const SizedBox(height: 2),
          Text(
            [
              if (widget.venue.cityName != null && widget.venue.cityName!.isNotEmpty)
                widget.venue.cityName!,
              widget.venue.typeLabel,
            ].join(' · '),
            style: CsTypography.body.copyWith(color: AppColors.taupe),
          ),
          const SizedBox(height: CsSpacing.lg),

          Text('CURRENT TEXT', style: CsTypography.eyebrow.copyWith(color: AppColors.taupe)),
          const SizedBox(height: CsSpacing.sm),
          Text(
            (state.currentText == null || state.currentText!.isEmpty)
                ? 'Nothing published yet.'
                : state.currentText!,
            style: CsTypography.body.copyWith(color: AppColors.forestGreen, height: 1.5),
          ),

          if (submission != null && submission.status != VenueAboutSubmissionStatus.approved) ...[
            const SizedBox(height: CsSpacing.md),
            _StatusBanner(status: submission.status, reviewNote: submission.reviewNote),
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
                  style: CsTypography.body.copyWith(color: AppColors.forestGreen, height: 1.5),
                ),
              ],
            ),
          ),

          const SizedBox(height: CsSpacing.lg),
          Text('WRITE A NEW VERSION', style: CsTypography.eyebrow.copyWith(color: AppColors.taupe)),
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
            Text(_error!, style: CsTypography.metadata.copyWith(color: AppColors.error)),
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
          Container(height: 1, color: AppColors.cardBorder),
          const SizedBox(height: CsSpacing.xl),
          _photosSection(),
          const SizedBox(height: CsSpacing.xxl),
        ],
      ),
    );
  }

  Widget _photosSection() {
    return FutureBuilder<_PhotosState>(
      future: _photosFuture,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: CsSpacing.lg),
              child: CircularProgressIndicator(color: AppColors.forestGreen, strokeWidth: 1.5),
            ),
          );
        }
        if (snap.hasError) {
          return Text(
            'Could not load photos. Pull down to try again.',
            style: CsTypography.body.copyWith(color: AppColors.taupe),
          );
        }
        final state = snap.data!;
        final isPrivateChef = widget.venue.venueTypeWireValue == 'private_chef';

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('PHOTOS', style: CsTypography.eyebrow.copyWith(color: AppColors.taupe)),
            const SizedBox(height: CsSpacing.sm),
            Text(
              state.published.isEmpty
                  ? 'No photos published yet.'
                  : 'The first photo below is the one that appears first on the venue\'s page.',
              style: CsTypography.body.copyWith(color: AppColors.taupe),
            ),
            if (isPrivateChef && state.published.isNotEmpty) ...[
              const SizedBox(height: CsSpacing.xs),
              Text(
                'Your first photo should be a portrait of you — not a plate, the dining '
                'room, or the kitchen.',
                style: CsTypography.body.copyWith(
                  color: AppColors.forestGreen,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            if (state.published.isNotEmpty) ...[
              const SizedBox(height: CsSpacing.md),
              for (var i = 0; i < state.published.length; i++)
                _PublishedPhotoRow(
                  photo: state.published[i],
                  isFirst: i == 0,
                  canMoveUp: i > 0,
                  canMoveDown: i < state.published.length - 1,
                  busy: _reordering,
                  onMoveUp: () => _movePhoto(state.published, i, -1),
                  onMoveDown: () => _movePhoto(state.published, i, 1),
                ),
            ],
            if (_photosError != null) ...[
              const SizedBox(height: CsSpacing.sm),
              Text(_photosError!, style: CsTypography.metadata.copyWith(color: AppColors.error)),
            ],
            if (state.openSubmissions.isNotEmpty) ...[
              const SizedBox(height: CsSpacing.lg),
              Text(
                'AWAITING OR NOT APPROVED',
                style: CsTypography.eyebrow.copyWith(color: AppColors.taupe),
              ),
              const SizedBox(height: CsSpacing.sm),
              for (final submission in state.openSubmissions)
                _OpenSubmissionRow(
                  submission: submission,
                  imageUrl: state.submissionPhotoUrls[submission.storagePath],
                ),
            ],
            const SizedBox(height: CsSpacing.lg),
            SizedBox(
              width: double.infinity,
              child: CsPrimaryButton(
                label: 'Add a photo',
                surface: CsSurface.light,
                onTap: () => _addPhoto(state.published),
              ),
            ),
          ],
        );
      },
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
              child: Text(text, style: CsTypography.metadata.copyWith(color: AppColors.taupe)),
            ),
          ],
        ),
        if (status == VenueAboutSubmissionStatus.rejected &&
            (reviewNote ?? '').trim().isNotEmpty) ...[
          const SizedBox(height: 2),
          Text(reviewNote!, style: CsTypography.metadata.copyWith(color: AppColors.taupe)),
        ],
      ],
    );
  }
}

/// One PUBLISHED photo — thumbnail, "Appears first" tag on index 0 (so
/// "which photo comes first" is never ambiguous), and up/down controls
/// that call VenueManagementScreen's own _movePhoto, which goes through
/// reorder_venue_photos — this row never writes display_order itself.
class _PublishedPhotoRow extends StatelessWidget {
  final PublishedVenuePhoto photo;
  final bool isFirst;
  final bool canMoveUp;
  final bool canMoveDown;
  final bool busy;
  final VoidCallback onMoveUp;
  final VoidCallback onMoveDown;

  const _PublishedPhotoRow({
    required this.photo,
    required this.isFirst,
    required this.canMoveUp,
    required this.canMoveDown,
    required this.busy,
    required this.onMoveUp,
    required this.onMoveDown,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: CsSpacing.xs),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.network(
              photo.imageUrl,
              width: 56,
              height: 56,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => const SizedBox(width: 56, height: 56),
            ),
          ),
          const SizedBox(width: CsSpacing.sm),
          Expanded(
            child: isFirst
                ? Text(
                    'Appears first',
                    style: CsTypography.body.copyWith(
                      color: AppColors.forestGreen,
                      fontWeight: FontWeight.w600,
                    ),
                  )
                : const SizedBox.shrink(),
          ),
          IconButton(
            onPressed: busy || !canMoveUp ? null : onMoveUp,
            icon: const Icon(Icons.keyboard_arrow_up_rounded),
            color: AppColors.forestGreen,
            tooltip: 'Move earlier',
          ),
          IconButton(
            onPressed: busy || !canMoveDown ? null : onMoveDown,
            icon: const Icon(Icons.keyboard_arrow_down_rounded),
            color: AppColors.forestGreen,
            tooltip: 'Move later',
          ),
        ],
      ),
    );
  }
}

/// One PENDING or REJECTED submission — never shown with any ordering
/// control (per explicit instruction: a pending submission has no
/// position until it's approved). A rejected row surfaces review_note
/// plainly when the reviewer left one, so "this needs to be a photo of
/// you" actually reaches the manager rather than a bare status.
class _OpenSubmissionRow extends StatelessWidget {
  final VenuePhotoSubmissionSummary submission;
  final String? imageUrl;

  const _OpenSubmissionRow({required this.submission, required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    final isPending = submission.status == VenuePhotoSubmissionStatus.pending;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: CsSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: imageUrl == null
                ? const SizedBox(width: 56, height: 56)
                : Image.network(
                    imageUrl!,
                    width: 56,
                    height: 56,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => const SizedBox(width: 56, height: 56),
                  ),
          ),
          const SizedBox(width: CsSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      isPending ? Icons.hourglass_top_outlined : Icons.storefront_outlined,
                      size: 16,
                      color: AppColors.forestGreen,
                    ),
                    const SizedBox(width: CsSpacing.xs),
                    Text(
                      isPending ? 'Awaiting review' : 'Not approved',
                      style: CsTypography.body.copyWith(color: AppColors.forestGreen),
                    ),
                  ],
                ),
                if (!isPending && (submission.reviewNote ?? '').trim().isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    submission.reviewNote!,
                    style: CsTypography.metadata.copyWith(color: AppColors.taupe),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
