import 'dart:math';

import 'package:flutter/foundation.dart';

import 'analytics_event.dart';
import 'analytics_properties.dart';

/// Events V2 Step 2 — the one vendor-neutral seam feature code depends on.
/// No screen, repository, or widget in this app ever imports a vendor SDK
/// (PostHog/Amplitude/Mixpanel/anything) directly, and none exists in
/// `pubspec.yaml` as of this step — every future provider is added later as
/// a new implementation of this class, never by changing any call site.
///
/// **Analytics is never authoritative.** Supabase (`event_attendance`,
/// `event_confirmed_attendance`, `follows_*`, `visits`, `planned_venues`)
/// remains the sole source of truth for every piece of transactional
/// product state — see `EVENTS_V2_ANALYTICS_CONTRACT.md` §2. Calling
/// [track] never performs, substitutes for, or is required for a state
/// change; it only ever records that one already happened.
///
/// [track] stamps every call with its own envelope — [AnalyticsEvent.name],
/// a timestamp, [analyticsSchemaVersion], the current session id, and the
/// identified user id if any — so no call site needs to pass any of that by
/// hand, and none of it can be accidentally omitted.
abstract class AnalyticsService {
  /// Records that [event] happened, with whatever [properties] apply.
  ///
  /// For any event that represents a database state change (Interested,
  /// Going, Follow, confirmed Attendance), the caller must only invoke this
  /// *after* the corresponding Supabase write has already succeeded — never
  /// before, never speculatively, never on a failed write. This rule is
  /// mandatory for every Step 3+ implementation; see the contract doc's
  /// "Successful-write rule".
  void track(AnalyticsEvent event, [AnalyticsProperties? properties]);

  /// Associates all future [track] calls with [userInternalId] — always an
  /// opaque internal id (`auth.uid()`), never an email, name, phone number,
  /// or raw Supabase auth token.
  void identify(String userInternalId);

  /// Clears the identified user (sign-out, account switch). Future [track]
  /// calls report anonymously (session id only) until the next [identify].
  void resetIdentity();
}

/// The production-safe default while no analytics vendor is selected.
/// Every call is a true no-op: nothing is computed beyond what the caller
/// already built, nothing is stored, nothing is ever sent anywhere. This is
/// the implementation this app ships with as of Step 2 — Step 2
/// deliberately does not wire it into `main.dart`/`app.dart` or any screen,
/// since this step establishes the contract only (no feature instrumented
/// yet).
class NoopAnalyticsService implements AnalyticsService {
  const NoopAnalyticsService();

  @override
  void track(AnalyticsEvent event, [AnalyticsProperties? properties]) {}

  @override
  void identify(String userInternalId) {}

  @override
  void resetIdentity() {}
}

/// A safe, local-only implementation for development: every [track] call
/// prints its fully-stamped envelope (event wire name, timestamp, schema
/// version, session id, identified user id if any, and every non-null
/// [AnalyticsProperties] field) via [debugPrint] — never a network call,
/// never a file write, never anything beyond the local device console.
/// Exists to let a developer visually confirm the abstraction produces the
/// right shape for a given call site; it is not the production default
/// (see [NoopAnalyticsService]) and is not wired into the app by this step.
///
/// Safe by construction, not by discipline: every field that can reach this
/// class already passed through [AnalyticsProperties]' own closed set of
/// approved fields, so there is no path for arbitrary/PII data to appear in
/// this output that isn't already governed by the contract doc's
/// REQUIRED/OPTIONAL/DO-NOT-TRACK list.
class DebugPrintAnalyticsService implements AnalyticsService {
  DebugPrintAnalyticsService() : _sessionId = _generateSessionId();

  final String _sessionId;
  String? _identifiedUserId;

  @override
  void track(AnalyticsEvent event, [AnalyticsProperties? properties]) {
    final envelope = <String, Object>{
      'event_name': event.wireName,
      'timestamp': DateTime.now().toUtc().toIso8601String(),
      'schema_version': analyticsSchemaVersion,
      'session_id': _sessionId,
      'user_internal_id': ?_identifiedUserId,
      ...?properties?.toMap(),
    };
    debugPrint('[analytics] $envelope');
  }

  @override
  void identify(String userInternalId) {
    _identifiedUserId = userInternalId;
  }

  @override
  void resetIdentity() {
    _identifiedUserId = null;
  }

  /// No `uuid` package dependency for a one-line need — a timestamp plus a
  /// short random suffix is unique enough for a local, non-authoritative
  /// session identifier. A future real provider adapter is free to
  /// generate/manage its own session id however that vendor's SDK expects;
  /// this generator only serves this debug implementation.
  static String _generateSessionId() {
    final random = Random();
    final suffix = List.generate(
      8,
      (_) => random.nextInt(16).toRadixString(16),
    ).join();
    return '${DateTime.now().microsecondsSinceEpoch.toRadixString(16)}$suffix';
  }
}
