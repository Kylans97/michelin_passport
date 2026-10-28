import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants/app_colors.dart';
import '../../core/theme/cs_spacing.dart';
import '../../core/theme/cs_surface_context.dart';
import '../../core/theme/cs_typography.dart';
import '../../core/widgets/cs_primary_button.dart';
import '../../core/widgets/framed_image.dart';
import '../../data/repositories/hotel_repository.dart';
import '../../data/repositories/private_chef_repository.dart';
import '../../data/repositories/restaurant_repository.dart';
import '../../data/repositories/review_repository.dart';
import '../../models/photo_framing.dart';
import '../../models/private_chef_photo.dart';
import '../../models/published_venue_photo.dart';
import '../../models/review_item.dart';
import '../hotels/hotel_detail_screen.dart';
import '../private_chefs/private_chef_detail_screen.dart';
import '../restaurants/restaurant_detail_screen.dart';

/// One item from the review queue, with what an admin needs to decide:
/// the claim's details, the about text, or the photo in its real header
/// and card frames — and, for text and photos, "Preview the venue page",
/// which opens the REAL detail screen with the submission in place (the
/// same override params the owner preview uses), so what is approved is
/// what visitors will see.
///
/// Approve, or Reject with a note the venue receives. Pops `true` once a
/// decision has actually been saved.
class ReviewItemScreen extends StatefulWidget {
  final ReviewItem item;
  final ReviewRepository repository;

  /// Test seam: the image for a pending photo. Defaults to a signed URL.
  final ImageProvider? photoImage;

  const ReviewItemScreen({
    super.key,
    required this.item,
    required this.repository,
    this.photoImage,
  });

  @override
  State<ReviewItemScreen> createState() => _ReviewItemScreenState();
}

class _ReviewItemScreenState extends State<ReviewItemScreen> {
  ReviewItem get _item => widget.item;
  bool _busy = false;
  String? _error;
  Future<String>? _signedUrl;

  bool get _isChef => _item.venueType == 'private_chef';

  @override
  void initState() {
    super.initState();
    if (_item.kind == ReviewKind.venuePhoto &&
        widget.photoImage == null &&
        _item.photoStoragePath != null) {
      _signedUrl = widget.repository.signedPhotoUrl(_item.photoStoragePath!);
    }
  }

