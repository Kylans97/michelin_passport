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
import '../../models/photo_framing.dart';
import '../../models/published_venue_photo.dart';
import 'widgets/photo_framing_editor.dart';

/// The venue's card photo: which of its APPROVED photos shows on the
/// small cards (Explore, search, Passport, Wishlist, Rankings, Guides) and
/// how it is cropped there — independent of the cover and its header crop.
/// Pushed from VenueManagementScreen's Card photo section; saving goes
/// live straight away through set_venue_card_photo (20261015120000), with
/// no review, like Adjust framing.
///
/// Picking a photo — the cover included — makes it the card photo until
/// changed. When one is chosen, "Follow my cover" clears that, so the
/// cards follow whatever photo is first again (the default for a venue
/// that never chooses).
///
/// Pops `true` only once a save has actually succeeded.
class CardPhotoScreen extends StatefulWidget {
  final ManagedVenue venue;

  /// The venue's published photos in display_order — index 0 is the
  /// cover.
  final List<PublishedVenuePhoto> photos;
  final VenuePhotoSubmissionRepository? repository;

  /// Test seam: the image for each photo. Defaults to its own URL.
  final ImageProvider Function(PublishedVenuePhoto photo)? imageFor;

  const CardPhotoScreen({
    super.key,
    required this.venue,
    required this.photos,
    this.repository,
    this.imageFor,
  });

  /// The photo the cards show today: the flagged one, else the cover.
  static PublishedVenuePhoto? currentCardPhoto(
    List<PublishedVenuePhoto> photos,
  ) {
    for (final p in photos) {
      if (p.isCard) return p;
    }
    return photos.isEmpty ? null : photos.first;
  }

  @override
  State<CardPhotoScreen> createState() => _CardPhotoScreenState();
}

class _CardPhotoScreenState extends State<CardPhotoScreen> {
  late final _repo =
      widget.repository ??
      VenuePhotoSubmissionRepository(Supabase.instance.client);

  bool get _isChef => widget.venue.venueTypeWireValue == 'private_chef';

  PhotoFraming get _default =>
      _isChef ? PhotoFraming.chefCardDefault : PhotoFraming.center;

  // A chef card shows an untouched crop at its own default, so the editor
  // starts from that and saving it again stores "untouched".
  PhotoFraming _shown(PublishedVenuePhoto p) =>
      _isChef ? p.cardFraming.forChefCard : p.cardFraming;

  PhotoFraming _stored(PhotoFraming f) => _isChef ? f.storedForChefCard : f;

  bool get _hasExplicitChoice => widget.photos.any((p) => p.isCard);

  late final PublishedVenuePhoto? _initial = CardPhotoScreen.currentCardPhoto(
    widget.photos,
  );
  late PublishedVenuePhoto? _selected = _initial;
  late final Map<String, PhotoFraming> _framings = {
    for (final p in widget.photos) p.id: _shown(p),
  };
  bool _saving = false;
  String? _error;

  ImageProvider _imageOf(PublishedVenuePhoto p) =>
      widget.imageFor?.call(p) ?? NetworkImage(p.imageUrl);

  bool get _changed {
    final selected = _selected;
    if (selected == null) return false;
    if (!_hasExplicitChoice) return true;
    return selected.id != _initial?.id ||
        _framings[selected.id] != _shown(selected);
  }

  Future<void> _save({required bool followCover}) async {
    if (_saving) return;
    final selected = _selected;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await _repo.setCardPhoto(
        venueType: widget.venue.venueTypeWireValue,
        venueId: widget.venue.id,
        photoId: followCover ? null : selected?.id,
        framing: followCover || selected == null
            ? PhotoFraming.center
            : _stored(_framings[selected.id] ?? _default),
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = 'Could not save. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final selected = _selected;
    return Scaffold(
      backgroundColor: AppColors.warmWhite,
      appBar: AppBar(
        title: Text(
          'Card photo',
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
              'The small photo people see on cards in Explore, search and '
              'Passport. Choose any of your photos and how it sits — your '
              'page\'s header is not affected.',
              style: CsTypography.body.copyWith(color: AppColors.taupe),
            ),
            const SizedBox(height: CsSpacing.md),
            Wrap(
              spacing: CsSpacing.sm,
              runSpacing: CsSpacing.sm,
              children: [
                for (var i = 0; i < widget.photos.length; i++)
                  _choice(widget.photos[i], isCover: i == 0),
              ],
            ),
            if (selected != null) ...[
              const SizedBox(height: CsSpacing.lg),
              PhotoFramingEditor(
                key: ValueKey(selected.id),
                target: PhotoFramingTarget.card,
                image: _imageOf(selected),
                venueTypeWireValue: widget.venue.venueTypeWireValue,
                initial: _framings[selected.id] ?? _default,
                defaultFraming: _default,
                onChanged: (f) => setState(() => _framings[selected.id] = f),
              ),
            ],
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
                label: 'Save',
                surface: CsSurface.light,
                loading: _saving,
                onTap: _changed && !_saving
                    ? () => _save(followCover: false)
                    : null,
              ),
            ),
            if (_hasExplicitChoice) ...[
              const SizedBox(height: CsSpacing.sm),
              Center(
                child: TextButton(
                  onPressed: _saving ? null : () => _save(followCover: true),
                  child: Text(
                    'Follow my cover',
                    style: CsTypography.metadata.copyWith(
                      color: AppColors.forestGreen,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _choice(PublishedVenuePhoto photo, {required bool isCover}) {
    final isSelected = photo.id == _selected?.id;
    return Semantics(
      button: true,
      selected: isSelected,
      label: isCover ? 'Your cover' : 'Photo',
      child: GestureDetector(
        onTap: () => setState(() => _selected = photo),
        child: Column(
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isSelected
                      ? AppColors.forestGreen
                      : AppColors.subtleBorderLight,
                  width: isSelected ? 2.5 : 1,
                ),
              ),
              padding: const EdgeInsets.all(2),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(7),
                child: FramedImage(
                  framing: _framings[photo.id] ?? _default,
                  builder: (alignment) => Image(
                    image: _imageOf(photo),
                    fit: BoxFit.cover,
                    alignment: alignment,
                    errorBuilder: (_, _, _) => const SizedBox.shrink(),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 2),
            SizedBox(
              height: 16,
              child: isCover
                  ? Text(
                      'Cover',
                      style: CsTypography.metadata.copyWith(
                        color: AppColors.taupe,
                        fontSize: 11,
                      ),
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}
