import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/cs_spacing.dart';
import '../../../core/theme/cs_typography.dart';
import '../../../core/widgets/cs_content_sheet.dart';
import '../../../core/widgets/cs_section_title.dart';

/// The small set of controls every Trips screen shares, so the list, Trip
/// Detail, Create/Edit Trip and the venue pickers read as one surface
/// rather than each growing its own one-off styling. Nothing here is gold:
/// CLAUDE.md reserves gold in-product for MICHELIN stars and Keys, so
/// actions, focus states, spinners and confirmations all stay in the
/// ivory-on-green register instead.

/// A section heading on Trips' deep-green canvas — the same shape as
/// Explore's own discovery section headers ("WHAT'S ON" + one quiet
/// subtitle line + an optional trailing text action), so a trip's STAY/
/// DINING sections read like the rest of the app rather than a form.
class TripSectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? trailing;

  const TripSectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: CsSectionTitle(
              title,
              color: AppColors.textOnDark,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: CsSpacing.sm),
            trailing!,
          ],
        ],
      ),
      if (subtitle != null) ...[
        const SizedBox(height: 2),
        Text(
          subtitle!,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: CsTypography.metadata.copyWith(
            color: AppColors.secondaryOnDark,
          ),
        ),
      ],
    ],
  );
}

/// A quiet ivory text action on the green canvas ("Add stay", "Change") —
/// text plus an optional leading glyph, no fill, no gold. [enabled] false
/// dims it and drops the tap, for actions that need something chosen
/// first (a destination before a venue).
class TripTextAction extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final IconData? icon;
  final bool enabled;

  const TripTextAction({
    super.key,
    required this.label,
    required this.onTap,
    this.icon = Icons.add_rounded,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final color = enabled
        ? AppColors.textOnDark
        : AppColors.secondaryOnDark.withValues(alpha: 0.6);
    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      excludeSemantics: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: BorderRadius.circular(CsRadius.small),
          splashColor: AppColors.textOnDark.withValues(alpha: 0.06),
          highlightColor: AppColors.textOnDark.withValues(alpha: 0.04),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 44),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: CsSpacing.xs),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 16, color: color),
                    const SizedBox(width: 6),
                  ],
                  Text(
                    label,
                    style: CsTypography.bodyMedium.copyWith(
                      color: color,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A one-line, muted note where a section has nothing in it yet — kept
/// quiet so an empty trip never looks broken.
class TripEmptyLine extends StatelessWidget {
  final String message;
  const TripEmptyLine(this.message, {super.key});

  @override
  Widget build(BuildContext context) => Text(
    message,
    style: CsTypography.metadata.copyWith(color: AppColors.secondaryOnDark),
  );
}

/// The deep-green confirmation dialog every destructive Trips action uses
/// (delete trip, remove a venue, delete a plan) — one shape, serif title,
/// Inter body, the destructive action in the app's editorial brick red.
Future<bool> showTripConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: AppColors.greenSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(CsRadius.card),
        side: const BorderSide(color: AppColors.subtleBorderDark, width: 0.5),
      ),
      title: Text(
        title,
        style: CsTypography.placeTitle.copyWith(color: AppColors.textOnDark),
      ),
      content: Text(
        message,
        style: CsTypography.metadata.copyWith(
          color: AppColors.secondaryOnDark,
          height: 1.5,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(
            'Cancel',
            style: CsTypography.bodyMedium.copyWith(
              color: AppColors.secondaryOnDark,
              fontSize: 14,
            ),
          ),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          child: Text(
            confirmLabel,
            style: CsTypography.bodyMedium.copyWith(
              color: AppColors.error,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    ),
  );
  return confirmed == true;
}

/// Trips' transient confirmation/error line — forest green (never gold),
/// matching Restaurant/Hotel Detail's own `_showSnack`.
void showTripSnackBar(
  BuildContext context,
  String message, {
  bool isError = false,
}) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        message,
        style: CsTypography.metadata.copyWith(color: AppColors.textOnDark),
      ),
      backgroundColor: isError ? AppColors.error : AppColors.forestGreen,
      duration: const Duration(seconds: 2),
    ),
  );
}

/// One row in [showTripActionSheet].
class TripSheetAction<T> {
  final T value;
  final String label;
  final IconData icon;
  final bool destructive;

  const TripSheetAction({
    required this.value,
    required this.label,
    required this.icon,
    this.destructive = false,
  });
}

/// The quiet action sheet behind Trips' "…" and long-press menus — the
/// shared [CsContentSheet] shell on the green
/// surface, Inter labels, the destructive row in brick red. Returns the
/// chosen [TripSheetAction.value], or null if dismissed.
Future<T?> showTripActionSheet<T>(
  BuildContext context, {
  String? title,
  required List<TripSheetAction<T>> actions,
}) {
  return showModalBottomSheet<T>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (context) => CsContentSheet(
      backgroundColor: AppColors.greenSurface,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          CsSpacing.base,
          CsSpacing.md,
          CsSpacing.base,
          CsSpacing.base,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (title != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  CsSpacing.sm,
                  0,
                  CsSpacing.sm,
                  CsSpacing.sm,
                ),
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: CsTypography.placeTitle.copyWith(
                    color: AppColors.textOnDark,
                  ),
                ),
              ),
            for (final action in actions)
              ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: CsSpacing.sm,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(CsRadius.medium),
                ),
                leading: Icon(
                  action.icon,
                  size: 20,
                  color: action.destructive
                      ? AppColors.error
                      : AppColors.secondaryOnDark,
                ),
                title: Text(
                  action.label,
                  style: CsTypography.bodyMedium.copyWith(
                    color: action.destructive
                        ? AppColors.error
                        : AppColors.textOnDark,
                  ),
                ),
                onTap: () => Navigator.pop(context, action.value),
              ),
          ],
        ),
      ),
    ),
  );
}
