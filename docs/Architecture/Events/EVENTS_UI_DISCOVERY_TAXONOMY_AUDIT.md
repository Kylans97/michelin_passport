# EVENTS UI REDESIGN + DISCOVERY FILTERS + EVENT TAXONOMY AUDIT

Architecture + product design audit only. Nothing was implemented,
migrated, backfilled, or modified. Grounded in the actual 27 live
production Events, not hypothetical categories.

## EXECUTIVE DECISION

Chasing Stars' Events catalogue has outgrown a single overloaded
`EventType` (70% of Events are currently typed `dinner`). The
catalogue itself already contains a clean, real separation between
**form** (dinner/lunch/festival/gala/tasting/brunch/party) and
**theme** (wine, winemaker, wild/game, guest chef, four hands,
charity) — this audit derives both from the 27 real rows, not from
the example lists in the brief.

**Recommendation in one paragraph**: keep `EventType` as a small,
Dart-enum-backed, non-explosive taxonomy (expand from 6 to 8 values:
add `lunch`, `gala`, `brunch`, `party`; retain `festival`, `dinner`,
`tasting`; retire `market`/`experience` from active use — see §5).
Add a genuinely new, separate concept — **Event Tags** — via a
normalized `event_tags` + `event_tag_assignments` join-table pair
(Option C, §9), curated (not free-text, not host-authored in V1),
starting with exactly 6 tags: Wine, Winemaker, Wild/Game, Guest Chef,
Four Hands, Charity. Filter UI should be a single **Filters** sheet
behind Search (no permanent chip row), with Social/Type/Theme/
Location/Admission/Date as its five groups; filtering happens first,
Step 8A ranking applies second, inside the filtered set — no ranking
logic is duplicated. This is a staged, additive rollout: existing
Event browsing keeps working at every phase.

## CURRENT EVENTS ARCHITECTURE

Read directly from the codebase (not assumed from docs):

- **Event model** (`lib/models/event.dart`): three independent time-
  precision tiers (calendar `startDate`/`endDate`, local clock
  `startTime`/`endTime`, exact instant `startAt`/`endAt` + `timezone`)
  — the Time Precision architecture is fully in place and does not
  need to change for this workstream.
- **`EventType`** (`lib/models/event.dart` lines 14–41): exactly six
  values today — `festival, dinner, tasting, market, experience,
  other` — with a `label` getter (Festival/Dinner/Tasting/Market/
  Experience/"Event"). Displayed only as a hero eyebrow on Event
  Detail (hidden for `other`); never shown on `EventCard`.
- **`EventsRepository`** (`lib/data/repositories/events_repository.dart`):
  `loadEvents({from, to, countryCode, query})` — free-text search
  already exists via a shared `buildIlikeOrFilter(query, ['name',
  'city', 'venue_name'])` helper (the same pattern `RestaurantRepository`/
  `HotelRepository` use), ANDed with optional country + a
  deliberately-widened date window. No client-side filter/sort logic
  beyond what SQL/`compareEventChronology` already does.
- **Step 8A ranking** (`event_discovery_service.dart` +
  `event_discovery_ranking.dart`): a **tiered comparator**, not a
  numeric score — `Trip > Friend Going > Followed Host > Friend
  Interested > Popularity > null (chronology)`, tier ascending then
  chronological within-tier. Every signal source loads in parallel and
  fails independently.
- **Step 8B** (`_loadHostedEvents` in `EventsRepository`): filters
  `event_restaurants`/`event_hotels`/`event_chefs` on
  `is_host = true` only — never venue-only or participant-only.
  Surfaced via `HostedEventsSection`, wired into Restaurant/Hotel/
  Private Chef Detail.
- **Step 8C** (`loadPassportEventAttendance`): reads exclusively
  `event_confirmed_attendance`; zero dependency on the Interested/
  Going intent table.
- **Events screen** (`events_screen.dart`): `SliverAppBar` → a 3-row
  `EventFilterBar` (free-text search, date-mode chips [Upcoming/This
  week/Month/Custom range], country filter) → attendance nudge → list
  of `EventCard`s built from the ranked discovery list.
- **`EventCard`**: image, name (+ CANCELLED badge), formatted date
  range, city/country, **one** relevance-reason row, FREE ENTRY pill.
  No price, no going/interested counts, no type badge today.
- **Event Detail hierarchy** (already finalized by a prior workstream,
  must be preserved): Hero → Essentials → Actions → Attendance →
  Interested/Going (+ Friends Going/Interested) → About → At This
  Event → Hotels → Location.
- **Analytics gap found**: `AnalyticsEvent.eventSearchPerformed` and
  `AnalyticsEvent.eventFilterApplied` are already defined in the
  canonical taxonomy (with a `resultCount` property) but have **zero
  call sites anywhere in the codebase** — the existing search box
  fires no analytics at all today. This is a real, pre-existing gap,
  not something this workstream created.
- **No dedicated Events search screen or result-count tracking exists
  today** — search is a single always-visible text field on the main
  list.

## 27-EVENT PRODUCTION CENSUS

Read fresh, read-only, from `events` + `event_restaurants` +
`event_hotels` (no `event_chefs` rows exist in production today).

