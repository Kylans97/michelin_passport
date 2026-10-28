import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/constants/app_colors.dart';
import '../../core/theme/cs_spacing.dart';
import '../../core/theme/cs_typography.dart';
import '../../core/utils/mailto_uri.dart';
import '../../core/widgets/framed_image.dart';
import '../../core/widgets/subtle_text_action.dart';
import '../../data/repositories/venue_events_repository.dart';
import '../../data/repositories/hotel_repository.dart';
import '../../data/repositories/private_chef_repository.dart';
import '../../data/repositories/restaurant_repository.dart';
import '../../data/repositories/venue_about_repository.dart';
import '../../data/repositories/venue_photo_submission_repository.dart';
import '../../models/managed_venue.dart';
import '../../models/private_chef_photo.dart';
import '../../models/published_venue_photo.dart';
import '../../models/venue_about_submission.dart';
import '../../models/venue_event.dart';
import '../../models/venue_photo_submission_status.dart';
import '../hotels/hotel_detail_screen.dart';
import '../private_chefs/private_chef_detail_screen.dart';
import '../restaurants/restaurant_detail_screen.dart';
import 'card_photo_screen.dart';
import 'venue_events_screen.dart';
import 'venue_photos_screen.dart';
import 'venue_preview_photo_merge.dart';
import 'venue_profile_screen.dart';

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

/// A venue's landing page, reached from My Venues: the venue's name and
/// card photo, then Profile (VenueProfileScreen, the about text), Photos
/// (VenuePhotosScreen, order, framing and the card photo) and Events
/// (VenueEventsScreen), each with a one-line summary, then Preview my
/// page and the contact line. Venue events plan phase 2: the same
/// content as the former one-screen version, split up and nothing
/// removed. Private chefs get the same page.
///
/// What this screen does NOT show, and why: address, coordinates, Place
/// ID, phone, website, MICHELIN stars/Keys, cuisine, and opening status
/// are all verified catalogue data a manager must never be able to
/// overwrite, so none of it is shown here at all.
///
/// A manager can email a question — the same shared inbox
/// notifications_screen.dart's own claim-question contact line already
/// uses (see _kVenueQuestionsEmail's own doc comment), reached from a
/// single restrained line at the foot of this screen.
class VenueManagementScreen extends StatefulWidget {
  final ManagedVenue venue;

  // Optional DI seams, matching every other screen in this feature.
  final VenueAboutRepository? aboutRepo;
  final VenuePhotoSubmissionRepository? photoRepo;
  final VenueEventsRepository? eventsRepo;

  // Owner preview only — the fresh venue re-fetch _openPreview does
  // alongside its existing photo/about-text fetches. Same DI-seam
  // convention as the ones above.
  final RestaurantRepository? restaurantRepo;
  final HotelRepository? hotelRepo;
  final PrivateChefRepository? privateChefRepo;

  const VenueManagementScreen({
    super.key,
    required this.venue,
    this.aboutRepo,
    this.photoRepo,
    this.eventsRepo,
    this.restaurantRepo,
    this.hotelRepo,
    this.privateChefRepo,
  });

  @override
  State<VenueManagementScreen> createState() => _VenueManagementScreenState();
}

class _AboutSummary {
  final String? currentText;
  final VenueAboutSubmission? latestSubmission;
  const _AboutSummary({required this.currentText, required this.latestSubmission});
}

class _PhotosSummary {
  final List<PublishedVenuePhoto> published;
  final List<VenuePhotoSubmissionSummary> openSubmissions;
  const _PhotosSummary({required this.published, required this.openSubmissions});
}

class _VenueManagementScreenState extends State<VenueManagementScreen> {
  late final _aboutRepo = widget.aboutRepo ?? VenueAboutRepository(Supabase.instance.client);
  late final _photoRepo =
      widget.photoRepo ?? VenuePhotoSubmissionRepository(Supabase.instance.client);
  late final _eventsRepo =
      widget.eventsRepo ?? VenueEventsRepository(Supabase.instance.client);
  late final _restaurantRepo =
      widget.restaurantRepo ?? RestaurantRepository(Supabase.instance.client);
  late final _hotelRepo = widget.hotelRepo ?? HotelRepository(Supabase.instance.client);
  late final _privateChefRepo =
      widget.privateChefRepo ?? PrivateChefRepository(Supabase.instance.client);

  // Three separate summaries, so one failing lookup only blanks its own
  // row's summary line — every row stays tappable either way.
  late Future<_AboutSummary> _aboutFuture;
  late Future<_PhotosSummary> _photosFuture;
  late Future<List<VenueEvent>> _eventsFuture;

  bool _previewLoading = false;
  String? _previewError;

  @override
  void initState() {
    super.initState();
    _loadSummaries();
  }

  void _loadSummaries() {
    final type = widget.venue.venueTypeWireValue;
    final id = widget.venue.id;
    setState(() {
      _aboutFuture = Future.wait([
        _aboutRepo.loadCurrentText(venueType: type, venueId: id),
        _aboutRepo.loadMyLatestSubmission(venueType: type, venueId: id),
      ]).then(
        (r) => _AboutSummary(
          currentText: r[0] as String?,
          latestSubmission: r[1] as VenueAboutSubmission?,
        ),
      );
      _photosFuture = Future.wait([
        _photoRepo.loadPublishedPhotos(venueType: type, venueId: id),
        _photoRepo.loadMyOpenSubmissions(venueType: type, venueId: id),
      ]).then(
        (r) => _PhotosSummary(
          published: r[0] as List<PublishedVenuePhoto>,
          openSubmissions: r[1] as List<VenuePhotoSubmissionSummary>,
        ),
      );
      _eventsFuture = _eventsRepo.loadVenueEvents(widget.venue);
    });
  }