  Future<void> _decide(Future<void> Function() action) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = 'Could not save the decision. Please try again.';
      });
    }
  }

  Future<void> _approve() => _decide(
    () => switch (_item.kind) {
      ReviewKind.venueClaim => widget.repository.approveClaim(_item),
      ReviewKind.venueAbout => widget.repository.approveAbout(_item),
      ReviewKind.venuePhoto => widget.repository.approvePhoto(_item),
      // Events open ReviewEventScreen, never this one.
      ReviewKind.venueEvent || ReviewKind.venueEventEdit => throw StateError(
        'Events are reviewed in ReviewEventScreen.',
      ),
    },
  );

  Future<void> _reject() async {
    final note = await showDialog<String>(
      context: context,
      builder: (_) => const RejectWithNoteDialog(),
    );
    if (note == null || note.trim().isEmpty) return;
    await _decide(
      () => switch (_item.kind) {
        ReviewKind.venueClaim => widget.repository.rejectClaim(
          _item,
          note.trim(),
        ),
        ReviewKind.venueAbout => widget.repository.rejectAbout(
          _item,
          note.trim(),
        ),
        ReviewKind.venuePhoto => widget.repository.rejectPhoto(
          _item,
          note.trim(),
        ),
        ReviewKind.venueEvent || ReviewKind.venueEventEdit => throw StateError(
          'Events are reviewed in ReviewEventScreen.',
        ),
      },
    );
  }

  // Opens the real detail screen with this submission in place. A photo
  // takes the place of the one it replaces, or is added at the end — the
  // same rule approve_venue_photo applies.
  Future<void> _previewPage({bool withPhoto = false}) async {
    final client = Supabase.instance.client;
    final signed = withPhoto ? await _signedUrl : null;
    if (!mounted) return;
    final about = _item.kind == ReviewKind.venueAbout ? _item.aboutText : null;
    final Widget page;
    switch (_item.venueType) {
      case 'restaurant':
        final repo = RestaurantRepository(client);
        final venue = await repo.getById(_item.venueId);
        final photos = signed == null
            ? null
            : _merge(await repo.getPhotos(_item.venueId), signed);
        if (venue == null || !mounted) return;
        page = RestaurantDetailScreen(
          restaurant: venue,
          aboutTextOverride: about,
          photosOverride: photos,
          isPreview: true,
        );
      case 'hotel':
        final repo = HotelRepository(client);
        final venue = await repo.getById(_item.venueId);
        final photos = signed == null
            ? null
            : _merge(await repo.getPhotos(_item.venueId), signed);
        if (venue == null || !mounted) return;
        page = HotelDetailScreen(
          hotel: venue,
          aboutTextOverride: about,
          photosOverride: photos,
          isPreview: true,
        );
      default:
        final repo = PrivateChefRepository(client);
        final chef = await repo.getPrivateChefById(_item.venueId);
        final existing = await repo.getChefPhotos(_item.venueId);
        List<PrivateChefPhoto>? photos;
        if (signed != null) {
          photos = [
            for (final p in _merge([
              for (final c in existing)
                PublishedVenuePhoto(
                  id: c.id,
                  imageUrl: c.imageUrl,
                  displayOrder: c.displayOrder,
                  framing: c.framing,
                ),
            ], signed))
              PrivateChefPhoto(
                id: p.id,
                privateChefId: _item.venueId,
                imageUrl: p.imageUrl,
                displayOrder: p.displayOrder,
                framing: p.framing,
              ),
          ];
        }
        if (!mounted) return;
        page = PrivateChefDetailScreen(
          chefId: _item.venueId,
          chefOverride: chef,
          aboutTextOverride: about,
          photosOverride: photos,
          isPreview: true,
        );
    }
    if (!mounted) return;
    await Navigator.push(context, MaterialPageRoute(builder: (_) => page));
  }

  List<PublishedVenuePhoto> _merge(
    List<PublishedVenuePhoto> published,
    String url,
  ) {
    final pending = PublishedVenuePhoto(
      id: _item.itemId,
      imageUrl: url,
      displayOrder: published.length,
      framing: _item.photoFraming,
    );
    final list = [...published];
    final at = list.indexWhere((p) => p.id == _item.photoReplacesPhotoId);
    if (at >= 0) {
      list[at] = pending;
    } else {
      list.add(pending);
    }
    return [
      for (var i = 0; i < list.length; i++)
        PublishedVenuePhoto(
          id: list[i].id,
          imageUrl: list[i].imageUrl,
          displayOrder: i,
          framing: list[i].framing,
          isCard: list[i].isCard,
          cardFraming: list[i].cardFraming,
        ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.warmWhite,
      appBar: AppBar(
        title: Text(
          _item.kind.label,
          style: CsTypography.placeTitle.copyWith(
            color: AppColors.forestGreen,
            fontSize: 20,
          ),
        ),
        backgroundColor: AppColors.warmWhite,
        surfaceTintColor: Colors.transparent,
        iconTheme: const IconThemeData(color: AppColors.forestGreen),
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            CsSpacing.pageHorizontal,
            CsSpacing.md,
            CsSpacing.pageHorizontal,
            CsSpacing.section,
          ),
          children: [
            Text(
              _item.venueName,
              style: CsTypography.placeTitle.copyWith(
                color: AppColors.forestGreen,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              [
                if (_item.venueCity != null) _item.venueCity!,
                _venueTypeLabel(_item.venueType),
                'from ${_item.submitterLabel}',
              ].join(' · '),
              style: CsTypography.metadata.copyWith(color: AppColors.taupe),
            ),
            const SizedBox(height: CsSpacing.lg),
            ..._body(),
            if (_error != null) ...[
              const SizedBox(height: CsSpacing.md),
              Text(
                _error!,
                style: CsTypography.metadata.copyWith(color: AppColors.error),
              ),
            ],
            const SizedBox(height: CsSpacing.lg),
            SizedBox(
              width: double.infinity,
              child: CsPrimaryButton(
                label: _item.kind == ReviewKind.venuePhoto
                    ? 'Approve and publish'
                    : 'Approve',
                surface: CsSurface.light,
                loading: _busy,
                onTap: _busy ? null : _approve,
              ),
            ),
            const SizedBox(height: CsSpacing.sm),
            Center(
              child: TextButton(
                onPressed: _busy ? null : _reject,
                child: Text(
                  'Reject with a note',
                  style: CsTypography.metadata.copyWith(color: AppColors.error),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _body() => switch (_item.kind) {
    ReviewKind.venueEvent || ReviewKind.venueEventEdit => const [],
    ReviewKind.venueClaim => [
      _field('Role', _item.claimRole),
      _field('Business email', _item.claimBusinessEmail),
      _field('Phone', _item.claimPhone),
      _field('Their note', _item.claimNotes),
      const SizedBox(height: CsSpacing.sm),
      Text(
        'Approving makes them a manager of this venue.',
        style: CsTypography.metadata.copyWith(color: AppColors.taupe),
      ),
    ],
    ReviewKind.venueAbout => [
      _label('NEW ABOUT TEXT'),
      const SizedBox(height: CsSpacing.sm),
      Text(
        _item.aboutText ?? '',
        style: CsTypography.body.copyWith(color: AppColors.forestGreen),
      ),
      const SizedBox(height: CsSpacing.md),
      _previewButton(() => _previewPage()),
    ],
    ReviewKind.venuePhoto => [
      if (_item.photoDuplicateOf != null)
        Padding(
          padding: const EdgeInsets.only(bottom: CsSpacing.md),
          child: Text(
            'Flagged as a near-duplicate of an earlier submission.',
            style: CsTypography.metadata.copyWith(color: AppColors.error),
          ),
        ),
      if (_item.photoReplacesPhotoId != null)
        Padding(
          padding: const EdgeInsets.only(bottom: CsSpacing.md),
          child: Text(
            'Replaces one of the venue\'s current photos.',
            style: CsTypography.metadata.copyWith(color: AppColors.taupe),
          ),
        ),
      _PhotoFrames(
        image: widget.photoImage,
        signedUrl: _signedUrl,
        framing: _item.photoFraming,
        isChef: _isChef,
      ),
      const SizedBox(height: CsSpacing.md),
      if (widget.photoImage == null)
        _previewButton(() => _previewPage(withPhoto: true)),
    ],
  };

  Widget _previewButton(VoidCallback onTap) => Align(
    alignment: Alignment.centerLeft,
    child: TextButton.icon(
      onPressed: _busy ? null : onTap,
      icon: const Icon(Icons.visibility_outlined, size: 18),
      label: Text(
        'Preview the venue page',
        style: CsTypography.metadata.copyWith(
          color: AppColors.forestGreen,
          fontWeight: FontWeight.w600,
        ),
      ),
      style: TextButton.styleFrom(
        foregroundColor: AppColors.forestGreen,
        padding: EdgeInsets.zero,
      ),
    ),
  );

  Widget _field(String label, String? value) {
    if (value == null || value.trim().isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: CsSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _label(label.toUpperCase()),
          const SizedBox(height: 2),
          Text(
            value,
            style: CsTypography.body.copyWith(color: AppColors.forestGreen),
          ),
        ],
      ),
    );
  }

  Widget _label(String text) =>
      Text(text, style: CsTypography.eyebrow.copyWith(color: AppColors.taupe));

  static String _venueTypeLabel(String wire) => switch (wire) {
    'restaurant' => 'Restaurant',
    'hotel' => 'Hotel',
    _ => 'Private chef',
  };
}

/// The pending photo in its real header frame with the manager's chosen
/// framing, and as a card: a new photo's card crop starts centred (the
/// manager sets it later in Card photo, if they choose it there).
class _PhotoFrames extends StatelessWidget {
  final ImageProvider? image;
  final Future<String>? signedUrl;
  final PhotoFraming framing;
  final bool isChef;

  const _PhotoFrames({
    required this.image,
    required this.signedUrl,
    required this.framing,
    required this.isChef,
  });

  @override
  Widget build(BuildContext context) {
    if (image != null) return _frames(image!);
    return FutureBuilder<String>(
      future: signedUrl,
      builder: (context, snap) {
        if (snap.hasError) {
          return Text(
            'Could not load the photo.',
            style: CsTypography.metadata.copyWith(color: AppColors.error),
          );
        }
        if (!snap.hasData) {
          return const SizedBox(
            height: 200,
            child: Center(
              child: CircularProgressIndicator(
                color: AppColors.forestGreen,
                strokeWidth: 1.5,
              ),
            ),
          );
        }
        return _frames(NetworkImage(snap.data!));
      },
    );
  }

  Widget _frames(ImageProvider provider) {
    final header = isChef ? framing.forChef : framing;
    Widget img(Alignment a) =>
        Image(image: provider, fit: BoxFit.cover, alignment: a);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'AS THE HEADER',
          style: CsTypography.eyebrow.copyWith(color: AppColors.taupe),
        ),
        const SizedBox(height: CsSpacing.sm),
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(
            width: double.infinity,
            height: isChef ? 320 : 300,
            child: FramedImage(framing: header, builder: img),
          ),
        ),
        const SizedBox(height: CsSpacing.md),
        Text(
          'AS A CARD',
          style: CsTypography.eyebrow.copyWith(color: AppColors.taupe),
        ),
        const SizedBox(height: CsSpacing.sm),
        SizedBox(
          width: 160,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: AspectRatio(
              aspectRatio: isChef ? 4 / 5 : 1,
              child: FramedImage(
                framing: isChef
                    ? PhotoFraming.center.forChefCard
                    : PhotoFraming.center,
                builder: img,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Asks for the note a venue receives with a rejection. Pops the note,
/// or null. Shared with ReviewEventScreen ("Take offline" uses its own
/// [title]).
class RejectWithNoteDialog extends StatefulWidget {
  final String title;
  const RejectWithNoteDialog({super.key, this.title = 'Reject'});
  @override
  State<RejectWithNoteDialog> createState() => _RejectWithNoteDialogState();
}

class _RejectWithNoteDialogState extends State<RejectWithNoteDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.warmWhite,
      title: Text(
        widget.title,
        style: CsTypography.placeTitle.copyWith(
          color: AppColors.forestGreen,
          fontSize: 20,
        ),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'The venue sees this note, so say what to change.',
            style: CsTypography.metadata.copyWith(color: AppColors.taupe),
          ),
          const SizedBox(height: CsSpacing.sm),
          TextField(
            controller: _controller,
            autofocus: true,
            minLines: 2,
            maxLines: 5,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(hintText: 'Reason'),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(
            'Cancel',
            style: CsTypography.bodyMedium.copyWith(color: AppColors.taupe),
          ),
        ),
        TextButton(
          onPressed: _controller.text.trim().isEmpty
              ? null
              : () => Navigator.pop(context, _controller.text),
          child: Text(
            widget.title,
            style: CsTypography.bodyMedium.copyWith(color: AppColors.error),
          ),
        ),
      ],
    );
  }
}
