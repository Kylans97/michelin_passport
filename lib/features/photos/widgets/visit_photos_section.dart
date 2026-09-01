import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/constants/app_colors.dart';
import '../../../data/repositories/photo_repository.dart';
import '../../../models/visit_photo.dart';
import '../../restaurants/widgets/detail_section.dart';
import '../photo_viewer_screen.dart';
import '../staged_photo.dart';
import 'add_photos_button.dart';
import 'visit_photo_grid.dart';

/// The whole "Photos" section for a single visit/stay: grid, empty state,
/// add/upload, delete. Self-contained and reused unchanged by both
/// VisitDetailScreen and StayDetailScreen — one persistence system, no
/// separate restaurant-photo/hotel-photo code paths. Always loads and
/// writes by [visitId], never by the venue's id, so repeat visits/stays to
/// the same venue keep fully independent photo sets.
class VisitPhotosSection extends StatefulWidget {
  final String visitId;
  final String entityType;
  final String entityId;

  // 'visit' or 'stay' — used only for empty-state copy ("No photos from
  // this visit/stay yet.").
  final String noun;

  const VisitPhotosSection({
    super.key,
    required this.visitId,
    required this.entityType,
    required this.entityId,
    required this.noun,
  });

  @override
  State<VisitPhotosSection> createState() => _VisitPhotosSectionState();
}

class _VisitPhotosSectionState extends State<VisitPhotosSection> {
  late final _repo = PhotoRepository(Supabase.instance.client);

  List<VisitPhoto>? _photos;
  Map<String, String> _urls = {};
  bool _loading = true;
  bool _uploading = false;
  bool _loadError = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!_uploading) setState(() => _loading = _photos == null);
    try {
      final photos = await _repo.loadPhotosForVisit(widget.visitId);
      final urls = await _repo.resolveDisplayUrls([
        for (final p in photos) p.storagePath,
      ]);
      if (!mounted) return;
      setState(() {
        _photos = photos;
        _urls = urls;
        _loading = false;
        _loadError = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError = _photos == null;
      });
    }
  }

  void _showSnack(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: GoogleFonts.inter(
            color: AppColors.textPrimary,
          ),
        ),
        backgroundColor: isError ? AppColors.error : AppColors.gold,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _addPhotos() async {
    if (_uploading) return; // prevent duplicate taps mid-upload
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null || userId.isEmpty) {
      _showSnack('Sign in to add photos.', isError: true);
      return;
    }

    final List<StagedPhoto> picked;
    try {
      picked = await pickStagedPhotos();
    } catch (_) {
      _showSnack('Could not open photo library.', isError: true);
      return;
    }
    if (picked.isEmpty) return;

    setState(() => _uploading = true);
    var failures = 0;
    for (final staged in picked) {
      try {
        await _repo.uploadPhoto(
          userId: userId,
          visitId: widget.visitId,
          entityType: widget.entityType,
          entityId: widget.entityId,
          bytes: staged.bytes,
          fileExtension: extensionOfXFile(staged.file),
        );
      } catch (_) {
        failures++;
      }
    }
    await _load(); // preserves existing photos while this runs; grid only swaps once the fresh list + urls are ready
    if (!mounted) return;
    setState(() => _uploading = false);
    if (failures > 0) {
      _showSnack(
        failures == picked.length
            ? 'Could not upload photos. Please try again.'
            : 'Some photos could not be uploaded.',
        isError: true,
      );
    }
  }

  Future<void> _confirmDelete(VisitPhoto photo) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.card,
        title: Text(
          'Delete photo?',
          style: GoogleFonts.playfairDisplay(
            color: AppColors.textPrimary,
            fontSize: 18,
          ),
        ),
        content: Text(
          'This photo will be permanently removed.',
          style: GoogleFonts.inter(
            color: AppColors.textSecondary,
            fontSize: 14,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancel',
              style: GoogleFonts.inter(color: AppColors.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              'Delete',
              style: GoogleFonts.inter(
                color: AppColors.error,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await _repo.deletePhoto(photo);
      if (!mounted) return;
      setState(() {
        _photos = [
          for (final p in _photos ?? [])
            if (p.id != photo.id) p,
        ];
      });
    } catch (_) {
      if (!mounted) return;
      _showSnack('Could not delete photo. Please try again.', isError: true);
    }
  }

  void _openViewer(int index) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PhotoViewerScreen(
          photos: _photos!,
          urls: _urls,
          initialIndex: index,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 24),
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              color: AppColors.gold,
              strokeWidth: 1.5,
            ),
          ),
        ),
      );
    }
    if (_loadError) {
      return DetailCard(
        child: Row(
          children: [
            const Icon(
              Icons.wifi_off_rounded,
              color: AppColors.textSecondary,
              size: 18,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Could not load photos.',
                style: GoogleFonts.inter(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                ),
              ),
            ),
            TextButton(
              onPressed: _load,
              child: Text(
                'Retry',
                style: GoogleFonts.inter(color: AppColors.gold),
              ),
            ),
          ],
        ),
      );
    }

    final photos = _photos ?? [];
    if (photos.isEmpty) {
      return DetailCard(
        child: Column(
          children: [
            const Icon(
              Icons.photo_library_outlined,
              color: AppColors.textSecondary,
              size: 28,
            ),
            const SizedBox(height: 10),
            Text(
              'No photos from this ${widget.noun} yet.',
              style: GoogleFonts.inter(
                color: AppColors.textSecondary,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 16),
            AddPhotosButton(
              busy: _uploading,
              label: 'Add photos',
              onTap: _addPhotos,
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        VisitPhotoGrid(
          photos: photos,
          urls: _urls,
          onTapPhoto: _openViewer,
          onDeletePhoto: _confirmDelete,
        ),
        const SizedBox(height: 12),
        AddPhotosButton(
          busy: _uploading,
          label: 'Add more photos',
          onTap: _addPhotos,
        ),
      ],
    );
  }
}
