# Guide inventory — every guide we could show beside MICHELIN, 50 Best and Gault&Millau

2026-11-16. Branch `claude/guide-inventory`. **Research only:** no
migration was written, nothing was imported and production was not read
or written. Nothing here is a decision; the recommendation at the end is
for the product owner.

| File | What it holds |
|---|---|
| this file | the inventory, the recommendation, the schema sketch |
| [`guide_inventory/guide_inventory.csv`](guide_inventory/guide_inventory.csv) | 72 rows, one per guide or group of guides, every field asked for, with sources |
| [`guide_inventory/research_global.md`](guide_inventory/research_global.md) | the evidence for global rankings (La Liste, OAD, regional 50 Best, James Beard, Condé Nast…) |
| [`guide_inventory/research_europe.md`](guide_inventory/research_europe.md) | Gault&Millau per market, Repsol, Gambero Rosso, Lekker, Feinschmecker, UK, Nordics… |
| [`guide_inventory/research_rest_of_world.md`](guide_inventory/research_rest_of_world.md) | Tabelog, Black Pearl, Australia, Canada, South Africa, India, Latin America… |
| [`guide_inventory/research_hotels_associations.md`](guide_inventory/research_hotels_associations.md) | Forbes, Condé Nast and T+L hotel lists, Relais & Châteaux, consortia |

## How this was done, and what it does not cover

Four parallel research passes on 2026-11-16, each opening the publisher's
own pages where it could. Every figure in the CSV carries
`venue_count_status`: **verified** means the publisher's own page was
opened; **press / secondary / unverified** means it came from coverage or
an aggregator and is not to be trusted as a total (CLAUDE.md: published
totals from secondary sources are unverified). Gaps, stated plainly:

- Several sites refused our fetches: `opinionatedaboutdining.com`
  (timeout, certificate mismatch; `oad.com` is a parked domain),
  `gamberorosso.it`, `falstaff.com`, `ratedtrips.com` (AA), `cntraveler.com`,
  `travelandleisure.com`, `bluer.co.kr`, `agfg.com.au`, and the Nine Good
  Food Guide 2027 articles. Their openness and terms are **not verified**.
- Terms of use were read for La Liste, Tabelog, Forbes Travel Guide, the
  Good Food Guide UK, Guía Repsol and Gault&Millau FR / BE / NL. For most
  others they were **not read**. None of this is legal advice.
- The 50 Best's current website terms could not be found (the old
  `/terms` paths 404 since the rebrand), so the basis for the list we
  already hold should be checked rather than assumed for the regional lists.
- Aggregators (Pearl / `joinpearl.co`, En Primeur Club,
  `restaurant-ranglisten.de`) were used only to locate lists, never as a
  source. Pearl's OAD data has visible errors (wrong years, a Zürich
  restaurant placed in Porto).
- Overlap with our catalogue was judged against the dated production
  export `restaurants_master_LIVE_20260824.csv` (FR 479, JP 254, NL 120,
  BE 120, DE 59, IT 58, ES 56, US 51, CH 31, HK 22, AT 20 …; under five
  in GB, AU-none, ZA-none, CA-none). Production has grown since; the
  order of countries is what matters here, not the counts.

## Three findings that touch what we already hold

1. **Gault&Millau Germany has had no edition since 2025.** The licence
   with Henris Edition ended; there is no 2026 German guide. Our 15 German
   rows are already labelled `guide_year = 2025` and sourced from press
   (`supabase/data/enrichment/gault_millau/research_dach.md`), so the data
   is honest. The site and app must render them as "2025, the last German
   edition", never as current. Henris is now building a platform that
   combines MICHELIN, G&M, Gambero Rosso and others — a competitor to this
   very idea, not a source.
2. **50 Best has rebranded as "The 50"** (September 2026), and
   `theworlds50best.com` now 301-redirects to `the50.com`. The stored
   `worlds_50_best_url` values point at the old domain; they still
   resolve, but should be refreshed. From 2026 the restaurant list is
   officially "The 50 Best Restaurants" (QA-475, label question already
   with the `w50b-2026` session).
3. **New Gault&Millau editions are out**: Belgium 2027 (9 Nov 2026),
   Luxembourg 2027 (27 Oct), Austria 2027 (19 Oct), France 2027 and
   Switzerland 2027. The Netherlands still runs 2026; its 2027 launch is
   1 Feb 2027.

