import 'analytics_event.dart';
import 'analytics_properties.dart';
import 'supabase_analytics_service.dart';

/// Records that [screen] became visible ([AnalyticsEvent.screenOpened],
/// written to `app_usage_events`). Never throws and never awaited — a
/// failed insert is swallowed inside [SupabaseAnalyticsService], so
/// navigation can never fail on it.
void trackScreenOpened(AnalyticsScreen screen) {
  SupabaseAnalyticsService.ofInstance().track(
    AnalyticsEvent.screenOpened,
    AnalyticsProperties(screen: screen),
  );
}
