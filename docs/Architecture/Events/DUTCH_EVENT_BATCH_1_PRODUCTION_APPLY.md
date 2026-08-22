# DUTCH EVENT ENRICHMENT — BATCH 1 PRODUCTION APPLY

Physical-data record of the approved Dutch Batch 1 production apply.
Authoritative plan: `DUTCH_EVENT_BATCH_1_PRE_APPLY.md`. All 8 approved
Events were inserted exactly as specified there, with zero
substitutions.

## PRE-WRITE PRODUCTION STATE

Re-read live immediately before writing: `events` count = 5 pre-
existing European candidates were already accounted for in the prior
apply — total pre-write count was **9**. None of the 8 approved Dutch
Event names existed yet (zero matches). All 8 canonical restaurant
UUIDs and the 1 canonical hotel UUID (Van Oys Maastricht Retreat)
re-resolved to their expected names, unchanged. `event_restaurants` =
11, `event_hotels` = 1, `event_chefs` = 0 (pre-write baselines). 39/39
migrations `local == remote`; dry-run reported "Remote database is up
to date." No discrepancy found.

## DÎNER DANSANT URL SAFETY CHECK

Re-checked immediately before writing, via a direct fetch of
`https://www.vanoys.com/event-calendar/diner-dansant/`: the page's
"Reserve your table" button still points to
`https://www.sevenrooms.com/events/thegrandsundaybrunchlatabledudimanche`
— confirmed still misrouted to an unrelated brunch event, unchanged
since the pre-apply pass. Per the pre-apply report's own already-
authorized safety fallback, the broken deep link was **not** stored —
`ticket_url` was set to the event's own official page
(`https://www.vanoys.com/event-calendar/diner-dansant/`) and
`availability_status` was set to `unknown`. This exactly matches the
pre-apply report's own SQL; no deviation occurred.

## EXACT 8 EVENTS APPLIED

| Event | UUID | Date | Precision |
|---|---|---|---|
| 4 Hands Dinner: Bas van Kranen x Sebastian Frank | `b7e5b3f7-f39b-4dfe-823d-d470d93094cd` | 2026-11-09 | DATE_ONLY |
| VanOost Sundays: 4 Hands Lunch — Sören Herzig | `12dea83b-799c-4908-afc8-92de5cd96d5f` | 2026-09-06 | DATE_ONLY |
| Game Brunch | `2a76f968-d2cb-45dd-964f-1176b4b52cbd` | 2026-10-18 | FULL_TIME |
| Dîner Dansant | `de0a1aee-c35c-46e6-8179-ebc83399c027` | 2026-12-24 | FULL_TIME |
| Chefs & Sommeliers Party | `60271509-2de7-4c28-ae5f-eadd0a30aeec` | 2026-08-31 | FULL_TIME |
| Winemakers Lunch — South Africa | `bb917cbc-434f-4545-be81-99164ac7ec1f` | 2026-09-12 | DATE_ONLY |
| Four Hands Dinner: Merlet x Restaurant Joann | `226646cf-6d82-4320-bfc8-e93d9298b334` | 2026-11-22 | START_KNOWN_END_UNKNOWN |
| Six Hands Dinner: Drie chefs, drie continenten, één avond | `7d9db50e-b7d5-497d-8399-0a9fbacee9b0` | 2026-09-24 | DATE_ONLY |

All 8 re-read post-write, field-by-field, matching §15 of the pre-apply
report exactly (title, event_type, description, dates, times, instants,
timezone, venue, address, city, country, coordinates, admission,
official_url, ticket_url, external_host_name, image_url, status,
moderation_status, availability_status).

## RELATIONSHIP ROWS INSERTED

**event_restaurants (10)**:
- Flore → HOST+VENUE (4 Hands Dinner: Bas van Kranen x Sebastian Frank)
- Inter Scaldes → HOST+VENUE, Bij Jef/Zarzo/Parkheuvel/Zilte → PARTICIPANT (Chefs & Sommeliers Party, 5 rows)
- Merlet → HOST+VENUE (Winemakers Lunch — South Africa)
- Merlet → HOST+VENUE, Joann → PARTICIPANT (Four Hands: Merlet x Joann, 2 rows)
- Bij Jef → HOST+VENUE (Six Hands Dinner)

**event_hotels (2)**:
- Van Oys Maastricht Retreat → HOST+VENUE (Game Brunch)
- Van Oys Maastricht Retreat → HOST+VENUE (Dîner Dansant)

