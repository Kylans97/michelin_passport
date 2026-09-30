import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/venue_photo_submission_limits.dart';
import '../../core/theme/cs_spacing.dart';
import '../../core/theme/cs_surface_context.dart';
import '../../core/theme/cs_typography.dart';
import '../../core/widgets/cs_primary_button.dart';
import '../../data/repositories/venue_photo_submission_repository.dart';
import '../../data/services/venue_photo_pipeline.dart';
import '../../models/managed_venue.dart';
import '../../models/published_venue_photo.dart';
import 'widgets/venue_photo_frame_preview.dart';
import 'widgets/venue_photo_picker.dart';

/// One or more photos, from pick through submission — pushed from
/// VenueManagementScreen's own Photos section (see that screen's doc
/// comment for why this is a separate pushed screen rather than inlined:
/// the guidance + frame preview genuinely need the room).
///
/// Flow: pick up to the venue's remaining capacity at once -> each one is
/// validated immediately (a photo that fails is reported and dropped, the
/// rest continue — never all-or-nothing) -> step through the surviving
/// photos one at a time (frame preview + "photo X of Y") -> one "Submit"
/// at the end sends all of them, each independently (one upload failing
/// never rolls back the ones that already succeeded, same as
/// AttendancePhotosSection's own established multi-upload loop).
///
/// Pops `true` iff at least one submission actually landed, so the caller
/// knows to reload; never pops `true` before a write has actually
/// succeeded.
class UploadVenuePhotoScreen extends StatefulWidget {
  final ManagedVenue venue;

  /// The venue's current published photos — only needed to know whether
  /// it's already at maxVenuePhotoCount, which requires naming a
  /// replacement (venue_photo_submissions_replacement_check), and to
  /// compute how many more may be picked at once. Passed in rather than
  /// reloaded here, since VenueManagementScreen already has this list.
  final List<PublishedVenuePhoto> publishedPhotos;

  // Optional DI seams, matching this feature's established convention.
  final VenuePhotoSubmissionRepository? repository;
  final Future<List<StagedVenuePhoto>> Function(BuildContext, {required int maxSelectable})? pickPhotos;

  /// Overrides the signed-in user id used at submission time — a plain
  /// value, not a function, mirroring how the rest of this screen's
  /// dependencies are injected. Defaults to
  /// Supabase.instance.client.auth.currentUser?.id, which (unlike the
  /// repository/pickPhotos seams above) was previously read directly
  /// inside _submit() with no override at all — a real gap this
  /// feature's own tests caught (Supabase.instance throws with no
  /// session initialized), not a hypothetical one.
  final String? currentUserId;

  const UploadVenuePhotoScreen({
    super.key,
    required this.venue,
    required this.publishedPhotos,
    this.repository,
    this.pickPhotos,
    this.currentUserId,
  });

  @override
  State<UploadVenuePhotoScreen> createState() => _UploadVenuePhotoScreenState();
}

class _UploadVenuePhotoScreenState extends State<UploadVenuePhotoScreen> {
  late final _repo = widget.repository ?? VenuePhotoSubmissionRepository(Supabase.instance.client);

  List<StagedVenuePhoto> _staged = [];
  List<String> _rejectedReasons = [];
  int _currentIndex = 0;
  String? _replacesPhotoId;
  bool _submitting = false;
  bool _submitted = false;
  int _submittedCount = 0;
  int _failedCount = 0;
  String? _submitError;

  // Distinct messages from failures the repository already translated
  // into a UI-safe StateError (e.g. "a replacement for this photo is
  // already awaiting review") — a permanent failure, retrying can't help.
  // Failures of every other shape stay uncounted here, so _confirmation()
  // can tell the two apart without this screen needing to know what
  // every possible repository error means.
  Set<String> _permanentFailureMessages = {};

  bool get _atCap => widget.publishedPhotos.length >= maxVenuePhotoCount;

  /// At cap, exactly one photo may be picked (it must name a replacement)
  /// — multi-select doesn't extend to "pick several, each replacing a
  /// different existing photo," which was never asked for and would need
  /// its own multi-replacement-picker UI. Otherwise, up to however many
  /// more the venue's maxVenuePhotoCount allows.
  int get _maxSelectable => _atCap ? 1 : maxVenuePhotoCount - widget.publishedPhotos.length;

