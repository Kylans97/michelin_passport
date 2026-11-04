import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/cs_typography.dart';

/// That Mantelier is independent of the guides it names, in the same words
/// as the terms (site/terms.html). At the foot of Profile, so it is in the
/// app and not only on the website.
class IndependenceNote extends StatelessWidget {
  const IndependenceNote({super.key});

  static const text =
      "Mantelier is independent. It is not affiliated with, endorsed by or "
      "sponsored by Michelin, The World's 50 Best, Gault&Millau or any venue "
      "listed. Their names are used only to describe their own selections.";

  @override
  Widget build(BuildContext context) => Text(
    text,
    textAlign: TextAlign.center,
    style: CsTypography.metadata.copyWith(
      color: AppColors.secondaryOnDark.withValues(alpha: 0.6),
    ),
  );
}
