# EVENTS NEAR ME — PHASE N2 FINAL REPORT

Status: finalized, physical-device validated, committed, pushed. N2
takes N1's domain/distance foundation (`EVENTS_NEAR_ME_PHASE_N1_FINAL.md`
— no GPS, no permission surface, no visible UI) and makes it real: a
production `geolocator` adapter, an Events-specific Location UI, explicit
user-activated one-shot GPS acquisition, complete failure/recovery UX,
and full integration with the existing Events discovery pipeline.

## OBJECTIVE

Let a signed-in or signed-out Events user say "show me what's happening
near me" — resolved once, on explicit request, against a fixed 100 km
radius — without introducing any of the surface area a naive
implementation would reach for: no distance UI, no adjustable radius, no
map, no background tracking, no coordinate persistence.

## N2.1–N2.6 PROGRESSION

- **N2.1** — production location adapter: `geolocator` dependency added,
  `GeolocatorCurrentLocationProvider` (direct `Geolocator.*` calls),
  native permission config (`NSLocationWhenInUseUsageDescription`,
  `ACCESS_COARSE_LOCATION`). No production caller yet.
- **N2.2** — `GeolocatorGateway` seam introduced purely for
  determinism (`Geolocator`'s own methods are `static`, otherwise
  unsubstitutable); 18 provider unit tests added with zero real
  plugin/platform code.
- **N2.3** — Events-specific Location UI (`event_location_sheet.dart`,
  `event_location_control.dart`) wired into `EventsScreen`; explicit
  Near-me activation only; inline loading; successful state transition;
  Country ↔ Near-me replacement; `EventDiscoveryFilterService` gained
  the additive `nearMeLocation` parameter threading into the existing
  N1 `applyDiscoveryFilters`.
- **N2.4** — complete per-`CurrentLocationFailureType` recovery UX;
  `LocationSettingsOpener` seam + `Open Settings`/`Open Location
  Settings` actions.
- **N2.5** — first service-level integration tests for
  `EventDiscoveryFilterService.loadFilteredDiscovery` itself (hand-rolled
  fake repositories), directly protecting the N2.3 early-return
  regression fix and proving Near me composes with Search/Date/Theme/
  Social/Country/All-locations through the real service boundary, not
  just the pure filter function.
- **N2.6** — physical-device validation on a real iPhone.

## HUMAN APPROVAL

N2.1–N2.5 were reviewed and approved incrementally as each phase's own
automated evidence (diff audits, targeted/full test runs, `flutter
analyze`) was produced. **N2.6 physical-device validation result:
PASS — the human tester reported no functional or visual defects**
after installing the release build on a physical iPhone ("kylan", iOS
26.6) and exercising the Events Near Me flow. This is recorded as
**overall physical-device human validation**, not as a checklist of
individually-confirmed sub-cases — the tester's report did not itemize
per-scenario observations (e.g. exact Settings-page identity, exact
denial-dialog copy). Every specific behavioral claim in this document
(failure-type mapping, replacement semantics, composition, privacy) is
backed by **automated test evidence or direct source inspection**, cited
as such; the physical-device pass is cited separately and only for what
it actually establishes: the real build compiles, installs, launches,
and the implemented flow works end-to-end on real iOS without any
defect the tester noticed.

## FINAL ARCHITECTURE

```
Events-specific Location control/sheet
  (event_location_control.dart, event_location_sheet.dart)
        │  explicit "Near me" tap only
        ▼
CurrentLocationProvider (current_location_provider.dart)
        │  production implementation
        ▼
GeolocatorCurrentLocationProvider (geolocator_current_location_provider.dart)
  — via GeolocatorGateway seam (testability only)
        │
        ▼
GeoCoordinate → EventNearMeLocation → EventLocationContext.nearMe(...)
  (lib/models/*.dart)
        │
        ▼
EventDiscoveryFilterService.loadFilteredDiscovery(nearMeLocation: ...)
  (event_discovery_filter_service.dart)
        │
        ▼
applyDiscoveryFilters → eventQualifiesForNearMe
  (event_discovery_filtering.dart, event_near_me_filtering.dart — N1,
   the one canonical Haversine implementation, unchanged since N1)
```