| # | Event | Current type | City/Country | Host | Relationship shape |
|---|---|---|---|---|---|
| 1 | 't Preuvenemint | festival | Maastricht, NL | external (Vrijthof) | 1 participant (Tout a Fait) |
| 2 | Friends & Family Zomer BBQ met Marko Karelse | dinner | Rijswijk, NL | 't Ganzenest (EXACT host) | host only |
| 3 | VanOost Sundays: BBQ with Friends | dinner | Amsterdam, NL | external (VanOost) | 2 participants (Triptyque, Basiliek) |
| 4 | Chefs & Sommeliers Party | dinner | Kruiningen, NL | Inter Scaldes (EXACT host) | 4 participants (Bij Jef, Zarzo, Parkheuvel, Zilte) |
| 5 | VanOost Sundays: 4 Hands Lunch — Sören Herzig | dinner | Amsterdam, NL | external (VanOost) | none (foreign guest) |
| 6 | Winemakers Lunch — South Africa | tasting | Schoorl, NL | Merlet (EXACT host) | host only |
| 7 | Forces of Nature: Ana Roš x Eric Vildgaard | dinner | Kobarid, SI | Hiša Franko (EXACT host) | 1 participant (Jordnær) |
| 8 | Wildfestival | tasting | Apeldoorn, NL | external (De Echoput) | none |
| 9 | Chaîne des Rôtisseurs Gala Dîner op SS Antoinette | dinner | Amsterdam, NL | external (Chaîne des Rôtisseurs) | none |
| 10 | Wine & Dine × Pierre Ache Wijnen | dinner | Eijsden, NL | Van Oys Maastricht Retreat (EXACT host, hotel) | host only |
| 11 | Wijnmakersdiner Montanha Vermelha | dinner | Blokzijl, NL | Kaatje bij de Sluis (EXACT host) | host only |
| 12 | Club Leroy bij Parkheuvel | experience | Rotterdam, NL | Parkheuvel (EXACT host) | host only |
| 13 | Exclusieve Wijnproeverij — Domaine Paul Pillot | tasting | Rijswijk, NL | 't Ganzenest (EXACT host) | host only |
| 14 | Six Hands Dinner: Drie chefs, drie continenten | dinner | Den Hoorn, NL | Bij Jef (EXACT host) | host only |
| 15 | Erloom x Henrique Sá Pessoa | dinner | Hilvarenbeek, NL | external (Erloom) | none |
| 16 | Four Hands Dinner: Marchal x Seafood Gastro | dinner | Copenhagen, DK | external (Marchal) | none |
| 17 | Vergeet Mij Niet Gala | dinner | Amsterdam, NL | external (Hotel Okura, `external_host_name` gap — see below) | 6 participants (Ciel Bleu, De Bokkedoorns, De Librije, De Treeswijkhoeve, Inter Scaldes, Restaurant Smink) |
| 18 | Jubileumdiner — 5 jaar Restaurant Roemer | dinner | Utrecht, NL | external (Restaurant Roemer) | none |
| 19 | Game Brunch | experience | Eijsden, NL | Van Oys Maastricht Retreat (EXACT host, hotel) | host only |
| 20 | Wijnmakerslunch Heidi Schröck & Söhne | tasting | Apeldoorn, NL | external (De Echoput) | none |
| 21 | 4 Hands Dinner: Bas van Kranen x Sang Hoon Degeimbre | dinner | Amsterdam, NL | Flore (EXACT host) | 1 participant (L'air du temps) |
| 22 | Douro to Table — Dinner III | dinner | Lamego, PT | external (Six Senses Douro Valley) | none |
| 23 | SHEf's Kitchen Party | experience | Bad Ragaz, CH | Grand Resort Bad Ragaz (EXACT host, hotel) | host only |
| 24 | Four-Hands Diner: Olde Marckt x Karels | dinner | Aalten, NL | Olde Marckt (EXACT host) | host only |
| 25 | 4 Hands Dinner: Bas van Kranen x Sebastian Frank | dinner | Amsterdam, NL | Flore (EXACT host) | host only |
| 26 | Four Hands Dinner: Merlet x Restaurant Joann | dinner | Schoorl, NL | Merlet (EXACT host) | 1 participant (Joann) |
| 27 | Dîner Dansant | dinner | Eijsden, NL | Van Oys Maastricht Retreat (EXACT host, hotel) | host only |

**Data-quality note found during this audit (not fixed here, out of
scope)**: Vergeet Mij Niet Gala's actual organizing host is Hotel
Okura Amsterdam, but `external_host_name` is `NULL` on that row —
every one of its 6 relationship rows is correctly participant-only
(`is_host=false`), so no Step 8B risk exists, but the Event currently
has no host attribution surfaced anywhere in the UI at all. Worth a
future one-row data fix, not part of this audit's scope.

## CURRENT EVENTTYPE AUDIT

| Value | Count | Events |
|---|---|---|
| `festival` | 1 | 't Preuvenemint |
| `dinner` | 19 | everything not listed below |
| `tasting` | 4 | Winemakers Lunch SA, Wildfestival, Paul Pillot, Heidi Schröck Lunch |
| `experience` | 3 | Club Leroy, Game Brunch, SHEf's Kitchen Party |
| `market` | 0 | — |
| `other` | 0 | — |

**Answers to the audit questions**:
- `dinner` is heavily overloaded — 70% of the catalogue — and
  genuinely contains at least 4 different real forms (formal seated
  dinners, midday four-hands "diners," a black-tie gala, a walking-
  format multi-chef party).
- `tasting` is also mixed: one genuine pure tasting (Paul Pillot) and
  three events that are really lunches or a festival, typed `tasting`
  only because they involve wine/food sampling as part of a larger
  format.
- `experience` is a catch-all covering three structurally unrelated
  formats (music+dinner, a seasonal brunch, a multi-chef midday
  party) — it has no coherent meaning today.
- `market` and `other` are **entirely unused** in production — zero
  Events. Safe to leave in the enum (no migration risk either way) but
  not meaningfully part of today's catalogue.
- **Expanding EventType would improve discovery** — see §7.
- **Changing EventType is low-risk**: it's a Postgres `CHECK`
  constraint (`ANY (ARRAY[...])`) plus a Dart enum with a fallback
  case; adding new allowed values is additive and non-breaking.
  Removing/renaming existing values would require a backfill (this
  audit does not recommend removing any current value).

## EVENT TYPE VS EVENT TAG CONTRACT

**Event Type** answers: *"What form does this Event take?"* — always
exactly one value, always known, drives the base card/detail
formatting expectations (a Gala reads differently from a Tasting).

**Event Tag** answers: *"What is this Event distinctively about?"* —
zero to several values, optional, purely a discovery/theming signal,
never required for an Event to be valid or complete.

Tested against all 27 real Events (see the backfill preview below):
the contract holds cleanly in every case. The clearest illustration
already exists in the catalogue itself: **Winemakers Lunch — South
Africa** (type=Lunch, tags=[Wine, Winemaker]) and **Four Hands Dinner:
Merlet x Restaurant Joann** (type=Dinner, tags=[Four Hands, Guest
Chef]) are structurally the same shape the brief's own hypothetical
examples described — this is not an invented pattern, it is what the
real data already looks like once form and theme are separated.

## PROPOSED V1 EVENT TYPES

| Type | Definition | Count | Examples | Why it earns its own type |
|---|---|---|---|---|
| **Dinner** | A formal or semi-formal seated evening/main meal, single or timed seatings | 15 | Six Hands Dinner, Forces of Nature, van Kranen x Sebastian Frank | The dominant real format; a genuine, coherent category on its own |
| **Lunch** | A seated midday meal, explicitly framed as lunch by the source | 3 | VanOost x Herzig, Winemakers Lunch SA, Heidi Schröck Lunch | Structurally and socially distinct from an evening dinner; all 3 are literally named "Lunch" by their own host |
| **Festival** | Open, multi-stop or multi-vendor walking format, broad/general admission | 2 | 't Preuvenemint, Wildfestival | Fundamentally different social/logistical shape (no fixed seat, multiple stations) |
| **Gala** | Formal, ticketed, often black-tie ceremonial dinner, frequently fundraising | 2 | Chaîne des Rôtisseurs Gala, Vergeet Mij Niet Gala | Distinct social contract (dress code, higher price point, often charitable) worth signalling before a user taps in |
| **Tasting** | A wine/food tasting where sampling — not a full multi-course meal — is the primary framing | 1 | Exclusieve Wijnproeverij — Domaine Paul Pillot | Genuinely different commitment level from a full dinner |
| **Brunch** | A late-morning/midday combined meal, explicitly branded brunch | 1 | Game Brunch | Distinct enough social format (family-friendly pricing tiers, hunting-horn ceremony) to warrant its own label rather than folding into Lunch |
| **Party** | A multi-chef/multi-station showcase format, explicitly branded as a "party," distinct from a single seated dinner | 3 | Chefs & Sommeliers Party, SHEf's Kitchen Party, Club Leroy bij Parkheuvel | All three are literally branded with "Party"/"Club" naming and share a walking/multi-station or entertainment-forward shape distinct from Dinner |

**Total: 15+3+2+2+1+1+3 = 27 — every Event maps.**

**Evaluated and excluded from V1** (per the brief's own candidate
list): none of the seven suggested types (Dinner, Lunch, Festival,
Gala, Tasting, Brunch, Party) were rejected — all seven have genuine,
non-trivial catalogue support (1–15 Events each). No merges were
needed; each earns its slot.

**Open naming question, not resolved here**: "Party" may read slightly
casual for Chasing Stars' understated-luxury editorial tone. Two of
its three members (Chefs & Sommeliers Party, SHEf's Kitchen Party)
literally use "Party" in their own official name, which argues for
keeping it verbatim; an alternative like "Showcase" or "Gathering"
would drift from the source's own branding. Flagged as a design
decision for human review, not resolved in this audit.

## PROPOSED V1 EVENT TAGS

| Tag (machine value) | Display label | Definition | Count | Source-explicit? |
|---|---|---|---|---|
| `wine` | Wine | Wine pairing/selection is a central, named feature of the Event | 5 | Yes — every member explicitly centers a named wine selection/producer |
| `winemaker` | Winemaker | A specific producer/estate (not just a wine merchant) is the featured guest | 4 | Yes — Montanha Vermelha, Newton Johnson/Grangehurst, Domaine Paul Pillot, Heidi Schröck & Söhne all explicitly named producer estates |
| `wild_game` | Wild / Game | Game/wild-hunted ingredients are the explicit seasonal theme | 3 | Yes — Wildfestival, Game Brunch, Olde Marckt x Karels all explicitly frame game/wild as the theme |
| `guest_chef` | Guest Chef | A chef from outside the host's own kitchen travels in to cook | 14 | Yes — every member has a named external chef explicitly credited |
| `four_hands` | Four Hands | The Event is explicitly branded/described as a "four hands"/"4 hands" two-chef paired collaboration | 6 | Yes — every member's own title or description literally says "four hands"/"4 hands" |
| `charity` | Charity | Proceeds explicitly support a named cause | 1 | Yes — Vergeet Mij Niet Gala explicitly states proceeds support dementia research |

**Evaluated and explicitly rejected for V1**:
- **Champagne** — no Event centers champagne as its theme; a few
  mention "champagne aperitif" as an incidental menu detail, which is
  not the same as a champagne-themed Event. No genuine support.
- **Seasonal** — every current candidate for this tag (Wildfestival,
  Game Brunch, Olde Marckt x Karels) is *already* covered 100% by
  Wild/Game — it has zero independent discriminating power in today's
  catalogue. Revisit once a non-game seasonal Event exists (e.g. a
  spring/asparagus or summer Event).
- **Seafood** — only Marchal x Seafood Gastro even brushes this theme,
  and only via the guest restaurant's own name, not a genuinely
  seafood-centric tasting menu described in the source. One event is
  too thin to justify.
- **Collaboration** — would be a pure synonym for Guest Chef; adding
  it creates ambiguity about which to apply, not new discovery value.
- **Harvest** — no Event uses harvest framing.
- **Michelin-related** — explicitly excluded per instruction: Michelin
  recognition belongs to the participating Restaurant/Hotel entities,
  not to the Event's own theme, even though most hosts happen to be
  starred.
- **Chef Series** ("4-Hands Dinner Series," "Douro to Table" Dinner
  III, "VanOost Sundays") — this is a real, recurring structural
  property, but it describes a *relationship between Events* (same
  host, recurring format), not a theme a user would filter by. Better
  suited to a future "part of a series" grouping feature than a tag.
  Not recommended for V1.
- **BBQ** — 2 Events (Karelse, VanOost BBQ) literally use the word.
  Too thin for V1; watch for a 3rd before reconsidering.

**Total tag assignments across the catalogue**: 33 (5+4+3+14+6+1) —
average 1.2 tags/Event, with `guest_chef` alone touching 52% of the
catalogue (a genuine, honest reflection of how much of this business
is chef-collaboration-driven, not a taxonomy flaw).

## 27-EVENT TAXONOMY BACKFILL PREVIEW

**Not executed — preview only.** Every Event is mapped; ambiguous
cases are flagged explicitly rather than silently resolved.

| # | Event | Proposed type | Proposed tags | Ambiguity flag |
|---|---|---|---|---|
| 1 | 't Preuvenemint | Festival | — | none |
| 2 | BBQ Karelse | Dinner | Guest Chef | none |
| 3 | VanOost BBQ with Friends | Dinner | Guest Chef | none |
| 4 | Chefs & Sommeliers Party | **Party** (was Dinner) | Guest Chef | reclassify from Dinner — walking/multi-kitchen format, "Party" in its own name |
| 5 | VanOost 4 Hands Lunch — Herzig | **Lunch** (was Dinner) | Guest Chef, Four Hands | reclassify — literally named "Lunch"; no clock time published either way |
| 6 | Winemakers Lunch — South Africa | **Lunch** (was Tasting) | Wine, Winemaker | reclassify — literally named "Lunch" |
| 7 | Forces of Nature | Dinner | Guest Chef | none |
| 8 | Wildfestival | **Festival** (was Tasting) | Wild/Game | reclassify — own name is "Wildfestival," walking multi-station format |
| 9 | Chaîne des Rôtisseurs Gala | **Gala** (was Dinner) | — | reclassify — "Gala" in its own name, black tie |
| 10 | Wine & Dine × Pierre Ache | Dinner | Wine | none |
| 11 | Wijnmakersdiner Montanha Vermelha | Dinner | Wine, Winemaker | none |
| 12 | Club Leroy bij Parkheuvel | **Party** (was Experience) | Guest Chef (entertainer, not culinary — see below) | **genuinely ambiguous**: could remain Dinner+tag instead; live-music-forward format tips it toward Party but reasonable people could disagree |
| 13 | Exclusieve Wijnproeverij — Paul Pillot | Tasting | Wine, Winemaker | none |
| 14 | Six Hands Dinner | Dinner | Guest Chef | Not tagged Four Hands — six hands/three chefs is a distinct, larger collaboration, correctly excluded |
| 15 | Erloom x Henrique Sá Pessoa | Dinner | Guest Chef | **genuinely ambiguous**: the source explicitly prices both a lunch (€99) and dinner (€129) seating on the same dates — a single Event row cannot cleanly be both Lunch and Dinner; Dinner chosen as the higher-signal seating, but this is a real modeling limitation worth a future look, not resolved here |
| 16 | Marchal x Seafood Gastro | Dinner | Guest Chef, Four Hands | none |
| 17 | Vergeet Mij Niet Gala | **Gala** (was Dinner) | Charity | reclassify — "Gala" in its own name, explicit charitable proceeds |
| 18 | Roemer Jubileumdiner | Dinner | — | none (anniversary framing is real but too thin a catalogue signal — 1 Event — to justify its own tag) |
| 19 | Game Brunch | **Brunch** (was Experience) | Wild/Game | reclassify — literally named "Game Brunch" |
| 20 | Wijnmakerslunch Heidi Schröck | **Lunch** (was Tasting) | Wine, Winemaker | reclassify — literally named "Wijnmakerslunch" |
| 21 | van Kranen x Sang Hoon Degeimbre | Dinner | Guest Chef, Four Hands | none |
| 22 | Douro to Table — Dinner III | Dinner | Guest Chef | none |
| 23 | SHEf's Kitchen Party | **Party** (was Experience) | Guest Chef | reclassify — "Party" in its own name, multi-chef live-cooking-station format |
| 24 | Olde Marckt x Karels | Dinner | Guest Chef, Four Hands, Wild/Game | none |
| 25 | van Kranen x Sebastian Frank | Dinner | Guest Chef, Four Hands | none |
| 26 | Merlet x Joann | Dinner | Guest Chef, Four Hands | **minor ambiguity**: starts 12:30, closer to lunchtime, but the source's own name is "Four Hands **Dinner**" — kept as Dinner per source framing |
| 27 | Dîner Dansant | Dinner | — | **minor ambiguity**: live music/dancing format could argue for Party, but "Dîner" is literally in Van Oys's own name — kept as Dinner |

**3 genuinely ambiguous cases flagged** (Club Leroy, Erloom x Sá
Pessoa's dual lunch/dinner pricing, and two minor naming-vs-format
tensions). None block the taxonomy — every Event still gets exactly
one defensible type — but they should get a human editorial call
before backfill, not an automated one.

## TAG GOVERNANCE

| Option | Description | Consistency | Query/filter | Future CMS | Host-created | Analytics | Renaming | Spelling drift | RLS | Maintenance |
|---|---|---|---|---|---|---|---|---|---|---|
| A — free text | Arbitrary strings per Event | Poor | Awkward (`ILIKE`) | Poor | Uncontrolled | Poor (fragmented values) | Manual find/replace | High risk | N/A | Low upfront, high long-term |
| B — `text[]` + app-controlled vocabulary | Postgres array column, Dart enum enforces allowed values | Good if enum is respected everywhere | Reasonable (`&&` array overlap, GIN index) | Fair — no place to store label/definition/order | Risky — nothing stops a bad value at the DB layer | Fair | Requires touching every row's array | Enum prevents it in Dart, but not in raw SQL/DB tools | Simple | Low upfront, medium long-term |
| C — `event_tags` + `event_tag_assignments` join table | Normalized taxonomy table + many-to-many join | Excellent — DB-enforced via FK | Excellent (standard join, indexed) | Excellent — one row to rename/relabel/reorder | Naturally supports curated dropdown, blocks free entry | Excellent — stable IDs for analytics | One-row update, propagates everywhere | Impossible at the DB layer | Standard, same pattern as other reference tables | Slightly higher upfront, low long-term |
| D — other | (not identified as clearly superior) | — | — | — | — | — | — | — | — | — |

**Recommendation: Option C.** This app already uses a normalized
reference-table pattern for comparable concepts (`cuisine_id` on
`restaurants_full`), so this is consistent with existing conventions,
not a new pattern. At 27 Events the difference is invisible; the
difference becomes real at 100+ Events once multiple people (or an
AI-assisted enrichment pipeline) are adding Events and typos/casing
drift in a free-text or unconstrained-array model would silently
fragment filters (e.g. "Wine" vs "wine" vs "Wines" becoming three
separate, non-matching filter buckets). A join table also gives a
single place to add `display_order`, a `definition` (for tooltips),
and future localization columns without touching `events` at all.

**Scale check**:
- 27 Events: any option works; the difference is invisible.
- 100 Events: Option C's advantage becomes visible — safe renaming,
  no drift.
- 1,000 Events: Option C's indexed join scales cleanly; Option B's
  GIN-indexed array also still performs but offers no protection
  against drift, which compounds with volume.
- 10,000 Events: Option C's normalized model is the only one that
  stays maintainable if Events start coming from multiple enrichment
  sources or host self-submission.

## TAG ASSIGNMENT SOURCE OF TRUTH

**Recommendation: manually curated, with AI-assisted suggestion as a
future accelerant — never fully automated, never host-authored in
V1.** Rationale, tied directly to this app's own repeated,
consistently-applied principle across every enrichment batch this
session: *"never invent a timestamp/coordinate"* extends naturally to
*"never invent a tag."* Search may be fuzzy (a user typing "wine"
should reasonably surface Wine-tagged Events even if the word "wine"
never appears in the title); the **stored taxonomy itself** must stay
deterministic — the same discipline already applied to time precision
and location. A future AI-suggest-then-human-approve pipeline (§28)
is a legitimate accelerant for volume, but the human approval step is
non-negotiable for V1.

## CURRENT EVENTS UI AUDIT

Read directly from `events_screen.dart` and `event_filter_bar.dart`:

```
SliverAppBar (pinned, brand green)
  "Events" / "Culinary happenings worth planning a trip around."
  bottom: EventFilterBar (ivory background)
    Row 1: free-text search field
    Row 2: date-mode chips (Upcoming / This week / Month / Custom range)
    Row 3: CountryFilterControl
    [Month mode only] Row 4: prev/next month stepper
AttendancePromptCard (conditional "Did you make it?" nudge)
Error / Loading / Empty states
SliverList<EventCard>
```

**What will become visually problematic once Social/Type/Theme
filters are added**: the `EventFilterBar` is already a 3–4 row fixed
block sitting *above* every scroll position (it lives in the
`SliverAppBar`'s `bottom:`, so it's always visible, not just at the
top). Adding 3 more filter dimensions (Social, Type, Theme) as
additional always-visible chip rows would push this block to 6–7 rows
tall before a single Event is visible — a serious problem for the
brand's own "minimal chrome, photography-ready" language and a
concrete argument for moving most filtering behind a single sheet
control rather than stacking more permanent rows (see §19–20).

## SOCIAL DISCOVERY SEMANTICS

**Recommended model: a separate "Social" filter group (Option C from
the brief's own framing), combinable with Type/Theme/Location/
Admission — not mutually exclusive top-level modes.** A user should
be able to select "Friends Going" + "Wine" + "Netherlands"
simultaneously; forcing social state into a single top-level tab (à la
Option A) would make combinations like that impossible without an
awkward secondary control. Reusing the filter-sheet pattern already
recommended for Type/Theme keeps the mental model uniform — everything
lives in filters, nothing is structurally special-cased.

## FILTER + SEARCH SEMANTICS

**Exact inclusion rules, reusing Step 8A's own definitions rather than
inventing new ones**:

- **Friends Going**: Event included if `EventAttendanceRepository.
  getVisibleUserIdsForEvents([eventId], 'going')` returns at least one
  ID present in `FriendshipRepository.getFriends()` — the identical
  computation Step 8A already performs for its own Friend Going
  signal, just used as an inclusion filter instead of a ranking tier.
- **Friends Interested**: identical, `status = 'interested'`.
- **Following**: Event included if `EventHostFollowRepository.
  getFollowedHostEventNames` returns a non-empty result for that
  Event — i.e., the user follows at least one entity with a genuine
  `is_host=true` relationship on that Event. Reuses `eventHostFollow
  Qualifies` exactly — no competing definition.
- **Current user's own Going/Interested state does not affect these
  filters** — they describe *other people's* attendance/follow state,
  matching their existing Step 8A meaning exactly.
- **Cancelled Events**: currently included (marked, not hidden) in
  `loadEvents`; recommend preserving this — a cancelled Event a friend
  was going to is still meaningful context, and Step 8B's own
  `upcomingHostedEvents` already excludes cancelled Events from the
  *hosted* surface specifically, a distinction worth keeping rather
  than flattening.
- **Ended Events**: excluded from the main discovery surface by the
  existing `eventBrowseWindowBounds` date logic already (default
  "Upcoming" mode); this does not change.
- **Signed-out behavior**: Social filters should not be offered at all
  to a signed-out user (there is no "friends"/"following" concept
  without an account) — same cold-start behavior Step 8A already has
  (plain chronological order, no reasons).
- **Zero-friend / zero-follow behavior**: the filter should still be
  selectable and simply return zero results with a clear empty state
  ("Friends aren't going to any upcoming Events yet") rather than
  being hidden or disabled — consistent with how empty states are
  already handled elsewhere in the app.

## FILTER DIMENSIONS

| Dimension | V1 recommendation | Basis |
|---|---|---|
| Social (Friends Going/Interested, Following) | **MUST HAVE** | Directly reuses existing Step 8A data; zero new backend work |
| Type (V1 taxonomy, §7) | **MUST HAVE** | Real, derived, 7-value taxonomy already fits the catalogue |
| Theme/Tags (V1 taxonomy, §8) | **MUST HAVE** | Same — 6 real tags, `guest_chef` alone covers half the catalogue |
| Location — Country | **MUST HAVE** | Already exists today (`CountryFilterControl`); just needs to move into the new sheet |
| Location — City | **NICE TO HAVE LATER** | With only 27 Events spanning ~20 distinct cities, a city filter would mostly show 1-Event results today — low value until the catalogue is denser |
| Admission (Free/Paid/Mixed) | **DO NOT ADD YET** | 26 of 27 Events are `paid`; a filter that returns "everything" for one option and near-nothing for the others has no discovery value at current catalogue composition |
| Date (Today/This weekend/This month/custom) | **MUST HAVE (mostly exists)** | `EventDateFilterMode` already implements this; carry it into the new architecture unchanged rather than rebuilding it |

## SEARCH

Current state confirmed: a real, working `ilike`-based search already
exists (`buildIlikeOrFilter` over name/city/venue_name), but with zero
analytics, no debounce, and — critically — **no connection to the tag
taxonomy at all**. Searching "wine" today only matches Events whose
*title* literally contains "wine" (e.g. "Winemakers Lunch"), not every
Wine-tagged Event — the exact gap the brief's own example
(`search "wine" → Events tagged Wine`) calls out.

**Recommended future behavior**: extend the existing Supabase query
rather than replacing it — add a tag-name match (`event_tags.name
ilike`) via the join table, ORed into the existing name/city/venue_name
match, plus a host-name match (join through `event_restaurants`/
`event_hotels` to `restaurants_full.name`/`hotels_full.name` OR
`external_host_name`). At 27–1,000 Events this remains comfortably
within a single Postgrest query with standard B-tree/GIN indexes — no
RPC or full-text-search vector column is justified yet (see §30 for
the scale threshold where that changes). Client-side filtering of an
already-small result set remains fine; this is about the *matching*
logic, not where filtering executes.

## FILTER + SEARCH INTERACTION

**Recommended V1 rule, deliberately simple**: **AND across dimensions,
OR within a dimension.** Example: `Search="wine" AND Social="Friends
Going" AND Type="Dinner" AND Location="Netherlands"` — all four must
hold. Within Themes, selecting both **Wine + Guest Chef** means **OR**
(any Event with either tag) — the opposite choice (AND, requiring
both) would be too restrictive given `guest_chef` already covers half
the catalogue; a user selecting two themes is almost always trying to
broaden their browse, not narrow it. **Clearing filters** should be a
single explicit action (a visible "Clear all" control inside the
sheet, plus tapping the active-filter summary itself) — never an
implicit side effect of any other action.

## STEP 8A RANKING INTERACTION

**Filter first, then rank — confirmed clean with the current
implementation, no duplication required.** `EventDiscoveryService.
rankForDiscovery({events, userId})` already takes an arbitrary `events`
list as input — it has no dependency on how that list was produced.
The correct integration point is: `EventsRepository.loadEvents(...)`
(extended with the new filter parameters) produces the filtered
candidate set → that set is passed into the *existing, unmodified*
`rankForDiscovery` exactly as today. Example: selecting "Friends
Going" narrows the candidate set to only Events at least one friend is
attending; Step 8A's own tiered comparator (Trip > Friend Going >
Followed Host > ...) then still orders *within* that narrowed set
exactly as it does today. No new ranking logic, no second comparator,
no risk of the two systems disagreeing.

## UPCOMING VS PAST

**Recommendation: upcoming-only on the main Events discovery surface;
past history remains exclusively Passport's job.** Passport (Step 8C)
already represents genuine attended history via confirmed attendance
— building a redundant "past Events" browse mode on the main Events
screen would duplicate that surface without a clear product reason,
and risks confusing "Events I could have gone to" (a discovery
concept) with "Events I actually went to" (Passport's own, more
meaningful concept). If a past, non-attended Event ever needs to be
findable (e.g. "what was that dinner at Flore last spring"), Search
extending to a broader date range is a smaller, more honest solution
than a whole second browse mode.

## UI OPTION A — MINIMAL LUXURY

```
SliverAppBar: "Events" + subtitle
Search (always visible, single field)
Small "Filters" affordance (icon + optional badge count) — opens a bottom sheet
Active-filter summary line (only when filters are active)
  e.g. "Netherlands · Wine · Friends Going"
Featured/most-relevant Event (optional, from Step 8A's own top result)
Event feed (SliverList<EventCard>, unchanged card shape)

Filter sheet (opened on demand):
  Social — All / Friends Going / Friends Interested / Following
  Type — chip multi-select
  Themes — chip multi-select
  Location — Country (+ City later)
  Date — existing date-mode control, unchanged
  [Clear all]  [Show N results]
```

## UI OPTION B — DISCOVERY LED

```
SliverAppBar: "Events" + subtitle
Search
Horizontal quick-filter row (persistent): e.g. "Friends" / "Wine" / "This month"
Featured Event
Event feed
Advanced filter sheet (for everything not covered by quick filters)
```

## UI OPTION C — SOCIAL LED

```
SliverAppBar: "Events" + subtitle
Prominent social mode switcher: All / Friends / Following (tab-like)
Search + secondary filters (Type/Theme/Location/Date) in a sheet
Event feed
```

## RECOMMENDED UI

**Option A — Minimal Luxury.** Reasoning, evaluated against the
brand's own stated language (dark green/ivory, understated luxury,
editorial, minimal chrome, no gold, avoid chip overload,
photography-ready, scalable to 100+ Events):

- Option B's persistent horizontal quick-filter row is exactly the
  "permanent chip row" problem identified in §11 — it just relocates
  it rather than solving it, and at 27 Events (only 1 charitable, only
  1 tasting) several "quick" filters would frequently return near-zero
  results, undermining their own usefulness.
- Option C's tab-like social switcher structurally reintroduces the
  "mutually exclusive top-level modes" problem already rejected in
  §12 — it would need real rework to support "Friends Going + Wine"
  cleanly.
- Option A keeps the always-visible surface to exactly two elements
  (Search, a single Filters affordance) — the smallest possible chrome
  footprint — while still surfacing an honest, glanceable summary of
  what's active. It scales identically at 27 or 1,000 Events, since
  the sheet's own content (not the trigger) is what grows.

## QUICK FILTERS

**Recommendation: none as permanent top-level chips.** The catalogue
distribution itself argues against it: `guest_chef` (14/27) and
`dinner` (15/27) are so dominant that a "quick filter" for either
barely narrows anything, while `charity`/`tasting`/`brunch` (1 Event
each) would almost always show a near-empty result — a bad first
impression either way. Everything except Search lives behind the
single **Filters** control.

## ACTIVE FILTER DISPLAY

**Recommendation: a single summary line, not removable chip tokens.**
`"Netherlands · Wine · Friends Going"` — joined with a middle-dot
separator, tapping the line itself reopens the sheet (where individual
selections can be changed or cleared). This matches the brand's own
"no chip overload" instruction directly — individual removable tokens
are exactly the chip-heavy pattern being avoided, while a small
`(3)` badge on the Filters button alone under-communicates *what* is
active. The summary line gives both at-a-glance clarity and zero extra
chrome.

## EVENT CARD

**Recommendation: do not add Type or Tags to `EventCard` in V1.**
`EventCard` today deliberately shows exactly one relevance-reason row
(never more than one, per the existing Step 8A design principle
already enforced in code) plus identity/date/location/FREE badge.
Adding a Type label would be redundant with information already
implied by the Event's own name/date pattern in most cases (a user
scanning "Winemakers Lunch — South Africa" already infers "this is
about wine" without a chip telling them). Taxonomy belongs primarily
in **discovery/filtering** (§22 answer: A), not card chrome — keeping
cards exactly as photography-forward and uncluttered as they are
today. If any single signal is ever added to the card, it should
follow the same "at most one" discipline already established for
relevance reasons, not stack alongside it.

## EVENT DETAIL

**Recommendation: tags appear subtly, near About — not under the
title, not as a badge stack in the hero.** The recently-finalized
Event Detail hierarchy (Hero → Essentials → Actions → Attendance →
Interested/Going → **About** → At This Event → Hotels → Location) is
explicitly preserved, not reopened. A small, quiet tag row
immediately below the About section's own text (not competing with
the title/date/venue block, which must stay exactly as clean as it is
today) — each tag rendered as an interactive discovery link (tapping
"Wine" navigates to the Events feed pre-filtered to Wine) gives real
utility without adding a new visual tier to the hierarchy. Event Type
itself needs no change — it already renders correctly as the existing
hero eyebrow.

