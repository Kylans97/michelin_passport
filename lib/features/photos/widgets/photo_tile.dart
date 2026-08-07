import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';

/// One square thumbnail in a [VisitPhotoGrid]. [url] is a signed URL
/// (resolved in a batch by PhotoRepository.resolveDisplayUrls) — null while
/// that batch hasn't resolved yet, or if resolution failed for this photo.
/// Delete is an always-visible small badge (not just long-press) so it's
/// actually discoverable; long-press still works too as a convenience.
class PhotoTile extends StatelessWidget {
  final String? url;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const PhotoTile({
    super.key,
    required this.url,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Material(
        color: AppColors.surface,
        child: Stack(
          fit: StackFit.expand,
          children: [
            InkWell(
              onTap: onTap,
              onLongPress: onDelete,
              child: url == null
                  ? const _TileIcon(Icons.image_outlined)
                  : Image.network(
                      url!,
                      fit: BoxFit.cover,
                      loadingBuilder: (context, child, progress) =>
                          progress == null ? child : const _TileLoading(),
                      errorBuilder: (context, error, stack) =>
                          const _TileIcon(Icons.broken_image_outlined),
                    ),
            ),
            Positioned(
              top: 4,
              right: 4,
              child: Material(
                color: Colors.black54,
                shape: const CircleBorder(),
                child: InkWell(
                  onTap: onDelete,
                  customBorder: const CircleBorder(),
                  child: const Padding(
                    padding: EdgeInsets.all(4),
                    child: Icon(
                      Icons.delete_outline_rounded,
                      color: AppColors.textPrimary,
                      size: 15,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TileIcon extends StatelessWidget {
  final IconData icon;
  const _TileIcon(this.icon);

  @override
  Widget build(BuildContext context) =>
      Center(child: Icon(icon, color: AppColors.textSecondary, size: 20));
}

class _TileLoading extends StatelessWidget {
  const _TileLoading();

  @override
  Widget build(BuildContext context) => const Center(
    child: SizedBox(
      width: 16,
      height: 16,
      child: CircularProgressIndicator(color: AppColors.gold, strokeWidth: 1.5),
    ),
  );
}
