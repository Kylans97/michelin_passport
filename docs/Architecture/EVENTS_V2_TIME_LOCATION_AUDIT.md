# Events V2 — Time & Location Audit

**Status: read-only audit. No migration, no Dart change, no production write.** This document exists to answer two questions before international Events scale up and before Confirmed Attendance/Passport are built: can every Event be stored and rendered in its own correct local time, and can every Event have a correct physical location independent of any canonical host? Every finding below is evidence-based — checked directly against live production data, tracked migrations, and the actual Dart source, not assumed.

## 1. Current time model

### Database

`events.start_at`/`end_at` are `timestamptz`, `not null`, indexed (`events_start_at_idx`), with `events_dates_valid check (end_at >= start_at)`. **There is no `timezone` column, no IANA identifier stored anywhere on `events`, and no separate date-only/time-only representation.** A `timestamptz` in Postgres is an unambiguous absolute instant (stored internally as UTC) — this part is architecturally sound and needs no correction. What it structurally cannot do is tell you what the *local* wall-clock time was intended to be, or in which zone, once the value is retrieved — that identity exists only in whoever's head computed the offset at insert time.

### Dart

`Event.fromJson` (`lib/models/event.dart:146-147`):

```dart
startAt: DateTime.parse(json['start_at'] as String).toLocal(),
endAt: DateTime.parse(json['end_at'] as String).toLocal(),
```

**This is the single point of risk in the entire codebase.** `.toLocal()` converts the parsed UTC instant into the **device's own current timezone** — not the event's location. Every downstream consumer of `Event.startAt`/`Event.endAt` inherits this: `event_date_format.dart`'s `formatEventDateTime`/`formatEventDateRange` (used by `EventMetaSection` on Event Detail, `EventCard`, and `explore_event_result_tile.dart` — every rendering surface in the app) all read `.hour`/`.day`/`.month`/`.year` off the already-device-converted value. There is exactly one root cause, not several scattered bugs — a meaningful, favorable finding for how contained the fix is.

**Chronological logic is not affected by this.** `canAttendEvent` (`event_detail_screen.dart:46`, `!event.isCancelled && event.endAt.isAfter(now ?? DateTime.now())`) and every other `isAfter`/`compareTo` use in the events feature compares Dart `DateTime` instants — `.toLocal()`/`.toUtc()` re-tag which zone a `DateTime` reports its components in, but never change the underlying instant, so `isAfter`/`isBefore`/`compareTo` remain correct regardless of the tagging. **Display is broken; ordering is not.** This distinction matters throughout this document.

`EventsRepository.loadEvents` (`events_repository.dart:57,60`) calls `.toUtc()` on caller-supplied `from`/`to` bounds before querying — correct, since those bounds originate from `DateTime.now()` (device-local) and need converting to the same UTC basis `start_at`/`end_at` are stored in for the comparison to be meaningful.

### Imports/dependencies

`pubspec.yaml` has no `package:timezone` (or equivalent) dependency — only `intl` (transitive, not a direct dependency; `intl` provides locale-aware *formatting*, not IANA timezone-database conversion). **Dart's `dart:core` `DateTime` supports exactly two states — UTC and "whatever the OS reports as local" — there is no built-in way to ask for an instant's wall-clock representation in an arbitrary IANA zone like `Asia/Tokyo` without either a timezone-database package or server-side conversion.** Confirmed by direct `pubspec.yaml`/`pubspec.lock` inspection.

### Sorting/filtering

`EventDateFilter.resolve()` (`lib/features/events/models/event_date_filter.dart`) computes "upcoming/this week/this month" windows from `DateTime.now()` (device-local) and passes them to `EventsRepository.loadEvents`, which converts to UTC before querying. This is self-consistent for "what does the viewer mean by *this week*" and is not the same risk as the display bug — but see §6/§10 for the one place it can still produce a surprising result near a date boundary.

## 2. Timezone risk

