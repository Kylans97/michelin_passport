# Event Participant Enrichment Standard

Status: **established, operational**. This document is the default process for
enriching any Chasing Stars gastronomic event with participating-restaurant
data. It generalizes the workflow first proven end-to-end on 't Preuvenemint
(2026 edition) — see `supabase/data/enrichment/event_participants/preuvenemint/`
for that pilot's full evidence trail, now marked `APPLIED / VERIFIED` for its
one linked restaurant.

This is a **process standard**, not a retrospective — every rule below is
written to be followed for the *next* event, not just to explain what was
done for Preuvenemint.

---

## 1. Core pipeline (mandatory sequence)

```
OFFICIAL EVENT SOURCE
  ↓
CURRENT-EDITION PARTICIPANT EXTRACTION
  ↓
PARTICIPANT CLASSIFICATION
  ↓
CANONICAL CATALOGUE MATCH
  ↓
SOURCE EVIDENCE
  ↓
HUMAN REVIEW
  ↓
FRESH FK REVALIDATION
  ↓
CONTROLLED LINK
  ↓
POST-WRITE VERIFICATION
```

No step may be skipped, and no step may be reordered — in particular, **FRESH
FK REVALIDATION always happens immediately before the write, never earlier**
(see §8). A pilot run that produced this exact standard caught a real
transcription error at this exact point (§8) — the rule exists because of a
concrete failure mode, not as a theoretical precaution.

## 2. Source hierarchy

**TIER 1 — primary, required:**
- the official event website
- official participant/programme pages
- an official downloadable programme or PDF
- the official event's own social account, **only when** the website doesn't
  provide sufficient participant information on its own

**TIER 2 — supplementary, cross-validation only:**
- an official participating restaurant's own website/social account
  confirming its participation
- a reputable editorial source (a named food/culture publication, not an
  aggregator) confirming current-edition details

**Never used as a standalone source for a match:** generic event
aggregators, user-generated lists, scraped directories, unsourced blogs, or
SEO-summary content. A Tier 2 source may corroborate a Tier 1 finding; it
may never be the sole basis for extracting a participant or accepting a
match.

## 3. Edition safety (hard rule)

**Never mix participants from different event editions.** Every enrichment
run must independently establish, before extracting a single participant
name:
- the event's identity (which production `events` row)
- the edition/year the source content actually describes
- the dates that edition covers
- that the participant source being read is the *current* edition's, not an
  archived or cached page for a prior year

A historical participant page must never silently populate a future or
different-edition event. Where a source page doesn't self-date clearly,
cross-check against a second source (e.g. an editorial article explicitly
about the target edition) before trusting it — exactly how the Preuvenemint
pilot used a dated magazine article to confirm the official roster was
2026-specific and complete.

## 4. Participant classification

Every extracted participant must be classified by business/entity type
before any matching is attempted. Non-exhaustive examples:

`restaurant` · `hotel_restaurant` · `chef` · `private_chef` · `caterer` ·
`winery` · `wine_merchant` · `bar` · `producer_vendor` · `sponsor` ·
`organization` (e.g. a student association) · `specialty_shop` · `other`

**Only `restaurant` (and `hotel_restaurant`, matched to the restaurant, not
the hotel — see §6) are eligible for `event_restaurants` linking.** Do not
force every gastronomic participant into the restaurant model — a wine
merchant, a coffee vendor, or a sponsor activation stand is real data worth
recording (see §9), but it is not a restaurant, and recording it as one
would corrupt the one signal `event_restaurants` exists to carry.

## 5. Match classification

Every `restaurant`-type candidate receives **exactly one** of:

| Status | Meaning | May link automatically? |
|---|---|---|
| `EXACT_MATCH` | Strong identifying evidence — name (normalized), city, and at least one further independent signal (chef, address, Michelin URL, website) all agree | **Yes**, after human review (§7) |
| `PROBABLE_MATCH` | Likely the same restaurant, but one important identifier still needs confirmation | **No** — review required, not a default-link status |
| `MANUAL_REVIEW` | Conflicting or genuinely ambiguous evidence | **No** |
| `NO_MATCH` | No production restaurant found for this participant | No — becomes a catalogue-expansion candidate (§10), never linked |
| `NOT_A_RESTAURANT` | Not eligible for `event_restaurants` at all (§4) | No |

**`PROBABLE_MATCH` is not permission to link.** Only `EXACT_MATCH` may
proceed toward a production write, and even then only after human review.

