import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/app_colors.dart';
import '../theme/app_spacing.dart';

/// The filled call-to-action button for a screen's one genuinely primary
/// action ("Add Stay", "Mark as visited"'s equivalent). Deliberately
/// modest in height/type size — a considered accent, not a slab — so it
/// reads as elegant rather than dominating the venue content around it.
class PrimaryButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final double height;

  const PrimaryButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.height = 46,
  });

  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    height: height,
    child: FilledButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 16),
      label: Text(
        label,
        style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13),
      ),
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.brandGreen,
        foregroundColor: AppColors.textOnDark,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.md),
        ),
      ),
    ),
  );
}

/// The quiet outlined counterpart — external links (Maps, Michelin Guide,
/// Website) and other secondary, utility-level actions. Compact by
/// design: these support the venue, they don't compete with it.
class SecondaryButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const SecondaryButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    height: 42,
    child: OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 14),
      label: Text(
        label,
        overflow: TextOverflow.ellipsis,
        style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w500),
      ),
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.textSecondary,
        side: const BorderSide(color: AppColors.cardBorder, width: 0.5),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.md),
        ),
      ),
    ),
  );
}