## The inventory at a glance

Three kinds of recognition run through everything below, and they must
never be shown as the same thing:

- **an award or rating** — independent inspection or anonymous voting;
- **a poll or survey** — popularity among readers or diners;
- **a membership** — the venue pays or is co-opted to belong. Never an award.

### Recommended: hold now

| Guide | Scale | Latest edition | Why now |
|---|---|---|---|
| **Asia's 50 Best Restaurants** | rank 1–100 | 25 Mar 2026 | Same publisher, method and review process as the list we hold; venue pages with address and website for 1–50; strong overlap with our JP/HK/TW/MO/SG/TH venues. |
| **North America's 50 Best** | rank 1–50 | 28 May 2026 (2nd edition) | Same pipeline; 50 rows a year; MICHELIN US/Canada top end. |
| **Latin America's 50 Best** | rank 1–100 | 2026 edition on **1 Dec 2026** | Same pipeline; fills Peru/Mexico/Brazil where MICHELIN is thin or absent. Start with 2026. |
| **La Liste — Top 1000 Restaurants** | score /100, no rank | 2027 edition on **23 Nov 2026** | Widest credible global list, free, per-venue page with street address, coordinates and website — the easiest of all to match. Overlaps our FR/JP weight. Store the score, never a rank. Caveat: it aggregates MICHELIN and G&M, so it partly restates them. Ask written permission first (T&C reserve commercial use). |
| **Guía Repsol (Spain)** | 1–3 Soles | 16 Feb 2026 | Open list, numeric ID per venue in the URL, small top tier (46 three-Sol, 173 two-Sol) overlapping our Spanish catalogue. Start with 2–3 Soles; Portugal later. |

### Recommended: hold later — the reason it waits is what differs

**Waits on written permission** (the terms forbid reproduction or
commercial use):

| Guide | Why it matters | What blocks it |
|---|---|---|
| **Tabelog Award** (Gold/Silver) | The credential inside Japan, our second-largest country. Stable numeric Tabelog ID per venue. | Tabelog rules Art. 8(3) and 9(1)(1) forbid reproducing its information without consent. User-voted, not inspected. |
| **Forbes Travel Guide** (Five-Star, hotels first) | Inspection-based; heavy overlap with Key hotels; per-property page with address and coordinates. | Terms: personal non-commercial use, no logo, no scraping. Conflict of interest (paid partnerships, consulting, paid "VERIFIED" badges — never shown). |
| **Gambero Rosso** (Tre Forchette only) | Italy's reference guide. | Full guide paywalled; terms unverified (site blocked us). Show only "Tre Forchette 2027", never the /100 scores. |
| **Lekker500** (Top 100 only) | Our home market. | Full list behind login; a full rank across our catalogue would re-use a substantial part of a paid product. |
| **Good Food Guide UK** (World Class / Exceptional) | The UK's historic critics' guide. | Terms bar commercial gain; membership paywall; scale changed recently. |

**Waits on a primary source we could not yet use:**

| Guide | Blocker |
|---|---|
| **OAD** (Europe first) | Publisher's site down / unstable; terms unread; mirrors contain errors. |
| **Black Pearl** (overseas list first) | Primary list is in the Dianping app, in Chinese; needs a Chinese-reading reviewer. Terms unread. |
| **Der Feinschmecker** (Germany) | Open list with full addresses, and now the main German second opinion — but its AGB were not read. Quick to unblock. |
| **White Guide** (Global Masters only) | Openness and terms need a manual browser check. |

**Waits on a catalogue-scope decision.** These are credible national
references in countries where we hold almost no restaurants. Today a new
guide could only annotate restaurants already in the catalogue, so they
add nothing until the product owner decides such restaurants may enter
(as the Selection did on 2026-10-28): **Canada's 100 Best** (open, per-venue
page with address — trivial to match), **Eat Out** (South Africa, no
MICHELIN there), **Gourmet Traveller Top 100** and **Good Food Guide hats**
(Australia; MICHELIN only in South Australia), **Cuisine NZ hats**,
**Golden Chef's Hat** (Greece), **Los 250** (Mexico, print only), the
**India** lists (need a second stable edition), **AAA Five Diamond**
(North America, hotels too), **James Beard** (US winners), **Tatler Best
Asia-Pacific 100**, **UK National Restaurant Awards**, **MENA's 50 Best**
(least independent of the regional lists: Abu Dhabi's tourism department
hosts and funds it).

