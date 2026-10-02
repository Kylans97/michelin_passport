import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/constants/app_colors.dart';
import '../../core/theme/cs_spacing.dart';
import '../../core/theme/cs_surface_context.dart';
import '../../core/theme/cs_typography.dart';
import '../../core/utils/mailto_uri.dart';
import '../../core/widgets/cs_primary_button.dart';
import '../../core/widgets/subtle_text_action.dart';
import '../../data/repositories/hotel_repository.dart';
import '../../data/repositories/private_chef_repository.dart';
import '../../data/repositories/restaurant_repository.dart';
import '../../data/repositories/venue_about_repository.dart';
import '../../data/repositories/venue_photo_submission_repository.dart';
import '../../models/managed_venue.dart';
import '../../models/private_chef_photo.dart';
import '../../models/published_venue_photo.dart';
import '../../models/venue_about_submission.dart';
import '../../models/venue_photo_submission_status.dart';
import '../hotels/hotel_detail_screen.dart';
import '../private_chefs/private_chef_detail_screen.dart';
import '../restaurants/restaurant_detail_screen.dart';
import 'upload_venue_photo_screen.dart';
import 'venue_preview_photo_merge.dart';

/// The one venue-ops inbox this app has — same address
/// notifications_screen.dart's own _kClaimQuestionsEmail already sends
/// claim questions to. A manager's question about their venue's page
/// (about text, photos, anything else here) goes to the same place a
/// claim question does; there is no separate inbox for this screen.
const _kVenueQuestionsEmail = 'claimedvenues@mantelier.app';

/// Top-level and `@visibleForTesting`, same reasoning as
/// notifications_screen.dart's own claimQuestionMailtoUri: this screen
/// constructs its repositories against a real SupabaseClient, so the one
/// part worth asserting on directly — the venue name reaching the mailto
/// subject — is tested as pure Uri-building logic instead of through the
/// widget. Encoding itself is mailtoUri's (core/utils/mailto_uri.dart) —
/// this must never hand-build its own `Uri(...)`, per that function's own
/// doc comment.
@visibleForTesting
Uri venueQuestionMailtoUri(String venueName) =>
    mailtoUri(_kVenueQuestionsEmail, subject: 'Venue question — $venueName');

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
///
/// A manager can email a question — the same shared inbox
/// notifications_screen.dart's own claim-question contact line already
/// uses (see _kVenueQuestionsEmail's own doc comment), reached from a
/// single restrained line at the foot of this screen. There is no other
/// contact point anywhere on this screen today.
class VenueManagementScreen extends StatefulWidget {
  final ManagedVenue venue;

  // Optional DI seams, matching every other screen in this feature.
  final VenueAboutRepository? aboutRepo;
  final VenuePhotoSubmissionRepository? photoRepo;

  // Owner preview only — the fresh venue re-fetch _openPreview does
  // alongside its existing photo/about-text fetches. Same DI-seam
  // convention as the two above, not three separate ones this screen
  // otherwise has no use for.
  final RestaurantRepository? restaurantRepo;
  final HotelRepository? hotelRepo;
  final PrivateChefRepository? privateChefRepo;

