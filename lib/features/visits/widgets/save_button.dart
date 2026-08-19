import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/app_colors.dart';

/// The deep-green primary-action save button shared by Add Visit, Add Stay
/// and Plan Visit — [label] is the only thing that differs ("Save visit" vs
/// "Save stay" vs "Save plan"/"Save changes"). UI Consistency pass: was a
/// large gold button; deep green is now this app's primary-action color
/// system-wide, gold reserved for Michelin-star/Key recognition only.
class SaveButton extends StatelessWidget {
  final bool saving;
  final String label;
  final VoidCallback onTap;

  const SaveButton({
    super.key,
    required this.saving,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      width: double.infinity,
      height: 56,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.deepGreen.withValues(alpha: saving ? 0.12 : 0.28),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: FilledButton(
        onPressed: saving ? null : onTap,
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.deepGreen,
          foregroundColor: AppColors.textOnDark,
          disabledBackgroundColor: AppColors.forestGreen,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          child: saving
              ? const SizedBox(
                  key: ValueKey('saving'),
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    color: AppColors.textOnDark,
                    strokeWidth: 2,
                  ),
                )
              : Text(
                  label,
                  key: const ValueKey('label'),
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                    letterSpacing: 0.2,
                  ),
                ),
        ),
      ),
    );
  }
}
