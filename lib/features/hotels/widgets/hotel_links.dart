import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/app_colors.dart';

/// Google Maps / Michelin Guide / Website — a small standalone version of
/// the same link-button styling used on Restaurant Detail, kept local to
/// this MVP screen rather than shared, since Restaurant Detail's version
/// also carries visited/wishlist toggles this screen doesn't have yet.
class HotelLinks extends StatelessWidget {
  final VoidCallback onOpenMaps;
  final VoidCallback? onOpenMichelin;
  final VoidCallback? onOpenWebsite;

  const HotelLinks({
    super.key,
    required this.onOpenMaps,
    required this.onOpenMichelin,
    required this.onOpenWebsite,
  });

  @override
  Widget build(BuildContext context) {
    final hasMichelin = onOpenMichelin != null;
    final hasWebsite = onOpenWebsite != null;

    return Column(
      children: [
        _LinkButton(
          icon: Icons.map_rounded,
          label: 'Google Maps',
          filled: true,
          onTap: onOpenMaps,
        ),
        if (hasMichelin || hasWebsite) ...[
          const SizedBox(height: 10),
          Row(
            children: [
              if (hasMichelin)
                Expanded(
                  child: _LinkButton(
                    icon: Icons.open_in_new_rounded,
                    label: 'Michelin Guide',
                    filled: false,
                    onTap: onOpenMichelin!,
                  ),
                ),
              if (hasMichelin && hasWebsite) const SizedBox(width: 10),
              if (hasWebsite)
                Expanded(
                  child: _LinkButton(
                    icon: Icons.language_rounded,
                    label: 'Website',
                    filled: false,
                    onTap: onOpenWebsite!,
                  ),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

class _LinkButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool filled;
  final VoidCallback onTap;
  const _LinkButton({
    required this.icon,
    required this.label,
    required this.filled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: filled ? 54 : 50,
      child: filled
          ? FilledButton.icon(
              onPressed: onTap,
              icon: Icon(icon, size: 18),
              label: Text(
                label,
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  letterSpacing: 0.1,
                ),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.gold,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            )
          : OutlinedButton.icon(
              onPressed: onTap,
              icon: Icon(icon, size: 16),
              label: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(fontSize: 13.5),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.textSecondary,
                side: const BorderSide(color: AppColors.cardBorder, width: 0.5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
    );
  }
}