**Membership, only if a separate treatment is wanted:** **Relais &
Châteaux** (580 members, 65 countries, verified) — as "Member of Relais &
Châteaux", in its own table, never an award, never gold. Otherwise leave out.

### Recommended: leave out

Reader or diner polls (Condé Nast Readers' Choice, T+L World's Best,
Harden's, Blue Ribbon, Falstaff's member-voted scores, Macarfi, Summum,
Prazeres da Mesa, EazyDiner, Tripadvisor, OpenTable); editorial picks
without criteria (CN Hot List and Gold List, TIME, Food & Wine top 10,
Robb Report, NYT/Eater, Telegraph, Tatler UK); defunct or dormant (World
Restaurant Awards 2019, Elite Traveler Top 100, AFR Top 100, The Best Chef
Awards has no 2026 edition); aggregates of what we already show (La Liste
Hotels — it now includes Keys); paid affiliations (Condé Nast Johansens,
LHW, SLH, Preferred, Virtuoso, Mr & Mrs Smith, JRE, Euro-Toques, Les
Grandes Tables du Monde — whose members are nearly all 2–3 star
restaurants we already show); and narrow or unstable guides (L'Espresso,
now 300 restaurants and a new format on 25 Nov; AA Rosettes, which
secondary sources say charges for assessment; Identità Golose, Le Fooding,
Boa Cama Boa Mesa, Tabelog Hyakumeiten, the German second tier). Each has
its reason in the CSV.

## Rules any new guide inherits

- **Never match on name.** A name may generate a candidate; the match is
  confirmed on address, coordinates, phone or website, and stored with its
  evidence and the guide's own ID or URL (see `guide_venue_links` below).
  Guides with a stable per-venue ID or page: La Liste, the 50 Best lists
  (1–50), Repsol, Tabelog, Forbes, Canada's 100 Best, Feinschmecker, G&M
  NL/BE/FR/AT. All others give name and town only, which is workable only
  for short lists, by hand.
- **Facts, not copies.** Showing "Guía Repsol 2026 · 3 Soles" with a link
  to the venue's page is a single fact with attribution. Copying a full
  list — every venue, tier and description — is what the EU database
  right protects. Import only venues in our catalogue, from the
  publisher's own pages, and ask permission first wherever the terms
  reserve commercial use (La Liste, Tabelog, Forbes, Good Food Guide UK,
  Gault&Millau FR).
- **No logos, no symbols.** Text only: no Sol, toque, Forbes star or
  Tabelog badge artwork without a written licence.
- **Never gold.** Gold stays reserved for MICHELIN stars and Keys; an
  Eat Out "star" or a Forbes "Five-Star" is text in the guide's own words.
