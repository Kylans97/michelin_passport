# Lucas de Jager / Jagers Catering — Private Chef Curation Report

**Status: APPLIED to production 2026-08-18.** Lucas de Jager is now the
first published Private Chef (`private_chefs.id =
2e2089b0-f94d-46f5-923b-4ebf9135a5a1`), with a confirmed Parkheuvel
restaurant background and a De Rooi Pannen education background. See §23
for the final applied state. Sections 1–21 are the original Step 2A
research/proposal, preserved as written. §22 records what changed in
Step 2B before apply (permission, photo/education architecture, About
length check, Parkheuvel confirmation).

This is Private Chefs Step 2A. It follows the same guardrail discipline as
every other enrichment workstream in `supabase/data/enrichment/` (see that
directory's own `README.md`): no `supabase db push`, no SQL against
production, no migrations, no changes to `lib/`, nothing committed until
explicitly approved — and, specific to this domain, no fact is promoted to
publishable status without a traceable source, and no `private_chef_id`
UUID exists yet since no row has been inserted.

---

## 1. Sources consulted

- **Official website**: `https://jagers-catering.nl` — homepage, `/ons-concept/`,
  `/veelgestelde-vragen/` (FAQ), `/wijn-arrangement/`. Fetched directly.
- **Instagram**: `https://www.instagram.com/jagerscatering/` — profile exists
  and is linked from the official site; bio/content not accessible without
  authentication (same limitation found during Step 0's original research).
  Used only to confirm the link is real, never scraped, never imported.
- **Web search** for independent corroboration of the Parkheuvel claim:
  `"Lucas de Jager" Parkheuvel sommelier chef`, `"Lucas de Jager" chef
  Rotterdam Parkheuvel LinkedIn`, `"Lucas de Jager" "Jagers Catering"
  Breda`.
- **Production database** (`supabase db query --linked`, read-only): resolved
  the canonical Parkheuvel restaurant row.

No forum posts, AI-generated summaries, unsourced biography pages, or
content-farm aggregators were used as evidence for any field.

---

## 2. Evidence table

See `evidence.csv` for the complete, structured version (one row per
field/claim, with classification and publication-safety). Summary:

| Field | Claim | Classification | Publication safe? |
|---|---|---|---|
| `display_name` | Lucas de Jager | VERIFIED_PRIMARY | YES |
| `business_name` | Jagers Catering | VERIFIED_PRIMARY | YES |
| `home_city` | Breda | VERIFIED_PRIMARY | YES |
| `home_country_code` | NL | VERIFIED_PRIMARY | YES |
| `service_area_text` | The Netherlands and Belgium | VERIFIED_PRIMARY | YES |
| `travel_available` | true | VERIFIED_PRIMARY | YES |
| `wine_pairing_available` | true | VERIFIED_PRIMARY | YES |
| Parkheuvel employment/experience | "from my youth and experience at Parkheuvel" | VERIFIED_PRIMARY (single source) | **NO** |
| Sommelier-at-two-star-restaurant pedigree | tied to the same Parkheuvel claim | VERIFIED_PRIMARY (single source) | **NO** |
| `minimum_guests` / `maximum_guests` | — | NOT_FOUND | n/a (null) |
| pricing (any field) | — | NOT_FOUND | n/a (null) |
| `languages` | — | NOT_FOUND | n/a (null) |
| `profile_image_url` | — | NOT_FOUND (no rights-cleared asset) | n/a (null) |
| User's personal-dinner account | food/wine excellent, adapted well to the host | USER_SUPPLIED_INTERNAL | NO (internal input only) |

**Nothing here was silently promoted** from `USER_SUPPLIED_INTERNAL` to
publication-safe. The user's own dinner is a genuine, valid reason to
curate this chef in the first place — it is not, on its own, evidence for
any specific public field value.

---

## 3. Identity

`display_name` = "Lucas de Jager" and `business_name` = "Jagers Catering"
are both VERIFIED_PRIMARY, consistent across every page of the official
site (the site's own logo asset is even filed as `Logo-lucas-de-jager.jpg`).
The site presents Lucas as the personal chef and "face" of the business —
copy reads "Het gezicht achter de smaak" (the face behind the taste) —
without stating a formal title. A LinkedIn search result (not the full
profile — LinkedIn blocked direct access, HTTP 999) shows a snippet: "Lucas
de Jager - Eigenaar Jagerscatering" (Owner). This is recorded in
`evidence.csv` for completeness but **not used for any proposed value** —
`private_chefs` has no title/role column, so it's not applicable to any
field regardless of how it's classified.

The approved public hierarchy — person first, business second — is
preserved exactly: **Lucas de Jager** / *Jagers Catering*, never the
reverse.

## 4. Website / Instagram

Both verified and canonical:
- `website_url`: `https://jagers-catering.nl`
- `instagram_url`: `https://www.instagram.com/jagerscatering/`

Instagram is used only as a link. No feed content, follower count, or
caption was imported or is referenced anywhere in the proposed profile.

## 5. Biography

**The available sources are meaningfully thinner than a full professional
biography would need** — there is no independently verifiable career
narrative, no confirmed prior restaurant, no confirmed dates. The proposed
biography (see `proposed_profile.json`) is deliberately built ONLY from
what's independently supportable: business identity, location, service
area, the full-service on-site format, and the wine-forward, personally-
selected-rather-than-standard-list approach. **It deliberately omits any
Parkheuvel/career-pedigree reference** — including that reference would
mean Chasing Stars asserting an unverified factual claim as its own
editorial copy, exactly what this task's evidence bar exists to prevent.
If/when the Parkheuvel claim is independently verified (§9), the biography
can be meaningfully strengthened with real career context — not before.

No superlatives ("world-class," "award-winning," "one of the best") appear
anywhere, since none is independently established.

## 6. Personalization

The user's own account (the dinner "adapted very well to the host's
wishes") is genuine internal curation input — it is part of *why* this
chef is being curated at all — but is not itself proposed as public copy.
Instead, `personalization_note` is grounded in the official FAQ's own
general service description ("dietary needs and allergies are inventoried
in advance to customize each guest's plate"), which is independently
verifiable and says something real and specific without relying on a
private anecdote.

## 7. Wine capability

`wine_pairing_available = true` is independently verified — there is a
dedicated "Wijn arrangement" page describing per-course pairing and
single-bottle options, entirely separate from the user's one-dinner
experience. `wine_note` is written from that page's own service
description. The sommelier/Parkheuvel pedigree claim tied to wine
selection is **excluded** from the public `wine_note` for the same reason
it's excluded from the biography — single-source, unverified.

## 8. Location / service area

`home_city` = "Breda" and `service_area_text` = "The Netherlands and
Belgium" are both stated identically on multiple pages of the official
site (not inferred from Instagram tags, a single event, or restaurant
provenance). `home_country_code` = "NL" follows directly. `travel_available
= true` is supported by the FAQ's own explicit per-km travel-cost line
(€0.35/km), confirming travel is a real, built-in part of the service
model, not assumed from the service-area text alone.

## 9. Guest range

**Not found.** No page checked (homepage, concept, FAQ, wine arrangement)
states a minimum or maximum group size. `minimum_guests`/`maximum_guests`
are proposed as `null` — not inferred from photos or event context.

## 10. Pricing

**Not found.** No per-person or package price is published anywhere. The
only public pricing-adjacent fact is a €0.35/km travel surcharge, which
is not a per-person/package price and is not proposed as `pricing_from`.
`price_on_request = true` is proposed; `pricing_from`/`pricing_currency`/
`pricing_unit` are all `null`.

## 11. Languages

**Not found**, and deliberately not inferred. The site is Dutch-language
only, but per this task's own explicit instruction, "Dutch because
Netherlands" or "Dutch because the website is Dutch" are not acceptable
inferences. `languages` is proposed as `null`.

## 12. Profile image

**Proposed as `null`.** No rights-cleared image asset for Lucas/Jagers
Catering exists anywhere in this repository, and none was downloaded or
imported from the website or Instagram — doing so without explicit rights
clearance would be exactly the risk this task's own instruction (§14)
flags. `PrivateChefAvatar`'s existing placeholder fallback (see
`lib/features/private_chefs/widgets/private_chef_avatar.dart`) already
handles a `null` `profile_image_url` correctly — no code change needed.
**Documented future requirement**: obtain an explicitly approved portrait
directly from Lucas / Jagers Catering before this field is populated.

---

## 13. Parkheuvel provenance — the central open question

**Claim**: Jagers Catering's own homepage states, in Lucas's own voice:
"Vanuit mijn jeugd en ervaring bij het tweesterren restaurant Parkheuvel
breng ik passie en kwaliteit naar elke maaltijd" ("From my youth and
experience at the two-star restaurant Parkheuvel, I bring passion and
quality to every meal"). The site's wine-arrangement page separately
describes a "sommelier in een tweesterrenrestaurant" background, which in
context refers to the same claim.

**Independent verification attempted**: web searches for "Lucas de Jager"
combined with "Parkheuvel," "sommelier," "chef," "Rotterdam," and
"LinkedIn" surfaced:
- Parkheuvel's own current/past-sommelier coverage (De RestaurantKrant,
  ChefsFriends): names Jean Luc Etienne, Jaco van Hensbergen (past), and
  Nick Van Den Heuvel (current Head Sommelier) — **Lucas de Jager is not
  named in any of this coverage.**
- A LinkedIn profile matching his name exists ("Lucas de Jager - Eigenaar
  Jagerscatering") but the full profile — and any work-history section
  that might independently list Parkheuvel — was inaccessible (LinkedIn
  returned HTTP 999, its standard anti-bot response to unauthenticated
  fetches).
- No third-party interview, culinary-press profile, or independent
  publication mentioning Lucas de Jager was found anywhere.

**Conclusion**: the Parkheuvel claim remains **VERIFIED_PRIMARY on a single
first-party source only** (Jagers Catering's own marketing copy) — it has
not reached VERIFIED_CROSS_SOURCE. The absence of his name in Parkheuvel's
own published sommelier history is *not* a contradiction (that coverage is
a handful of hiring-announcement articles, not an exhaustive staff
register), but it is not corroboration either. Per this task's own explicit
instruction ("The Parkheuvel statement must be independently verified
before publishing provenance") and `PRIVATE_CHEFS.md`'s own established
evidence/security-boundary reasoning (a business's own marketing copy is
corroborating evidence, not proof), **this does not meet the bar to
publish a canonical `private_chef_restaurant_history` row.**

**What would resolve this**: direct confirmation from Lucas himself (the
cleanest path — this is, after all, his own profile being published), a
Parkheuvel-side confirmation, or an independent third-party
interview/publication naming him specifically.

## 14. Canonical Parkheuvel resolution (restaurant identity only)

Queried fresh against production immediately before writing this report —
**not** reused from any earlier session's notes:

| Field | Value |
|---|---|
| `id` | `90d2b4ae-2b39-4bed-beec-31d6008a7ea8` |
| `restaurant_code` | `rest_0079` |
| `name` | Parkheuvel |
| `city` | Rotterdam |
| `country_code` | NL |
| `status` | open |
| current `michelin_stars` | 2 |

This is a **unique, unambiguous match** — exactly one row named
"Parkheuvel" exists in `public.restaurants`. This resolves *which*
Parkheuvel exists in the catalogue; it does **not** independently verify
*that* Lucas worked there (§13, above — a separate, unmet question). The
current 2-star count is recorded here for reference only and — per the
hard Michelin-attribution rule — **must never be copied into any
`private_chefs` or `private_chef_restaurant_history` column**; it would
only ever be read dynamically from the `Restaurant` row itself if/when a
provenance link is eventually published.

## 15. Michelin attribution check

Explicitly reconfirmed for this specific profile:
- `private_chefs` has no star/Key column — nothing to write regardless.
- No provenance row is being proposed at all in this task (§13), so
  `StarRow` will not render anywhere on this profile once published — the
  Provenance section will simply be absent until a verified row exists
  (`PrivateChefDetailScreen` already omits the section entirely when
  `getRestaurantHistory()` returns empty — no code change needed).
- The biography and `wine_note` deliberately never mention "Michelin,"
  "two-star," or "Parkheuvel" — see §5/§7 for why.
- If Parkheuvel provenance is verified later, the eventual row must still
  never carry a star value of its own — recognition renders only from the
  live, resolved `Restaurant.michelinStars`, exactly as
  `PrivateChefProvenanceRow` is already built and tested to do.

---

## 16. Publication-readiness classification

**READY_WITH_MISSING_OPTIONAL_FIELDS** for the core profile — identity,
business identity, location, service area, wine capability, and links are
all independently verified; guest range, pricing, languages, and photo are
missing but optional (their absence does not undermine credibility, per
`PRIVATE_CHEFS.md`'s own publication standard).

**BLOCKED_BY_PROVENANCE** for the Restaurant Provenance section
specifically — not the whole profile. Per this task's own instruction,
*"the first profile may be published without provenance if necessary"* —
the proposal reflects exactly that: publish the profile now, add
provenance later once independently verified.

**NEEDS_DIRECT_CHEF_CONFIRMATION** — see §17 below. This is a distinct
gate from data completeness.

## 17. Technical readiness vs. content-permission readiness

These are deliberately kept separate, per this task's own instruction:

- **TECHNICALLY_READY: YES.** Every proposed field maps to a real column,
  every non-null value has a traceable, classified source, the slug is
  valid and collision-free, and the insert SQL is confirmed syntactically
  correct (validated locally, see §19).
- **CONTENT_PERMISSION_READY: NOT YET.** No direct confirmation exists
  that Lucas de Jager has agreed to (a) being profiled on Chasing Stars at
  all, (b) the business name "Jagers Catering" being used publicly under
  his name, (c) this specific biography text, or (d) his own website/
  Instagram links being surfaced this way. This is a genuine, separate
  permission step this report cannot substitute for — flagged, not
  concluded (no legal claim is being made either way).

---

## 18. Proposed database rows

**`private_chefs`** — full payload in `proposed_profile.json`; the exact
INSERT is in `insert_private_chef.sql` (**NOT APPLIED**). Every `null`
field is individually explained in that JSON's own
`_deliberately_null_fields` block.

**`private_chef_restaurant_history`** — **no row proposed.** See
`proposed_provenance.csv`, which records the resolved canonical Restaurant
(§14) for reference but marks the whole row `PENDING_VERIFICATION` with an
explicit `blocking_reason`. Nothing here should be inserted until §13 is
resolved.

---

## 19. Local, non-production validation performed

- **JSON validity**: `proposed_profile.json` parses cleanly.
- **CSV validity**: `evidence.csv` (22 rows × 7 columns) and
  `proposed_provenance.csv` (2 rows × 12 columns) both well-formed, no
  malformed rows.
- **SQL syntax + column-shape check**: the full Step 1 migration was
  applied to the local Docker Postgres instance in a transaction, then
  `insert_private_chef.sql` was run against it (with `session_replication_role
  = replica` set locally only, to bypass the FK check against the local
  `countries` table — which is empty in this dev environment, a known,
  pre-existing local-data gap unrelated to this task, not a defect in the
  SQL). The insert succeeded and the resulting row was verified
  column-by-column to match the proposal exactly (`slug`, `display_name`,
  `business_name`, `publication_status='published'`, `home_city='Breda'`,
  `home_country_code='NL'`, `wine_pairing_available=true`,
  `price_on_request=true`, `languages`/`minimum_guests`/`pricing_from`
  all null). **Local database was then fully reverted** — the temporary
  tables (and the test row with them) were dropped, restoring local to
  exactly its prior state. **Zero production writes occurred at any
  point.**
- **Slug collision check**: `select slug from public.private_chefs where
  slug = 'lucas-de-jager'` against production returned zero rows (the
  table is empty entirely, confirmed separately).
- **Duplicate check**: production `private_chefs`/
  `private_chef_restaurant_history`/`private_chef_enquiries` all confirmed
  `0` rows immediately before this report was written.

---

## 20. App preview (conceptual — no code run, no production data)

Reasoned directly against the actual, already-shipped Step 2 code
(`private_chef_detail_screen.dart`, `private_chef_hero.dart`,
`private_chef_experience_section.dart`, `private_chef_connect_section.dart`,
`private_chef_provenance_row.dart`) — not a guess:

| Section | Renders? | Why |
|---|---|---|
| Landing row | Yes | `display_name` + `business_name` + "Breda, NL" — `PrivateChefRow` renders all three since all are non-null |
| Hero | Yes | "PRIVATE CHEF" eyebrow, "Lucas de Jager", "Jagers Catering" subordinate line, "Breda, NL"; `CsImagePlaceholder` fallback since `profile_image_url` is null |
| About | Yes | `biography` is non-null and non-blank |
| Restaurant Provenance | **Omitted entirely** | `getRestaurantHistory()` returns an empty list — no provenance row exists — `PrivateChefDetailScreen._body()` only includes the section `if (hasProvenance)`, which is false |
| The Experience | Yes | Renders: "Available across The Netherlands and Belgium." (service area), "Menus are shaped around..." wait — `personalizationNote` renders verbatim as its own line, "Wine pairing available — Wines are personally selected..." (wine note), "Price on request." No guest-range line (`formatGuestRange` returns null since both bounds are null). No languages line (empty list) |
| Connect | Yes | Both "Instagram" and "Website" `SubtleTextAction` rows render |
| Request an Experience | **Not rendered** | Step 3, not built — matches every other chef profile today |

No star, no rating, no "Chasing Stars Selected" badge, no price badge —
all correctly absent, matching the already-tested, already-approved Step
2 UI exactly as-is. **No code change is required** for this profile to
render correctly.

---

## 21. Files in this directory

- `PROFILE_RESEARCH_REPORT.md` — this file.
- `evidence.csv` — structured, per-field evidence table.
- `proposed_profile.json` — the proposed `private_chefs` payload.
- `proposed_provenance.csv` — the Parkheuvel resolution + explicit
  `PENDING_VERIFICATION` status (no row proposed for insert).
- `insert_private_chef.sql` — **NOT APPLIED — HUMAN APPROVAL REQUIRED**,
  syntax-validated locally only (§19).

---

## 22. Step 2B update — permission, photo architecture, final decision

**Profile permission**: the user has confirmed Lucas de Jager has agreed
to being included in Chasing Stars. Recorded plainly in `evidence.csv` as
`profile_permission` — no formal legal-consent language is asserted, only
this confirmation, per explicit instruction. `PROFILE_PERMISSION:
APPROVED_BY_CHEF`.

**Photography permission**: **not granted.** No specific images have been
approved, and no image files for Lucas/Jagers Catering exist anywhere in
this repository (confirmed by a fresh repository search immediately
before this update). `profile_image_url` stays `null` and zero
`private_chef_photos` rows are proposed — the existing avatar/hero
placeholder is the expected, correct result, not a gap blocking
publication.

**Fact revalidation**: the official site was re-fetched immediately
before this update. Display name, business name, Breda base, NL+Belgium
service area, and the Instagram handle are all unchanged from §1–15
above — no new material facts, no broadened research.

**About length check**: the proposed biography (§5, unchanged) is
**432 characters / 68 words** — inside the 350–650 editorial target and
well under the 900-character hard maximum now enforced at the database
layer by `private_chefs_biography_max_length`
(`supabase/migrations/20260818120000_add_private_chef_photos_and_biography_limit.sql`).
No change needed.

**Parkheuvel provenance — decision at the time this section was written
(SUPERSEDED — see §23): still PENDING, not inserted.**
General permission to be included is not, and must not be treated as, a
re-confirmation of the specific Parkheuvel employment claim — the task's
own instruction is explicit on this point, and nothing in this task's
context states that Lucas separately, specifically re-confirmed the
Parkheuvel detail. The standing evidence bar from §13 (independent
verification as a precondition of a publishable provenance row — see
PRIVATE_CHEFS.md §41's own "verification is a precondition of the row
existing," not a first-party claim plus general permission) is unchanged
and unmet. The canonical Parkheuvel restaurant resolution was re-queried
fresh immediately before this update and is unchanged: `id =
90d2b4ae-2b39-4bed-beec-31d6008a7ea8`, `restaurant_code = rest_0079`,
Rotterdam, NL, 2 Michelin stars, status `open`. **No
`private_chef_restaurant_history` row is proposed for this apply.** The
profile publishes without provenance, exactly as PRIVATE_CHEFS.md's own
architecture anticipates.

**Idempotency check (Step 2B, immediately before apply)**: `private_chefs`
table confirmed empty (0 rows) in production; zero rows match slug
`lucas-de-jager`; zero rows match `display_name`/`business_name` for
Lucas de Jager / Jagers Catering. No duplicate risk.

**Final proposed apply** (unchanged payload from §18, `publication_status
= 'published'` since inclusion is approved): `private_chefs` +1,
`private_chef_restaurant_history` +0, `private_chef_photos` +0,
`private_chef_enquiries` +0.

---

## 23. Step 2B FINAL — applied 2026-08-18

**Background architecture change (before apply)**: the product direction
was extended — a chef's relevant background includes hospitality/
service/education, not only kitchen positions. The user-facing section
was renamed "Restaurant Provenance" → **"Background"**. Architecturally,
`private_chef_restaurant_history` was kept exactly as designed (Option
A — see `supabase/migrations/20260818130000_add_private_chef_education.sql`'s
own header comment for the full Option A vs. Option B reasoning) and a
new, small, single-purpose `private_chef_education` table was added
alongside it. The Background section now merges both sources —
restaurant items first, then education items.

**Parkheuvel — CONFIRMED, superseding §22's PENDING status.** Lucas
directly confirmed his Parkheuvel experience: restaurant Parkheuvel,
Rotterdam; function Service / Front of House (explicitly NOT a kitchen/
chef role); duration 2.5 years; explicit permission to mention it
granted. This is `DIRECTLY_CONFIRMED_BY_CHEF` — direct chef confirmation
was always the evidentiary bar PRIVATE_CHEFS.md's own publication
standard names as sufficient. `role = 'Service'`, `period_text = '2.5
years'` — no more specific title, no exact dates, no kitchen
responsibilities were claimed or invented.

**De Rooi Pannen — CONFIRMED.** Institution "De Rooi Pannen," program
"Horeca Ondernemend Management," directly confirmed by Lucas. No degree
level, diploma type, graduation year, campus, city, honours, or
qualification equivalence is claimed — none of that was independently
confirmed.

**Applied production state**:

| Table | Row | Key fields |
|---|---|---|
| `private_chefs` | `2e2089b0-f94d-46f5-923b-4ebf9135a5a1` | slug `lucas-de-jager`, `publication_status = 'published'`, `selected_at` set to the apply timestamp (audit-only) |
| `private_chef_restaurant_history` | `ee0e36aa-ba1f-4b68-a6d9-f0e42bf8e5f1` | `restaurant_id = 90d2b4ae-2b39-4bed-beec-31d6008a7ea8` (Parkheuvel, re-queried fresh immediately before apply), `role = 'Service'`, `period_text = '2.5 years'` |
| `private_chef_education` | `f5facd4b-720c-4520-997c-3c3bf2ca3681` | `institution = 'De Rooi Pannen'`, `program = 'Horeca Ondernemend Management'`, `period_text = null` |
| `private_chef_photos` | none | 0 rows — no rights-cleared images exist |

**Live verification performed**: schema/RLS for both new tables
(`private_chef_photos`, `private_chef_education`) confirmed live; `anon`
role successfully read the chef, the restaurant background, and the
education background; `authenticated`/`anon` write attempts against the
new tables both rejected with RLS policy violations (rolled back, no
data persisted); final row counts confirmed exactly `1 / 1 / 1 / 0 / 0`
across `private_chefs` / `private_chef_restaurant_history` /
`private_chef_education` / `private_chef_photos` /
`private_chef_enquiries`.

Photography permission remains **not granted** — `profile_image_url` is
`null`, zero `private_chef_photos` rows exist, and the existing branded
placeholder is the correct, expected result.
