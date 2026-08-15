import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/constants/app_colors.dart';
import '../../../data/repositories/photo_repository.dart';
import '../../../models/visit_photo.dart';

/// A small, read-only row of a friend's visit photos (Social Foundation
/// Step 2 — Friend Profile VISITED). Deliberately not [VisitPhotoGrid]/
/// [PhotoTile]: those are owner-oriented (an always-visible delete badge
/// on every tile), which would be actively misleading here — a viewer can
/// never delete a friend's photo (RLS only ever grants friends SELECT,
/// never DELETE, on someone else's photos), so no delete affordance
/// should ever render. Access itself is already the database's decision
/// by the time this widget runs: [PhotoRepository.loadPhotosForVisit] and
/// [PhotoRepository.resolveDisplayUrls] both go through the same
/// friends-visibility RLS/storage policies as everywhere else in the
/// app — an empty result here means either no photos exist or the viewer
/// isn't authorized, and both render identically (nothing), never an
/// error that would distinguish the two.
class FriendPhotoStrip extends StatefulWidget {
  final String visitId;

  const FriendPhotoStrip({super.key, required this.visitId});

  @override
  State<FriendPhotoStrip> createState() => _FriendPhotoStripState();
}

class _FriendPhotoStripState extends State<FriendPhotoStrip> {
  late final _repo = PhotoRepository(Supabase.instance.client);
  List<VisitPhoto>? _photos;
  Map<String, String> _urls = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final photos = await _repo.loadPhotosForVisit(widget.visitId);
      final urls = await _repo.resolveDisplayUrls([
        for (final p in photos) p.storagePath,
      ]);
      if (!mounted) return;
      setState(() {
        _photos = photos;
        _urls = urls;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _photos = []);
    }
  }

  @override
  Widget build(BuildContext context) {
    final photos = _photos;
    if (photos == null || photos.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: 64,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: photos.length,
        separatorBuilder: (_, _) => const SizedBox(width: 6),
        itemBuilder: (context, i) {
          final url = _urls[photos[i].storagePath];
          return ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              width: 64,
              height: 64,
              child: url == null
                  ? const ColoredBox(color: AppColors.brandGreenLight)
                  : Image.network(
                      url,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) =>
                          const ColoredBox(color: AppColors.brandGreenLight),
                    ),
            ),
          );
        },
      ),
    );
  }
}
