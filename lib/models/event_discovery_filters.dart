import 'event.dart';

/// Events V2 Discovery Taxonomy Phase B — the three V1 social filter
/// dimensions. Deliberately re-uses Step 8A's own definitions (see
/// [event_discovery_filtering.dart]'s doc comment) rather than inventing a
/// second meaning for "friend going"/"followed host" — a filter and a
/// ranking signal describe the same underlying fact, just used for two
/// different purposes (inclusion vs. relevance ordering).
enum EventSocialFilter { friendsGoing, friendsInterested, following }

/// The V1 date-filter presets a future Phase C control could offer,
/// resolved to a concrete calendar-date range by
/// [resolveEventDiscoveryDateRange] — kept deliberately separate from the
/// existing screen-scoped [EventDateFilterMode]/[EventDateFilter]
/// (`event_date_filter.dart`), which resolves the *base browse window*
/// (what "Upcoming" even means), a different concept from a *filter*
/// layered on top of it. `thisWeekend` in particular has no equivalent in
/// the existing enum (which has `thisWeek`, the whole week — a Saturday/
/// Sunday-only reading is a genuinely different, narrower range).
enum EventDiscoveryDatePreset { none, today, thisWeekend, thisMonth, custom }

/// A resolved, calendar-date-only range — `from`/`to` are inclusive
/// calendar dates (UTC-tagged [DateTime]s at midnight, matching
/// [Event.startDate]/[Event.endDate]'s own convention), never a
/// timestamp-with-time. `null` on either side means "open" on that side
/// (no lower/upper bound). An empty range (`from == null && to == null`)
/// applies no date restriction at all.
class EventDiscoveryDateRange {
  final DateTime? from;
  final DateTime? to;

  const EventDiscoveryDateRange({this.from, this.to});

  static const none = EventDiscoveryDateRange();

  bool get isEmpty => from == null && to == null;

  /// Normalizes an explicit (from, to) pair: a genuinely invalid range
  /// (`from` after `to`) is swapped rather than silently dropped or
  /// thrown away — the caller's intent ("these two dates, whichever order
  /// they arrived in") is preserved instead of losing the selection
  /// entirely (Phase B §19: malformed filter state must never become an
  /// inconsistent query, but a swap is a safe, deterministic recovery a
  /// silent drop is not).
  factory EventDiscoveryDateRange.normalized({DateTime? from, DateTime? to}) {
    if (from != null && to != null && from.isAfter(to)) {
      return EventDiscoveryDateRange(from: to, to: from);
    }
    return EventDiscoveryDateRange(from: from, to: to);
  }

  @override
  bool operator ==(Object other) =>
      other is EventDiscoveryDateRange && other.from == from && other.to == to;

  @override
  int get hashCode => Object.hash(from, to);
}

/// Resolves an [EventDiscoveryDatePreset] into a concrete
/// [EventDiscoveryDateRange], given the current instant (device-local
/// "now" — matching every other preset resolver in this codebase, e.g.
/// [EventDateFilter.resolve]). `custom` returns [customRange] verbatim
/// (already normalized by the caller via [EventDiscoveryDateRange.
/// normalized]); `none` returns [EventDiscoveryDateRange.none].
EventDiscoveryDateRange resolveEventDiscoveryDateRange(
  EventDiscoveryDatePreset preset, {
  DateTime? now,
  EventDiscoveryDateRange? customRange,
}) {
  final effectiveNow = now ?? DateTime.now();
  final today = DateTime.utc(
    effectiveNow.year,
    effectiveNow.month,
    effectiveNow.day,
  );
  switch (preset) {
    case EventDiscoveryDatePreset.none:
      return EventDiscoveryDateRange.none;
    case EventDiscoveryDatePreset.today:
      return EventDiscoveryDateRange(from: today, to: today);
    case EventDiscoveryDatePreset.thisWeekend:
      // ISO weekday: 1=Monday .. 7=Sunday. Saturday is (8 - weekday) days
      // ahead when weekday <= 6; if today already IS Saturday/Sunday, the
      // weekend in question is the current one, not next week's.
      final weekday = effectiveNow.weekday;
      final daysUntilSaturday = weekday == DateTime.saturday
          ? 0
          : weekday == DateTime.sunday
          ? -1
          : DateTime.saturday - weekday;
      final saturday = today.add(Duration(days: daysUntilSaturday));
      final sunday = saturday.add(const Duration(days: 1));
      return EventDiscoveryDateRange(from: saturday, to: sunday);
    case EventDiscoveryDatePreset.thisMonth:
      final start = DateTime.utc(effectiveNow.year, effectiveNow.month, 1);
      final end = DateTime.utc(effectiveNow.year, effectiveNow.month + 1, 0);
      return EventDiscoveryDateRange(from: start, to: end);
    case EventDiscoveryDatePreset.custom:
      return customRange ?? EventDiscoveryDateRange.none;
  }
}