- **Say what we hold.** As the site does for Gault&Millau today ("not yet
  every market or every restaurant"), every guide gets a coverage note
  per country and edition (`guide_coverage` below).
- **The edition label is the publisher's.** La Liste's November 2026 list
  is its 2027 edition; Gault&Millau NL is still 2026. Check the label on
  each list before import (the QA-217 lesson).

## Schema sketch — not a migration

### What exists and why it is shaped that way

| Source | Table | Shape |
|---|---|---|
| MICHELIN | `award_history` + `restaurants.michelin_stars` / `hotels.michelin_keys` | a tier (higher is better), one row per change |
| The World's 50 Best | `worlds_50_best`, `worlds_50_best_hotels` | a rank (lower is better), one row per venue per year, `list_type` for 51–100 and hall of fame |
| Gault&Millau | `gault_millau_awards`, `gault_millau_special_awards` | a score **and** a toque count, each independently nullable, one row per restaurant per `guide_year`, `recognition_type` for unscored tiers |
| Mantelier Selection | `editorial_selections` | membership with `added_on` / `removed_on`, not an award |

`DATABASE_ARCHITECTURE.md` §3.6 gives the reason these were kept apart:
a rank and a tier are opposed scales, and one `award_value` column would
make `ORDER BY award_value DESC` right for one and wrong for the other.
Every new guide in this inventory is one of exactly four shapes:

1. **rank** — lower is better (the regional 50 Best lists, OAD,
   Lekker500, National Restaurant Awards, Canada's 100 Best);
2. **score** — higher is better, on a guide-specific maximum (La Liste
   /100 — La Liste shows no rank, so we store none);
3. **tier** — a small ordinal, higher is better (Repsol Soles 1–3, Black
   Pearl diamonds 1–3, Tre Forchette, Tabelog Gold/Silver/Bronze, Feinschmecker
   F, Forbes Four/Five-Star, Eat Out stars, Good Food Guide AU hats);
4. **membership** — present or not, with dates (Relais & Châteaux, Les
   Grandes Tables du Monde). A membership is paid or co-opted; it is
   never an award and must never be drawn as one.

### Recommendation: one shared shape for new guides, existing tables untouched

One table per guide (the `gault_millau_awards` route) costs a migration,
a view change, a Dart model and a site component per guide. With six or
more guides to come that is the expensive part, and the per-guide tables
would be near-identical. The opposed-scale problem that justified
separate MICHELIN and 50 Best tables is solved just as well by keeping
rank, score and tier in **separate typed columns**, with a reference row
that says which one a guide uses — never one shared value column.

`award_history`, `worlds_50_best(_hotels)` and `gault_millau_awards` stay
as they are. They are read by shipped builds (CLAUDE.md: a shape a shipped
build reads cannot be removed while that build is in the wild), and
Gault&Millau's score-plus-toque-plus-colour structure is the one case that
genuinely does not fit a single typed column.

A migration would need to create:

**`guides`** — reference table, one row per guide (and per regional list
where the list is its own ranking: Asia's 50 Best ≠ Latin America's).

| Column | Notes |
|---|---|
| `guide_code` `text primary key` | stable human key, e.g. `la_liste`, `oad_europe`, `asia_50_best`, `guia_repsol`, `relais_chateaux` |
| `name` | display name as the publisher writes it |
| `publisher` | |
| `venue_kind` | `restaurant`, `hotel`, `both` |
| `measure` | `rank`, `score`, `tier`, `membership` — check |
| `score_max` / `tier_max` | e.g. 100, 5, 3; NULL when not that measure |
| `tier_labels` `jsonb` | display labels per tier value (`{"1":"1 Sol",...}`) — display only, never parsed back |
| `is_award` `boolean` | false for memberships; the UI may only call `is_award` rows a recognition |
| `homepage_url`, `terms_url` | |
| `added_on` | |

No colour column: gold stays reserved for MICHELIN stars and Keys by
the design rule, so no guide row can ask for it.

**`guide_awards`** — one row per venue per guide per edition.

| Column | Notes |
|---|---|
| `id` `uuid` | |
| `guide_code` `text not null references guides` | |
| `restaurant_id` `uuid references restaurants on delete cascade` | exactly one of the two is set (check) — two typed FKs, not `award_history`'s untyped `entity_id` |
| `hotel_id` `uuid references hotels on delete cascade` | |
| `edition_year` `smallint not null` | the edition label the publisher prints, checked per edition (the QA-217 lesson) |
| `list_name` `text` | sub-list within one guide: `top_100`, `extended_51_100`, `hall_of_fame`, `casual` — per guide vocabulary |
| `rank` `smallint` | NULL unless `measure = 'rank'` |
| `score` `numeric(5,2)` | NULL unless `measure = 'score'`; check `score <= guides.score_max` via trigger or import validation |
| `tier` `smallint` | NULL unless `measure = 'tier'` |
| `distinction_label` `text` | verbatim named distinction, display only (e.g. "Tre Forchette", "Hall of Fame") |
| `source_url` `text` | the page this row was verified against |
| `announced_on` `date` | |
| unique `(guide_code, restaurant_id, edition_year, list_name)` / same for `hotel_id` | partial unique indexes, one per FK |
| unique `(guide_code, edition_year, list_name, rank) where rank is not null` | as `worlds_50_best_year_rank_uidx` |

Absence from an edition is no row, never a zero or a NULL rank — the
`worlds_50_best` rule.

**`guide_venue_links`** — the matching record, so a venue is matched once
and every later edition reuses it.

| Column | Notes |
|---|---|
| `guide_code`, `restaurant_id` / `hotel_id` | as above |
| `external_id` `text` | the publisher's own stable ID or slug, where one exists (Tabelog store number, La Liste ID, Black Pearl / Dianping shop ID) |
| `profile_url` `text unique` | the venue's page on the guide's site |
| `evidence` `text` | why this listing is this venue: address, coordinates, phone, website — never the name |
| `verified_at` | |
| unique `(guide_code, external_id)` | |

This is how "never match on name" stays true at scale: a name may only
generate the candidate; the human confirmation is stored with its
evidence, keyed on the guide's own ID, exactly like
`hotel_restaurants.evidence` and the `worlds_50_best_url` columns.
`worlds_50_best_url` and `gault_millau_url` stay where they are.

**`guide_coverage`** — what we hold, so the site can be as honest about
every new guide as it is about Gault&Millau today.

| Column | Notes |
|---|---|
| `guide_code`, `country_code` (NULL = whole list), `edition_year` | |
| `coverage` | `complete` (every listing matched or logged as out of catalogue) or `partial` |
| `note` | shown verbatim on the site |

**`venue_memberships`** — or memberships as `guide_awards` rows with
`measure = 'membership'` and `edition_year` = year verified. Recommended:
a separate table with `member_since` / `left_on`, mirroring
`editorial_selections`' `added_on` / `removed_on`, because membership is
current state, not an annual edition, and keeping it out of
`guide_awards` makes it structurally impossible to rank or render it as an
award.

**Also needed in the same migration:** RLS enabled on all new tables with
the §15.2 catalogue policy (public select, no client write); no
functions, so no `revoke execute` is needed unless a view-backing
function is added later (then CLAUDE.md's revoke rule applies);
`inclusion_reason` is **not** widened — a restaurant that exists only
because of La Liste or Repsol is a scope decision for the product owner,
not a schema side effect. Today a new guide is shown only for venues
already in the catalogue. A view `venue_guide_awards_current` (latest
`edition_year` per venue per guide, `security_invoker = true`) feeds the
app and the site; the `*_full` views are not widened.

### Why the regional 50 Best lists do not go into `worlds_50_best`

It is tempting, since the publisher and method are the same. But
`worlds_50_best` has `unique (restaurant_id, year)` and a unique
`(year, rank)`: The Chairman cannot be No. 1 in Asia and No. 1 in the
world in the same year, and a restaurant on both lists collides with
itself. The `*_full` views also read "the current rank" as the row of the
maximum year with a rank, so regional rows would silently replace the
global rank shown in shipped builds. Widening that table means changing
constraints and views that installed builds read; a new `guide_awards`
row with `guide_code = 'asia_50_best'` changes nothing they read.

### When a guide should get its own table instead

Only when its fact does not fit one typed column, as Gault&Millau's does
not (score and toques and colour, independently nullable). None of the
guides recommended below has that problem; Falstaff (points plus forks)
comes closest and is not recommended now.

## Proposed build order (for the product owner to decide)

> **Status 2026-11-16:** the product owner chose step 1 first, then the La
> Liste permission request. The shared tables and the three regional lists
> are applied to production (2026-11-16; `supabase/data/enrichment/regional_50_best/
> REGIONAL_50_BEST_REPORT.md`); the La Liste letter is drafted, not sent
> (`guide_inventory/LA_LISTE_PERMISSION_REQUEST.md`).

1. **The three regional 50 Best lists** — Asia (2026), North America
   (2026), Latin America (2026, on 1 Dec). Lowest risk: same publisher
   and review process as the list we hold. This is also the moment to
   create the shared tables below, with a guide whose data we understand.
2. **La Liste 2027** (out 23 Nov) — after a written request for
   permission. The broadest overlap with our catalogue.
3. **Guía Repsol 2026** (2–3 Soles), then the February 2027 gala.
4. **Permission requests in parallel**, since they take weeks: Kakaku.com
   (Tabelog), Forbes Travel Guide, Gambero Rosso, Pijper Media (Lekker),
   and the Gault&Millau NL and BE licensees for wordmark and scores.
5. Separately, a **scope decision**: may restaurants that hold only a
   national award (Canada's 100 Best, Eat Out, Gourmet Traveller…) enter
   the catalogue? Until then those guides stay "hold later".

Not part of this task, and not done: no codes were claimed, no QA ids
were taken, no staging files were written, no migration exists.

