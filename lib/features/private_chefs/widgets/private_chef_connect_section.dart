import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/cs_spacing.dart';
import '../../../core/theme/cs_typography.dart';
import '../../../core/widgets/subtle_text_action.dart';

/// Chef Detail's "CONNECT" section — reuses [SubtleTextAction] (the same
/// understated "Label →" affordance Restaurant/Hotel Detail already use
/// for their own secondary entry points), never a large social-media
/// button treatment. URL opening itself is the caller's responsibility
/// (same inline `_openUrl` pattern RestaurantDetailScreen/
/// HotelDetailScreen already use — see Chef Detail's own screen file) —
/// this widget stays presentation-only and pure/testable. Omits itself
/// entirely when neither [onTapInstagram] nor [onTapWebsite] is supplied.
class PrivateChefConnectSection extends StatelessWidget {
  final VoidCallback? onTapInstagram;
  final VoidCallback? onTapWebsite;

  const PrivateChefConnectSection({
    super.key,
    this.onTapInstagram,
    this.onTapWebsite,
  });

  @override
  Widget build(BuildContext context) {
    if (onTapInstagram == null && onTapWebsite == null) {
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'CONNECT',
          style: CsTypography.eyebrow.copyWith(color: AppColors.taupe),
        ),
        const SizedBox(height: CsSpacing.sm),
        if (onTapInstagram != null)
          SubtleTextAction(label: 'Instagram', onTap: onTapInstagram!),
        if (onTapWebsite != null)
          SubtleTextAction(label: 'Website', onTap: onTapWebsite!),
      ],
    );
  }
}
