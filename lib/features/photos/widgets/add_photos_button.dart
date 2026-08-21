import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/app_colors.dart';

/// The outlined "Add photos" / "Add more photos" button shared by
/// VisitPhotosSection (post-save) and StagedPhotoPicker (pre-save).
///
/// [enabled] (Events V2 Step 4's photo-limit correction) defaults to
/// `true` — every pre-existing call site (Restaurant/Hotel, the pre-save
/// picker) omits it and is completely unaffected. Only
/// AttendancePhotosSection ever passes `false`, when its own attendance
/// has reached the 6-photo maximum. Deliberately styled as quietly
/// unavailable (muted taupe/cardBorder, same disabled-button pattern as
/// [busy]) rather than an error state — this is a normal, expected limit,
/// not a failure.
class AddPhotosButton extends StatelessWidget {
  final bool busy;
  final bool enabled;
  final String label;
  final VoidCallback onTap;

  const AddPhotosButton({
    super.key,
    required this.busy,
    this.enabled = true,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final tint = enabled ? AppColors.gold : AppColors.textSecondary;
    return SizedBox(
      width: double.infinity,
      height: 46,
      child: OutlinedButton.icon(
        onPressed: (enabled && !busy) ? onTap : null,
        icon: busy
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  color: AppColors.gold,
                  strokeWidth: 2,
                ),
              )
            : Icon(Icons.add_photo_alternate_outlined, size: 18, color: tint),
        label: Text(
          label,
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w600,
            fontSize: 14,
            color: tint,
          ),
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: tint,
          side: BorderSide(
            color: enabled ? AppColors.goldBorder60 : AppColors.cardBorder,
            width: 1,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    );
  }
}
