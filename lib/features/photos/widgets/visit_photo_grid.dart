import 'package:flutter/material.dart';
import '../../../models/visit_photo.dart';
import 'photo_tile.dart';

/// A compact 3-column grid of a visit/stay's photos. Purely presentational
/// — loading, uploading and deletion all live in VisitPhotosSection, which
/// embeds this. [urls] is keyed by storage_path (see
/// PhotoRepository.resolveDisplayUrls).
class VisitPhotoGrid extends StatelessWidget {
  final List<VisitPhoto> photos;
  final Map<String, String> urls;
  final ValueChanged<int> onTapPhoto;
  final ValueChanged<VisitPhoto> onDeletePhoto;

  const VisitPhotoGrid({
    super.key,
    required this.photos,
    required this.urls,
    required this.onTapPhoto,
    required this.onDeletePhoto,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: photos.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemBuilder: (context, i) => PhotoTile(
        url: urls[photos[i].storagePath],
        onTap: () => onTapPhoto(i),
        onDelete: () => onDeletePhoto(photos[i]),
      ),
    );
  }
}
