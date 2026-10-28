import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants/app_colors.dart';
import '../../core/theme/cs_spacing.dart';
import '../../core/theme/cs_surface_context.dart';
import '../../core/theme/cs_typography.dart';
import '../../core/widgets/cs_primary_button.dart';
import '../../core/widgets/framed_image.dart';
import '../../data/repositories/venue_photo_submission_repository.dart';
import '../../models/managed_venue.dart';
import '../../models/published_venue_photo.dart';
import '../../models/venue_photo_submission_status.dart';
import 'adjust_photo_framing_screen.dart';
import 'card_photo_screen.dart';
import 'upload_venue_photo_screen.dart';

/// Photos, reached from a venue's landing page (VenueManagementScreen).
/// Split out of the former one-screen VenueManagementScreen unchanged
/// (venue events plan phase 2).
///
/// PHOTOS build on the existing venue_photo_submissions review queue and
/// storage bucket (both RLS-gated onto venue_managers_*) and the
/// VenuePhotoSubmissionRepository/venue_photo_pipeline.dart pipeline
/// (validate -> strip EXIF -> hash -> upload -> insert). Ordering reads
/// restaurant_photos/hotel_photos/private_chef_photos' own display_order
/// directly and writes ONLY through reorder_venue_photos() — never a
/// direct display_order UPDATE from this client. Framing (focus point +
/// zoom, 20261014120000) is set at upload in UploadVenuePhotoScreen and
/// can be changed on a published photo through AdjustPhotoFramingScreen
/// — live at once, via set_venue_photo_framing, never a direct UPDATE.
/// The first photo is the cover (it leads the page); the arrows reorder.
/// The small cards show the Card photo instead (20261015120000) — the
/// cover unless the manager chose another approved photo, with its own
/// crop — set in CardPhotoScreen from the section below the photo list.
class VenuePhotosScreen extends StatefulWidget {
  final ManagedVenue venue;
  final VenuePhotoSubmissionRepository? photoRepo;

  const VenuePhotosScreen({super.key, required this.venue, this.photoRepo});

  @override
  State<VenuePhotosScreen> createState() => _VenuePhotosScreenState();
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

class _VenuePhotosScreenState extends State<VenuePhotosScreen> {
  late final _photoRepo =
      widget.photoRepo ??
      VenuePhotoSubmissionRepository(Supabase.instance.client);

  late Future<_PhotosState> _photosFuture;
  bool _reordering = false;
  String? _photosError;