  // Every sub-screen can change what its row summarises, so coming back
  // from any of them reloads all three.
  Future<void> _open(Widget screen) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
    if (mounted) _loadSummaries();
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
                    framing: mergedPhotos[i].framing,
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
                    framing: mergedPhotos[i].framing,
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
                    framing: mergedPhotos[i].framing,
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

  @override
  Widget build(BuildContext context) {
    final isPrivateChef = widget.venue.venueTypeWireValue == 'private_chef';
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
      body: RefreshIndicator(
        color: AppColors.forestGreen,
        backgroundColor: AppColors.warmWhite,
        onRefresh: () async => _loadSummaries(),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(
            horizontal: CsSpacing.pageHorizontal,
            vertical: CsSpacing.md,
          ),
          children: [
            _header(isPrivateChef),
            const SizedBox(height: CsSpacing.lg),
            Container(height: 1, color: AppColors.cardBorder),
            FutureBuilder<_AboutSummary>(
              future: _aboutFuture,
              builder: (context, snap) => _SectionRow(
                title: 'Profile',
                summary: snap.hasData ? _aboutLine(snap.data!) : null,
                onTap: () => _open(
                  VenueProfileScreen(venue: widget.venue, aboutRepo: widget.aboutRepo),
                ),
              ),
            ),
            FutureBuilder<_PhotosSummary>(
              future: _photosFuture,
              builder: (context, snap) => _SectionRow(
                title: 'Photos',
                summary: snap.hasData ? _photosLine(snap.data!) : null,
                onTap: () => _open(
                  VenuePhotosScreen(venue: widget.venue, photoRepo: widget.photoRepo),
                ),
              ),
            ),
            FutureBuilder<List<VenueEvent>>(
              future: _eventsFuture,
              builder: (context, snap) => _SectionRow(
                title: 'Events',
                summary: snap.hasData
                    ? VenueEventsScreen.summary(snap.data!, DateTime.now())
                    : null,
                onTap: () => _open(
                  VenueEventsScreen(venue: widget.venue, repository: widget.eventsRepo),
                ),
              ),
            ),
            const SizedBox(height: CsSpacing.lg),
            // Renders the real venue page — never a replica of it — with
            // whatever is currently pending: see _openPreview's own doc
            // comment.
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
            const SizedBox(height: CsSpacing.xl),
            _contactLine(),
            const SizedBox(height: CsSpacing.xxl),
          ],
        ),
      ),
    );
  }

  // The venue's card photo — what every card in the app shows — beside
  // its name, so the landing page reads as this venue at a glance. Empty
  // until the photos load, and simply absent when there are none.
  Widget _header(bool isPrivateChef) => Row(
    children: [
      FutureBuilder<_PhotosSummary>(
        future: _photosFuture,
        builder: (context, snap) {
          final card = snap.hasData
              ? CardPhotoScreen.currentCardPhoto(snap.data!.published)
              : null;
          if (card == null) return const SizedBox.shrink();
          return Padding(
            padding: const EdgeInsets.only(right: CsSpacing.md),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                width: 72,
                height: isPrivateChef ? 90 : 72,
                child: FramedImage(
                  framing: isPrivateChef ? card.cardFraming.forChefCard : card.cardFraming,
                  builder: (alignment) => Image.network(
                    card.imageUrl,
                    fit: BoxFit.cover,
                    alignment: alignment,
                    errorBuilder: (_, _, _) => const SizedBox.shrink(),
                  ),
                ),
              ),
            ),
          );
        },
      ),
      Expanded(
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
          ],
        ),
      ),
    ],
  );

  static String _aboutLine(_AboutSummary s) => switch (s.latestSubmission?.status) {
    VenueAboutSubmissionStatus.pending => 'Awaiting review',
    VenueAboutSubmissionStatus.rejected => 'Not approved',
    _ => (s.currentText ?? '').trim().isEmpty ? 'Nothing published yet' : 'Published',
  };

  static String _photosLine(_PhotosSummary s) {
    final n = s.published.length;
    final waiting = s.openSubmissions
        .where((x) => x.status == VenuePhotoSubmissionStatus.pending)
        .length;
    return [
      n == 0 ? 'No photos published yet' : n == 1 ? '1 photo' : '$n photos',
      if (waiting > 0) '$waiting awaiting review',
    ].join(' · ');
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
}

/// One row of the landing page: the section's name, its one-line
/// summary (blank while loading or if the lookup failed — the row stays
/// tappable either way), and a chevron.
class _SectionRow extends StatelessWidget {
  final String title;
  final String? summary;
  final VoidCallback onTap;

  const _SectionRow({required this.title, required this.summary, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: CsSpacing.md),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: CsTypography.placeTitle.copyWith(
                          color: AppColors.forestGreen,
                          fontSize: 19,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        summary ?? '',
                        style: CsTypography.metadata.copyWith(color: AppColors.taupe),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded, color: AppColors.taupe),
              ],
            ),
          ),
        ),
        Container(height: 1, color: AppColors.cardBorder),
      ],
    );
  }
}
