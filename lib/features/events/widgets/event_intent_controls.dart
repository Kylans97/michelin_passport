import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/cs_spacing.dart';
import '../../../core/theme/cs_typography.dart';
import '../../../models/event_attendance.dart';

/// The Interested/Going intent controls on Event Detail (Events V2 Step 3)
/// — replaces the single-toggle `EventGoingButton` (Social Foundation Step
/// 2B), now that Going is one of two independent intent states rather
/// than the only one. Two compact pills, side by side, sharing
/// EventGoingButton's own established visual language exactly: outline =
/// unselected (forest-green border/text, transparent fill), filled =
/// selected (forest-green fill, ivory text/icon), a spinner replaces the
/// icon while its own mutation is pending. Never gold — gold stays
/// reserved for Michelin recognition. Both intrinsically sized, never a
/// `SizedBox(width: double.infinity)` booking CTA — intent is a
/// restrained personal marker, not a ticket-purchase action.
///
/// Purely presentational: this widget has no opinion on what a tap means
/// (select vs. remove) — [onTap] always receives the tapped
/// [EventIntentStatus], and the caller resolves the actual transition via
/// `resolveIntentTap` (event_intent.dart) and performs the write. Every
/// business rule stays in repository/domain logic, never in this widget —
/// see EVENTS_V2_ARCHITECTURE.md's web-readiness note.
class EventIntentControls extends StatelessWidget {
  /// The last confirmed status — null means no intent recorded (NONE).
  final EventIntentStatus? status;

  /// True while a mutation is in flight. Both pills are non-interactive
  /// during this window, preventing a second tap from racing the first
  /// (Events V2 Step 3 §19's concurrency requirement).
  final bool busy;

  /// The status a mutation-in-flight is moving toward. Only meaningful
  /// while [busy] is true; null while [busy] is true specifically means a
  /// removal is in flight (moving toward NONE, so no pill has a target
  /// status to show as selected).
  final EventIntentStatus? pendingTarget;

  final ValueChanged<EventIntentStatus> onTap;

  const EventIntentControls({
    super.key,
    required this.status,
    required this.busy,
    required this.pendingTarget,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // Wrap, not Row: at high text scale on a narrow screen, two full-size
    // pills side by side can exceed the available width — Wrap reflows the
    // second pill onto its own line instead of overflowing horizontally,
    // the same "never overflow, degrade gracefully" approach this
    // codebase already established for VenueUtilityActions' own row of
    // actions.
    return Wrap(
      spacing: CsSpacing.sm,
      runSpacing: CsSpacing.sm,
      children: [
        _IntentPill(
          label: 'Interested',
          unselectedIcon: Icons.bookmark_border_rounded,
          selectedIcon: Icons.bookmark_rounded,
          selected: busy
              ? pendingTarget == EventIntentStatus.interested
              : status == EventIntentStatus.interested,
          spinning: busy && pendingTarget == EventIntentStatus.interested,
          enabled: !busy,
          onTap: () => onTap(EventIntentStatus.interested),
        ),
        _IntentPill(
          label: 'Going',
          unselectedIcon: Icons.add_circle_outline_rounded,
          selectedIcon: Icons.check_circle_rounded,
          selected: busy
              ? pendingTarget == EventIntentStatus.going
              : status == EventIntentStatus.going,
          spinning: busy && pendingTarget == EventIntentStatus.going,
          enabled: !busy,
          onTap: () => onTap(EventIntentStatus.going),
        ),
      ],
    );
  }
}

class _IntentPill extends StatelessWidget {
  final String label;
  final IconData unselectedIcon;
  final IconData selectedIcon;
  final bool selected;
  final bool spinning;
  final bool enabled;
  final VoidCallback onTap;

  const _IntentPill({
    required this.label,
    required this.unselectedIcon,
    required this.selectedIcon,
    required this.selected,
    required this.spinning,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // Selected state is never color-only: a distinct icon (outline vs.
    // filled) pairs with the fill/border color change, matching
    // EventGoingButton's own established rule.
    return Semantics(
      button: true,
      selected: selected,
      label: selected ? '$label. Tap to remove.' : label,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: BorderRadius.circular(CsRadius.pill),
          splashColor: AppColors.forestGreen.withValues(alpha: 0.12),
          highlightColor: AppColors.forestGreen.withValues(alpha: 0.08),
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: CsSpacing.base,
              vertical: CsSpacing.sm,
            ),
            decoration: BoxDecoration(
              color: selected ? AppColors.forestGreen : Colors.transparent,
              borderRadius: BorderRadius.circular(CsRadius.pill),
              border: Border.all(color: AppColors.forestGreen, width: 1),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (spinning)
                  SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: selected
                          ? AppColors.textOnDark
                          : AppColors.forestGreen,
                    ),
                  )
                else
                  Icon(
                    selected ? selectedIcon : unselectedIcon,
                    size: 16,
                    color: selected
                        ? AppColors.textOnDark
                        : AppColors.forestGreen,
                  ),
                const SizedBox(width: CsSpacing.xs),
                Text(
                  label,
                  style: CsTypography.smallLabel.copyWith(
                    color: selected
                        ? AppColors.textOnDark
                        : AppColors.forestGreen,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
