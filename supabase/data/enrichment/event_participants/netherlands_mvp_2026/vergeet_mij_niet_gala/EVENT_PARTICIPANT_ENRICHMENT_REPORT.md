# Vergeet Mij Niet Gala — Event Participant Enrichment Report

Status: research complete, event insert **PREPARED — NOT applied to production**. No Michelin restaurant or hotel relationship prepared (none could be confirmed). Recommendation: **SELECTED — #3 (ultra-premium chef-experience portfolio slot)**.

---

## 1. Event

| Field | Value |
|---|---|
| Name | Vergeet Mij Niet Gala |
| Edition | 1st |
| Date | 6 October 2026 |
| City / Country | Amsterdam, Netherlands (NL) |
| Venue | Hotel Okura Amsterdam, Grand Ballroom |
| Official URL | https://www.vergeetmijnietgala.nl |
| Admission | `paid` — EUR 575/seat or EUR 5,500/table (10 seats), black tie |

Confirmed via the official gala site. This is a genuinely first-edition event (no prior-year press found, consistent with "first edition" framing) — a charity gala with a clear cause (young-onset dementia / Alzheimer's research), high price point, and formal dress code, bringing together (per its own description) "the finest restaurants in the Netherlands" for a 5-course dinner.

## 2. Michelin participation — deliberately not linked (re-confirmed on a second, deeper research pass)

**No specific participating restaurant or chef was named in any source found.** More than that: the organizers themselves explicitly state that programme details, including the chef line-up, **"will be announced in the coming weeks"** — as of this research date, no roster exists to research, not merely one this pass failed to find. Per the enrichment standard's explicit evidence bar ("no vague citations such as 'a search showed...'"), **zero restaurants were matched or linked.**

Presenters (not participating chefs in the dinner sense) are confirmed as SVH Meesterkok/pastry chef Rudolph van Veen and psychologist Eveline Stallaart — hosting roles, not kitchen participation.

**Plausible but explicitly unconfirmed:** the host hotel, Okura Amsterdam, itself contains two restaurants already in the Chasing Stars catalogue — **Ciel Bleu** (2 Michelin stars) and **Yamazato** (1 Michelin star). Given the venue, their participation is plausible, but plausibility is not evidence — recorded as a note for future re-verification, not a match. **Recommended follow-up:** re-check the official site once the announced line-up actually goes live, and re-run the full matching pass at that point.

## 3. Hotel relationship — CONFIRMED not eligible (dedicated catalogue-gap investigation)

A dedicated follow-up pass (`catalogue_gap_pass/`) reconstructed this project's actual, already-established hotel inclusion rule from its architecture docs and migrations: a hotel qualifies for the canonical catalogue only via **1-3 Michelin Keys OR a World's 50 Best Hotels (2023-2025) appearance** — explicitly **not** via hosting a Michelin-starred restaurant ("a starred restaurant inside a hotel is not evidence that the hotel holds a Key" — stated identically in three architecture documents).

Under that rule, Hotel Okura Amsterdam was investigated fresh and found to satisfy **neither** condition: no Michelin Key evidence was found for the hotel itself (only its restaurants carry stars), and it does not appear on the official World's 50 Best Hotels list. **Decision: `NOT_ELIGIBLE_UNDER_CURRENT_RULES`** — not a pending gap, a confirmed negative finding (with one recommended final manual check against `guide.michelin.com/hotels-stays`, which blocks automated fetches). This corrects the prior pass's `HOTEL_CATALOGUE_EXPANSION_CANDIDATE` framing, which had relied on exactly the reasoning ("hosts starred restaurants") the architecture explicitly rejects.

This is distinct from "The Okura Tokyo," a separate property (Japan, 1 Key) that *is* in the catalogue — that name-collision risk was explicitly checked and ruled out.

**No `event_hotels` relationship is prepared or expected** unless Okura Amsterdam's own status changes via a separate, dedicated hotel-catalogue decision — see `catalogue_gap_pass/DUTCH_CATALOGUE_GAP_REPORT.md` for the full evidence trail.

## 4. Quality score (1–5 scale, unweighted average)

| Dimension | Score |
|---|---|
| Gastronomic significance | 4 |
| Exclusivity | 5 |
| Michelin relevance | 1 |
| Travel-worthiness | 4 |
| Consumer accessibility | 3 |
| Chasing Stars brand fit | 4 |
| Source quality | 5 |
| **Average** | **3.71** |

**Editorial reasoning for selection:** despite zero confirmed Michelin ties today, this is the clearest "ultra-premium, exclusive" portfolio fit among all candidates found — the highest price point of any Dutch candidate researched (€575/seat), a genuine black-tie gala format, first-edition novelty, and a strong charitable-prestige angle that itself is a legitimate draw for the target audience. The plausible (if unconfirmed) Ciel Bleu/Yamazato hotel connection is a real reason to expect this event to develop real Michelin relevance closer to the date — worth including now and re-enriching once the lineup is announced, rather than waiting and potentially missing the announcement window.

## 5. Data quality

- No participant CSV was created for this event — genuinely no participant data exists to record yet (avoids an empty/noise file per the task's explicit instruction).
- No Michelin star data fabricated or assumed from the venue alone — the Ciel Bleu/Yamazato connection is explicitly flagged as unconfirmed, not treated as a match.
- `insert_event.sql` contains a plain insert with zero relationship rows and zero literal UUIDs.

## 6. APPLIED AND VERIFIED (production apply, 2026-08-16)

- **Production event id:** `fd23d7f5-ff7c-4caf-ba9b-a17e6397a607`
- **Pre-flight duplicate check:** zero existing rows for this name/date before insert.
- **Post-insert independent re-query:** all fields confirmed to exactly match the prepared payload.
- **Relationship counts:** `event_restaurants` = 0, `event_hotels` = 0 — confirmed correct and expected: no chef line-up has been officially announced, and Hotel Okura Amsterdam is confirmed `NOT_ELIGIBLE_UNDER_CURRENT_RULES` for the canonical hotel catalogue.
- **Runtime verification:** confirmed live via the anon-key PostgREST endpoint — event appears correctly in the full events list, `event_restaurants` REST query returns `[]`.
- **applied_at:** 2026-08-16. **verified_at:** 2026-08-16.

## 7. Future enrichment note

Chef line-up was not yet officially announced at production application time. When the official 2026 chef line-up becomes available:

1. Re-fetch the official source (`vergeetmijnietgala.nl`).
2. Identify chef/restaurant affiliations from the published materials.
3. Apply `EVENT_PARTICIPANT_ENRICHMENT_STANDARD.md` in full (classification, evidence, fresh-FK revalidation).
4. Match against canonical `restaurants` — the plausible-but-unconfirmed Ciel Bleu (2★)/Yamazato (1★) connection is the first thing to re-check, but must not be assumed without official confirmation.
5. Human-review every `EXACT_MATCH` before linking.
6. Add `event_restaurants` rows only after that approval.
7. Verify the `MICHELIN AT THIS EVENT` section renders correctly at runtime once linked.

No automation for this re-check was built in this task, per explicit instruction.
