import 'package:flutter/material.dart';
import '../../../core/theme/cs_spacing.dart';
import '../../../core/widgets/subtle_text_action.dart';

/// Events V2 Time Precision Phase B — Event Detail Hierarchy UX
/// correction: the compact, quiet external-link action area directly
/// below Event Essentials — Tickets (or the admission-aware "Optional
/// ticket" label) and Official website. Moved up from the former LOCATION
/// section, which now owns only physical-location facts — actionable
/// links no longer sit buried near the bottom of the screen.
///
/// Tickets renders FIRST when both exist — "slightly stronger priority"
/// per the correction's own instruction, expressed purely through
/// left-to-right reading order rather than a second, louder button style;
/// this is still [SubtleTextAction], the same quiet "Label →" affordance
/// used elsewhere on Restaurant/Hotel Detail, deliberately not a
/// marketplace-style filled button. No gold.
///
/// When [ticketUrl] and [officialUrl] are the exact same URL — a real
/// production case, not a hypothetical: Vergeet Mij Niet Gala's own
/// official site doubles as its ticket page — only ONE action renders
/// (Tickets, the more specific of the two intents), never two
/// visually-duplicated links pointing at the identical destination.
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

    return Row(
      children: [
        if (hasTickets)
          Semantics(
            label: '$ticketLabel for $eventName',
            button: true,
            child: ExcludeSemantics(
              child: SubtleTextAction(
                label: ticketLabel,
                onTap: () => onTapUrl(ticketUrl!),
              ),
            ),
          ),
        if (hasTickets && hasWebsite) const SizedBox(width: CsSpacing.xl),
        if (hasWebsite)
          Semantics(
            label: 'Official website for $eventName',
            button: true,
            child: ExcludeSemantics(
              child: SubtleTextAction(
                label: 'Website',
                onTap: () => onTapUrl(officialUrl!),
              ),
            ),
          ),
      ],
    );
  }
}
