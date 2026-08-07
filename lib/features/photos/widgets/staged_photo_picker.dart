import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../staged_photo.dart';
import 'add_photos_button.dart';

/// Pre-save photo selection for Add Visit / Add Stay: a horizontal strip of
/// local thumbnails (each with an explicit remove "X", no long-press
/// required) plus an "Add photos" button. Purely local state — [photos]
/// live in memory only until the sheet actually saves the visit/stay and
/// uploads them against the new visit_id.
class StagedPhotoPicker extends StatelessWidget {
  final List<StagedPhoto> photos;
  final bool picking;
  final VoidCallback onAdd;
  final ValueChanged<StagedPhoto> onRemove;

  const StagedPhotoPicker({
    super.key,
    required this.photos,
    required this.picking,
    required this.onAdd,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (photos.isNotEmpty) ...[
          SizedBox(
            height: 84,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: photos.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, i) => _StagedThumb(
                photo: photos[i],
                onRemove: () => onRemove(photos[i]),
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],
        AddPhotosButton(
          busy: picking,
          label: photos.isEmpty ? 'Add photos' : 'Add more photos',
          onTap: onAdd,
        ),
      ],
    );
  }
}

class _StagedThumb extends StatelessWidget {
  final StagedPhoto photo;
  final VoidCallback onRemove;
  const _StagedThumb({required this.photo, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 84,
      height: 84,
      child: Stack(
        children: [
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.memory(photo.bytes, fit: BoxFit.cover),
            ),
          ),
          Positioned(
            top: 4,
            right: 4,
            child: Material(
              color: Colors.black54,
              shape: const CircleBorder(),
              child: InkWell(
                onTap: onRemove,
                customBorder: const CircleBorder(),
                child: const Padding(
                  padding: EdgeInsets.all(4),
                  child: Icon(
                    Icons.close_rounded,
                    color: AppColors.textPrimary,
                    size: 14,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
