import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/cs_spacing.dart';
import '../../../core/theme/cs_typography.dart';
import '../../../core/widgets/cs_image_placeholder.dart';

/// Shared shape for both Passport empty states: no visits logged at all, or
/// a year filter with nothing in it. Only the message differs. Restyled
/// for the deep-green Passport canvas — the official monogram (via
/// [CsImagePlaceholder], small and quiet) stands in for the old generic
/// book icon, and text reads in the redesigned [CsTypography] roles. No
/// new CTA: nothing existed here before, and this task doesn't add flows.
class PassportEmptyState extends StatelessWidget {
  final String message;

  const PassportEmptyState({super.key, required this.message});

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CsImagePlaceholder(
            width: 64,
            height: 64,
            borderRadius: BorderRadius.all(Radius.circular(CsRadius.medium)),
            logoScale: 0.5,
          ),
          const SizedBox(height: CsSpacing.lg),
          Text(
            message,
            textAlign: TextAlign.center,
            style: CsTypography.placeTitle.copyWith(
              color: AppColors.textOnDark,
            ),
          ),
        ],
      ),
    ),
  );
}