`LocationSettingsOpener` (`location_settings_opener.dart`) is a
deliberately separate interface from `CurrentLocationProvider` —
Settings navigation is a UI-edge recovery action, not part of "resolve
my current location once." `GeolocatorCurrentLocationProvider` is the
one concrete class implementing both, sharing the same
`GeolocatorGateway`, but the two interfaces stay independently
injectable and independently reasoned about.

Country and Near me remain structurally mutually exclusive:
`EventLocationContext`'s base constructor asserts
`country == null || nearMe == null`; every mode transition constructs a
brand-new instance (no mutation API exists), so replacement is
deterministic by construction, in both directions.

Explore (`lib/features/explore/`, `lib/core/widgets/`) has **zero diff**
across the entire N2 workstream — reconfirmed at finalization via `git
diff --stat`. Near me exists only inside the Events-specific Location
sheet; the shared `CountryFilterControl`/`showCountryPickerSheet` never
learned Near me exists.

## PERMISSIONS

- **iOS**: `NSLocationWhenInUseUsageDescription` only (`ios/Runner/
  Info.plist`) — reconfirmed via `grep` at finalization, no Always/
  background key present.
- **Android**: `ACCESS_COARSE_LOCATION` only
  (`android/app/src/main/AndroidManifest.xml`) — reconfirmed via `grep`,
  no `ACCESS_FINE_LOCATION`, no `ACCESS_BACKGROUND_LOCATION`.
- `geolocator: ^14.0.3` (resolved `14.0.3` in `pubspec.lock`) is the only
  location-related dependency added across N2; no `permission_handler`,
  no `url_launcher`.
- `LocationAccuracy.low` is used for acquisition — sufficient margin
  under the 100 km radius, chosen specifically to minimize the accuracy
  (and therefore permission strength) requested.
- Location is requested **only** by an explicit "Near me" tap inside the
  Location sheet — never at app launch, Events-screen open, Location-
  sheet open, Country selection, or any other filter change. Proven by
  dedicated widget tests asserting the fake provider's call count stays
  `0` through every one of those paths.

## FAILURE STATES

| `CurrentLocationFailureType` | Copy | Action |
|---|---|---|
| `permissionDenied` | "Location access is needed to show Events near you." | **Try again** → re-calls `getCurrentLocation()` |
| `permissionDeniedForever` | "Location access is turned off for Chasing Stars. Enable it in Settings to use Near me." | **Open Settings** → `LocationSettingsOpener.openAppSettings()` |
| `servicesDisabled` | "Location Services are turned off. Turn them on to use Near me." | **Open Location Settings** → `LocationSettingsOpener.openLocationSettings()` |
| `unavailable` | "We couldn't determine your current location." | **Try again** |

A failure never activates a partial Near-me state, never clears the
previously active valid Location context, and never leaves the sheet in
an inconsistent state — proven by dedicated widget tests including a
failure→different-failure transition (`permissionDenied` →
`permissionDeniedForever` mid-retry) and a failure→success recovery
case. A Settings-open attempt that itself fails (`openAppSettings`/
`openLocationSettings` returning `false`) shows one small restrained
line ("Couldn't open Settings.") — never a new domain failure type,
never a crash (both adapter methods wrap the platform call in try/catch
and cannot throw past their own boundary).

## PRIVACY GUARANTEES

Reconfirmed via source/diff search at finalization:

- No `toJson`/`fromJson` on `GeoCoordinate` or `EventNearMeLocation` —
  deliberately absent; a resolved coordinate lives in transient
  `EventsScreen` state only.
- Zero coordinate values ever passed to `print`/`debugPrint`/any logging
  call anywhere in `lib/`.
- Zero analytics calls anywhere in the Location sheet/control/adapter
  files — the one pre-existing `eventFilterApplied` analytics call still
  fires only for an explicit Country selection, exactly as before N2,
  never for Near Me.
- No reverse geocoding (`placemarkFromCoordinates`/`geocoding` — zero
  matches).
- No `getPositionStream`/`watchPosition` anywhere — `CurrentLocationProvider`
  has no `Stream`-returning method, so continuous/background tracking is
  unreachable through this API surface, not merely avoided by
  convention.
- No background location permission on either platform.
- No automatic location request at app startup, Events-screen open,
  Location-sheet open, or app resume.