  bool get _isPrivateChef => widget.venue.venueTypeWireValue == 'private_chef';

  Future<void> _choosePhotos() async {
    final pick = widget.pickPhotos ?? pickVenuePhotos;
    final picked = await pick(context, maxSelectable: _maxSelectable);
    if (picked.isEmpty) return; // cancelled, or nothing downloaded — not an error

    final valid = <StagedVenuePhoto>[];
    final reasons = <String>[];
    for (final photo in picked) {
      final validation = validateVenuePhoto(photo.bytes);
      if (validation is VenuePhotoValidationRejected) {
        reasons.add(validation.message);
      } else {
        valid.add(photo);
      }
    }
    setState(() {
      _staged = valid;
      _rejectedReasons = reasons;
      _currentIndex = 0;
      _replacesPhotoId = null;
      _submitError = null;
    });
  }

  void _goBack() {
    if (_currentIndex == 0) return;
    setState(() => _currentIndex--);
  }

  void _goNext() {
    if (_currentIndex >= _staged.length - 1) return;
    setState(() => _currentIndex++);
  }

  Future<void> _submit() async {
    if (_staged.isEmpty || _submitting) return;
    if (_atCap && _staged.length == 1 && _replacesPhotoId == null) {
      setState(() => _submitError = 'Choose which existing photo this one replaces.');
      return;
    }
    final userId = widget.currentUserId ?? Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) {
      setState(() => _submitError = 'Please sign in and try again.');
      return;
    }
    setState(() {
      _submitting = true;
      _submitError = null;
    });

    // Each photo submits independently — one failing must never roll back
    // the ones that already succeeded, same shape as
    // AttendancePhotosSection's own established multi-upload loop.
    var successes = 0;
    var failures = 0;
    final permanentMessages = <String>{};
    for (final photo in _staged) {
      try {
        await _repo.submit(
          userId: userId,
          venueType: widget.venue.venueTypeWireValue,
          venueId: widget.venue.id,
          rawBytes: photo.bytes,
          replacesPhotoId: _staged.length == 1 ? _replacesPhotoId : null,
        );
        successes++;
      } on StateError catch (e) {
        // The repository's own conflict translation — a permanent
        // failure, distinct from a generic/transient one below.
        failures++;
        permanentMessages.add(e.message);
      } catch (_) {
        failures++;
      }
    }
    if (!mounted) return;
    setState(() {
      _submitting = false;
      _submitted = true;
      _submittedCount = successes;
      _failedCount = failures;
      _permanentFailureMessages = permanentMessages;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.warmWhite,
      appBar: AppBar(
        title: Text(
          'Add photos',
          style: CsTypography.placeTitle.copyWith(color: AppColors.forestGreen, fontSize: 20),
        ),
        backgroundColor: AppColors.warmWhite,
        surfaceTintColor: Colors.transparent,
        iconTheme: const IconThemeData(color: AppColors.forestGreen),
        automaticallyImplyLeading: !_submitted,
      ),
      body: _submitted ? _confirmation() : _body(),
    );
  }

