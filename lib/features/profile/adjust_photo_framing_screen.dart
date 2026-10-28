import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants/app_colors.dart';
import '../../core/theme/cs_spacing.dart';
import '../../core/theme/cs_surface_context.dart';
import '../../core/theme/cs_typography.dart';
import '../../core/widgets/cs_primary_button.dart';
import '../../data/repositories/venue_photo_submission_repository.dart';
import '../../models/managed_venue.dart';
import '../../models/photo_framing.dart';
import '../../models/published_venue_photo.dart';
import 'widgets/photo_framing_editor.dart';

/// Re-frames one of a venue's PUBLISHED photos — pushed from
/// VenueManagementScreen's photo rows. Saving goes live straight away
/// through set_venue_photo_framing (20261014120000), with no new review:
/// the photo itself doesn't change, only how it sits in the frame.
///
/// Pops `true` only once a save has actually succeeded, so the caller
/// knows to reload.
class AdjustPhotoFramingScreen extends StatefulWidget {
  final ManagedVenue venue;
  final PublishedVenuePhoto photo;
  final VenuePhotoSubmissionRepository? repository;

  /// Test seam: the image to frame. Defaults to the photo's own URL.
  final ImageProvider? image;

  const AdjustPhotoFramingScreen({
    super.key,
    required this.venue,
    required this.photo,
    this.repository,
    this.image,
  });

  @override
  State<AdjustPhotoFramingScreen> createState() =>
      _AdjustPhotoFramingScreenState();
}

class _AdjustPhotoFramingScreenState extends State<AdjustPhotoFramingScreen> {
  late final _repo =
      widget.repository ??
      VenuePhotoSubmissionRepository(Supabase.instance.client);

  bool get _isChef => widget.venue.venueTypeWireValue == 'private_chef';

  // What the photo looks like right now — for a chef, an untouched photo
  // is shown high in the frame (PhotoFraming.forChef), so the editor
  // starts from exactly what visitors see.
  late final PhotoFraming _start = _isChef
      ? widget.photo.framing.forChef
      : widget.photo.framing;
  late PhotoFraming _framing = _start;
  bool _saving = false;
  String? _error;

  Future<void> _save() async {
    if (_saving) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await _repo.setPhotoFraming(
        venueType: widget.venue.venueTypeWireValue,
        photoId: widget.photo.id,
        framing: _isChef ? _framing.storedForChef : _framing,
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
    return Scaffold(
      backgroundColor: AppColors.warmWhite,
      appBar: AppBar(
        title: Text(
          'Adjust framing',
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
              'Changes go live as soon as you save — no new review needed.',
              style: CsTypography.body.copyWith(color: AppColors.taupe),
            ),
            const SizedBox(height: CsSpacing.md),
            PhotoFramingEditor(
              image: widget.image ?? NetworkImage(widget.photo.imageUrl),
              venueTypeWireValue: widget.venue.venueTypeWireValue,
              initial: _start,
              defaultFraming: _isChef
                  ? PhotoFraming.chefDefault
                  : PhotoFraming.center,
              onChanged: (framing) => setState(() => _framing = framing),
            ),
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
                onTap: _framing == _start || _saving ? null : _save,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
