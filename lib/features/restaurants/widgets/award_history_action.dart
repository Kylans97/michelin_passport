import 'package:flutter/material.dart';
import '../../../core/widgets/subtle_text_action.dart';

/// The single subtle "Award history →" affordance shown below Restaurant
/// Detail's current-awards card. Deliberately plain so it reads as a quiet
/// secondary action, not a competing block of content —
/// RestaurantAwardsCard itself stays exactly as it was.
class AwardHistoryAction extends StatelessWidget {
  final VoidCallback onTap;
  const AwardHistoryAction({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) =>
      SubtleTextAction(label: 'Award history', onTap: onTap);
}