  Widget _confirmation() {
    final total = _submittedCount + _failedCount;
    final noun = total == 1 ? 'photo' : 'photos';
    final String title;
    final String subtitle;
    // A permanent failure (the repository's own conflict translation —
    // e.g. a replacement for this exact photo is already pending) reads
    // as permanent: its own message replaces "please try again", since
    // trying again can't succeed until that pending review is decided.
    // Any failure with no permanent message attached is left exactly as
    // before — still generic, still "try again", because it might be.
    final permanentMessage = _permanentFailureMessages.length == 1
        ? _permanentFailureMessages.first
        : null;
    if (_failedCount == 0) {
      title = total == 1 ? 'Submitted for review' : 'Submitted $total photos for review';
      subtitle = "We'll review $noun submitted and let you know here once we've made a decision.";
    } else if (_submittedCount == 0) {
      title = total == 1 ? 'Could not submit this photo' : 'Could not submit these photos';
      subtitle = permanentMessage ?? 'Please try again.';
    } else {
      title = 'Submitted $_submittedCount of $total photos';
      subtitle = permanentMessage ??
          '$_failedCount could not be submitted — please try again for those.';
    }
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(CsSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _submittedCount > 0 ? Icons.hourglass_top_outlined : Icons.error_outline_rounded,
              color: _submittedCount > 0 ? AppColors.forestGreen : AppColors.error,
              size: 40,
            ),
            const SizedBox(height: CsSpacing.md),
            Text(
              title,
              textAlign: TextAlign.center,
              style: CsTypography.placeTitle.copyWith(color: AppColors.forestGreen, fontSize: 20),
            ),
            const SizedBox(height: CsSpacing.sm),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: CsTypography.body.copyWith(color: AppColors.taupe),
            ),
            const SizedBox(height: CsSpacing.lg),
            SizedBox(
              width: double.infinity,
              child: CsPrimaryButton(
                label: 'Done',
                surface: CsSurface.light,
                onTap: () => Navigator.of(context).pop(_submittedCount > 0),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _body() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: CsSpacing.pageHorizontal, vertical: CsSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _guidanceCard(),
          const SizedBox(height: CsSpacing.lg),
          if (_staged.isEmpty) ...[
            if (_rejectedReasons.isNotEmpty) ...[
              _rejectedSummaryCard(),
              const SizedBox(height: CsSpacing.md),
            ],
            SizedBox(
              width: double.infinity,
              child: CsPrimaryButton(
                label: _maxSelectable > 1 ? 'Choose photos' : 'Choose a photo',
                surface: CsSurface.light,
                onTap: _choosePhotos,
              ),
            ),
          ] else
            _stepThrough(),
          const SizedBox(height: CsSpacing.xxl),
        ],
      ),
    );
  }

  Widget _stepThrough() {
    final total = _staged.length;
    final current = _staged[_currentIndex];
    final isLast = _currentIndex == total - 1;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_rejectedReasons.isNotEmpty) ...[
          _rejectedSummaryCard(),
          const SizedBox(height: CsSpacing.md),
        ],
        if (total > 1) ...[
          Text('PHOTO ${_currentIndex + 1} OF $total', style: CsTypography.eyebrow.copyWith(color: AppColors.taupe)),
          const SizedBox(height: CsSpacing.sm),
        ],
        VenuePhotoFramePreview(
          image: MemoryImage(current.bytes),
          venueTypeWireValue: widget.venue.venueTypeWireValue,
        ),
        const SizedBox(height: CsSpacing.md),
        TextButton(
          onPressed: _choosePhotos,
          style: TextButton.styleFrom(padding: EdgeInsets.zero, alignment: Alignment.centerLeft),
          child: Text(
            total > 1 ? 'Choose different photos' : 'Choose a different photo',
            style: CsTypography.body.copyWith(
              color: AppColors.forestGreen,
              fontWeight: FontWeight.w600,
              decoration: TextDecoration.underline,
            ),
          ),
        ),
        if (_atCap) ...[
          const SizedBox(height: CsSpacing.lg),
          _replacementPicker(),
        ],
        if (_submitError != null) ...[
          const SizedBox(height: CsSpacing.md),
          Text(_submitError!, style: CsTypography.metadata.copyWith(color: AppColors.error)),
        ],
        const SizedBox(height: CsSpacing.lg),
        Row(
          children: [
            if (_currentIndex > 0)
              TextButton(
                onPressed: _goBack,
                child: Text('Back', style: CsTypography.body.copyWith(color: AppColors.forestGreen)),
              ),
            const Spacer(),
          ],
        ),
        if (_currentIndex > 0) const SizedBox(height: CsSpacing.sm),
        SizedBox(
          width: double.infinity,
          child: CsPrimaryButton(
            label: isLast ? (total == 1 ? 'Submit for review' : 'Submit all $total photos') : 'Next photo',
            surface: CsSurface.light,
            loading: _submitting,
            onTap: isLast ? _submit : _goNext,
          ),
        ),
      ],
    );
  }

  Widget _guidanceCard() {
    final maxMb = (maxVenuePhotoSubmissionBytes / (1024 * 1024)).toStringAsFixed(0);
    return Container(
      padding: const EdgeInsets.all(CsSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('BEFORE YOU UPLOAD', style: CsTypography.eyebrow.copyWith(color: AppColors.taupe)),
          const SizedBox(height: CsSpacing.sm),
          Text(
            'Up to $maxVenuePhotoCount photos per venue. JPEG or PNG, up to $maxMb MB, '
            'at least $minVenuePhotoShortSidePx pixels on the shorter side, and shaped '
            'somewhere between a 3:4 portrait and a 16:9 landscape — not a banner, not a '
            'square post.\n\n'
            "We review every photo by hand before it appears on the venue's page. "
            "You'll see the outcome here — either way.",
            style: CsTypography.body.copyWith(color: AppColors.forestGreen, height: 1.5),
          ),
          // Stated up front, before the picker opens — not discovered only
          // after picking too many. Only shown when it says something the
          // sentence above doesn't already: at zero published photos,
          // "remaining" already equals the venue-wide max.
          if (widget.publishedPhotos.isNotEmpty && !_atCap) ...[
            const SizedBox(height: CsSpacing.sm),
            Text(
              'This venue already has ${widget.publishedPhotos.length} of $maxVenuePhotoCount — '
              'you can add up to $_maxSelectable more right now.',
              style: CsTypography.body.copyWith(
                color: AppColors.forestGreen,
                fontWeight: FontWeight.w600,
                height: 1.5,
              ),
            ),
          ],
          if (_isPrivateChef) ...[
            const SizedBox(height: CsSpacing.sm),
            Text(
              'Your first photo is a portrait of you — not a plate, the dining room, or '
              'the kitchen.',
              style: CsTypography.body.copyWith(
                color: AppColors.forestGreen,
                fontWeight: FontWeight.w600,
                height: 1.5,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _rejectedSummaryCard() {
    final count = _rejectedReasons.length;
    return Container(
      padding: const EdgeInsets.all(CsSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.error),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 18),
              const SizedBox(width: CsSpacing.sm),
              Expanded(
                child: Text(
                  count == 1 ? "1 photo couldn't be used" : "$count photos couldn't be used",
                  style: CsTypography.body.copyWith(color: AppColors.forestGreen, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: CsSpacing.xs),
          for (final reason in _rejectedReasons)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text('•  $reason', style: CsTypography.metadata.copyWith(color: AppColors.forestGreen)),
            ),
        ],
      ),
    );
  }

  Widget _replacementPicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'This venue already has $maxVenuePhotoCount photos — choose which one this replaces',
          style: CsTypography.eyebrow.copyWith(color: AppColors.taupe),
        ),
        const SizedBox(height: CsSpacing.sm),
        for (final photo in widget.publishedPhotos)
          _ReplacementRow(
            photo: photo,
            selected: _replacesPhotoId == photo.id,
            onTap: () => setState(() => _replacesPhotoId = photo.id),
          ),
      ],
    );
  }
}

