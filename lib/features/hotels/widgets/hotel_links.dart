import 'package:flutter/material.dart';
import '../../../core/widgets/app_button.dart';

/// Google Maps / Michelin Guide / Website for Hotel Detail — one row of
/// compact, equally-weighted utility buttons, shared with Restaurant
/// Detail's equivalent link row rather than a separate, heavier styling.
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

    return Row(
      children: [
        Expanded(
          child: SecondaryButton(
            icon: Icons.map_outlined,
            label: 'Maps',
            onTap: onOpenMaps,
          ),
        ),
        if (hasMichelin) ...[
          const SizedBox(width: 8),
          Expanded(
            child: SecondaryButton(
              icon: Icons.open_in_new_rounded,
              label: 'Michelin',
              onTap: onOpenMichelin!,
            ),
          ),
        ],
        if (hasWebsite) ...[
          const SizedBox(width: 8),
          Expanded(
            child: SecondaryButton(
              icon: Icons.language_rounded,
              label: 'Website',
              onTap: onOpenWebsite!,
            ),
          ),
        ],
      ],
    );
  }
}
