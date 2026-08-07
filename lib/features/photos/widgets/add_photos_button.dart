import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/app_colors.dart';

/// The outlined "Add photos" / "Add more photos" button shared by
/// VisitPhotosSection (post-save) and StagedPhotoPicker (pre-save).
class AddPhotosButton extends StatelessWidget {
  final bool busy;
  final String label;
  final VoidCallback onTap;

  const AddPhotosButton({
    super.key,
    required this.busy,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    height: 46,
    child: OutlinedButton.icon(
      onPressed: busy ? null : onTap,
      icon: busy
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                color: AppColors.gold,
                strokeWidth: 2,
              ),
            )
          : const Icon(Icons.add_photo_alternate_outlined, size: 18),
      label: Text(
        label,
        style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14),
      ),
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.gold,
        side: const BorderSide(color: AppColors.goldBorder60, width: 1),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
  );
}
