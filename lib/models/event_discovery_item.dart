import 'event.dart';
import 'event_relevance_reason.dart';

/// Events V2 Step 8A — one entry in the single, unified Events discovery
/// list (never a section-stack; see
/// EVENTS_V2_STEP_8_PERSONALIZED_DISCOVERY_AUDIT.md). Wraps an [Event]
/// with, at most, the one strongest [EventRelevanceReason] it qualified
/// for — an event with no personalization signal (cold start, or simply no
/// qualifying signal today) carries a null [primaryReason] and renders
/// exactly like today's plain chronological card.
class EventDiscoveryItem {
  final Event event;
  final EventRelevanceReason? primaryReason;

  const EventDiscoveryItem({required this.event, this.primaryReason});
}
