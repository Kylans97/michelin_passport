import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/cs_section_title.dart';

/// The single editorial section title above Passport's venue list — always
/// "YOUR COLLECTION", regardless of the selected venue-type filter. The
/// selected tab (All/Restaurants/Hotels) already establishes what's being
/// viewed, and the venue count is already shown in the metric strip above,
/// so neither is repeated here. Kept as its own widget (rather than an
/// inline Text in PassportScreen.build) so it stays directly testable —
/// PassportScreen itself can't be widget-tested (see
/// passport_view_model_test.dart's note on its unconditional
/// Supabase-backed repository).
class PassportCollectionHeader extends StatelessWidget {
  const PassportCollectionHeader({super.key});

  @override
  Widget build(BuildContext context) =>
      const CsSectionTitle('YOUR COLLECTION', color: AppColors.textOnDark);
}