## URL / DEEP-LINK STATE

Not implemented here, but the recommended architecture does not block
it: because filters resolve to a small, enumerable state (a Social
enum + a set of Type values + a set of Tag machine-values + a country
code + a date mode), a future `/events?social=friends-going&type=
dinner&tag=wine&country=nl` mapping is a straightforward 1:1
serialization of the same state object the Filters sheet already
needs internally — no redesign required later.

## DATABASE / SCHEMA

**Recommended, not created here**:

```sql
-- event_tags: the curated taxonomy itself
CREATE TABLE event_tags (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  machine_value text NOT NULL UNIQUE,   -- e.g. 'wine'
  display_label text NOT NULL,          -- e.g. 'Wine'
  definition text,
  display_order smallint,
  created_at timestamptz NOT NULL DEFAULT now()
);

-- event_tag_assignments: many-to-many
CREATE TABLE event_tag_assignments (
  event_id uuid NOT NULL REFERENCES events(id) ON DELETE CASCADE,
  tag_id uuid NOT NULL REFERENCES event_tags(id) ON DELETE CASCADE,
  PRIMARY KEY (event_id, tag_id)
);
```

Plus an `ALTER TABLE events ADD CONSTRAINT events_event_type_check`
update to widen the allowed `event_type` values from six to the
recommended eight (`lunch`, `gala`, `brunch`, `party` added; existing
`festival`, `dinner`, `tasting`, `market`, `experience`, `other`
retained — no value removed, so this is purely additive).

