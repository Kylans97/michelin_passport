import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/photo_limits.dart';
import '../../../data/repositories/photo_repository.dart';
import '../../../models/visit_photo.dart';
import '../../photos/photo_viewer_screen.dart';
import '../../photos/staged_photo.dart';
import '../../photos/widgets/add_photos_button.dart';
import '../../photos/widgets/visit_photo_grid.dart';

/// The "Photos" block inside AttendanceDetailsSheet — Events V2 Step 4's
/// photo hardening pass. Deliberately the closest possible mirror of
/// VisitPhotosSection's own load/upload/delete shape (same picker, same
/// compression, same grid, same viewer, same confirm-delete copy pattern),
/// substituting PhotoRepository's attendance-keyed methods for its
/// visit-keyed ones — no new photo system, no new image package, per
/// explicit instruction. Kept as its own small widget rather than
/// generalizing VisitPhotosSection itself: that widget's public API
/// (visitId/entityType/entityId/noun) is visit-shaped, and attendance
/// photos have a different upload/delete method shape underneath
/// (uploadAttendancePhoto vs. uploadPhoto, storage-only
/// deleteAllPhotosForAttendance vs. row+storage deleteAllPhotosForVisit) —
/// forking the shell here is smaller and clearer than branching one
/// widget's internals on which kind of photo it's managing.
class AttendancePhotosSection extends StatefulWidget {
  final String attendanceId;
  final String eventId;

  /// Called once per photo that successfully uploads — the caller (the
  /// details sheet) fires `event_photo_added` analytics from here, after
  /// the write has already succeeded, matching this app's non-negotiable
  /// successful-write rule.
  final VoidCallback onPhotoUploaded;

  const AttendancePhotosSection({
    super.key,
    required this.attendanceId,
    required this.eventId,
    required this.onPhotoUploaded,
  });

  @override
  State<AttendancePhotosSection> createState() =>
      _AttendancePhotosSectionState();
}

class _AttendancePhotosSectionState extends State<AttendancePhotosSection> {
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
      final photos = await _repo.loadPhotosForAttendance(widget.attendanceId);
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

  // [isError] mirrors VisitPhotosSection's own identical convention — a
  // plain informational notice (the 6-photo limit is a normal product
  // rule, not a failure: §3's explicit "do not show an error-looking
  // state") uses forestGreen instead of the red error background.
  void _showSnack(String message, {bool isError = true}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: GoogleFonts.inter(color: AppColors.textOnDark),
        ),
        backgroundColor: isError ? AppColors.error : AppColors.forestGreen,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _addPhotos() async {
    if (_uploading) return;
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null || userId.isEmpty) {
      _showSnack('Sign in to add photos.');
      return;
    }

    // Events V2 Step 4's final photo-limit correction. Guards against this
    // method somehow being reached while the Add action should already be
    // disabled (e.g. a queued tap that lands right as the 6th photo
    // finishes uploading from a prior call) — not the primary UX guard,
    // which is the disabled AddPhotosButton in build() below.
    final remaining = remainingAttendancePhotoCapacity(_photos?.length ?? 0);
    if (remaining <= 0) return;

    final List<StagedPhoto> picked;
    try {
      // Advisory cap at the OS picker level — see pickStagedPhotos' own
      // doc comment for why the defensive clamp below still runs
      // regardless of whether this was honored.
      picked = await pickStagedPhotos(limit: remaining);
    } catch (_) {
      _showSnack('Could not open photo library.');
      return;
    }
    if (picked.isEmpty) return;

    // Never uploads the excess and deletes it afterward (§4's explicit
    // instruction) — items beyond capacity are simply never attempted.
    final accepted = clampToRemainingCapacity(picked, remaining);
    final overflow = picked.length - accepted.length;

    setState(() => _uploading = true);
    var successes = 0;
    var failures = 0;
    for (final staged in accepted) {
      try {
        await _repo.uploadAttendancePhoto(
          userId: userId,
          attendanceId: widget.attendanceId,
          eventId: widget.eventId,
          bytes: staged.bytes,
          fileExtension: extensionOfXFile(staged.file),
        );
        successes++;
      } catch (_) {
        failures++;
      }
    }
    await _load();
    if (!mounted) return;
    setState(() => _uploading = false);
    // Fired once per successfully-uploaded photo, only after each write
    // succeeded — never for a failed one, and never for one of the
    // clamped-away overflow items (those were never attempted at all).
    for (var i = 0; i < successes; i++) {
      widget.onPhotoUploaded();
    }
    if (failures > 0) {
      _showSnack(
        failures == accepted.length
            ? 'Could not upload photos. Please try again.'
            : 'Some photos could not be uploaded.',
      );
    } else if (overflow > 0) {
      _showSnack(
        'Only $remaining of ${picked.length} photos were added — maximum '
        '$maxEventAttendancePhotos photos per event.',
        isError: false,
      );
    }
  }

  Future<void> _confirmDelete(VisitPhoto photo) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
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
      _showSnack('Could not delete photo. Please try again.');
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
          padding: EdgeInsets.symmetric(vertical: 16),
          child: SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              color: AppColors.forestGreen,
              strokeWidth: 1.5,
            ),
          ),
        ),
      );
    }
    if (_loadError) {
      return Row(
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
              style: GoogleFonts.inter(color: AppColors.forestGreen),
            ),
          ),
        ],
      );
    }

    final photos = _photos ?? [];
    // Recomputed from the loaded list every build — never a stored flag —
    // so a delete (which updates _photos locally with no re-fetch, see
    // _confirmDelete) makes the Add action available again immediately,
    // and a fresh _load() after an upload/limit-hit stays in sync with
    // whatever the server actually holds. Existing photos above
    // maxEventAttendancePhotos (pre-dating this limit) are NEVER
    // truncated from [photos] itself — only this affordance reacts to the
    // count; the grid above always renders the full list unchanged.
    final remaining = remainingAttendancePhotoCapacity(photos.length);
    final atCapacity = remaining <= 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (photos.isNotEmpty) ...[
          VisitPhotoGrid(
            photos: photos,
            urls: _urls,
            onTapPhoto: _openViewer,
            onDeletePhoto: _confirmDelete,
          ),
          const SizedBox(height: 12),
        ],
        AddPhotosButton(
          busy: _uploading,
          enabled: !atCapacity,
          label: photos.isEmpty ? 'Add photos' : 'Add more photos',
          onTap: _addPhotos,
        ),
        if (atCapacity) ...[
          const SizedBox(height: 6),
          Text(
            'Maximum $maxEventAttendancePhotos photos',
            style: GoogleFonts.inter(
              color: AppColors.textSecondary,
              fontSize: 12,
            ),
          ),
        ],
      ],
    );
  }
}
