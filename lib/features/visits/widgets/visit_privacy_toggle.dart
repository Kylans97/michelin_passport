import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/cs_spacing.dart';

/// The "Visible to friends" control shown on visit/stay creation (and, on
/// [VisitDetailScreen]/[StayDetailScreen], editing) — Social Foundation
/// Step 2. Deliberately small and restrained (a single row, not a card
/// wrapping the whole section) so it reads as secondary to actually
/// recording the visit, per the task brief. Uses this screen's own
/// existing light-card visual language (AppColors.surface/textPrimary/
/// textSecondary/gold, GoogleFonts.inter) rather than the newer dark
/// editorial CsTypography roles — this sheet doesn't use that system
/// anywhere else yet, and CsTypography's roles default to a color tuned
/// for the dark canvas, not this screen's ivory one. CsSpacing is still
/// used for layout, since it carries no color assumption either way.
///
/// No technical terms ("RLS", "visibility", "row policy") ever appear in
/// the copy — only the plain product-level meaning.
class VisitPrivacyToggle extends StatelessWidget {
  final bool friendsVisible;
  final ValueChanged<bool> onChanged;

  const VisitPrivacyToggle({
    super.key,
    required this.friendsVisible,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => onChanged(!friendsVisible),
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: CsSpacing.base,
            vertical: CsSpacing.md,
          ),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: AppColors.cardBorder.withValues(alpha: 0.55),
              width: 0.5,
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Visible to friends',
                      style: GoogleFonts.inter(
                        color: AppColors.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Friends can see this visit, your rating and photos.',
                      style: GoogleFonts.inter(
                        color: AppColors.textSecondary,
                        fontSize: 12.5,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: CsSpacing.md),
              Switch(
                value: friendsVisible,
                onChanged: onChanged,
                activeTrackColor: AppColors.forestGreen,
                thumbColor: const WidgetStatePropertyAll(Colors.white),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
