import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/cs_typography.dart';
import '../../../models/gault_millau_award.dart';
import '../../guides/widgets/guide_gault_millau_mark.dart';

/// Every recorded Gault&Millau edition for one restaurant, newest first —
/// the third source on Award History beside MICHELIN and World's 50 Best.
/// Each row reads exactly what [formatGaultMillauDistinction] reads (score,
/// toques, or the unscored tier's own label); an edition with nothing
/// publishable shows "Listed" rather than a made-up number. Ivory on the
/// green canvas, never gold — gold is reserved for MICHELIN alone.
class GaultMillauHistorySection extends StatelessWidget {
  /// Newest guide year first, as RestaurantGaultMillauRepository
  /// .loadForRestaurant returns them.
  final List<GaultMillauAward> awards;
  const GaultMillauHistorySection({super.key, required this.awards});

  @override
  Widget build(BuildContext context) {
    if (awards.isEmpty) return const SizedBox.shrink();
    return Column(
      children: [
        for (var i = 0; i < awards.length; i++) ...[
          _EditionRow(award: awards[i]),
          if (i != awards.length - 1) ...[
            const SizedBox(height: 10),
            const Divider(color: AppColors.subtleBorderDark, height: 1),
            const SizedBox(height: 10),
          ],
        ],
      ],
    );
  }
}

class _EditionRow extends StatelessWidget {
  final GaultMillauAward award;
  const _EditionRow({required this.award});

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Text(
        '${award.guideYear}',
        style: CsTypography.metadata.copyWith(
          color: AppColors.textOnDark,
          fontWeight: FontWeight.w600,
        ),
      ),
      const Spacer(),
      Text(
        formatGaultMillauDistinction(award) ?? 'Listed',
        style: CsTypography.metadata.copyWith(
          color: AppColors.textOnDark,
          fontWeight: FontWeight.w700,
        ),
      ),
    ],
  );
}