## UI BEHAVIOR

Dark green + ivory, restrained — mirrors `EventDateControl`'s own visual
language rather than the legacy gold-accented `CountryFilterControl`
style. No gold anywhere in the new Location UI. No distance text ("km
away"), no radius selector, no nearest-first ordering, no map view, no
oversized GPS iconography — all reconfirmed via repository-wide grep at
finalization (zero matches for any of these patterns in `lib/`). Near me
is presented as one location option among others ("All locations", a
searchable Country list), not a separate filter category, matching the
task's own original mental model.

## FILTERING INTEGRATION

Near me composes with Search, Date, Theme, and Social exactly like
Country always has — proven at both the pure level (N1's
`event_near_me_filtering_test.dart`) and, as of N2.5, at the real
`EventDiscoveryFilterService` boundary with hand-rolled fake
repositories (`event_discovery_filter_service_test.dart`). NULL-
coordinate Events are excluded, never given a proxy location. Cross-
border inclusion is purely geometric — `eventQualifiesForNearMe` never
reads `Event.countryCode`. The 100 km boundary is inclusive
(`distance == radius` qualifies), proven by N1's own boundary test and
unaltered by every layer Near me now passes through. Near me determines
**inclusion only** — it never sorts, never ranks, never displays a
distance, and the fixed radius is not user-adjustable anywhere in the
codebase.

## AUTOMATED TEST EVIDENCE

- `dart format --set-exit-if-changed .` — 428 files, 0 changed.
- `flutter analyze` — No issues found.
- `flutter test` — **1717 passed, 0 failed** (from N1's 1663-test
  baseline: +18 N2.2 provider tests, +11 N2.3 Location-control tests,
  +13 N2.4 settings/recovery tests [4 adapter + 9 widget], +12 N2.5
  service-integration tests).
- Migration check: `supabase migration list` — 40/40 local↔remote
  matched. `supabase db push --dry-run` — `"Remote database is up to
  date."` Zero schema changes, zero RLS changes across all of N2.

## PHYSICAL-DEVICE EVIDENCE

- Device: user's iPhone, device name **"kylan"**.
- iOS version: **26.6**.
- Release build (`flutter run -d <device> --release`): compiled
  successfully (Xcode build, ~74s), installed, and launched
  successfully on the physical device.
- Human tester subsequently exercised the Events Near Me flow on-device
  and reported: **no functional or visual defects observed.**
- No more granular per-scenario physical observations were recorded by
  the tester beyond this overall pass — individual behaviors listed
  elsewhere in this document (exact failure copy, exact Settings
  destinations, replacement semantics, etc.) are evidenced by the
  automated test suite and direct source inspection, not by itemized
  physical-device notes.

## ANDROID STATUS

**Android physical-device validation was not performed** — no Android
SDK/emulator/device is available in this development environment.
Android status is: **configuration and automated/source validation
complete; physical-device validation pending.** Confirmed present and
unchanged: `ACCESS_COARSE_LOCATION` only, `ACCESS_FINE_LOCATION` absent,
`ACCESS_BACKGROUND_LOCATION` absent. This should not be represented as
Android having been physically tested.

## EXPLICIT NON-GOALS (confirmed still absent)

Radius selector or any user-adjustable radius; distance badges/labels;
nearest-first or any distance-based ordering; map view; reverse
geocoding or city inference; an automatic "Near me" startup mode;
coordinate persistence of any kind; background or continuous location
tracking of any kind.

## FINAL ACCEPTANCE

All automated validation green, all N2-scoped source/privacy/permission
audits clean, Explore unaffected, exactly one canonical Haversine
implementation, and physical-device human validation passed with no
reported defects. Phase N2 (Events Near Me) is finalized.

## FILES

See the chat final-answers report (`EVENTS NEAR ME — PHASE N2 FINAL
REPORT`) for the exact committed file list, commit hash, message, and
push confirmation recorded at finalization time.

## UNRELATED EXCLUSIONS

Present in the working tree as untracked but deliberately not staged,
not committed, not deleted, and not modified by any part of N2: `.claude/`,
several European/Gault&Millau/imagery-pilot research and enrichment
documents, everything under `supabase/data/enrichment/`.