  const VenueManagementScreen({
    super.key,
    required this.venue,
    this.aboutRepo,
    this.photoRepo,
    this.restaurantRepo,
    this.hotelRepo,
    this.privateChefRepo,
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
  late final _restaurantRepo =
      widget.restaurantRepo ?? RestaurantRepository(Supabase.instance.client);
  late final _hotelRepo = widget.hotelRepo ?? HotelRepository(Supabase.instance.client);
  late final _privateChefRepo =
      widget.privateChefRepo ?? PrivateChefRepository(Supabase.instance.client);

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

  bool _previewLoading = false;
  String? _previewError;

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

  // Re-fetches the venue itself fresh, for _openPreview below. widget.venue
  // is whatever My Venues last loaded — could be minutes old by the time
  // a manager taps Preview, and every field it carries (name, address,
  // stars/Keys, status, cover-image fallback) would otherwise be shown as
  // current when it might not be. Returns null on ANY failure — a thrown
  // error or a legitimately-absent row alike — so the caller has one
  // simple fallback path rather than needing to tell the two apart.
  //
  // getPrivateChefById filters to publication_status = 'published' (the
  // Restaurant/Hotel getById methods have no such filter) — a manager's
  // own chef profile sitting in 'draft' at the moment they open Preview
  // would come back null here too, read the same as any other refetch
  // failure: falls back to the cached model, marked stale. That's an
  // honest label for "not fresh," even though the underlying reason here
  // is narrower ("not published"), not a network failure.
  Future<ManagedVenue?> _refetchVenue(ManagedVenue venue) async {
    try {
      return switch (venue) {
        ManagedRestaurant() => await _restaurantRepo
            .getById(venue.id)
            .then((r) => r == null ? null : ManagedRestaurant(r)),
        ManagedHotel() => await _hotelRepo
            .getById(venue.id)
            .then((h) => h == null ? null : ManagedHotel(h)),
        ManagedPrivateChef() => await _privateChefRepo
            .getPrivateChefById(venue.id)
            .then((c) => c == null ? null : ManagedPrivateChef(c)),
      };
    } catch (_) {
      return null;
    }
  }

  // Reached from the header, not the photos/about sections specifically —
  // it renders the manager's PROPOSED future state (pending about text if
  // any, published + pending photos merged via mergePreviewPhotoOrder),
  // never a mode of the live page. Deliberately fetches its own fresh
  // copy of everything rather than reusing _future/_photosFuture: those
  // are this screen's own cached state, which can be minutes old by the
  // time a manager taps Preview, and resolveDisplayUrls' signed URLs
  // expire in an hour — re-entering the preview later must resolve fresh
  // ones, not reuse whatever was signed at this screen's own last load.
  // The venue itself is included in that same "fetch fresh" contract via
  // _refetchVenue above — a failure there doesn't abort the preview the
  // way a photos/about-text failure below does; it falls back to the
  // cached model and says so on the preview screen itself
  // (OwnerPreviewMarker's subtitle), since falling back is acceptable but
  // showing stale data as if it were fresh is not.
  Future<void> _openPreview() async {
    if (_previewLoading) return;
    setState(() {
      _previewLoading = true;
      _previewError = null;
    });
    try {
      final cachedVenue = widget.venue;
      final freshVenueFuture = _refetchVenue(cachedVenue);
      final publishedFuture = _photoRepo.loadPublishedPhotos(
        venueType: cachedVenue.venueTypeWireValue,
        venueId: cachedVenue.id,
      );
      final openSubmissionsFuture = _photoRepo.loadMyOpenSubmissions(
        venueType: cachedVenue.venueTypeWireValue,
        venueId: cachedVenue.id,
      );
      final pendingAboutFuture = _aboutRepo.loadMyLatestSubmission(
        venueType: cachedVenue.venueTypeWireValue,
        venueId: cachedVenue.id,
      );
      final freshVenue = await freshVenueFuture;
      final published = await publishedFuture;
      final openSubmissions = await openSubmissionsFuture;
      final pendingAbout = await pendingAboutFuture;
      final signedUrls = await _photoRepo.resolveDisplayUrls([
        for (final s in openSubmissions) s.storagePath,
      ]);

      final isStale = freshVenue == null;
      final venue = freshVenue ?? cachedVenue;

      final mergedPhotos = mergePreviewPhotoOrder(
        published: published,
        pendingSubmissions: openSubmissions,
        pendingSignedUrls: signedUrls,
      );
      // Only a still-PENDING about submission represents a proposed
      // future — a rejected one will not happen, same reasoning as the
      // photo merge excluding rejected photos. null here means "no
      // override": the Detail screen falls back to loading the live
      // approved text itself, same as the live page.
      final aboutOverride =
          pendingAbout?.status == VenueAboutSubmissionStatus.pending
          ? pendingAbout!.aboutText
          : null;

      if (!mounted) return;
      setState(() => _previewLoading = false);

      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => switch (venue) {
            ManagedRestaurant(:final restaurant) => RestaurantDetailScreen(
              restaurant: restaurant,
              aboutTextOverride: aboutOverride,
              photosOverride: [
                for (var i = 0; i < mergedPhotos.length; i++)
                  PublishedVenuePhoto(
                    id: mergedPhotos[i].id,
                    imageUrl: mergedPhotos[i].imageUrl,
                    displayOrder: i,
                  ),
              ],
              isPreview: true,
              previewIsStale: isStale,
            ),
            ManagedHotel(:final hotel) => HotelDetailScreen(
              hotel: hotel,
              aboutTextOverride: aboutOverride,
              photosOverride: [
                for (var i = 0; i < mergedPhotos.length; i++)
                  PublishedVenuePhoto(
                    id: mergedPhotos[i].id,
                    imageUrl: mergedPhotos[i].imageUrl,
                    displayOrder: i,
                  ),
              ],
              isPreview: true,
              previewIsStale: isStale,
            ),
            ManagedPrivateChef(:final chef) => PrivateChefDetailScreen(
              chefId: chef.id,
              chefOverride: chef,
              aboutTextOverride: aboutOverride,
              photosOverride: [
                for (var i = 0; i < mergedPhotos.length; i++)
                  PrivateChefPhoto(
                    id: mergedPhotos[i].id,
                    privateChefId: chef.id,
                    imageUrl: mergedPhotos[i].imageUrl,
                    displayOrder: i,
                  ),
              ],
              isPreview: true,
              previewIsStale: isStale,
            ),
          },
        ),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _previewLoading = false;
        _previewError = 'Could not prepare the preview. Please try again.';
      });
    }
  }

  Future<void> _emailUs() async {
    final uri = venueQuestionMailtoUri(widget.venue.name);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
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
          const SizedBox(height: CsSpacing.sm),
          // Reached here, above CURRENT TEXT/PHOTOS, since it's the one
          // place with context for both sections at once. Renders the
          // real venue page — never a replica of it — with whatever is
          // currently pending: see _openPreview's own doc comment.
          SubtleTextAction(
            label: _previewLoading ? 'Preparing preview…' : 'Preview my page',
            onTap: _openPreview,
          ),
          if (_previewError != null) ...[
            const SizedBox(height: 2),
            Text(
              _previewError!,
              style: CsTypography.metadata.copyWith(color: AppColors.error),
            ),
          ],
          const SizedBox(height: CsSpacing.md),

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
          const SizedBox(height: CsSpacing.xl),
          _contactLine(),
          const SizedBox(height: CsSpacing.xxl),
        ],
      ),
    );
  }

  // One restrained line, not a card or a section of its own — the same
  // register as everything else on this screen. Sends to the one
  // venue-ops inbox a claimed venue's manager already knows is read (the
  // same address the claim-approval notification's own contact line
  // uses), since there is no other contact point anywhere on this screen.
  Widget _contactLine() => GestureDetector(
    onTap: _emailUs,
    child: Text.rich(
      TextSpan(
        text: 'Questions about your page? ',
        style: CsTypography.metadata.copyWith(color: AppColors.taupe),
        children: [
          TextSpan(
            text: _kVenueQuestionsEmail,
            style: CsTypography.metadata.copyWith(
              color: AppColors.forestGreen,
              decoration: TextDecoration.underline,
            ),
          ),
        ],
      ),
    ),
  );

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