## 6. Matching signals

Use multiple independent signals wherever available — never rely on fuzzy
name similarity alone when any ambiguity exists:

normalized name · city · address · official website · Michelin URL ·
coordinates · chef/owner identity · an existing hotel relationship (a
hotel's named restaurant, matched to the restaurant record, never the
hotel) · any other canonical identifier the catalogue exposes

The more signals agree, the stronger the match. A single agreeing signal
(name alone) is never sufficient for `EXACT_MATCH` when the name is common
or when a plausible same-named-different-place restaurant exists elsewhere
in the catalogue — the pilot's own `Le Philippe` case (a same-named
restaurant genuinely exists on the Michelin Guide in a different country)
is the concrete example: it was resolved by directly querying the full
catalogue for any restaurant named "Philippe" and confirming neither
matched, not by assuming the name was unique.

## 7. Evidence requirements

Every proposed relationship — whether ultimately linked or left as
`NO_MATCH`/`MANUAL_REVIEW` — must retain, at minimum:

- event identity and edition
- participant display name (as shown by the source, verbatim)
- canonical restaurant identity (name, `restaurant_code`, UUID) if matched
- official source URL
- source evidence (quoted/paraphrased text, not just a URL)
- matching reasoning, in plain language — not a bare similarity score
- `verified_at`
- review status

A future developer or agent reading only the evidence artifact must be able
to answer: **why do we believe this restaurant participated in this
event?** If that question can't be answered from the artifact alone, the
evidence is insufficient — regenerate it before proceeding.

## 8. Fresh FK revalidation (hard rule)

**This rule exists because of a real, caught failure**, not a theoretical
one: while preparing the Preuvenemint pilot's linking SQL, a restaurant
UUID was mistranscribed — the id recorded for "Tout a Fait" was actually
**Au Coin des Bons Enfants**'s id, copied from an adjacent row in the same
query result. It was caught only because a validation pass existed and
re-queried the recorded id, found the returned `name` didn't match, and
corrected it before anything was applied. No incorrect id ever reached
production — but nothing about the CSV, the prepared SQL file, or the
earlier terminal output would have caught it on its own.

**Therefore: immediately before every production relationship write —**

1. Re-resolve the event fresh, from production, using a stable identifier
   (name + date/location, or its known UUID re-verified).
2. Re-resolve the restaurant fresh, from production, using its canonical
   identifier (`restaurant_code`, never a UUID alone).
3. Independently confirm identity: name, city, status, and any other field
   the match evidence depends on, all read from *this* fresh query.
4. Use only the UUID returned by *this* fresh lookup for the write.

**Never trust a UUID merely because it appears in a CSV, a previous report,
copied terminal output, a generated SQL file, or an LLM's own prior
response.** Each of those may be stale, or may have been mistranscribed
exactly as happened here. The fresh lookup immediately preceding the write
is the only UUID source of truth for that write.

## 9. Michelin recognition — canonical source only (hard rule)

**Event sources establish participation. They never establish Chasing
Stars' own Michelin recognition.** Never copy any of the following from an
event website, programme, or social post into `event_restaurants` or any
other write:

- Michelin stars
- Gault & Millau score
- World's 50 Best ranking
- Hall of Fame status
- Michelin Keys

Recognition always comes from the canonical venue record. For Event Detail
today, that is `Restaurant.michelinStars`, read fresh off `restaurants_full`
at render time via the existing `EventsRepository.loadLinkedVenues` →
`MichelinAtEventSection` path — never a value stored on the join row itself
(`event_restaurants` intentionally carries no recognition columns at all,
matching how `hotel_restaurants` never duplicates award data either). An
event page's own Michelin mention may be used only to *corroborate* that a
match is a genuine, currently-recognized establishment — never as the
source of the star count.

## 10. Historical recognition — documented MVP limitation

The current Event UI always shows a restaurant's **current** canonical
Michelin stars, resolved at render time. For an upcoming or current event
this is reasonable and matches how the app works everywhere else (a
restaurant's recognition is always "as of now," never a frozen snapshot,
except where the product explicitly captures history — e.g.
`Visit.keysAtVisit`). For a genuinely historical event edition, current
recognition may differ from what a restaurant held at that edition's own
date — this standard does not solve that, and no enrichment run should
claim historical accuracy it doesn't have. Do not build historical
event-award snapshotting as part of routine enrichment; that would be its
own dedicated data-model decision, undertaken only if the product
explicitly needs to browse genuinely historical event editions.

