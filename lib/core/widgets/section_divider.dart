import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../theme/cs_spacing.dart';

/// A restrained editorial hairline between major sections of Restaurant/
/// Hotel Detail's ivory content canvas. Used sparingly — between named
/// sections only, never after every row — so it reads as editorial
/// grouping, not a settings-list divider. Never gold.
///
/// UI Consistency Step 1E: on-device review found [AppColors.
/// subtleBorderLight] (`softStone`, `0xFFDED8CE`) nearly invisible against
/// the ivory canvas (`0xFFF4F0E7`) — both are light, low-saturation
/// neutrals with barely any luminance gap between them. Rather than invent
/// a new arbitrary color, this now uses the app's own existing secondary-
/// text token, [AppColors.taupe] (already established as accessible on
/// ivory — see its own definition comment, 4.68:1), at reduced opacity: a
/// visible line without reading as a full-strength text-weight rule. Not
/// full-bleed — inserted directly inside each screen's own padded content
/// column, so it's already aligned with the surrounding content margins.
class SectionDivider extends StatelessWidget {
  const SectionDivider({super.key});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: CsSpacing.lg),
    child: Divider(
      color: AppColors.taupe.withValues(alpha: 0.4),
      thickness: 0.75,
      height: 0.75,
    ),
  );
}