/// A tappable, selectable photo row — not RadioListTile (deprecated in
/// this Flutter version in favor of RadioGroup, and this app has no
/// existing Radio usage to match either way), matching this feature's
/// own established "custom selectable chip/row, not a Material form
/// control" convention (_RoleChip in claim_venue_details_screen.dart).
class _ReplacementRow extends StatelessWidget {
  final PublishedVenuePhoto photo;
  final bool selected;
  final VoidCallback onTap;

  const _ReplacementRow({required this.photo, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.transparent,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: CsSpacing.xs),
        child: Row(
          children: [
            Icon(
              selected ? Icons.radio_button_checked_rounded : Icons.radio_button_unchecked_rounded,
              size: 20,
              color: selected ? AppColors.forestGreen : AppColors.taupe,
            ),
            const SizedBox(width: CsSpacing.sm),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Image.network(
                photo.imageUrl,
                width: 44,
                height: 44,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const SizedBox(width: 44, height: 44),
              ),
            ),
            const SizedBox(width: CsSpacing.sm),
            Text(
              photo.displayOrder == 0 ? 'Currently first' : 'Photo ${photo.displayOrder + 1}',
              style: CsTypography.body.copyWith(color: AppColors.forestGreen),
            ),
          ],
        ),
      ),
    ),
  );
}
