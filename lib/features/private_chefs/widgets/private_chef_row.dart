import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/cs_spacing.dart';
import '../../../core/theme/cs_typography.dart';
import '../../../models/private_chef.dart';
import 'private_chef_avatar.dart';

/// One chef in the Private Chefs catalogue — the same restrained editorial
/// index-row family as [GuideVenueCard] (hairline-separated, not a boxed
/// marketplace card), but person-first: [PrivateChef.displayName] is
/// always primary, [PrivateChef.businessName] — when present — is a
/// clearly subordinate second line, never the other way around (see
/// PRIVATE_CHEFS.md §4/§30 and §11 of the Step 2 brief). No score, no
/// rating, no price badge, no "Chasing Stars Selected" badge — the row
/// existing on this screen at all IS the selection signal.
class PrivateChefRow extends StatelessWidget {
  final PrivateChef chef;
  final VoidCallback onTap;

  const PrivateChefRow({super.key, required this.chef, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final businessName = chef.businessName?.trim() ?? '';
    final hasBusinessName = businessName.isNotEmpty;

    final location = [
      if ((chef.homeCity ?? '').trim().isNotEmpty) chef.homeCity!.trim(),
      if ((chef.homeCountryCode ?? '').trim().isNotEmpty)
        chef.homeCountryCode!.trim(),
    ].join(', ');
    final hasLocation = location.isNotEmpty;

    final semanticLabel = [
      chef.displayName,
      if (hasBusinessName) businessName,
      if (hasLocation) location,
    ].join(', ');

    return Semantics(
      button: true,
      label: semanticLabel,
      excludeSemantics: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          splashColor: AppColors.forestGreen.withValues(alpha: 0.06),
          highlightColor: AppColors.forestGreen.withValues(alpha: 0.04),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: CsSpacing.sm),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                PrivateChefAvatar(imageUrl: chef.profileImageUrl, size: 60),
                const SizedBox(width: CsSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        chef.displayName,
                        style: CsTypography.placeTitle.copyWith(
                          fontSize: 17,
                          color: AppColors.forestGreen,
                        ),
                      ),
                      if (hasBusinessName) ...[
                        const SizedBox(height: 2),
                        Text(
                          businessName,
                          style: CsTypography.metadata.copyWith(
                            color: AppColors.taupe,
                          ),
                        ),
                      ],
                      if (hasLocation) ...[
                        const SizedBox(height: 2),
                        Text(
                          location,
                          style: CsTypography.metadata.copyWith(
                            color: AppColors.taupe,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
