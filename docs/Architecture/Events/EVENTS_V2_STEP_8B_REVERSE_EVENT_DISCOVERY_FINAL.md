# EVENTS V2 STEP 8B — REVERSE EVENT DISCOVERY FINAL

Physical-device-approved final record of Step 8B: Restaurant/Hotel/
Private Chef Detail pages show Events the viewed entity genuinely HOSTS
(`is_host = true`). Supersedes nothing in the audit
(`EVENTS_V2_STEP_8B_REVERSE_EVENT_DISCOVERY_AUDIT.md`) or the pre-final
report (`EVENTS_V2_STEP_8B_REVERSE_EVENT_DISCOVERY_PRE_FINAL.md`) — both
remain the historical record of how this was designed and implemented;
this document is the closing summary once human approval was recorded.

## PHYSICAL DEVICE APPROVAL

Confirmed on real device, real production data: Restaurant Flore shows
the EVENTS section; the real date-only pilot ("4 Hands Dinner: Bas van
Kranen x Sang Hoon Degeimbre") appears correctly; date displays with no
fabricated time; the compact row renders correctly; tap opens the
existing Event Detail; back navigation returns correctly to Flore;
Follow and Wishlist remain functional; L'air du temps correctly shows no
EVENTS section; restaurants without a hosted Event show no empty
section; overall Restaurant Detail layout is unaffected. Hotel and
Private Chef are approved through automated coverage — neither has a
production host relationship to verify physically against.

## FINAL REPOSITORY ARCHITECTURE

`EventsRepository.loadHostedEventsForRestaurant`/`...ForHotel`/
`...ForChef`, each delegating to a shared private `_loadHostedEvents`:
exactly 2 queries (relationship-id fetch filtered to `is_host = true`,
then one batched `events` fetch), no N+1, no SECURITY DEFINER, existing
RLS respected unmodified (`event_restaurants`/`event_hotels`/
`event_chefs` are openly readable; `events` itself enforces
`moderation_status = 'published'` on the second query). The standalone
pure function `upcomingHostedEvents` filters to non-cancelled,
not-yet-ended Events (`eventHasEnded`, never `end_at > now`) and sorts
via `compareEventChronology`.

## FINAL HOST SEMANTICS

The query filters on `is_host = true` alone — `is_venue` is never
referenced by the filter, so: `is_host=true, is_venue=true` → included;
`is_host=true, is_venue=false` → included; `is_host=false, is_venue=true`
→ excluded; `is_host=false, is_venue=false` → excluded. Re-verified
directly against live production data immediately before finalization.

## DATE-ONLY PROOF

The real Flore pilot (`start_date=end_date=2026-10-19`, `start_time=
end_time=start_at=end_at=NULL`, `timezone='Europe/Amsterdam'`) round-trips
through the exact production query end to end and displays `19 Oct 2026`
with no fabricated time — confirmed by automated test, live production
query, and physical device.

## REAL FLORE POSITIVE CASE

Re-confirmed immediately before finalization: `event_restaurants` for
Flore (`d656c75f-9354-4f57-b133-b5ce03b913a7`) is still exactly one row,
`is_host=true, is_venue=true`, pointing at the pilot Event — unchanged
since implementation.

## L'AIR DU TEMPS NEGATIVE CASE

Re-confirmed: `is_host=false, is_venue=false`, unchanged. Correctly
excluded from Flore's own hosted-Events query and from its own Detail
page.

## GALA NEGATIVE CASES

Re-confirmed: all 6 Vergeet Mij Niet Gala participants (Ciel Bleu, De
Bokkedoorns, De Librije, De Treeswijkhoeve, Inter Scaldes, Restaurant
Smink) remain `is_host=false, is_venue=false`, unchanged — none
accidentally gained a hosted EVENTS section.

## HOTEL / CHEF AUTOMATED-ONLY APPROVAL

Production has zero `event_hotels`/`event_chefs` rows. Both paths share
the identical `_loadHostedEvents` implementation Restaurant uses (no
per-table branch exists to diverge), and are covered by
`test/hosted_events_domain_test.dart`'s table-agnostic pure-function
tests. No production fixtures were created for either — approved via
automated coverage only, exactly as scoped.

## FINAL VALIDATION

`dart format --set-exit-if-changed .`: clean. `flutter analyze`: no
issues. `flutter test`: **1492 passed, 0 failed**. `supabase migration
list --linked`: 39/39 synced. `supabase db push --linked --dry-run`:
"Remote database is up to date." Production row counts confirmed
unchanged immediately before finalization: `events`=5,
`event_restaurants`=9, `event_hotels`=0, `event_chefs`=0.

## FINAL GIT

Commit hash and message recorded in the chat final report accompanying
this document's publication (this file is written just before staging,
so the hash isn't yet known at write time — see the final report for
the exact committed hash).