**event_chefs**: 0 (none approved, none created).

VanOost (VanOost x Sören Herzig) has **zero** relationship rows —
confirmed by direct query, not merely assumed — recorded exclusively
via `external_host_name = 'VanOost'` / `external_host_url`.

## HOST-SEMANTICS VERIFICATION

Re-read every new relationship row directly post-write:

- **Bij Jef's dual role, confirmed correct**: `is_host=true,
  is_venue=true` on its own Six Hands Dinner; `is_host=false,
  is_venue=false` on Chefs & Sommeliers Party. Same restaurant, two
  different roles, both stored correctly.
- Inter Scaldes, Merlet (both its Events), Flore, Van Oys Maastricht
  Retreat (both its Events): all `is_host=true, is_venue=true` for
  their own Events.
- Zarzo, Parkheuvel, Zilte, Joann: all `is_host=false, is_venue=false`
  — participant-only, as approved.
- No participant was promoted into a host anywhere.

## TIME-PRECISION VERIFICATION

Searched all 8 new rows for fabricated `00:00`/`23:59`/other invented
precision: **Chefs & Sommeliers Party** and **Dîner Dansant** both
genuinely have a sourced `00:00` end time (the actual, confirmed close
of each event, crossing into the next calendar date) — these are
legitimate sourced values, not fabricated. No other candidate has any
time value that wasn't explicitly approved. Flore, VanOost, Winemakers
Lunch, and Six Hands Dinner all have `start_time`/`end_time`/
`start_at`/`end_at` = NULL exactly as approved (DATE_ONLY). Merlet x
Joann has `start_time='12:30:00'`, `end_time=NULL` exactly as approved
(START_KNOWN_END_UNKNOWN).

## EXISTING-DATA INTEGRITY

Re-read all 9 pre-existing Events post-write: 't Preuvenemint,
Wildfestival, Forces of Nature, Erloom x Henrique Sá Pessoa, Four
Hands Dinner: Marchal x Seafood Gastro, Vergeet Mij Niet Gala, 4 Hands
Dinner: Bas van Kranen x Sang Hoon Degeimbre, Douro to Table — Dinner
III, SHEf's Kitchen Party — every name/date/status/venue identical to
the pre-write baseline. `event_confirmed_attendance` = 0, unchanged.
`event_attendance` unchanged. `planned_trips`, `visits`, `photos`
untouched by this transaction (the SQL never referenced any of those
tables).

## COUNT DELTAS

```
events                +8   (9 → 17)
event_restaurants    +10   (11 → 21)
event_hotels           +2   (1 → 3)
event_chefs             0   (0 → 0)
event_confirmed_attendance  0 (unchanged)
```

All deltas match the approved pre-apply plan exactly.

## DUPLICATE VERIFICATION (POST-APPLY)

Each of the 8 approved Events exists exactly once — confirmed via
direct re-query, no title/date collisions, no URL collisions.

## STEP 8A / 8B / 8C SAFETY

**Step 8A**: resulting inventory = 17, comfortably below the
~50-concurrently-displayed batching threshold. No optimization
triggered.
**Step 8B**: Flore, Van Oys Maastricht Retreat, Inter Scaldes, Merlet,
and Bij Jef each have a genuine `is_host=true` relationship and will
correctly surface their new Event(s) under Reverse Hosted-Event
Discovery. Zarzo, Parkheuvel, Zilte, and Joann have zero `is_host=true`
rows from this batch and will correctly show nothing new. VanOost has
no relationship row at all and cannot participate in Step 8B.
**Step 8C**: `event_confirmed_attendance` remains 0 — none of the 8
new Events can appear in any user's Passport. No attendance fixture
was created.

## VALIDATION

`dart format --set-exit-if-changed .`: clean, 0 changed. `flutter
analyze`: no issues. `flutter test`: **1506 passed, 0 failed** —
baseline unchanged, no Dart code was touched. `supabase migration list
--linked`: 39/39 synced. `supabase db push --linked --dry-run`: "Remote
database is up to date." `git status --short`: no new untracked files
from this task (this report itself will appear once written). `git
diff` / `git diff --cached`: both empty.

## PHYSICAL-DEVICE CHECKLIST

1. Events screen shows all 17 Events (9 pre-existing + 8 new),
   chronologically ordered — earliest new entry: Chefs & Sommeliers
   Party (Aug 31); latest: Dîner Dansant (Dec 24).
2. Ordering/date display looks correct across the full list.
3. DATE_ONLY Events (Flore x Sebastian Frank, VanOost x Herzig,
   Winemakers Lunch, Six Hands Dinner) show a bare date only — no
   fabricated time anywhere.
4. Known-time Events show only genuinely sourced precision: Game
   Brunch (12:00–15:00), Chefs & Sommeliers Party (18:00–00:00,
   crossing into Sept 1), Dîner Dansant (19:00 Dec 24–00:00 Dec 25),
   Merlet x Joann (12:30 start, no end shown).
5. Long titles (e.g. "Six Hands Dinner: Drie chefs, drie continenten,
   één avond") wrap correctly, no overflow.
6. Ticket / Official Website actions behave correctly for all 8.
7. **Dîner Dansant specifically**: confirm tapping its ticket/booking
   action opens the Van Oys event page itself, not an unrelated brunch
   — the underlying booking CTA on Van Oys's own site is still broken,
   so Chasing Stars should not compound it by mislabeling the link as
   a working direct-booking action.
8. Event → Restaurant/Hotel links work for every canonical
   relationship: Flore, Inter Scaldes (+ Bij Jef/Zarzo/Parkheuvel/
   Zilte under AT THIS EVENT), Merlet (both its Events, + Joann on the
   second), Bij Jef, Van Oys Maastricht Retreat (both its Events).
9. Restaurant/Hotel → hosted Event works only for genuine hosts —
   spot-check that Zarzo, Parkheuvel, Zilte, and Joann's own Detail
   pages show **no** newly hosted Event from this batch.
10. Bij Jef's own Detail page shows its Six Hands Dinner under hosted
    Events.
11. **Bij Jef must NOT show Chefs & Sommeliers Party as a hosted
    Event** — this is the sharpest negative test in the batch.
12. VanOost renders correctly on Event Detail despite being an
    external host — no map pin (coordinates are NULL), no canonical
    Restaurant link, `external_host_name` displays instead.
13. Existing 9 Events still render and behave identically to before
    this apply.
14. Interested/Going still work on both old and new Events.
15. No obvious Event Detail visual regression across old or new
    Events.

## DEVIATIONS FROM THE PRE-APPLY REPORT

None. The Dîner Dansant ticket-URL fallback was already explicitly
authorized in the pre-apply report's own §15/§20 and was applied
exactly as written — not a new deviation introduced at apply time.

## FINAL PHYSICAL DEVICE APPROVAL

Human device verification was carried out against the physical-device
checklist above and the human tester confirmed: "Het klopt allemaal!"
("It all checks out!"), given in direct response to this batch. This
is recorded as the approval gate for the following observed behavior:

- New Dutch Events appear correctly in the Events list, alongside the
  9 pre-existing Events.
- Ordering/date display works correctly across the full 17-Event list.
- DATE_ONLY precision behaves correctly — no fabricated times observed
  on Flore x Sebastian Frank, VanOost x Herzig, Winemakers Lunch, or
  Six Hands Dinner.
- Event Detail hierarchy works for the new batch.
- Tickets / Official Website actions behave correctly, including
  Dîner Dansant not opening an unrelated booking page.
- Event → Restaurant/Hotel navigation works where canonical
  relationships exist.
- Restaurant/Hotel → Event reverse discovery works correctly for
  genuine hosts.
- Bij Jef's host/participant semantics behave correctly on device (own
  Event shows it as host; Inter Scaldes's Event does not).
- VanOost's external-host Event renders correctly with no fabricated
  map pin or canonical Restaurant link.
- Existing Events remain fully functional, no regression observed.
- Interested/Going remain functional on both old and new Events.
- No Event Detail visual regression was observed.

No claim beyond what the checklist covers and the human confirmed is
made here.

## DATABASE

Production writes = 8 Event inserts + 12 relationship inserts (this
task's entire purpose, from the prior apply step). Schema changes = 0.
Migrations = 0. RLS changes = 0. Storage writes = 0. Zero further
production writes occurred during finalization/device-approval — this
section itself was authored as documentation only.

## GIT

Nothing staged, committed, or pushed as of this document's own
authoring. Staging/commit/push are handled as a separate step in the
finalization workflow, recorded in `DUTCH_EVENT_BATCH_1_FINAL.md`.

DUTCH EVENT ENRICHMENT — BATCH 1 APPLIED TO PRODUCTION, DATA AND HOST
SEMANTICS VERIFIED, PHYSICAL-DEVICE APPROVED