**What currently works**: the underlying storage (`timestamptz`) and every chronological comparison (`isAfter`, sorting, filtering) are already correct and remain correct at any DST boundary or across any offset, because Dart/Postgres instant comparison never depends on which zone a value is *displayed* in.

**What fails internationally**: display. `Event.fromJson`'s `.toLocal()` means **the primary Event UI already silently translates every event into the viewer's current device timezone** — the exact violation of this task's own hard rule ("a gastronomic calendar, not a video-call calendar"). This has simply never been visible in production yet because all 4 live events and (presumably) every developer/tester to date have been in the same timezone as the events themselves (Europe/Amsterdam). It will surface the first time a non-Netherlands-timezone viewer opens any event, or the first time a non-Netherlands event is entered.

**DST implications**: none for chronological correctness (the stored instant is DST-agnostic by construction). Real implication for *data entry*: see §4 — DST-awareness today lives entirely in a human's head at insert time, not in any tool or constraint.

**Viewer-location behavior, confirmed precisely**: a Tokyo event stored correctly as `2026-10-12T10:00:00Z` (19:00 JST) will render as `19:00` only to a viewer whose device happens to be set to `Asia/Tokyo`. A viewer in Amsterdam sees `12:00`; a viewer in New York sees `06:00` (previous calendar day, in EDT). None of these are the event's own time — every one of them is silently wrong today, per this task's own product rule.

## 3. Recommended time model

**Recommendation: `timestamptz` (unchanged) + one new `timezone text` column, IANA identifier.** This is Option A from the brief, and it is deliberately the smallest change, not a default — the reasoning below is why the other two options add risk without adding correctness this system doesn't already get from A.

- **Unambiguous real instant** — already satisfied, unchanged (`start_at`/`end_at` stay exactly as they are; zero risk to existing indexing, sorting, or the 4 live rows).
- **Timezone identity** — the one genuine gap; filled by the new column.
- **DST correctness** — inherited for free from Postgres's own bundled IANA tzdata (`AT TIME ZONE 'Europe/Amsterdam'` already correctly handles every historical and future DST transition for that zone; no hand-maintained offset table).
- **Original local wall-clock time, "preserved"** — this is the one requirement that sounds like it needs a *third*, independently-stored field (Option C). It doesn't: given a *correct* `(instant, IANA zone)` pair, `AT TIME ZONE` reconstruction is exact and lossless — this is precisely what every real calendar system (Google Calendar, IANA tzdata itself) relies on. A separately-stored literal local-time string would duplicate a value that's already deterministically reconstructable, and duplication is itself a drift risk (the two could be edited independently and fall out of sync) — worse for correctness, not better. **The real vulnerability isn't the storage shape, it's the write-time process** (§4/§27): today a human computes and hand-types a raw UTC offset (`+02`) with nothing checking it against the actual zone or date. That's a process fix, not a schema fix, and no amount of extra columns solves it by itself.

**Concretely, `Tokyo 2026-10-10 19:00 Asia/Tokyo` is stored and reconstructed as**: `start_at = '2026-10-10T10:00:00Z'` (the UTC instant, computed once, correctly, from local time + zone — ideally via a real timezone library rather than hand arithmetic, see §28), `timezone = 'Asia/Tokyo'`. Display always does `start_at AT TIME ZONE timezone` (server-side) or the Dart/web equivalent (client-side, if a timezone package is added) to get back `2026-10-10 19:00` — never `.toLocal()`.

## 4. Current location model

`events.venue_name`/`address`/`city`/`country_code`/`latitude`/`longitude` are all plain columns on `events` itself — `venue_name` and `city` nullable-but-populated in practice, `address`/`latitude`/`longitude` nullable and, in every one of the 4 live rows, either null or (for `address`) populated only once. None of these are ever resolved via a join to `event_restaurants`/`restaurants_full` at read time anywhere in the Dart code (`EventsRepository.loadEventById`/`loadEvents` select from `events` directly, no venue join for location fields) — **the schema already snapshots location independently of any canonical link; it does not dynamically resolve it.** This is confirmed by code inspection, not assumed.