  @override
  void initState() {
    super.initState();
    _loadPhotos();
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
        return _PhotosState(
          published: published,
          openSubmissions: open,
          submissionPhotoUrls: urls,
        );
      }();
    });
  }

  Future<void> _movePhoto(
    List<PublishedVenuePhoto> current,
    int index,
    int delta,
  ) async {
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

  Future<void> _chooseCardPhoto(List<PublishedVenuePhoto> published) async {
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => CardPhotoScreen(
          venue: widget.venue,
          photos: published,
          repository: widget.photoRepo,
        ),
      ),
    );
    if (saved == true && mounted) _loadPhotos();
  }

  Future<void> _adjustFraming(PublishedVenuePhoto photo) async {
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => AdjustPhotoFramingScreen(
          venue: widget.venue,
          photo: photo,
          repository: widget.photoRepo,
        ),
      ),
    );
    if (saved == true && mounted) _loadPhotos();
  }

  Future<void> _addPhoto(List<PublishedVenuePhoto> published) async {
    final added = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => UploadVenuePhotoScreen(
          venue: widget.venue,
          publishedPhotos: published,
        ),
      ),
    );
    if (added == true) _loadPhotos();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.warmWhite,
      appBar: AppBar(
        title: Text(
          'Photos',
          style: CsTypography.placeTitle.copyWith(
            color: AppColors.forestGreen,
            fontSize: 20,
          ),
        ),
        backgroundColor: AppColors.warmWhite,
        surfaceTintColor: Colors.transparent,
        iconTheme: const IconThemeData(color: AppColors.forestGreen),
      ),
      body: RefreshIndicator(
        color: AppColors.forestGreen,
        backgroundColor: AppColors.warmWhite,
        onRefresh: () async => _loadPhotos(),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(
            horizontal: CsSpacing.pageHorizontal,
            vertical: CsSpacing.md,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _photosSection(),
              const SizedBox(height: CsSpacing.xxl),
            ],
          ),
        ),
      ),
    );
  }

  Widget _photosSection() {
    return FutureBuilder<_PhotosState>(
      future: _photosFuture,
      builder: (context, snap) {
        // Spinner only on the FIRST load. A reload (after a reorder, Make
        // cover, a framing save or a new photo) keeps showing the previous
        // list — FutureBuilder carries the last data into the new future's
        // waiting state — so the page doesn't collapse to a spinner and
        // throw the manager back to the top mid-reorder.
        if (snap.connectionState == ConnectionState.waiting && !snap.hasData) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: CsSpacing.lg),
              child: CircularProgressIndicator(
                color: AppColors.forestGreen,
                strokeWidth: 1.5,
              ),
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
            Text(
              'PHOTOS',
              style: CsTypography.eyebrow.copyWith(color: AppColors.taupe),
            ),
            const SizedBox(height: CsSpacing.sm),
            Text(
              state.published.isEmpty
                  ? 'No photos published yet.'
                  : 'Your cover is the first photo: it leads your page.',
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
                  isPrivateChef: isPrivateChef,
                  onMoveUp: () => _movePhoto(state.published, i, -1),
                  onMoveDown: () => _movePhoto(state.published, i, 1),
                  onAdjustFraming: () => _adjustFraming(state.published[i]),
                ),
            ],
            if (_photosError != null) ...[
              const SizedBox(height: CsSpacing.sm),
              Text(
                _photosError!,
                style: CsTypography.metadata.copyWith(color: AppColors.error),
              ),
            ],
            if (state.published.isNotEmpty) ...[
              const SizedBox(height: CsSpacing.lg),
              _CardPhotoSection(
                published: state.published,
                isPrivateChef: isPrivateChef,
                busy: _reordering,
                onChange: () => _chooseCardPhoto(state.published),
              ),
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

/// One PUBLISHED photo — thumbnail, "Appears first" tag on index 0 (so
/// "which photo comes first" is never ambiguous), and up/down controls
/// that call VenuePhotosScreen's own _movePhoto, which goes through
/// reorder_venue_photos — this row never writes display_order itself.
/// One published photo: its thumbnail (with the manager's header framing
/// applied), "Cover" on the first, Adjust framing (live straight away,
/// see AdjustPhotoFramingScreen), and the move arrows.
class _PublishedPhotoRow extends StatelessWidget {
  final PublishedVenuePhoto photo;
  final bool isFirst;
  final bool canMoveUp;
  final bool canMoveDown;
  final bool busy;
  final bool isPrivateChef;
  final VoidCallback onMoveUp;
  final VoidCallback onMoveDown;
  final VoidCallback onAdjustFraming;

  const _PublishedPhotoRow({
    required this.photo,
    required this.isFirst,
    required this.canMoveUp,
    required this.canMoveDown,
    required this.busy,
    required this.isPrivateChef,
    required this.onMoveUp,
    required this.onMoveDown,
    required this.onAdjustFraming,
  });

  static final _actionStyle = TextButton.styleFrom(
    padding: EdgeInsets.zero,
    minimumSize: const Size(0, 32),
    alignment: Alignment.centerLeft,
  );

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: CsSpacing.xs),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              width: 56,
              height: 56,
              child: FramedImage(
                framing: isPrivateChef ? photo.framing.forChef : photo.framing,
                builder: (alignment) => Image.network(
                  photo.imageUrl,
                  fit: BoxFit.cover,
                  alignment: alignment,
                  errorBuilder: (_, _, _) => const SizedBox.shrink(),
                ),
              ),
            ),
          ),
          const SizedBox(width: CsSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (isFirst)
                  Text(
                    'Cover',
                    style: CsTypography.body.copyWith(
                      color: AppColors.forestGreen,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                TextButton(
                  onPressed: busy ? null : onAdjustFraming,
                  style: _actionStyle,
                  child: Text(
                    'Adjust framing',
                    style: CsTypography.metadata.copyWith(
                      color: AppColors.taupe,
                    ),
                  ),
                ),
              ],
            ),
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

/// The Card photo: what the small cards (Explore, search, Passport…)
/// show — the flagged card photo, else the cover — at card size with its
/// card crop, and "Change" into CardPhotoScreen.
class _CardPhotoSection extends StatelessWidget {
  final List<PublishedVenuePhoto> published;
  final bool isPrivateChef;
  final bool busy;
  final VoidCallback onChange;

  const _CardPhotoSection({
    required this.published,
    required this.isPrivateChef,
    required this.busy,
    required this.onChange,
  });

  @override
  Widget build(BuildContext context) {
    final card = CardPhotoScreen.currentCardPhoto(published)!;
    final chosen = published.any((p) => p.isCard);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'CARD PHOTO',
          style: CsTypography.eyebrow.copyWith(color: AppColors.taupe),
        ),
        const SizedBox(height: CsSpacing.sm),
        Text(
          'The small photo on cards in Explore, search and Passport.',
          style: CsTypography.body.copyWith(color: AppColors.taupe),
        ),
        const SizedBox(height: CsSpacing.sm),
        Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                width: 56,
                height: isPrivateChef ? 70 : 56,
                child: FramedImage(
                  framing: isPrivateChef
                      ? card.cardFraming.forChefCard
                      : card.cardFraming,
                  builder: (alignment) => Image.network(
                    card.imageUrl,
                    fit: BoxFit.cover,
                    alignment: alignment,
                    errorBuilder: (_, _, _) => const SizedBox.shrink(),
                  ),
                ),
              ),
            ),
            const SizedBox(width: CsSpacing.sm),
            Expanded(
              child: Text(
                chosen ? 'Your chosen photo' : 'Same as your cover',
                style: CsTypography.body.copyWith(color: AppColors.forestGreen),
              ),
            ),
            TextButton(
              onPressed: busy ? null : onChange,
              child: Text(
                'Change',
                style: CsTypography.metadata.copyWith(
                  color: AppColors.forestGreen,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ],
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
                    errorBuilder: (_, _, _) =>
                        const SizedBox(width: 56, height: 56),
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
                      isPending
                          ? Icons.hourglass_top_outlined
                          : Icons.storefront_outlined,
                      size: 16,
                      color: AppColors.forestGreen,
                    ),
                    const SizedBox(width: CsSpacing.xs),
                    Text(
                      isPending ? 'Awaiting review' : 'Not approved',
                      style: CsTypography.body.copyWith(
                        color: AppColors.forestGreen,
                      ),
                    ),
                  ],
                ),
                if (!isPending &&
                    (submission.reviewNote ?? '').trim().isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    submission.reviewNote!,
                    style: CsTypography.metadata.copyWith(
                      color: AppColors.taupe,
                    ),
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
