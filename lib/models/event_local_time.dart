/// Events V2 — Time Precision Phase B. A pure wall-clock time-of-day, with
/// no date and no timezone attached — exactly what Postgres' own `time`
/// column (`events.start_time`/`end_time`) represents. Deliberately not
/// Flutter's `TimeOfDay` (`package:flutter/material.dart`) — this type
/// lives in the models layer, which stays framework-free like every other
/// model in this codebase (`Event` itself has zero Flutter imports); a
/// widget-layer type has no business appearing in a JSON-parsed domain
/// model. The smallest safe abstraction the architecture audit asked for,
/// not a general-purpose duration/clock library.
class EventLocalTime implements Comparable<EventLocalTime> {
  final int hour;
  final int minute;
  final int second;

  const EventLocalTime({
    required this.hour,
    required this.minute,
    this.second = 0,
  });

  /// Parses PostgREST's own `time` serialization — `"HH:MM:SS"`, optionally
  /// with a fractional-seconds suffix this app never populates and always
  /// ignores (no Event time is ever sub-second precise). Throws on a
  /// malformed value, matching every other required-field parse in
  /// [Event.fromJson] — never silently substitutes a default time.
  factory EventLocalTime.parse(String value) {
    final parts = value.split(':');
    if (parts.length < 2) {
      throw FormatException('Not a valid HH:MM:SS time string: "$value"');
    }
    return EventLocalTime(
      hour: int.parse(parts[0]),
      minute: int.parse(parts[1]),
      second: parts.length > 2 ? int.parse(parts[2].split('.').first) : 0,
    );
  }

  int get _sinceMidnightSeconds => hour * 3600 + minute * 60 + second;

  @override
  int compareTo(EventLocalTime other) =>
      _sinceMidnightSeconds.compareTo(other._sinceMidnightSeconds);

  @override
  bool operator ==(Object other) =>
      other is EventLocalTime &&
      _sinceMidnightSeconds == other._sinceMidnightSeconds;

  @override
  int get hashCode => _sinceMidnightSeconds;

  /// `"HH:MM"` — every current display rule needs minute precision only;
  /// seconds exist purely to round-trip whatever Postgres sent, never to
  /// be shown.
  String format() =>
      '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';

  @override
  String toString() => 'EventLocalTime(${format()})';
}

/// Events V2 Time Precision — the future host-submission workstream's own
/// validation rule (architecture audit §"Host-Created Events": a
/// Restaurant/Hotel/Private Chef submitting their own Event must provide
/// exact start AND end times, unlike editorial/external ingestion, which
/// may legitimately be date-only). A pure rule with zero UI/Supabase
/// dependency, so that future submission flow can reuse it rather than
/// reimplement it — NOT called anywhere in this app today, since Chasing
/// Stars does not yet support host-created Events; this exists purely so
/// the rule is written down once, in the domain layer it belongs to,
/// rather than invented ad hoc when that workstream actually starts.
bool satisfiesHostCreatedEventTimeRequirement({
  required EventLocalTime? startTime,
  required EventLocalTime? endTime,
}) => startTime != null && endTime != null;