`is_host`/`is_venue` (Events V2 Step 1) exist on `event_restaurants`/`event_hotels`/`event_chefs`, correctly modeling HOST ≠ VENUE ≠ PARTICIPANT as three independent facts. In production today: exactly one participant row exists (Tout à Fait ↔ 't Preuvenemint, `is_host=false, is_venue=false` — correctly a plain participant), and zero rows anywhere have `is_host=true` or `is_venue=true`. The host/venue distinction is architecturally sound but **has never been exercised by real data** — worth flagging as an untested-in-production gap, separate from the schema being correct.

## 5. Recommended location model

**No schema change needed.** The existing pattern — free `venue_name`/`address`/`city`/`country_code`/`latitude`/`longitude` columns on `events`, populated once at event-creation time, never re-derived — is already "Option B: snapshot Event location fields at publication time" from the brief's own comparison. This already correctly guarantees historical integrity: a 2028 address change on Parkheuvel can never retroactively alter a 2026 Event's stored location, because nothing reads through the join for display. **This needs to become an explicit, written convention, not just an accidental property of the current code**: *even when an event links a canonical `is_venue=true` entity, `events.venue_name`/`address`/`latitude`/`longitude` must still be independently populated at creation time from that entity's then-current address* — never left null with an implicit "resolve it from the venue later" assumption, which would silently reintroduce the dynamic-resolution risk this design otherwise avoids by construction.

**Host vs. venue, restated precisely for this audit**: never infer venue from host, or host from venue. Case A (Parkheuvel hosts at Parkheuvel) — one `event_restaurants` row, `is_host=true, is_venue=true`. Case B (Parkheuvel hosts off-site) — `is_host=true, is_venue=false`, and `events.venue_*` describes the actual off-site location independently. Case D (Preuvenemint) — `events.external_host_name` (if ever populated) for the organizer, `events.venue_name='Vrijthof'` for the location, with no canonical entity satisfying either role. All six reference cases in the brief (§13) resolve cleanly against the existing `is_host`/`is_venue` model with zero schema change — confirmed by re-checking each against the live column set.

## 6. Production events — data quality matrix

| Event | Start (UTC stored) | End (UTC stored) | Local time (Europe/Amsterdam, derived) | Timezone stored? | Venue name | Address | City | Country | Coordinates | Canonical venue link? | Data confidence |
|---|---|---|---|---|---|---|---|---|---|---|---|
| 't Preuvenemint | 2026-08-27T16:00Z | 2026-08-30T22:00Z | 18:00 → 00:00 (next day) CEST | No | Vrijthof | Vrijthof 25, 6211 LE Maastricht, NL | Maastricht | NL | None | No (external, correctly so — Vrijthof isn't a restaurant/hotel) | High — address verified, times match the official site's stated opening hours exactly |
| Erloom x Henrique Sá Pessoa | 2026-09-25T10:00Z | 2026-09-27T21:00Z | 12:00 → 23:00 CEST | No | Erloom (bio-boerderij 't Schop) | None | Hilvarenbeek | NL | None | No | Medium — a 3-day residency window, not one specific service's exact start/end; venue not in catalogue |
| Vergeet Mij Niet Gala | 2026-10-06T16:00Z | 2026-10-06T21:59Z | 18:00 → 23:59 CEST | No | Hotel Okura Amsterdam (Grand Ballroom) | None | Amsterdam | NL | None | No (Hotel Okura not linked as a canonical `event_hotels` row despite being a real, likely-catalogued hotel — a genuine enrichment gap, not a schema one) | Medium — plausible gala timing, address not independently recorded |
| Wildfestival | 2026-09-13T11:00Z | 2026-09-13T15:00Z | 13:00 → 17:00 CEST | No | Hotel Gastronomique De Echoput | None | Apeldoorn | NL | None | No | High — times, price and description directly sourced; address deliberately left null (not independently confirmed, per the enrichment record's own note) |

All four independently back-calculate to sensible Europe/Amsterdam local times (verified by hand against the UTC values above) — the *data* is currently correct for all four, entirely because a human got the `+02` offset right four times in a row, with nothing in the system that would have caught it if they hadn't.

## 7. Reference cases

**Preuvenemint (§23 of the brief)** — currently one broad `start_at`/`end_at` window spanning the full multi-day festival (Thursday 18:00 → Sunday 24:00), not per-day sessions. This is sufficient for MVP: the festival's own admission is "mixed" (free general entry, one ticketed sub-event), and nothing in the current product (Event Detail, Trip matching) needs finer granularity than "the festival is running during these days." Individual daily/session-level times (e.g. a specific vendor's serving hours) are real future complexity — not required now, and building it now would be solving a problem no current screen has.

**Club Leroy at Parkheuvel** — conceptual record only, no data inserted, unknowns marked as such per this task's explicit instruction (no web research performed to fill gaps):

```
name:              Club Leroy at Parkheuvel
date:              2026-09-20 (known)
start/end time:    UNKNOWN — only a date was ever provided, no time-of-day
timezone:          Europe/Amsterdam (high-confidence inference — Rotterdam, NL,
                    single national zone; not independently verified against
                    an official source)
host:               external_host_name = "Club Leroy" (Erik van Loo's presenting
                    brand — not a canonical Chasing Stars entity)
venue:              event_restaurants row, Parkheuvel, is_venue=true, is_host=false
location snapshot:  venue_name="Parkheuvel", address/city/country/lat/lng =
                    UNKNOWN in this audit (would be populated from Parkheuvel's
                    own then-current address at real event-creation time,
                    per §5's convention)
admission:          paid, €249 per person (known)
ticketing:          UNKNOWN — booking channel referenced as "official Parkheuvel
                    source" but no URL captured here
recognition:        Parkheuvel's own MICHELIN 2-star recognition — read live off
                    Restaurant.michelinStars at display time (AtThisEventSection),
                    never copied onto the event row
```

**Lucas de Jager — external-venue reference (§25 of the brief)** — conceptual only:

```
host:        event_chefs row, Lucas de Jager, is_host=true, is_venue=false
venue:       NOT canonical — an external Tuscany location
timezone:    Europe/Rome (Tuscany) — independent of Lucas's own home_city
             (Breda, NL) and independent of his employer-restaurant history;
             confirms events.venue_* must never be derived from a host
             entity's own location fields, which don't exist for exactly
             this reason (Private Chefs audit, earlier this project)
location:    address/coordinates independently populated at event-creation
             time — never inferred from Lucas's private_chefs.home_city
Passport pin (future): the event's own lat/lng, not Lucas's home_city — already
             the documented rule (EVENTS_V2_ARCHITECTURE.md §12)
```

Both cases validate cleanly against the existing host/venue model — no schema gap surfaced by either.

## 8. Attendance / Passport implication (not built — dependency documented only)

The future "did you make it?" trigger must fire off `event.endAt.isAfter(now)` — an **instant** comparison, exactly what `canAttendEvent` already does today, and exactly the part of this system already confirmed correct regardless of timezone. **The dependency for the future Attendance step is narrow and already satisfiable**: as long as that step continues to compare instants (never re-derives "has this event ended" from a `.toLocal()`-tagged value's hour-of-day), a European viewer of a Tokyo event will be prompted at the objectively correct moment, never based on a misinterpreted viewer timezone. This is a caution to carry into that step's own implementation, not a blocker today.

## 9. Trips implication

`eventMatchesTrip` (`lib/models/event_trip_match.dart`) truncates both sides to calendar dates before comparing overlap — its own doc comment already states plainly that `event.startAt`/`endAt` are "already converted to device-local time... via `.toLocal()`." **This is a real, if narrow, edge case**: near a date boundary, a large enough offset between the event's own zone and the *viewer's device* zone can shift which calendar date the truncated comparison lands on, potentially excluding or misplacing an event that should match a trip (or the reverse). Example: a Tokyo event at 08:00 JST on Oct 12 is `2026-10-11T23:00Z`; a device set to `America/Los_Angeles` (UTC-7/8) would `.toLocal()` that to Oct 11 — one calendar day earlier than the event's own Tokyo date. **Recommendation for a future fix (not implemented here)**: once `events.timezone` exists, trip matching should compare using the event's *own* local calendar date (`start_at AT TIME ZONE timezone`), never the viewer's device zone — a small, contained change once the schema gap in §3 is closed.

## 10. Web readiness

Evaluated conceptually only — no web build performed.

| Requirement | Status |
|---|---|
| Stable Event ID | Yes — `uuid`, already the canonical identifier everywhere |
| Slug | **Missing** — no column, no uniqueness/collision policy exists. Not urgent (§20) |
| Public publication state | Yes — `moderation_status='published'` gate (Events V2 Step 1), already correct |
| Shareable URL readiness | Blocked only by the missing slug; everything else needed (stable id, public gate) exists |
| Event-local timezone | **Missing** — this audit's central finding (§1-3) |
| Physical location | Present but incomplete data (§6) — schema is sound |
| Canonical hosts | Present (`is_host`/`is_venue`, Step 1) |
| Media | `image_url` exists, unused in all 4 live rows |
| Ticket URL / source URL | Present (`ticket_url`, `official_url`) |
| Meta title/description potential | `name`/`description` already sufficient raw material |
| schema.org `Event` readiness | See below |

**schema.org `Event` — conceptual mapping only, no external research performed**: `name`→`name`, `startDate`/`endDate`→`start_at`/`end_at` (once timezone-aware, these map directly to schema.org's own ISO-8601-with-offset expectation), `eventStatus`→`status`, `location`→`venue_name`/`address`/`lat`/`lng` (already sufficient shape, just needs the coordinate/address data completed), `offers`→`ticket_url`/`admission_type`/`admission_note` (loosely — schema.org's `Offer` wants a structured price, which `admission_note`'s free text doesn't provide; not a blocker, a future refinement), `image`→`image_url`, `organizer`→`external_host_name`/canonical host resolution, `description`→`description`, `url`→ blocked on the missing slug. **No genuinely missing canonical information beyond timezone, location completeness, and slug** — schema.org readiness is a consequence of the same three gaps already identified, not a fourth one.

## 11. Migration decision

**YES — before large-scale international Event enrichment.** Scope: **timezone only.**

```
alter table public.events add column timezone text;
-- backfill (see §12) before tightening to NOT NULL
alter table public.events alter column timezone set not null;
alter table public.events add constraint events_timezone_valid
  check (timezone is not null and length(timezone) > 0);
```

Plus a validation trigger (not a CHECK, since validating an IANA identifier against Postgres's real tzdata requires attempting a conversion, which a CHECK constraint's expression can still do): `before insert or update on events for each row execute function validate_event_timezone()`, where that function performs `perform now() at time zone new.timezone;` inside an exception handler — Postgres raises a real error for an invalid zone name, which is a stronger guarantee than any regex could give, and reuses Postgres's own bundled, kept-current IANA database rather than trusting a hand-maintained list.

**Columns**: one — `timezone text`. **Nullable rule**: nullable during backfill, `not null` once all 4 existing rows are classified (§12). **Constraint**: the tzdata-validating trigger above. **Index**: none needed — `timezone` is never itself a filter/sort key. **Backfill**: all 4 rows → `'Europe/Amsterdam'` (§12). **RLS impact**: none — `events_public_read` already gates on `moderation_status`, unrelated to this column; no new policy needed. **Existing Event impact**: zero rows change meaning — the 4 events' already-correct `start_at`/`end_at` values are untouched; only a new, currently-implicit fact becomes explicit and queryable.

**Explicitly not bundled into this migration, per the brief's own "don't combine unrelated features" instruction**: location-snapshot fields (§5 — no schema gap exists, this is a data/process fix); slug (§10/§20 — a web-readiness concern with no urgency tied to international enrichment or Attendance/Passport).

## 12. Backfill strategy

| Classification | Meaning |
|---|---|
| `VERIFIED_TIMEZONE` | The original source explicitly stated a timezone/local-time convention, independently re-confirmed |
| `SAFE_LOCATION_DERIVATION` | `country_code` unambiguously maps to a single national IANA zone, with no city-level ambiguity |
| `MANUAL_REVIEW` | Country spans multiple zones, or city-level disambiguation is required |
| `UNKNOWN` | Insufficient information to assign any zone with confidence |

**All 4 current events → `SAFE_LOCATION_DERIVATION` → `Europe/Amsterdam`.** The Netherlands has exactly one IANA zone nationwide (no internal variation, unlike e.g. the US or Spain's Canary Islands), so `country_code='NL'` alone is sufficient for high-confidence derivation — further corroborated by this audit's own back-calculation confirming all 4 stored UTC values are internally consistent with correct CEST (`+02`) conversion for their actual dates. None reach `VERIFIED_TIMEZONE` in this pass specifically because that tier is reserved for an explicit source statement independently re-confirmed, which this read-only audit didn't re-fetch (per the brief's own "do not web-research unless explicitly required" instruction) — not because confidence is actually low.

## 13. Timezone package / platform decision

**Dart alone cannot correctly convert an instant into an arbitrary IANA zone's wall-clock time** — confirmed by `pubspec.yaml` inspection (no `package:timezone`, `intl` is formatting-only) and by `dart:core`'s own documented UTC/local-only `DateTime` model. Two ways to close this gap, not mutually exclusive:

1. **Client-side**: add `package:timezone` (the standard Dart IANA-timezone package, ships/updates real tzdata) and convert `start_at` + `timezone` into a `TZDateTime` for display. Works offline; needs periodic tzdata updates as a dependency-version concern.
2. **Server-side**: have Postgres do the conversion (`start_at AT TIME ZONE timezone`) and either expose an already-local-formatted value via `restaurants_full`-style view columns, or simply ship `timezone` to the client and let a thin client-side formatter combine it with the instant.

**Recommendation, given the explicit web-readiness requirement**: prefer computing the authoritative local representation **server-side** (option 2) as the primary path — Postgres's IANA support is already correct and already there, and this produces one conversion result usable identically by Flutter, a future web app, and any future external API partner, rather than duplicating timezone-conversion logic in two client codebases (Flutter now, a web client later). A client-side package remains reasonable as a secondary/offline convenience later, but is not required to close this audit's core gap. **No package is installed in this task**, per explicit instruction.

## 14. Web/API representation

Recommend the same shape the brief itself sketches, since it already matches how this codebase's own `restaurants_full`/`hotels_full` pattern already separates raw canonical data from resolved display fields:

```
start_at:  2026-10-10T10:00:00Z    (the stored instant, unambiguous)
timezone:  Asia/Tokyo               (the IANA identifier)
```

Every consumer — Flutter, a future webapp, a future public website, a future external/API partner — derives the display value identically: `start_at` converted into `timezone`. No consumer should ever derive display time from its own ambient/device zone. This is the same representation regardless of platform, which is exactly the "platform-neutral" requirement Events V2 Step 3 already established for its own analytics taxonomy — this audit extends the same principle to time.

## 15. Confirmed: no implementation occurred

Migrations: **0**. Schema changes: **0**. Production writes: **0**. Dart changes: **0**. No package installed. This document is the entire deliverable.