**Per proposed change**:
- **`event_tags`/`event_tag_assignments`**: required for the tag
  taxonomy at all; cannot be deferred if tags are wanted for V1, but
  the *rollout* of populating them can be phased (§32).
- **RLS model**: `event_tags` — public read (`SELECT` for `anon`/
  `authenticated`), write restricted to a service/editor role, same
  pattern already used for other reference tables. `event_tag_
  assignments` — public read; write restricted identically. No new
  RLS *pattern* is needed, only new policies matching existing
  conventions.
- **Indexes**: B-tree on `event_tag_assignments.tag_id` (for "all
  Events with tag X") in addition to the natural PK index on
  `(event_id, tag_id)` (which already covers "all tags for Event Y").
  A B-tree on `event_tags.machine_value` (already implied by the
  `UNIQUE` constraint).
- **Compatibility with existing 27 Events**: fully additive — no
  existing row changes shape; every current Event simply has zero tag
  assignments until backfilled.
- **Backfill requirement**: see §26 — a one-time, human-reviewed
  insert of ~33 tag assignments across 27 Events, using the mapping
  in this document as the starting draft, not the final authority.

## RLS

Covered above — no new *pattern*, only new policies on two new tables
following the existing public-read/service-write convention already
used elsewhere in this schema.

## INDEXES

Covered above (§25) — two small B-tree indexes, both cheap at any
realistic scale for this app.

## PERFORMANCE

| Scale | Dart-side filtering | Supabase-side filtering | Notes |
|---|---|---|---|
| 27 Events (today) | Fully acceptable | Also fine | The entire catalogue fits in one screen's worth of memory either way |
| 100 Events | Still acceptable | Preferable | Filter predicates should move into the Postgrest query (`.in()`/join) rather than fetching everything and filtering client-side, to avoid over-fetching |
| 1,000 Events | Not acceptable client-side | Required | Standard indexed joins remain fast; this is where the tag-join and type filters *must* be server-side, not client-side |
| 10,000 Events | Not acceptable | Required, with care | This is the point where a dedicated search RPC or a materialized/denormalized read model might become justified for the *search* path specifically (not filtering, which indexed joins handle fine) — not something to build now |

**When does Supabase filtering become preferable over Dart-side?**
Immediately after V1 ships, in practice — even at 100 Events, pushing
filter predicates into the query (rather than fetching all Events and
filtering in Dart) avoids unnecessary over-fetch and keeps the
`EventsRepository.loadEvents` pattern consistent with how it already
handles country/date filtering today (server-side, not client-side).

## ANALYTICS

**Recommended minimal V1** (the two relevant events **already exist**
in the canonical taxonomy and just need real call sites — this is a
gap-closing recommendation, not new taxonomy):
- `AnalyticsEvent.eventFilterApplied` — fired when the Filters sheet's
  "Show N results" action is taken, with the active filter state and
  `resultCount` (the property already exists on `AnalyticsProperties`).
- `AnalyticsEvent.eventSearchPerformed` — fired on search submission
  (not every keystroke), with `resultCount`.
- `eventOpened`'s existing `sourceContext` should be extended to
  recognize `searchResult`/filtered-context if the user arrived via an
  active filter/search state — `AnalyticsSourceContext.searchResult`
  already exists and is currently unused.

**Explicitly not recommended for V1**: per-keystroke search tracking,
zero-result-specific event types (a `resultCount: 0` on the existing
event covers this without a new taxonomy entry), or any tracking of
sheet-open/sheet-close as separate events.

## ACCESSIBILITY

- **320px width**: the Filters sheet's Type/Theme chip groups must
  wrap, not scroll horizontally off-screen — same discipline already
  applied elsewhere in this app's chip-based UI.
- **Large text**: the active-filter summary line must truncate
  gracefully (not overflow) at 1.6x scale — consistent with the
  existing card-level overflow testing convention already used
  throughout this codebase's own test suite.
- **VoiceOver**: each filter chip needs an accessible label stating
  both the value and its selected/unselected state (not color alone);
  the Filters button needs a label reflecting the active count
  ("Filters, 3 active" rather than just "Filters").
- **Keyboard/search**: the search field needs a clear/submit affordance
  independent of hardware keyboard "search" key behavior.
- **Filter-sheet scrolling**: the sheet itself must be independently
  scrollable with its own safe-area handling, not clipped by the
  device's bottom inset.
- **Tap targets**: chip targets ≥44×44pt, consistent with existing
  interactive elements in this codebase.
- **Color-independent state**: selected filter chips must carry a
  non-color signal (checkmark or filled/outlined shape change), not
  rely on the brand-green fill alone.

## FUTURE HOST-CREATED EVENTS

When Restaurant/Hotel/Private Chef owners can eventually submit
Events: **Event Type should be required** (a single-select from the
fixed V1 list); **Event Tags should be optional, host-selected from
the existing curated list only — hosts should not be able to create
new tags.** This directly prevents taxonomy drift: if every host could
freely add "Wine Tasting" alongside an existing "Wine" tag, or
"4-Hands" alongside "Four Hands," the exact spelling-variant problem
Option C's governance model is designed to prevent would simply move
from the database layer into the submission form. A capped tag count
per Event (e.g. max 3) is worth considering to keep host-submitted
Events from over-tagging for visibility — not decided here, flagged as
an open question for that future workstream.

## FUTURE EDITORIAL / AI ENRICHMENT

The recommended schema supports this workflow cleanly without changes:
source ingestion → AI suggests `event_type` + candidate
`event_tag_assignments` (from the existing curated `event_tags` list
only — never inventing new tag rows) → a human/editor reviews and
approves or edits before `moderation_status` moves to `published` —
exactly the same approval gate already used for the Event row itself.
No schema addition is needed to support "suggested but unapproved"
state if suggestions are simply held outside the database (e.g. in an
enrichment-pipeline artifact, matching this session's own established
pattern of pre-apply research documents) until a human approves them
for insertion.

## MIGRATION / ROLLOUT PLAN

Existing Event browsing must remain fully functional throughout every
phase — none of these phases are destructive or blocking.

**Phase A — Schema**: create `event_tags` (seeded with exactly the 6
approved V1 tags) and `event_tag_assignments`; widen the `event_type`
CHECK constraint to add `lunch`/`gala`/`brunch`/`party`. Purely
additive; zero effect on current UI.

**Phase B — Backfill**: human-reviewed application of this document's
27-Event mapping (§26) — both the `event_type` reclassifications and
the tag assignments — as a single reviewed data change, following the
same pre-apply → human-approve → apply → verify pattern already used
for every Dutch/European Event batch this session.

**Phase C — Dart parsing/query support**: extend `Event`/`EventType`
to the 8-value enum; add `EventTag`/`EventTagAssignment` models;
extend `EventsRepository.loadEvents` to accept the new filter
parameters (type, tags, social) and join against the new tables.
Ship with zero UI change yet — the app keeps working exactly as today
throughout this phase, purely additive plumbing.

**Phase D — Filter UI**: build the Filters sheet (Option A) and active-
filter summary line; wire Social filter semantics (§13) reusing
existing Step 8A repositories.

**Phase E — Search enhancement**: extend the existing `ilike` query to
include tag-name and host-name matching; wire the two existing-but-
unused analytics events.

**Phase F — Event Card / Detail polish**: (optional, lowest priority)
the subtle tag row on Event Detail's About section, if approved.

## TEST STRATEGY

- Pure-function unit tests for the new filter-combination logic (AND
  across dimensions, OR within Themes) — mirroring the existing test
  pattern already used for `compareEventChronology`/
  `rankEventsForDiscovery`.
- Golden/widget tests for the Filters sheet at 320px and 1.6x text
  scale — matching this codebase's own existing overflow-testing
  convention.
- A social-filter semantics test suite explicitly covering: zero
  friends, zero follows, signed-out state, cancelled-Event inclusion —
  mirroring the existing `passport_event_attendance_domain_test.dart`
  pattern of testing edge cases as first-class cases, not afterthoughts.
- A taxonomy backfill dry-run test (assert every one of the 27 real
  Events maps to exactly one Type and a defensible tag set) before any
  real backfill is applied — the same "prove it before you apply it"
  discipline already used throughout this session's enrichment work.

## PHYSICAL DEVICE STRATEGY

Once implemented (not now): verify the Filters sheet opens/closes
smoothly, chip wrapping at 320px, active-filter summary truncation at
large text sizes, that filtering + Step 8A ranking together produce a
sensible, explainable order (spot-check a "Friends Going + Wine"
combination against the real 27-Event catalogue), and that clearing
filters returns to the exact unfiltered chronological/ranked state.

## RISKS / OPEN DECISIONS

- **"Party" naming tone** (§7) — genuinely open, flagged for human
  design review, not resolved here.
- **Club Leroy's type** (Dinner+tag vs. Party) — genuinely ambiguous,
  flagged for editorial judgment during Phase B backfill.
- **Erloom x Henrique Sá Pessoa's dual lunch/dinner pricing** — a real
  modeling limitation (one Event row, two distinct meal services);
  not solved by this taxonomy, worth a separate future look at whether
  such dual-seating Events need their own structural support.
- **Vergeet Mij Niet Gala's missing `external_host_name`** — a small,
  pre-existing data-completeness gap found during this audit, not
  fixed here.
- **Tag cap for future host-submitted Events** — flagged, not decided.
- **Whether "Party" additionally needs its own distinct visual
  treatment on Event Detail** (given its structurally different,
  multi-chef/walking format) — out of scope for this audit, noted for
  a future design pass if Party-type Events prove to need it.

## EXPLICIT NON-GOALS

Confirmed deliberately out of scope for this audit and left entirely
untouched: Event Hero Imagery (remains parked — no image research,
uploads, or `image_url` changes occurred); Passport Historical
Integrity (hard-delete cascade, unpublish-hiding-confirmed-attendance
— remains separate backlog); Dutch Event Batch 3 (not started);
further European Event enrichment (not continued).

## RECOMMENDED IMPLEMENTATION SCOPE

If approved, the smallest complete V1 slice is: Phase A (schema) +
Phase B (backfill, human-reviewed) + Phase C (Dart plumbing) + Phase D
(Filters sheet, Option A) + the Social filter semantics from §13.
Phase E (search enhancement) and Phase F (Event Detail tag row) are
genuinely separable follow-ups, not required for a coherent V1 — Type
and Theme filtering alone, reusing Step 8A ranking underneath, already
delivers the core discovery value this audit set out to evaluate.

## VALIDATION

`dart format --set-exit-if-changed .`: clean (no Dart touched).
`flutter analyze`: no issues. `flutter test`: baseline unchanged (see
accompanying chat report for the exact re-run count). `supabase
migration list --linked`: 39/39 synced. `supabase db push --linked
--dry-run`: "Remote database is up to date." `git status --short` /
`git diff` / `git diff --cached`: only this new audit document appears
untracked — nothing staged.

## DATABASE

Production writes = 0. Schema changes = 0. Migrations = 0. RLS changes
= 0. Backfill = 0 (preview only, §26). Storage writes = 0.

## GIT

Nothing staged, committed, or pushed.

EVENTS UI REDESIGN + DISCOVERY FILTERS + EVENT TAXONOMY — 27-EVENT
PRODUCTION CATALOGUE AUDITED, V1 DISCOVERY MODEL DEFINED, READY FOR
HUMAN REVIEW BEFORE IMPLEMENTATION
