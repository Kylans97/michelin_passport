import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../data/repositories/photo_repository.dart';
import '../../features/photos/photo_viewer_screen.dart';
import '../../models/visit_photo.dart';
import '../constants/app_colors.dart';
import '../theme/cs_spacing.dart';

/// A compact, read-only preview of the most recent visit/stay's photos —
/// the "personal photos" slice of Restaurant/Hotel Detail's hierarchy.
/// Deliberately read-only: adding/removing photos already works fully on
/// VisitDetailScreen/StayDetailScreen (see VisitPhotosSection), so this
/// widget reuses PhotoRepository purely for display and never duplicates
/// the upload/delete flow — tapping a thumbnail opens the same
/// PhotoViewerScreen those screens use, on the same underlying data.
class PersonalPhotosPreview extends StatefulWidget {
  final String latestVisitId;
  const PersonalPhotosPreview({super.key, required this.latestVisitId});

  @override
  State<PersonalPhotosPreview> createState() => _PersonalPhotosPreviewState();
}

class _PersonalPhotosPreviewState extends State<PersonalPhotosPreview> {
  late final _repo = PhotoRepository(Supabase.instance.client);
  List<VisitPhoto>? _photos;
  Map<String, String> _urls = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant PersonalPhotosPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.latestVisitId != widget.latestVisitId) _load();
  }

  Future<void> _load() async {
    try {
      final photos = await _repo.loadPhotosForVisit(widget.latestVisitId);
      final urls = await _repo.resolveDisplayUrls([
        for (final p in photos) p.storagePath,
      ]);
      if (!mounted) return;
      setState(() {
        _photos = photos;
        _urls = urls;
      });
    } catch (_) {
      // A failed preview load just leaves the strip empty — the real
      // photo management on Visit/Stay Detail is unaffected either way.
    }
  }

  @override
  Widget build(BuildContext context) {
    final photos = _photos;
    if (photos == null || photos.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: 84,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: photos.length,
        separatorBuilder: (_, _) => const SizedBox(width: CsSpacing.sm),
        itemBuilder: (context, i) {
          final url = _urls[photos[i].storagePath];
          return ClipRRect(
            borderRadius: BorderRadius.circular(CsRadius.small),
            child: GestureDetector(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => PhotoViewerScreen(
                    photos: photos,
                    urls: _urls,
                    initialIndex: i,
                  ),
                ),
              ),
              child: SizedBox(
                width: 84,
                height: 84,
                child: url == null
                    ? const ColoredBox(color: AppColors.warmWhite)
                    : Image.network(
                        url,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) =>
                            const ColoredBox(color: AppColors.warmWhite),
                      ),
              ),
            ),
          );
        },
      ),
    );
  }
}
