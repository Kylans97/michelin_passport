import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/cs_typography.dart';

/// Events V2 Time Precision Phase B — Event Detail Hierarchy UX
/// correction: the external-link action area directly below Event
/// Essentials — Tickets (or the admission-aware "Optional ticket" label)
/// and Official website. Moved up from the former LOCATION section, which
/// now owns only physical-location facts — actionable links no longer sit
/// buried near the bottom of the screen.
///
/// Editorial Hero + Essentials/Actions polish pass (physical-device
/// finding on the real date-only pilot): refined from a pair of loose
/// "Label →" text links ([SubtleTextAction], still used elsewhere on
/// Restaurant/Hotel Detail — unchanged there) into deliberate full-width
/// action rows — label left, chevron right, a consistent row height, and
/// a single restrained hairline between the two when both exist. Still no
/// card, no filled CTA block, no gold — dark-green (forest green)
/// typography and iconography directly on the page's own ivory
/// background, "understated luxury," not a marketplace button.
///
/// Tickets renders FIRST when both exist — "slightly stronger priority"
/// per the correction's own instruction, expressed purely through
/// top-to-bottom reading order, never a second, louder row style.
///
/// When [ticketUrl] and [officialUrl] are the exact same URL — a real
/// production case, not a hypothetical: Vergeet Mij Niet Gala's own
/// official site doubles as its ticket page — only ONE action renders
/// (Tickets, the more specific of the two intents), never two
/// visually-duplicated rows pointing at the identical destination.
///
/// Renders nothing at all when neither URL exists — never an empty
/// action row taking up space.
class EventActionsRow extends StatelessWidget {
  final String? ticketUrl;
  final String? officialUrl;
  final String ticketLabel;
  final String eventName;
  final ValueChanged<String> onTapUrl;

  const EventActionsRow({
    super.key,
    required this.ticketUrl,
    required this.officialUrl,
    required this.ticketLabel,
    required this.eventName,
    required this.onTapUrl,
  });

  @override
  Widget build(BuildContext context) {
    final hasTickets = ticketUrl != null && ticketUrl!.isNotEmpty;
    var hasWebsite = officialUrl != null && officialUrl!.isNotEmpty;
    if (hasTickets && hasWebsite && officialUrl == ticketUrl) {
      hasWebsite = false;
    }
    if (!hasTickets && !hasWebsite) return const SizedBox.shrink();

    return Column(
      children: [
        if (hasTickets)
          _EventActionRow(
            label: ticketLabel,
            semanticsLabel: '$ticketLabel for $eventName',
            onTap: () => onTapUrl(ticketUrl!),
          ),
        // A single restrained hairline between the two rows, not
        // SectionDivider — that widget's own contract ("between named
        // sections only, never after every row") is explicitly for
        // section boundaries, not for separating two rows within the
        // same small action area.
        if (hasTickets && hasWebsite)
          Divider(
            color: AppColors.taupe.withValues(alpha: 0.25),
            thickness: 0.5,
            height: 0.5,
          ),
        if (hasWebsite)
          _EventActionRow(
            label: 'Official website',
            semanticsLabel: 'Official website for $eventName',
            onTap: () => onTapUrl(officialUrl!),
          ),
      ],
    );
  }
}

class _EventActionRow extends StatelessWidget {
  final String label;
  final String semanticsLabel;
  final VoidCallback onTap;

  const _EventActionRow({
    required this.label,
    required this.semanticsLabel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Semantics(
    label: semanticsLabel,
    button: true,
    child: ExcludeSemantics(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          splashColor: AppColors.forestGreen.withValues(alpha: 0.06),
          highlightColor: AppColors.forestGreen.withValues(alpha: 0.06),
          child: SizedBox(
            width: double.infinity,
            height: 52,
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: CsTypography.bodyMedium.copyWith(
                      color: AppColors.forestGreen,
                    ),
                  ),
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.forestGreen,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
