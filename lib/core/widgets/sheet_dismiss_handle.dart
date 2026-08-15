import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import 'editorial_back_button.dart';

/// The top row of a dismissible modal bottom sheet: an explicit, always-
/// visible Close control (left) plus the conventional drag handle,
/// centered via a trailing spacer that balances the button's own
/// footprint. Shared by every sheet that previously relied on swipe-to-
/// dismiss alone with no on-screen affordance (Create Trip, Add Visit,
/// Add Stay) — one widget, not a one-off per sheet.
///
/// [onClose] should be exactly `Navigator.pop(context)` with no result —
/// identical to what swipe-to-dismiss/system-back already return — so a
/// caller's existing `if (result != null)` gate means this never
/// triggers a save, a refresh, or any repository/database write.
class SheetDismissHandle extends StatelessWidget {
  final VoidCallback onClose;

  // Defaults to the dark-canvas ivory EditorialBackButton itself defaults
  // to; pass AppColors.textPrimary for a light-card sheet.
  final Color? color;
  final Color handleColor;

  const SheetDismissHandle({
    super.key,
    required this.onClose,
    this.color,
    this.handleColor = AppColors.divider,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        EditorialBackButton(
          icon: Icons.close_rounded,
          semanticLabel: 'Close',
          color: color,
          onTap: onClose,
        ),
        Expanded(
          child: Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: handleColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        ),
        // Balances EditorialBackButton's own footprint so the drag handle
        // stays visually centered in the row.
        const SizedBox(width: 44),
      ],
    );
  }
}