## 11. Catalogue-expansion separation (hard rule)

**Event participant enrichment must never create restaurants.** A
`NO_MATCH` restaurant-type participant — a real, verifiable restaurant that
simply isn't in the Chasing Stars catalogue yet — becomes a **catalogue
expansion candidate**, recorded with its evidence, and nothing more. It may
later be picked up by a separate, dedicated Restaurant Catalogue Expansion
workflow (out of scope for this document), which has its own review bar for
what belongs in the canonical catalogue at all (this app is Michelin/
recognition-curated, not a general restaurant directory — see the pilot's
own finding that Maastricht has 1,362 candidate restaurants city-wide but
only 5 meet the catalogue's inclusion bar). Keeping these separate prevents
one event's worth of research pressure from quietly lowering the
catalogue's own bar.

The Preuvenemint pilot's own three `NO_MATCH` restaurants — **Noon**, **Le
Philippe**, and **Enigma** — are recorded here as a concrete historical
example of this rule in practice, not as a standing exception to it: all
three remain unlinked and uncreated pending a separate catalogue-expansion
decision.

## 12. Idempotency

Every relationship application must:

- check for an existing `(event_id, restaurant_id)` pair before writing
  (§ Phase 5 of the apply workflow)
- rely on the table's own `unique(event_id, restaurant_id)` constraint,
  never a manual duplicate-check substitute
- use conflict-safe SQL (`on conflict (event_id, restaurant_id) do
  nothing`) so a re-run is always a safe no-op
- verify the final row count for that event immediately after writing
- re-resolve the written row via a JOIN back to both canonical entities,
  not just trust the `INSERT`'s own return value

Repeated enrichment runs — including accidental re-runs of the same
prepared SQL file — must never create duplicate relationships.

## 13. Post-write verification

A successful `INSERT` (or a conflict-safe no-op) is **not, by itself,
sufficient evidence that the relationship is correct and usable.** After
every production link application, independently verify:

- the relationship exists (row count for that event)
- it resolves via `JOIN` to the exact intended event and exact intended
  restaurant
- the canonical restaurant remains valid (`status = 'open'`, or otherwise
  not withdrawn) at write time
- no unexpected duplicate exists
- **the actual UI runtime query path** — not a convenient alternative
  query shape — successfully resolves the relationship. For Event Detail
  today that means mirroring `EventsRepository.loadLinkedVenues`'s exact
  two-query shape (`event_restaurants` → `restaurant_id` list →
  `restaurants_full.select(restaurantFullColumns).inFilter('id', ids)`),
  and ideally also exercising the real PostgREST REST endpoint with the
  app's own anon key, not only a privileged admin connection — RLS and the
  PostgREST schema cache are part of the real path, and a privileged
  connection can silently mask a permissions problem the real app would
  hit.

## 14. Re-run / event update handling

Event rosters change between visits to the same source. A future re-run
against an already-enriched event must never blindly re-apply a prior
result. Compare the existing official roster against the newly fetched one
and classify every participant as:

- `ADDED` — new on the source, not yet in any prior enrichment artifact
- `UNCHANGED` — present in both, no new evidence needed
- `REMOVED_FROM_SOURCE` — was present before, no longer appears
- `AMBIGUOUS` — the source changed in a way that doesn't cleanly map to
  the above (renamed listing, restructured page, merged/split stand)

**Do not automatically `DELETE` an existing `event_restaurants` row solely
because a name disappeared from a website.** A site may have moved content,
be temporarily incomplete, or restructured its programme page without the
restaurant actually having withdrawn. Removal is a reviewed decision, never
an automatic side effect of a re-scrape.

## 15. Automation boundary

**Safe to eventually automate:**
- fetching and normalizing the official roster page
- edition-to-edition roster diffing (§14)
- city/country-scoped candidate lookup against the canonical catalogue as a
  pre-filter (narrowing, never deciding)
- the mechanical duplicate/FK/status validation pass (§12–13) — this should
  *always* run, automated or not
- evidence-artifact generation in the established CSV/Markdown shape

**Must remain human-reviewed, indefinitely:**
- final identity resolution for every `EXACT_MATCH` before its first
  production application
- everything landing in `PROBABLE_MATCH` or `MANUAL_REVIEW`
- participant business-type classification wherever it isn't obvious from
  the name alone (the pilot needed real judgment for a steakhouse/cocktail
  pop-up concept and a shared two-vendor seafood stand — a naive automated
  classifier would likely mishandle at least one of these per event)
- conflicting-evidence resolution
- production write approval itself

**Do not build a generalized crawler now.** The pilot needed exactly two
official-page fetches, one cross-validation fetch, and three targeted
verification searches for a ~30-stand event. A fixed, repeatable manual
checklist is sufficient at this scale; revisit only if this process is run
across many more events with materially larger rosters and the manual
steps become the genuine bottleneck.

## 16. Future entity types — documented, not built

The pilot's raw participant data included wine merchants, a coffee vendor,
bars, a student association, a delicatessen, and sponsor activations —
real gastronomic-event data with no home in the current schema beyond the
generic `participant_source.csv` shape. Future product direction may
eventually want first-class support for chefs, private chefs, wineries,
producers, and culinary brands as their own entities. **Do not create those
schemas now.** `event_restaurants` remains restaurant-specific by design
(§4); broadening it, or adding parallel tables for these other entity
types, is a separate, dedicated data-modeling decision this document does
not make.

## 17. Private Chef provenance — architectural note only

No Private Chef feature exists, and this document does not implement one.
For whenever that workstream begins, the same evidence-and-provenance
principle established here should be reusable: a verified Private Chef's
background credentials (e.g. "formerly head chef at Restaurant X") should
be modeled as an evidence-backed relationship to the **canonical**
`Restaurant` record — never a duplicated or re-typed copy of that
restaurant's name/recognition — navigating to the existing
`RestaurantDetailScreen` exactly as `MichelinAtEventSection` does today,
and reading that restaurant's **current** canonical recognition at render
time rather than freezing it. Such a relationship would also need to
distinguish *historical employment* (a fact about the past, evidenced and
dated) from *current restaurant recognition* (read live, same as
everywhere else in this app) — the same distinction §10 already draws for
events. No table, model, or UI code for this exists or should be created
as part of this standard.

## 18. Global-facing completeness — canonical entities, never local duplicates

Chasing Stars is a global-facing product. Restaurant and Hotel are shared
canonical entities — Events, Trips, Passport, Guides, Community, and any
future Private Chef provenance feature must all be able to resolve against
the *same* Restaurant/Hotel objects, not feature-specific copies of them.

When event research surfaces a venue that seems to be missing, the required
path is always:

```
EVENT RESEARCH → CATALOGUE GAP → SEPARATE CANONICAL VALIDATION
  → CANONICAL ENTITY (if it earns inclusion on its own merits)
  → EVENT RELATIONSHIP
```

**Never:** `EVENT → CREATE CONVENIENT PLACEHOLDER VENUE`. A venue is never
added to `hotels`/`restaurants` *because* an event needs it — it is added
(by a separate, dedicated catalogue workstream) only if it independently
satisfies that catalogue's own existing inclusion rule, exactly as if no
event had ever mentioned it. If it doesn't qualify, the event still ships
— simply without that relationship — rather than lowering the catalogue's
bar to make one event's data look more complete.

This is not hypothetical: a hotel hosting a Michelin-starred restaurant is
explicitly **not**, by itself, evidence that the hotel qualifies for the
canonical `hotels` table (see `docs/Architecture/Michelin_Database/
DATABASE_ARCHITECTURE.md`'s own hotel-scope rules) — "famous host of a
starred restaurant" and "canonical Key/W50B hotel" are different
questions, and event enrichment must never conflate them.

---

## Applying this standard: quick checklist

For the next event enrichment pass, in order:

1. Identify the exact production `events` row (§3) — stop if it doesn't
   resolve uniquely.
2. Fetch the official current-edition source(s) (§2) — confirm edition/
   dates match the production row before extracting anything.
3. Extract every participant verbatim, with source evidence per row (§7).
4. Classify every participant by entity type (§4).
5. For `restaurant`-type participants only, match against the catalogue
   using multiple signals (§6), and classify the result (§5).
6. Record `NO_MATCH` restaurants as catalogue-expansion candidates (§11) —
   do not create them.
7. Human review every `EXACT_MATCH` (and anything in `PROBABLE_MATCH`/
   `MANUAL_REVIEW`, though those never proceed to linking here).
8. Immediately before writing: fresh FK revalidation for both entities
   (§8) — never reuse an earlier UUID.
9. Duplicate check (§12), then the controlled write.
10. Post-write verification through the real UI query path, including the
    actual REST endpoint (§13).
11. Update the evidence artifact with applied status — never rewrite the
    original research evidence itself (preserve auditability).