/// Events V2 Discovery Taxonomy Phase B — the full, immutable, value-
/// comparable filter state for Events discovery. An empty [Set]/[
/// EventDiscoveryDateRange.isEmpty] on any dimension means that dimension
/// applies no restriction — never "match nothing" (see [isEmpty]/
/// [activeDimensionCount] below, and [applyDiscoveryFilters] in
/// event_discovery_filtering.dart for the actual inclusion semantics).
///
/// Deliberately typed, not `Map<String, dynamic>` or UI strings — every
/// value here is a real domain type ([EventType], a tag `slug` string
/// matching `event_tags.slug`, an uppercased ISO country code matching
/// `events.country_code`) so a caller can never construct filter state
/// that doesn't correspond to something the repository layer actually
/// understands.
class EventDiscoveryFilters {
  final Set<EventSocialFilter> social;
  final Set<EventType> eventTypes;
  final Set<String> tagSlugs;
  final Set<String> countryCodes;
  final EventDiscoveryDateRange dateRange;

  /// The seven V1 types intended to be user-selectable in a future Phase C
  /// control. Legacy values ([EventType.experience], [EventType.market],
  /// [EventType.other]) remain fully parseable everywhere else in the
  /// codebase (Phase A's own compatibility guarantee) but are deliberately
  /// NOT part of this constant — Phase B does not remap them to anything,
  /// and nothing prevents a caller from putting one in [eventTypes]
  /// anyway (it would simply match any legacy-typed Event exactly like any
  /// other [EventType] value), but the V1 product surface only ever
  /// offers these seven.
  static const selectableEventTypes = {
    EventType.dinner,
    EventType.lunch,
    EventType.festival,
    EventType.gala,
    EventType.tasting,
    EventType.brunch,
    EventType.party,
  };

  EventDiscoveryFilters({
    Set<EventSocialFilter> social = const {},
    Set<EventType> eventTypes = const {},
    Set<String> tagSlugs = const {},
    Set<String> countryCodes = const {},
    this.dateRange = EventDiscoveryDateRange.none,
  }) : social = Set.unmodifiable(social),
       eventTypes = Set.unmodifiable(eventTypes),
       // Normalized: tag slugs are stored lowercase, matching the
       // convention every seeded Phase A slug already follows
       // ('wine', 'wild_game', ...) — a caller passing mixed case still
       // resolves correctly rather than silently matching nothing.
       tagSlugs = Set.unmodifiable({
         for (final slug in tagSlugs) slug.trim().toLowerCase(),
       }),
       // Normalized: country codes are stored uppercase, matching
       // `events.country_code`'s own stored convention ('NL', 'DK', ...).
       countryCodes = Set.unmodifiable({
         for (final code in countryCodes) code.trim().toUpperCase(),
       });

  static final empty = EventDiscoveryFilters();

  bool get isEmpty =>
      social.isEmpty &&
      eventTypes.isEmpty &&
      tagSlugs.isEmpty &&
      countryCodes.isEmpty &&
      dateRange.isEmpty;

  /// The number of dimensions that currently apply a restriction — a
  /// future active-filter summary ("Netherlands · Wine · Friends Going")
  /// counts DIMENSIONS, never individual selected values (selecting both
  /// Wine and Guest Chef is still one active Theme dimension, not two) —
  /// see Phase B §21.
  int get activeDimensionCount =>
      (social.isNotEmpty ? 1 : 0) +
      (eventTypes.isNotEmpty ? 1 : 0) +
      (tagSlugs.isNotEmpty ? 1 : 0) +
      (countryCodes.isNotEmpty ? 1 : 0) +
      (dateRange.isEmpty ? 0 : 1);

  EventDiscoveryFilters copyWith({
    Set<EventSocialFilter>? social,
    Set<EventType>? eventTypes,
    Set<String>? tagSlugs,
    Set<String>? countryCodes,
    EventDiscoveryDateRange? dateRange,
  }) => EventDiscoveryFilters(
    social: social ?? this.social,
    eventTypes: eventTypes ?? this.eventTypes,
    tagSlugs: tagSlugs ?? this.tagSlugs,
    countryCodes: countryCodes ?? this.countryCodes,
    dateRange: dateRange ?? this.dateRange,
  );

  @override
  bool operator ==(Object other) =>
      other is EventDiscoveryFilters &&
      _setEquals(other.social, social) &&
      _setEquals(other.eventTypes, eventTypes) &&
      _setEquals(other.tagSlugs, tagSlugs) &&
      _setEquals(other.countryCodes, countryCodes) &&
      other.dateRange == dateRange;

  @override
  int get hashCode => Object.hash(
    Object.hashAllUnordered(social),
    Object.hashAllUnordered(eventTypes),
    Object.hashAllUnordered(tagSlugs),
    Object.hashAllUnordered(countryCodes),
    dateRange,
  );
}

bool _setEquals<T>(Set<T> a, Set<T> b) =>
    a.length == b.length && a.containsAll(b);
