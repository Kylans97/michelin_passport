# Private Chefs — Product & Data Architecture

**Status:** Step 0 (product/data architecture), Step 1 (database
foundation), Step 1A (enquiry integrity hardening), Step 1B (production
deployment), Step 2 (application layer + Explore discovery + Chef
Detail), Step 2A (Lucas de Jager / Jagers Catering curation research),
and Step 2B (5-photo hero gallery, Background architecture, and Lucas
de Jager production apply) are all complete. **Lucas de Jager / Jagers
Catering is the first published Private Chef** — see "STEP 2B" below for
the full applied state. No enquiry form yet (Step 3).

## PRIVATE CHEFS DATABASE FOUNDATION — DEPLOYED

- **Migration**: `supabase/migrations/20260817120000_create_private_chefs_foundation.sql`
- **Production tables**: `private_chefs`, `private_chef_restaurant_history`, `private_chef_enquiries` — all three live, schema/RLS verified against the deployed migration.
- **All three tables empty** — 0 rows each. No Lucas, no Jagers Catering, no real chef data of any kind.
- **RLS enabled on all three**, policies verified live: published-only catalogue reads for `private_chefs`/`private_chef_restaurant_history`; owner-only SELECT + hardened INSERT for `private_chef_enquiries`; no client UPDATE/DELETE anywhere.
- **Step 1A enquiry hardening is live**: a client-created enquiry must satisfy `user_id = auth.uid()`, `status = 'submitted'`, and the target chef currently `publication_status = 'published'` — confirmed via the exact live `WITH CHECK` predicate matching the approved design.
- **Published = Selected**: `publication_status = 'published'` alone is the authoritative public selection signal — no separate `chasing_stars_selected` boolean exists or is planned.
- **Michelin/Keys recognition belongs only to the canonical Restaurant** — no star/key columns exist anywhere on `private_chefs` or `private_chef_restaurant_history`.
- **Enquiries are not bookings** — `private_chef_enquiries` represents a bespoke request only; no booking/payment/availability infrastructure exists.

**Privilege audit result** (project-wide, read-only, 2026-08-17): `anon`/`authenticated` hold broad table-level grants on every application table in this project, including all three Private Chefs tables — this is a **universal Supabase project default** (`ALTER DEFAULT PRIVILEGES` at the project level), confirmed identical on 25 pre-existing tables (`restaurants`, `profiles`, `event_attendance`, `friendships`, etc.), and is **not Private-Chefs-specific**. The explicit `GRANT` statements in the Private Chefs migration do not themselves narrow this — **RLS is the actual, sole, authoritative effective security boundary** for these tables, exactly as it already is for every other table in this project. Private Chefs' own RLS policies were live-verified and are correct. Project-wide default-privilege hardening (making the migration's own `GRANT` statements independently restrictive) remains a deferred, separate decision — see `docs/Architecture/DATABASE_GUIDE.md`'s "Row Level Security" section.

One unrelated pre-existing defect was found and fixed during this audit: `public.worlds_50_best_hotels` had RLS disabled entirely (migration `20260817130000_fix_worlds_50_best_hotels_rls.sql`) — not a Private Chefs table, noted here only because it was discovered during the same review pass.

## PRIVATE CHEFS STEP 2 — APPLICATION LAYER + DISCOVERY UI

The read-only application layer against the deployed schema. No enquiry
form (Step 3), no real chef data, no bottom-navigation change.

**Application models** — `lib/models/private_chef.dart` (`PrivateChef`,
mirrors `restaurant.dart`/`hotel.dart`'s own doc-comment-heavy,
`fromJson`-only, no-`copyWith` convention exactly) and
`lib/models/private_chef_restaurant_history.dart`
(`PrivateChefRestaurantHistory`, built via `fromRow(row, {restaurant})`
rather than a bare `fromJson`, since resolving its canonical `Restaurant`
requires a second query the model itself has no business making). Neither
model carries a Michelin/Keys field of any kind — recognition is read
only from the resolved `Restaurant` (see §10, unchanged).

**Repository** — `lib/data/repositories/private_chef_repository.dart`
(`PrivateChefRepository`, read-only, matching
`RestaurantRepository`/`HotelRepository`/`EventsRepository`'s exact
constructor-injection shape and `privateChefFullColumns` explicit-column-
list convention). Four methods: `getPublishedChefs()`,
`getPrivateChefById()`, `getPrivateChefBySlug()` (unused today, kept
because `slug` is the schema's own stable public identity and the lookup
is genuinely cheap — not spec work), and `getRestaurantHistory()`.

- **Published query**: `getPublishedChefs()` explicitly re-applies
  `publication_status = 'published'` even though `private_chefs_public_read`
  RLS already restricts anon/authenticated reads to published rows —
  deliberately, so the query documents its own intent and keeps behaving
  correctly if this repository is ever reused under a service-role
  context. Ordered by `display_name` ascending — no editorial
  `display_order`/ranking field exists on `private_chefs`, and this
  domain has no popularity concept to invent one from; `display_name` is
  the smallest honest, deterministic fallback.
- **Detail query**: `getPrivateChefById()` is published-gated the same
  way — a draft/archived chef id must not resolve. `PrivateChefDetailScreen`
  takes only a `chefId` and resolves it internally (matching
  `EventDetailScreen`'s `eventId`-only convention, not Restaurant/Hotel
  Detail's "caller already has the model" convention) precisely so a
  removed/archived chef renders `PrivateChefNotFoundState` rather than
  stale data.
- **Provenance query / restaurant resolution**: `getRestaurantHistory()`
  is two queries total — the history rows, then one batched
  `restaurants_full` lookup via `.inFilter('id', ...)` across every
  canonical `restaurant_id` among them — never one query per row,
  mirroring `EventsRepository.loadLinkedVenues` exactly. **N+1 result:
  none** — verified by construction (the same pattern already proven
  correct for Event Detail's linked venues).

**Explore placement** — a second `GuideDestinationRow` ("Private Chefs" /
"Exceptional chefs, selected for private dining.", `surface:
CsSurface.dark`) directly beneath "Browse the Guides" in
`explore_screen.dart`'s discovery slivers, pushing `PrivateChefsScreen` via
plain `MaterialPageRoute` — the exact same permanent-navigation-row
pattern Guides already uses, not a duplicate landing page rendered
inline, not a 6th bottom-navigation tab, and not folded into the main
restaurant/hotel/event search.

**`PrivateChefsScreen`** (`lib/features/private_chefs/private_chefs_screen.dart`) —
a pushed route with its own `Scaffold`, reusing `GuideCatalogueLayout`'s
proven `Scaffold(deepGreen)` → `SafeArea(bottom: false)` masthead → ivory
`ColoredBox` + `SafeArea(top: false)` content architecture (the exact fix
for the ivory-strip-behind-the-status-bar bug that shell already solved),
but with a single `screenTitle`/`body` heading — matching Explore/
Wishlist's primary-tab header language — rather than Guides' two-level
source/title split, since Private Chefs has no family-of-catalogues
hierarchy above it. Production currently has zero published chefs, so
`PrivateChefsEmptyState` ("Private Chefs are coming soon" / "We're
curating a small collection of exceptional chefs for private dining
experiences.") is the real, first-class state most users see today — not
"No chefs found," no promised date, no mention of Lucas or the database.
Populated rows use `PrivateChefRow` (a `GuideVenueCard`-family editorial
index row, but person-first: `display_name` primary, `business_name`
clearly subordinate) with `PrivateChefAvatar` — a small, circular,
chef-specific image primitive reusing `CsImagePlaceholder`'s exact
fallback logic rather than `VenueThumbnail` (whose rounded-square
treatment is built for venue photography and reads wrong for a person).

**`PrivateChefDetailScreen`** (`lib/features/private_chefs/private_chef_detail_screen.dart`) —
canonical hierarchy HERO → ABOUT → RESTAURANT PROVENANCE → THE EXPERIENCE
→ CONNECT, each section conditional and self-omitting, separated by
`SectionDivider` only between sections actually present:

- **Hero** (`PrivateChefHero`) — a parallel, trimmed sibling of
  `VenueDetailHero`, not a reuse of it: that widget hard-requires
  wishlist state, which has no equivalent here (Private Chefs is not on
  Wishlist, §33 unchanged). Shows the chef's real `profile_image_url`
  photo when present (unlike Restaurant/Hotel, which have no photo column
  yet), falling back to the same deep-green gradient treatment
  otherwise. The only editorial context label is a small "PRIVATE CHEF"
  eyebrow — never "Chasing Stars Selected" as a badge, never a score,
  rating, review count, or price badge. The page existing at all is the
  selection signal (§14).
- **About** — `biography` verbatim, section omitted entirely (not shown
  with placeholder copy) when null/blank.
- **Restaurant Provenance** — `PrivateChefProvenanceRow` per history row.
  **Hard Michelin-attribution rule, enforced in code and tested
  explicitly**: `StarRow` renders only beside the *restaurant's* own name,
  sourced only from the resolved `Restaurant.michelinStars` — never
  beside the chef's name, never inferred, never phrased as "the chef has
  N stars." Canonical rows are tappable → `RestaurantDetailScreen` (via
  the already-resolved `Restaurant` model, no second lookup) and show
  city + flag from that same `Restaurant`; text-only rows show only
  `restaurant_name_text` + role/period, are never tappable, never show a
  fabricated location, and are visually distinguished only by the absence
  of the tap affordance (no arrow icon) — not by looking broken.
- **The Experience** (`PrivateChefExperienceSection`) — editorial prose,
  never a specification table, built entirely from conditional fields via
  two pure, independently tested functions: `formatGuestRange` (both /
  min-only / max-only / neither, never "null–14 guests") and
  `formatPricingFrom` (`price_on_request` always wins regardless of
  whether `pricing_from` is also set; the raw ISO 4217 code is shown as
  text — no currency-symbol mapping invented, matching this codebase's
  existing precedent of never guessing one, e.g. `Visit.currency`/
  `EventCard`'s raw country-code text). `wine_pairing_available == false`
  renders no wine line at all (omission, not a negative statement).
- **Connect** — reuses `SubtleTextAction` (the same understated "Label →"
  affordance Restaurant/Hotel Detail already use), never a large
  social-button treatment. Self-omits entirely when neither
  `instagram_url` nor `website_url` is present; shows just the one that
  exists otherwise. URL opening is the screen's own inline `_openUrl`
  (identical `canLaunchUrl`/`launchUrl(mode: externalApplication)`
  pattern already duplicated in `RestaurantDetailScreen`/
  `HotelDetailScreen` — no shared helper exists in this codebase to
  extract into, so this doesn't invent one either).
- **Step 3 seam** — no CTA of any kind (disabled, "coming soon", or
  otherwise) is rendered where "Request an Experience" will eventually
  go; a documented comment in `_body()` marks exactly where Step 3 adds
  it. Nothing about the current section list/divider structure needs to
  change to accommodate that addition later.

**Testing** — model tests are pure Dart (JSON mapping, nullable fields,
pricing, languages, canonical-vs-text-fallback). Every presentational
widget (`PrivateChefRow`, `PrivateChefHero`, `PrivateChefProvenanceRow`,
`PrivateChefExperienceSection`, `PrivateChefConnectSection`, the four
state widgets) is a pure `StatelessWidget` with no Supabase dependency
and is widget-tested directly. `PrivateChefsScreen`/`PrivateChefDetailScreen`
themselves construct `PrivateChefRepository` against
`Supabase.instance.client` eagerly in `initState` — the same established
Supabase-eager-screen limitation as every other primary/pushed screen in
this app — so their own shell/composition is covered by mirrored-widget-
tree tests (`private_chefs_screen_shell_test.dart`,
`private_chef_detail_screen_shell_test.dart`), following
`wishlist_screen_shell_test.dart`'s exact established pattern, built
almost entirely from the real, already-independently-tested production
sub-widgets rather than re-mirroring their internals. The Explore entry
is covered the same way `explore_guides_entry_test.dart` already covers
"Browse the Guides." The repository's own N+1-avoidance and query shape
are verified by code inspection against `EventsRepository
.loadLinkedVenues`'s already-proven pattern, not a live-Supabase test —
this codebase has no mocking harness for `SupabaseClient`, matching the
existing precedent for every other repository in this app.

**Physical-device review — APPROVED.** Step 2 was reviewed on a real
iPhone against the live (empty) production catalogue. Confirmed: the
Explore → Private Chefs entry renders correctly; the deepGreen/ivory
masthead-to-content treatment matches the approved Chasing Stars
language; the safe area paints deepGreen cleanly through the status-bar
area with no white/ivory/legacy strip; navigation into and back out of
`PrivateChefsScreen` works correctly; the production empty state
("Private Chefs are coming soon...") reads as intentional, not broken or
placeholder-like; no decorative gold was introduced anywhere in the
feature; and "Browse the Guides" remains unaffected alongside the new
row. Populated-landing and Chef Detail physical review is explicitly
**deferred** until the first real chef is published — production
currently has zero chefs, so only the empty state is reviewable on-device
today; the populated path's evidence is its automated widget coverage
(§ above).

## STEP 2B — 5-PHOTO HERO GALLERY + BACKGROUND ARCHITECTURE + LUCAS DE JAGER APPLIED

**First published chef: Lucas de Jager / Jagers Catering — APPLIED to
production 2026-08-18.** `private_chefs.id =
2e2089b0-f94d-46f5-923b-4ebf9135a5a1`, `publication_status = 'published'`,
`selected_at` set to the apply timestamp as audit-only metadata (never
read for visibility). Full curation research lives in
`supabase/data/enrichment/private_chefs/lucas_de_jager/`
(`PROFILE_RESEARCH_REPORT.md` is the source of truth). Profile-inclusion
permission was confirmed by Lucas directly (`PROFILE_PERMISSION:
APPROVED_BY_CHEF`). Photography permission has **not** been granted for
any specific image, and no image files exist in this repository — the
profile publishes with zero photos and no `profile_image_url`, using the
existing branded placeholder, which is the expected and correct MVP
result, not a blocker.

**BACKGROUND — renamed from "Restaurant Provenance."** A chef's relevant
professional background is broader than kitchen positions —
hospitality, service, wine, and education can all be curation-relevant.
The user-facing section heading changed from "RESTAURANT PROVENANCE" to
**"BACKGROUND"**, and now merges two distinct sources: restaurant
background (`private_chef_restaurant_history`, unchanged) and education
background (new `private_chef_education` table), restaurant items
rendered first, then education items — no sub-headings between them.

**Architecture decision (Option A, chosen) vs. Option B (rejected)** —
see `supabase/migrations/20260818130000_add_private_chef_education.sql`'s
own header comment for the full reasoning:
- **Option A (chosen)**: keep `private_chef_restaurant_history` exactly
  as already deployed/tested/RLS'd, and add one new, small,
  single-purpose `private_chef_education` table alongside it
  (`private_chef_id` FK, `institution`, `program`, `period_text`,
  `display_order`, `created_at`/`updated_at`, RLS gated on parent-chef-
  published, no client write policy — mirrors every other Private Chefs
  table's own established shape). Plain text `institution`/`program`,
  no institution catalogue, no polymorphic association, never tappable
  (no canonical "institution" domain exists or is planned).
- **Option B (rejected)**: one generalized `private_chef_background`
  table with a type discriminator and per-type-nullable columns.
  Rejected because it would require reworking
  `private_chef_restaurant_history`'s already-shipped canonical/text-
  fallback/XOR/Michelin-attribution design for no present benefit, and a
  polymorphic table with optional columns per type is *worse* for
  referential integrity and simplicity than two small typed tables —
  exactly the "CV system" this domain's own product principle warns
  against building, not a simplification of it.

**Parkheuvel — CONFIRMED, applied.** Lucas directly confirmed his
Parkheuvel experience: restaurant Parkheuvel, Rotterdam; function
Service / Front of House (explicitly not kitchen/chef); duration 2.5
years; explicit permission to mention it granted
(`DIRECTLY_CONFIRMED_BY_CHEF`). `private_chef_restaurant_history.id =
ee0e36aa-ba1f-4b68-a6d9-f0e42bf8e5f1`, `restaurant_id =
90d2b4ae-2b39-4bed-beec-31d6008a7ea8` (re-queried fresh immediately
before apply), `role = 'Service'`, `period_text = '2.5 years'` — no more
specific title, no exact dates, no kitchen responsibilities claimed or
invented. The restaurant's current 2 Michelin stars are **not** written
anywhere in Private Chef tables — recognition renders dynamically from
the live `Restaurant` row via `PrivateChefProvenanceRow`'s existing,
audited `StarRow` logic (§4 of the task: confirmed unambiguous as-is —
the star renders only on the same line as, and grammatically bound only
to, the restaurant's own name; `role`/`period_text` render on their own
separate, visually subordinate line).

**De Rooi Pannen — CONFIRMED, applied.** `private_chef_education.id =
f5facd4b-720c-4520-997c-3c3bf2ca3681`, `institution = 'De Rooi Pannen'`,
`program = 'Horeca Ondernemend Management'`, `period_text = null` — no
degree level, diploma type, graduation year, campus, city, honours, or
qualification equivalence is claimed; none of that was independently
confirmed.

**New migrations**:
`supabase/migrations/20260818120000_add_private_chef_photos_and_biography_limit.sql`
and
`supabase/migrations/20260818130000_add_private_chef_education.sql` —
both applied to production 2026-08-18, each recorded remotely exactly
once. The first adds two things on top of the already-deployed
foundation:

- **`private_chef_photos`** — an admin-curated, up-to-5-image Detail-hero
  gallery per chef. Shape mirrors `private_chef_restaurant_history`
  (synthetic uuid pk, `private_chef_id` FK on delete cascade,
  `display_order`, `created_at`/`updated_at` with the shared
  `set_updated_at()` trigger) rather than the unrelated,
  Storage-backed `public.photos` table (personal user-uploaded visit
  photos — a different system for a different, private/user-owned use
  case). `image_url` is a plain text URL, matching
  `private_chefs.profile_image_url`'s own shape — admin-curated
  photography, no new Supabase Storage bucket.
  - **Ordering, single source of truth**: `display_order` alone — no
    separate `is_cover` boolean. The lowest `display_order` for a chef
    is always the cover/first hero image. A `unique (private_chef_id,
    display_order)` constraint makes "which one is first" unambiguous
    by construction.
  - **Max 5, enforced at the database layer**: a single-purpose
    `BEFORE INSERT` trigger (`private_chef_photos_max_five` /
    `enforce_private_chef_photo_limit()`) rejects a 6th row for any
    chef — not just a convention the admin/import workflow has to
    remember.
  - **RLS**: enabled, `select to anon, authenticated` gated on the
    parent chef's `publication_status = 'published'`, matching
    `private_chef_restaurant_history_public_read`'s exact predicate
    shape. No client write policy — admin-managed, same as every other
    Private Chefs table.
  - **`profile_image_url` vs. `private_chef_photos` — the deliberate
    MVP split**: `profile_image_url` is the compact portrait/avatar
    used by catalogue rows (`PrivateChefRow`/`PrivateChefAvatar`) and
    is also the Detail hero's fallback when no gallery photo exists.
    `private_chef_photos` is the curated, richer Detail-hero gallery;
    when present it is authoritative for the hero. Neither column is
    dropped or deprecated by the other — this is additive, not a
    migration of meaning.
- **Biography length cap**: `private_chefs_biography_max_length` CHECK
  constraint — `biography is null or char_length(biography) <= 900`,
  added via `ALTER TABLE` on the already-deployed (still zero-row)
  `private_chefs` table. Editorial target is 350–650 characters,
  enforced by curation practice, not the database; this constraint is
  only the hard outer bound. Scoped to `biography` only —
  `personalization_note` and every other editorial field are
  unaffected.

**Hero gallery UI** (`PrivateChefHero`, now a `StatefulWidget`):
background resolves in order — (1) `photos` (1 photo → static image; 2–5
→ a swipeable `PageView` with a small restrained dot indicator, ivory for
the active page, `secondaryOnDark` at reduced opacity otherwise, excluded
from the accessibility tree since `PageView` already carries swipe
semantics); (2) `profileImageUrl` as a single static fallback; (3) the
existing branded gradient placeholder. No autoplay, no thumbnail rail, no
large pagination chrome, no gold anywhere in the gallery — matching the
same restrained, editorial (never marketplace/Instagram-feed) language
the rest of this feature already uses. A broken image among several
falls back per-image, never taking down the whole gallery. A small,
hero-specific gallery implementation — not a new generic reusable
carousel primitive, since nothing else in this app needs one yet.

**Live verification performed** (2026-08-18, immediately after apply):
RLS and schema confirmed on both new tables; `anon` role successfully
read the chef, the restaurant background, and the education background
end to end; `authenticated`/`anon` write attempts against both new
tables rejected with RLS policy violations (rolled back, nothing
persisted); final production counts `private_chefs = 1`,
`private_chef_restaurant_history = 1`, `private_chef_education = 1`,
`private_chef_photos = 0`, `private_chef_enquiries = 0`.

**Physical-device review**: populated-state review (landing row, hero,
About, Background — restaurant item with recognition + education item,
Experience, Connect — all with zero photos, since none are available)
is now possible for the first time. Photo-gallery swipe review
specifically remains deferred until rights-cleared images are supplied
for Lucas or any future chef.

**Step 1 corrections to the original Step 0 proposal below** (the
sections themselves are updated in place; this box is a map to what
changed and why):

| # | Correction | Where |
|---|---|---|
| A | No `chasing_stars_selected` boolean. `publication_status = 'published'` alone is the authoritative public selection signal. `selected_at` is optional historical/audit context only, never read to gate visibility. | §6, §14, §45, §53 |
| B | Michelin/Keys recognition belongs to the Restaurant, never the chef — unchanged from Step 0, reconfirmed. | §10 (unchanged) |
| C | `source_url`/`verified_at` do **not** live on `private_chef_restaurant_history`. Omitting sensitive columns from the app's own SELECT list is not a security boundary — RLS in this project is row-level, not column-level, so any column on a client-readable table is reachable by any client holding a valid key. Evidence stays entirely outside any publicly-readable table: verification happens *before* a row is entered, via internal enrichment artifacts. | §13, §41, §45, §50, §52 |
| D | `private_chef_enquiries` is a bespoke request, never a booking — unchanged from Step 0, reconfirmed. | §24–26 (unchanged) |
| E | `private_chef_internal_reviews` remains deferred — not built in Step 1 either. | §15, §49 |
| F | `private_chef_photos` remains deferred — no reusable media pattern in this codebase required it now; `profile_image_url` is sufficient for MVP. **Superseded in Step 2B** — a 5-photo hero gallery was product-approved and built; see §31. | §16, §31, §45 |

**Step 1A hardening** (patched into the same, still-undeployed migration
— see §26 "Enquiry integrity" for the full detail): the original
`private_chef_enquiries` INSERT policy only verified `user_id =
auth.uid()`, leaving a gap a direct PostgREST client could exploit —
supplying `status = 'confirmed'` at creation time, or opening an enquiry
against a `draft`/`archived` chef. The INSERT policy now additionally
requires `status = 'submitted'` and that the target chef is currently
`published`, enforced entirely by ordinary RLS composition (no
`SECURITY DEFINER` needed — see §26 for the reasoning).

---

## 1. Product vision

Private Chefs is a highly curated Chasing Stars collection of chefs capable
of delivering exceptional private dining experiences — a small, personally
selected roster, not an open marketplace. The product must answer, in this
order of importance: *who is this chef*, *why should I trust them*, *what
kind of experience can they create*, and *how do I request one*.

**Reference feeling**: Aman, Belmond, Soho House — editorial, selective,
personal. **Explicitly not**: a chef marketplace, catering directory,
freelancer platform, "chef near me" search, gig-economy app, or
price-comparison tool. Trust comes from curation, professional provenance,
editorial storytelling, and photography — never from review counts, star
ratings, or a leaderboard.

`docs/Architecture/DATABASE_GUIDE.md` already lists "Chef Profiles" under
Future Expansion — this document is that expansion, designed to require no
redesign of anything that already exists.

---

## 2. Non-marketplace principle

Deliberately **not copied** from a generic chef marketplace:

| Marketplace pattern | Why Chasing Stars rejects it |
|---|---|
| Self-service chef signup | Curation is the entire trust mechanism — anyone could list themselves on a marketplace |
| Public star ratings / review counts | Turns hospitality into a scoreboard; the task brief is explicit: no public numeric score |
| Price sort / cheapest-first / deal badges | Premium positioning cannot coexist with price-shopping UX |
| Instant booking / real-time calendar | Implies commodity availability; a curated relationship is negotiated, not clicked |
| Follower-count-based ranking | Popularity ≠ quality; Instagram is context, not a ranking signal |
| Dozens of rigid filters | A members'-club discovery experience is editorial, not faceted search |

What Chasing Stars leans into instead: curation, limited supply, editorial
storytelling, professional provenance (tied to the *existing* canonical
Restaurant catalogue — a differentiator no generic marketplace has), high
-quality photography, and a personalization-first proposition rather than a
configurable product catalogue.

---

## 3. Real-world validation case — Lucas / Jagers Catering

Used throughout this document as a reality check for every field decision,
not designed in the abstract. Facts below are explicitly separated by
source; nothing here is treated as ready for publication.

**User-provided (personal experience, not independently verified)**:
- Attended a private dinner cooked by a chef named "Lucas," hosted by a
  mutual friend.
- Food and wine were excellent; the experience was well adapted to the
  host's wishes.
- User's own understanding: Lucas has professional experience at
  Parkheuvel.

**Publicly available, fetched from jagers-catering.nl on 2026-08-24 —
the business's own first-party marketing claims, not independent
third-party verification**:
- Business name: "Jagers Catering."
- Chef name as stated on the site: "Lucas de Jager" — a surname that
  appears in this public source, not invented here; still requires direct
  confirmation with Lucas before any profile uses it.
- The site itself states experience at "het tweesterren restaurant
  Parkheuvel" (the two-Michelin-star restaurant Parkheuvel) — this
  **corroborates** the user's own Parkheuvel statement via an independent
  channel, which is meaningfully more than the user's word alone, but a
  business's own marketing copy is still not the same as third-party
  verification (see §32).
- The site also references sommelier experience, worded ambiguously
  enough (in what was fetched) that the exact claim shouldn't be repeated
  verbatim without re-checking the source directly.
- Based in Breda, Noord-Brabant; operates across the Netherlands and
  Belgium.
- Offers: dinner arrangements, full-service catering, walking dinners,
  wine-pairing arrangements, private dining at the client's own location.
- A philosophy quote exists on the site (paraphrased here, not to be
  used verbatim without permission: cooking framed as care and
  memory-making, not just ingredients/recipes) — useful as a *tone*
  reference for what a `biography`/`philosophy` field should support, not
  as Lucas's confirmed final copy.
- Direct public contact: phone number, email address, and a quote-request
  form on the site.

**Instagram (@jagerscatering)**: the handle resolves to a real account;
the profile's bio/content was not accessible without authentication, so
nothing beyond "the account exists" is recorded here.

**Explicitly still unknown — not invented, not guessed**: Lucas's exact
role/title at Parkheuvel, employment dates/duration, whether he is
currently employed there or elsewhere, formal education, awards, guest
capacity, structured pricing, and languages spoken.

**What this case validates architecturally**:
1. **Chef vs. business is a real, not theoretical, tension.** "Jagers
   Catering" reads as a small catering business/team with Lucas as head
   chef — not purely "Lucas operating solo under his own name." The
   optional `business_name` field (§4, §46) is directly justified by this
   example, not invented speculatively.
2. **Service area is never just one city.** Breda + "Netherlands and
   Belgium" confirms `home_city` + a free-text `service_area_text` (not a
   single-city model) is the right MVP shape (§21–22).
3. **Direct public contact already exists and should NOT be what Chasing
   Stars surfaces.** The business already publishes a phone number and
   email; Chasing Stars' value-add is curation *and* a mediated,
   privacy-preserving enquiry path instead of raw contact-detail exposure
   (§27).
4. **Provenance needs a first-party/third-party distinction the schema
   must support**, not just a boolean "verified" — a business's own
   website is corroborating evidence, not proof (§32).

---

## 4. Chef vs. business identity — architecture decision

**Decision: one `private_chefs` table, no separate business/company
domain in MVP.**

`display_name` (always present — the name the profile is headlined with,
normally the person's own name, matching the product's "WHO IS THIS CHEF"
positioning) plus an optional `business_name` (a subordinate line,
rendered smaller, only when the chef genuinely operates under a brand)
cleanly represents every case audited:

- Independent chef using their own name: `display_name = "Lucas de
  Jager"`, `business_name = null`.
- Chef operating through a business brand (the Jagers Catering case):
  `display_name = "Lucas de Jager"`, `business_name = "Jagers Catering"`.
- A small private-dining team led by a named chef: same shape — the
  *person* is still the display identity; the team/brand is the
  subordinate line. Chasing Stars curates a chef relationship, not a
  company account, even when a small team supports them.

A separate `private_chef_businesses` table was audited and rejected for
MVP: it would only earn its keep if a single business fielded *multiple*
independently-curated chefs, or if business-level fields (legal entity,
multiple locations, a business-wide rating) were needed — none of which
the MVP requires, and none of which the reference case demonstrates.
`website_url`/`instagram_url` living on the chef row (not split into
chef-specific and business-specific variants — see §8) removes any
remaining ambiguity about "whose URL is this": it's simply the profile's
one public link, exactly as a curated editorial profile would present it,
regardless of whose name is on the letterhead.

Which value the admin sets in which field is a **curation decision made
per chef**, not something the schema enforces beyond "display_name is
required and primary, business_name is optional and secondary."

---

## 5. Strict MVP

**IN:**
- Curated Private Chef catalogue (`private_chefs`), admin-managed only.
- Chef Detail (individual chef identity + optional business identity).
- Biography / cooking philosophy (editorial, not structured).
- Private dining proposition: service area, travel, guest range,
  personalization, wine capability.
- Instagram + website (optional links, not embedded feeds).
- Professional provenance, linked to the canonical Restaurant catalogue
  wherever the referenced restaurant exists there.
- Correct Michelin-recognition semantics (stars belong to the Restaurant,
  never the chef).
- "Chasing Stars Selected" as a qualitative public signal.
- "Request an Experience" — a database-backed enquiry, not a booking.
- Admin-managed content pipeline (research → human review → SQL import),
  matching the existing Claude Data Pipeline in `DATABASE_GUIDE.md`.

**Deferred (explicitly out of MVP)**: payments, instant booking,
real-time availability/calendar, chef self-service registration or
profile editing, in-app chat, a matching/recommendation engine, public
reviews or ratings, any ranking/leaderboard, dynamic pricing, friend
-based social intelligence about chefs, Passport stamps for private
dining, Wishlist integration, and Events relationships (`event_chefs`).

**Challenging the draft list**: the draft grouped "multiple bookable
products per chef" under deferred — agreed, but for a more specific
reason than just "keep it simple": modeling per-experience-type products
(§17) would require *pricing per product*, which reopens the
price-comparison risk this whole document argues against. Deferring it
is a product-integrity decision, not just a scope-discipline one.

---

## 6. Chef profile — architecture

### Identity
`id` (uuid), `slug` (unique, URL-friendly, admin-set — not derived from a
name that might change), `display_name` (required), `business_name`
(optional). No `first_name`/`last_name` split — `profiles.display_name`
already establishes single-field free-text names as this project's
convention, and a split adds rigidity (compound/international names,
professional-name-only presentation) with no proven MVP benefit.

### Biography
One `biography` field (editorial, admin-written, can absorb "philosophy"
— see §7 for why a second `philosophy` column isn't justified). A short
`headline` for list/card contexts was proposed in Step 0 but **is not in
the Step 1 migration** — Step 1's field list scoped Editorial down to
`biography`/`personalization_note` only; `headline` remains a clean,
additive column for later if a real list/card need for it emerges.

### Location & service area
`home_city` (free text — see §22 for why not a `cities` FK),
`home_country_code` (FK to `countries`, matching every other catalogue
table's convention), `service_area_text` (free editorial text — "The
Netherlands and Belgium," matching the Jagers Catering case exactly),
`travel_available` (boolean, cheap and independently useful even though
`service_area_text` often implies it).

### Guest range & personalization
`minimum_guests`, `maximum_guests` (both nullable smallint — many chefs
won't have a hard floor/ceiling), `personalization_note` (free editorial
text — *not* a checkbox grid; see §18).

### Wine
`wine_pairing_available` (boolean), `wine_note` (optional free editorial
text — e.g. "works closely with a sommelier for extended wine pairings").
No wine inventory, no vintage/bottle modeling.

### Pricing
`pricing_from` (nullable numeric), `pricing_currency` (nullable char(3),
ISO 4217, required if `pricing_from` is set), `pricing_unit` (nullable
text, `per_person`/`per_experience`), `price_on_request` (boolean,
default `true` — the premium-safe default; a chef only gets a visible
number if curation explicitly chooses to show one).

### Social / web
One `instagram_url`, one `website_url` — see §8.

### Photography
`profile_image_url` (portrait — see §31), plus a small additive
`private_chef_photos` gallery table (mirrors the existing
`photos`/`visit_photos` media-table shape exactly: `id`, `chef_id`,
`storage_path`, `caption`, `display_order`, `created_at`).

### Curation / publication
`publication_status` (`draft`/`published`/`archived`) — **the sole
public visibility/selection signal, see §14 for why there is no separate
`chasing_stars_selected` boolean**. `selected_at` (nullable timestamptz,
optional historical/audit context only — see §14). `featured` (boolean,
optional manual landing-page highlight — deferred beyond Step 1, not yet
in the migration), `display_order` (optional manual sort — deferred
beyond Step 1, not yet in the migration).

### Field classification

| Field | Type | MVP classification | Reasoning |
|---|---|---|---|
| `id` | uuid pk | MVP_REQUIRED | Standard |
| `slug` | text unique | MVP_REQUIRED | Stable URL identity independent of display name |
| `display_name` | text not null | MVP_REQUIRED | The whole point of "who is this chef" |
| `business_name` | text | MVP_OPTIONAL | Only when a brand genuinely exists — validated by Jagers Catering |
| `headline` | text | DEFER (not in Step 1 migration) | Nice for list/card context, not launch-blocking; Step 1's Editorial scope is `biography`/`personalization_note` only |
| `biography` | text | MVP_REQUIRED | Core trust/editorial content |
| `philosophy` | text | REJECT (fold into `biography`) | See §7 — a second free-text field for admin-written prose doesn't earn its own column |
| `profile_image_url` | text | MVP_REQUIRED (nullable at schema level, enforced by publication gate not a NOT NULL constraint) | A profile with no portrait shouldn't be curatable to `published`, but the constraint belongs to the curation *process* (§41), not a schema-level block that would fight the draft workflow |
| `hero_image_url` | text | DEFER | MVP can reuse `profile_image_url` for both card and hero; a distinct hero asset is a nice-to-have once photography volume justifies it |
| `instagram_url` | text | MVP_OPTIONAL | Optional per §8 |
| `website_url` | text | MVP_OPTIONAL | Optional; one field, not chef/business split — §8 |
| `home_city` | text | MVP_REQUIRED | Free text, not a `cities` FK — §22 |
| `home_country_code` | char(2) FK | MVP_REQUIRED | Matches every other catalogue table |
| `service_area_text` | text | MVP_REQUIRED | Validated directly by the reference case |
| `travel_available` | boolean | MVP_OPTIONAL | Cheap, independently useful |
| `cuisine_style` | text | DEFER (not in Step 1 migration) | Editorial, not a taxonomy — §7; Step 1's field list did not include it, a clean additive column later |
| `minimum_guests` | smallint | MVP_OPTIONAL | Nullable; many chefs have no hard floor |
| `maximum_guests` | smallint | MVP_OPTIONAL | Same |
| `personalization_note` | text | MVP_OPTIONAL | High product value given the reference case, but a chef can be published without it |
| `wine_pairing_available` | boolean | MVP_REQUIRED | Explicit product differentiator |
| `wine_note` | text | MVP_OPTIONAL | Editorial depth when relevant |
| `pricing_from` / `pricing_currency` / `pricing_unit` | numeric / char(3) / text | MVP_OPTIONAL | Most chefs will likely default to price-on-request |
| `price_on_request` | boolean not null default true | MVP_REQUIRED | The safe default that keeps this from becoming a price-comparison product |
| `languages` | text[] | MVP_OPTIONAL | See §23 |
| `sommelier_collaboration` | boolean | REJECT (fold into `wine_note`) | Checkbox overload — §18/§19 |
| `availability_note` | text | REJECT (redundant with `service_area_text` + `travel_available`) | Avoid two fields answering the same question |
| `publication_status` | text + check | MVP_REQUIRED | The curation gate *and* the sole public selection signal — see §14, no separate boolean |
| `selected_at` | timestamptz | MVP_OPTIONAL | Historical/audit context only, never read by the app to gate visibility — see §14 |
| `featured` | boolean | DEFER (not in Step 1 migration) | Manual landing highlight, not launch-blocking; a clean additive column later |
| `display_order` | integer | DEFER (not in Step 1 migration) | Manual curation ordering; a clean additive column later |
| `created_at` / `updated_at` | timestamptz | MVP_REQUIRED | Standard, `updated_at` via `set_updated_at()` trigger |

Reality check against Lucas/Jagers Catering: every field above maps
cleanly — `display_name`="Lucas de Jager" (once confirmed),
`business_name`="Jagers Catering", `home_city`="Breda",
`service_area_text`="The Netherlands and Belgium", `wine_pairing
_available`=true, `wine_note` could carry the sommelier detail once
re-verified. No awkward hack was needed anywhere in the model.

---

## 7. Editorial vs. structured cuisine

**Step 1 note: `cuisine_style` is not in the Step 1 migration** — Step 1's
field list scoped `private_chefs` down to the fields explicitly named in
that task; the recommendation below stands as the design intent for a
future additive column, not as something built now.

**Recommendation: one free-text `cuisine_style` field, no cuisine
taxonomy table for Private Chefs.** "Modern French cooking with
Mediterranean influences" genuinely communicates more than three rigid
tags would, and private-chef identity is inherently more personal/
idiosyncratic than a restaurant's catalogue classification (contrast with
`restaurants.cuisine_id`, which *does* use a structured `cuisines` table
— restaurants are compared/filtered at scale; a curated handful of chefs
are read individually, not filtered at scale). If a genuine future filter
need emerges (e.g. "wine-focused chefs"), `wine_pairing_available` already
covers the one differentiator explicitly called out as a product
priority — no other structured cuisine facet is justified by anything in
this brief. Same reasoning applies to "philosophy" as a merged concept
inside `biography` rather than a second column: both are admin-written
free prose serving the same "who is this chef" narrative purpose; forcing
them apart doesn't create product value, only two text fields to fill.

---

## 8. Instagram + website

**One `instagram_url`, one `website_url` on `private_chefs` — no
chef/business split.** The reference case shows exactly why a split isn't
needed: Jagers Catering's Instagram and website *are* Lucas's public
professional presence; there is no scenario in this MVP where a chef
needs to show two different Instagram accounts or two different websites.
If a future chef genuinely operates a personal account *and* a separate
business account, the single "professional presence" link is still the
one that matters editorially — curation picks the one URL that best
represents the chef, exactly as an editorial profile would. Both fields
are optional; both are validated as real, professional/relevant URLs
during curation (§41), never scraped, never embedded as a live feed, and
follower counts are never displayed or used for ranking (explicit
requirement, §8 of the task brief, reconfirmed here).

---

## 9. Professional provenance

Provenance — where a chef has cooked before, especially at a recognized
restaurant — is one of the strongest trust signals available, and the
reference case is a direct example: "previously at Parkheuvel ★★" (stars
belonging to the *restaurant*) is a materially stronger credibility
signal than any self-written biography claim could be alone.

**Concept**: `private_chef_restaurant_history` — a normalized table
linking a chef to zero or more prior (or current) restaurant
relationships, using the canonical `restaurants` foreign key wherever
that restaurant exists in the Chasing Stars catalogue (§12).

**Display concept** (documented for later UI work, not built now):
```
PREVIOUSLY AT
[thumbnail]  Parkheuvel ★★
             Rotterdam, Netherlands
```
Tapping the row opens the canonical `RestaurantDetailScreen` — the exact
same screen Explore/Guides/Trips already route to, never a duplicate or
chef-specific restaurant view.

---

## 10. Michelin semantics — hard architecture rule

**Michelin stars (and Keys) belong exclusively to the Restaurant/Hotel
entity that earned them. They never transfer to an employee, former
employee, or affiliated chef.**

Concretely, this system must:
- **Never** create a `private_chefs.michelin_stars` (or any equivalent)
  column.
- **Never** render `StarRow` beside a chef's name, portrait, or headline.
- **Never** generate copy like "2-Michelin-star chef" from the fact that
  a chef once worked at a starred restaurant.
- **Always** render Michelin/Keys recognition only beside the linked
  `restaurants`/`hotels` row itself, exactly where `StarRow`/`KeyRow`
  already render it today.

The only sanctioned pattern is "Previously at *[Restaurant]* ★★" — the
stars are legible as belonging to the restaurant name directly next to
them, not the chef. If a chef someday has an independently, personally
awarded distinction (this does not currently exist in the Michelin system
for private chefs, but if an equivalent ever did), that would need its
own, separately reviewed claim model — explicitly out of scope here, not
assumed, not designed against.

This rule exists because Chasing Stars' entire credibility rests on
Michelin/W50B/Gault&Millau data being exactly correct — a single
misattributed star claim would undermine that far more than it would
help one chef's profile.

---

## 11–12. Provenance data model & canonical Restaurant relationship

**`private_chef_restaurant_history`** — as built in the Step 1 migration
(`private_chef_id`, not `chef_id` — see §45 for the full, final column
list):

| Field | Type | Notes |
|---|---|---|
| `id` | uuid pk | |
| `private_chef_id` | uuid, FK → `private_chefs(id)` on delete cascade | |
| `restaurant_id` | uuid, FK → `restaurants(id)` on delete set null, **nullable** | See below |
| `restaurant_name_text` | text, nullable | Populated only when `restaurant_id` is null — see below |
| `role` | text | Free text ("Sous Chef," "Head Chef," "Trained under...") — see reasoning below |
| `period_text` | text | Free text ("2018–2021," "Several seasons") — deliberately not precise dates, see below |
| `display_order` | smallint, default 0 | Chef/admin controls ordering — kept from Step 0, justified directly by §59's "multiple provenance rows, correctly ordered" testing expectation |
| `created_at` / `updated_at` | timestamptz | `updated_at` via the shared `set_updated_at()` trigger |

**Two Step 1 corrections from the Step 0 shape above**:
- **`is_current` was dropped.** It appeared in the Step 0 sketch but
  wasn't in Step 1's restated field list and nothing in this document's
  own test checklist (§59) exercises it; `period_text` free text
  ("Head Chef, 2022–present") already conveys current status without a
  second column. A clean additive column later if a real need for
  structured "currently at" phrasing emerges.
- **`source_url`/`verified_at` were removed entirely** — see §13's
  correction. Verification now happens upstream of this table, not as a
  column on it.

**Constraint — strict XOR, not a simple OR**: exactly one of
`restaurant_id`/`restaurant_name_text` must be populated, never both,
never neither (`(restaurant_id is not null and restaurant_name_text is
null) or (restaurant_id is null and restaurant_name_text is not null)`).
This is stricter than Step 0's original "at least one" framing — it
directly enforces "avoid creating duplicate/conflicting restaurant
identities" at the database level, not just as a curation guideline.

**Simple vs. structured employment model**: the task's own draft offered
`started_at`/`ended_at` as an alternative to `period_text`. Rejected for
MVP — precise start/end dates invite exactly the kind of fabrication the
brief explicitly forbids ("do not invent... employment dates, duration").
`period_text` lets an admin write what's actually known ("around
2019–2021," "several years," "a season") without implying false
precision. Structured dates remain a clean additive column for later, if
and when a specific chef's dates are genuinely confirmed to the day/month
— adding them later requires no redesign.

**Role as free text, not an enum**: role language is genuinely open-ended
and international ("Sous Chef," "Chef de Partie," "Head Chef," "Trained
at," "Collaborated with," and equivalents in other languages/kitchen
cultures). A `check` constraint enum would either be incomplete on day
one or require a migration for every new title encountered — free text
matches this project's own established distinction between "fixed,
closed taxonomies" (enum) and "open, likely-to-grow taxonomies" (text),
and role/title is unambiguously the latter.

**Restaurant FK nullability (§12 A vs. B)**: **recommend A — text-only
provenance is allowed, but the canonical FK is always used when the
restaurant exists in the catalogue.** Reasoning: a globally-facing product
will surface chefs whose formative experience was at restaurants far
outside the current (Michelin-guide-driven) catalogue scope — small
regional restaurants, restaurants in not-yet-covered countries, or
restaurants that will simply never meet Michelin-catalogue inclusion
criteria. Requiring every provenance claim to resolve to a canonical
Restaurant row would either force low-quality/premature catalogue
additions (explicitly forbidden — "do not weaken Restaurant catalogue
inclusion rules") or silently drop legitimate, valuable provenance
context. The product-safe boundary is enforced at the **display layer**,
not the data layer: a linked row renders as a tappable, canonical row
with real recognition; a text-only row renders as plain text, never
tappable, never showing fabricated stars or a fake catalogue entry.

**One chef → many restaurants, one restaurant → many chefs**: the join
table's own `private_chef_id`/`restaurant_id` pair (both plain FKs, no
composite PK) already supports this many-to-many shape natively — no
additional modeling needed, matching exactly how `hotel_restaurants` and
`event_restaurants` already handle their own many-to-many relationships
in this schema.

---

## 13. Provenance source verification — CORRECTED IN STEP 1

**Step 0 originally recommended `source_url`/`verified_at` as production
columns directly on `private_chef_restaurant_history`, reasoning that the
app's own "explicit column list, never `select *`" repository convention
was a sufficient boundary to keep them out of normal reads. Step 1
rejects that reasoning and corrects the design.**

Why the original reasoning doesn't hold: RLS in this project is
**row-level**, not column-level, in every single policy this schema
already uses (`restaurants_public_read`, `hotels_public_read`,
`private_chefs_public_read`, etc. all gate which *rows* are visible, none
of them gate which *columns* are visible within a visible row). A repository
choosing not to `select` a column is a client-side convention, not a
server-side guarantee — any caller holding a valid `anon` or
`authenticated` Supabase key can query any column covered by a table's
SELECT policy directly via PostgREST, regardless of what the Flutter
app's own repository happens to ask for. A column that must never reach a
client cannot be "kept out" by client-side selectivity; it must not exist
on a client-readable table at all.

**Resolution: `private_chef_restaurant_history` contains only public
presentation data — no `source_url`, no `verified_at` column exists on
it.** Verification instead happens upstream of the table entirely: a
provenance row is only ever inserted once a human has already verified it
through internal enrichment artifacts/documentation (the same
research-then-review pattern already used for Michelin/W50B/Gault&Millau
bulk import), so the table only ever contains publication-ready data by
construction — there is no unverified state within it to additionally
gate. Acceptable evidence sources for that upstream verification step
remain the same as Step 0 described: the restaurant's own biography/
history, the chef's own professional website, a reputable interview, or
an official employer statement — a business's own marketing website (as
in the reference case) is useful corroborating evidence but is not, on
its own, sufficient; genuine independent verification is the bar before a
provenance row is entered at all.

**Explicitly not built in Step 1**: a dedicated
`private_chef_provenance_evidence` table (service-role-only) is a
plausible future home for structured evidence records if this process
ever outgrows plain documentation — noted for continuity, not created
now, since nothing in the MVP requires it yet.

---

## 14. Chasing Stars Selected — CORRECTED IN STEP 1

**Step 0 originally proposed a separate `chasing_stars_selected` boolean
alongside `publication_status`, reasoning that "row visibility" and
"badge visibility" were conceptually distinct enough to deserve separate
columns. Step 1 rejects that design.**

The product premise is not "some published chefs are selected and some
aren't" — it's the reverse: **a chef only ever becomes visible *because*
Chasing Stars selected them.** There is no scenario in this MVP where a
row is `published` but not selected, or selected but not published — the
two states are, by product definition, the same event. Keeping them as
two columns doesn't protect against a real future divergence; it just
creates a second flag that must always agree with the first, with no
mechanism enforcing that agreement and no product need it actually
serves.

**Resolution: `publication_status = 'published'` is the sole,
authoritative public visibility/selection signal.** No
`chasing_stars_selected` column exists on `private_chefs`. The "CHASING
STARS SELECTED" badge (a future UI concern, not built in Step 1) renders
whenever a chef is visible at all — because visible only ever means
selected. The app must never need `published AND selected = true` to
decide anything; `published` alone is the complete answer.

**`selected_at` (nullable timestamptz, included in the Step 1 migration)
is optional historical/audit context only** — when curation first
approved this chef, for internal record-keeping. It is not read by RLS,
not read by the app to gate visibility, and not auto-set by any trigger;
it would be set manually by a future admin workflow at first-publish
time. Dropping it entirely was considered and rejected only because it is
cheap, harmless, genuinely useful as an audit trail, and — critically —
architecturally inert: nothing about visibility depends on it existing or
being null.

**Internal workflow status does not belong in this table.** A richer
internal pipeline (candidate → reviewing → test-dinner-scheduled →
approved → rejected, etc.) is a real future need, but it must **not**
leak into the client-readable catalogue table — see §16 for why, and §49
for where it belongs instead.

**Step 1A re-assessment (final decision): `selected_at` is kept, exactly
as scoped in Step 1.** Re-examined one last time before pre-deployment
review, specifically for whether it risks semantic confusion now that the
enquiry-hardening work has put every visibility/selection rule under
fresh scrutiny — it does not. It participates in zero RLS policies (grep
of the migration confirms no policy predicate anywhere references
`selected_at`), zero application visibility logic (none exists yet — no
Dart code has been written), and zero badge-rendering logic (not built).
Its only role is a manually-set admin timestamp with no read path back
into anything security- or visibility-relevant. Removing it would save
one nullable column and return no risk-reduction, since it was never a
risk to begin with. Kept as documented: audit/provenance metadata only,
`publication_status = 'published'` remains the sole authoritative
signal.

---

## 15. Test-dinner / internal evaluation model

**Recommendation: a hybrid, heavily qualitative model — a short list of
named dimensions, each with free-text notes, plus one overall qualitative
recommendation.** Explicitly **not** numeric scoring (rejects options C
and pure-A "checklist" in favor of a lighter B/C hybrid), for the same
reason the public side has no numeric score: a number anchors decisions
the wrong way ("7.8 vs 8.1") for what is fundamentally a subjective,
high-touch, low-volume judgment call — "would I confidently recommend
this chef to a Chasing Stars member?"

Dimensions worth naming explicitly (as a *process template* for the
reviewer to write prose against, not as separate database columns — see
§49): food quality, consistency, personalization, wine knowledge/pairing,
service and hospitality, presentation, professionalism, communication,
reliability. The reviewer writes qualitative notes against these as
prompts, then records one overall `recommendation` value
(`recommend`/`recommend_with_notes`/`not_yet`/`decline`). This is
recorded internally (§49), never exposed publicly, and is one of several
inputs into the human publication decision (§41) — not an automatic gate.

---

## 16. Internal/public data separation

**Hard boundary, documented now, enforced by RLS later (§50):**

```
private_chefs                          → public catalogue (published rows only) — BUILT, Step 1
private_chef_restaurant_history        → public catalogue (parent chef published only) — BUILT, Step 1
private_chef_enquiries                 → user-owned only (own INSERT/SELECT, no client UPDATE/DELETE) — BUILT, Step 1
private_chef_photos                    → public catalogue (parent chef published only) — BUILT, Step 2B, see §31/§45
private_chef_internal_reviews          → DEFERRED — admin/service-role ONLY when built, never client-readable, see §15/§49
```

Categories of information that must never become a publicly selectable
catalogue column: test-dinner notes, reliability concerns, rejection
reasons, private contact details (phone/email), internal sourcing notes
(how a chef was found/introduced), and approval/curation notes. All of
these belong in `private_chef_internal_reviews` or admin-only tooling,
never as a column on `private_chefs` itself — this is as much a schema
-design discipline as an RLS one: if a sensitive field is never even
*created* on the public table, there is no RLS policy that can
accidentally leak it.

---

## 17. Experience offering

**Recommendation: one chef profile + one flexible enquiry flow — no
`private_chef_experiences` table in MVP.** The reference case supports
this directly: Jagers Catering lists several experience *types* (dinner
arrangements, full-service catering, walking dinner, wine pairing), but
none of them are independently priced, bookable products — they're all
facets of "what this chef can create for you," best communicated through
`biography`/`personalization_note` as editorial prose plus the enquiry
form's own free-text `occasion`/`message` fields (§26). Modeling them as
separate rows would immediately reopen the price-comparison and
"marketplace product catalogue" risk this document argues against
throughout. If a genuinely distinct, separately-curated experience format
emerges later (e.g. Chasing-Stars-hosted chef collaborations at a
specific venue), that's closer to an Events relationship (§35) than a new
chef-owned product table.

---

## 18. Personalization

**Recommendation: one free-text `personalization_note` column** — not a
checkbox grid (`vegan=yes`/`birthday=yes`/`wedding=yes`/...). The Lucas
example is the direct justification: "adapted very well to the host's
wishes" is a *quality of relationship*, not a list of supported dietary
flags. A curated editorial line ("Menus are built around a conversation
with you — dietary needs, favorite ingredients, and the occasion all
shape the evening") communicates the same trust signal a checkbox grid
would attempt to fake, without making the profile feel like a
configurable e-commerce product.

---

## 19. Wine

**Recommendation**: `wine_pairing_available` (boolean) +
`wine_note` (optional editorial text) — no wine inventory, no vintage/
bottle-level modeling, no sommelier certification taxonomy. The product
question is exactly as the brief frames it: *can this chef meaningfully
create or support a wine-paired experience* — a yes/no plus one line of
editorial context answers that completely. "Sommelier collaboration" is
folded into `wine_note` as prose rather than a separate boolean, since it
describes *how* wine capability is delivered, which is exactly the kind
of nuance free text handles better than a second flag.

---

## 20. Pricing

**Recommendation: support all of price-on-request, from-price-per-person,
and from-price-per-experience, defaulting to price-on-request.**
`price_on_request` (boolean, default `true`) is the safe default; a chef
only shows a number if curation deliberately sets `pricing_from`. Global
currency is required from day one (`pricing_currency`, ISO 4217) — no
assumption of EUR-only, per the global-readiness principle (§39). No
discount labels, deal badges, cheapest-sort, price-ranking, or dynamic
bidding — pricing here is informational context for a member deciding
whether to enquire, never a comparison axis.

---

## 21–22. Availability & service area

No real-time calendar in MVP. `home_city` + `home_country_code` establish
where a chef is based; `service_area_text` (free editorial text, not a
normalized region table) covers everything from "Rotterdam and the wider
Randstad" to "The Netherlands and Belgium" (the reference case) to
"Available for destination dinners worldwide" without needing a
geographic-region taxonomy this MVP has no proven need for.
`travel_available` (boolean) is a cheap, independently useful signal for
a future "chefs who travel" discovery moment, without committing to a
structured multi-region model prematurely. If Chasing Stars' existing
`countries`/`cities` architecture later makes a genuinely useful
structured filter obvious (e.g. "chefs available in France"), a
`private_chef_service_countries` join table would be a clean additive
extension — not designed now, since no current product requirement
justifies it.

---

## 23. Languages

**Classification: MVP_OPTIONAL.** Genuinely useful for a global-facing
product (a host may specifically want a chef who speaks their language),
and cheap to add (`text[]`, no separate table needed for a handful of
language codes/names). Not launch-blocking: the first curated chefs
(including the reference case) don't have this as a differentiator yet,
and it can be added to any existing row with zero migration risk to
anything else. Recommend deferring population, not deferring the column.

---

## 24–26. Enquiry — MVP conversion & architecture

**MVP conversion is "Request an Experience," not booking.** No instant
booking, payment, escrow, calendar, automatic quotes, bidding, in-app
chat, cancellation engine, or availability engine.

**Architecture comparison**:

| Option | Assessment |
|---|---|
| A. `mailto:` link | Loses all product learning (no record of demand, no ownership history for the member), and exposes the chef's raw email — rejected |
| B. External form (e.g. Typeform) | Breaks the in-app experience, no member-side history, no consistent data shape — rejected |
| C. Database-backed Chasing Stars enquiry | **Recommended** — see below |
| D. Direct chef contact (phone/Instagram DM) | Already exists (the reference case has a phone number and email publicly), which is exactly what Chasing Stars' curated mediation should elevate *past* — rejected as the primary path |
| E. Chasing Stars-mediated enquiry | Same as C in practice — a database-backed enquiry *is* the mediation |

**Recommendation: C/E — a database-backed `private_chef_enquiries`
table.** It's the smallest architecture that (a) feels premium (a proper
in-app "Request an Experience" flow, not a mailto link), (b) protects
chef contact details by default, (c) creates a durable record of member
interest the product can learn from later, (d) can evolve toward a real
booking/CRM flow without a redesign, and (e) does not pretend to be a
booking system today (see §48 on naming).

**Proposed fields** — as built in Step 1, see §45–49 for the final,
authoritative shape and the reasoning behind each nullability judgment
call (`private_chef_id` not `chef_id`, `on delete restrict` not cascade,
`wine_pairing_interest` not `wine_pairing_requested`):

| Field | Type | MVP classification |
|---|---|---|
| `id` | uuid pk | MVP_REQUIRED |
| `user_id` | uuid, FK → `profiles(id)` on delete cascade | MVP_REQUIRED |
| `private_chef_id` | uuid, FK → `private_chefs(id)` on delete restrict | MVP_REQUIRED |
| `preferred_date` | date, nullable | MVP_OPTIONAL — many hosts are flexible |
| `location_text` | text, not null | MVP_REQUIRED |
| `guest_count` | smallint, nullable | MVP_OPTIONAL |
| `occasion` | text, nullable | MVP_OPTIONAL |
| `message` | text, nullable | MVP_OPTIONAL — see §45–49 for why this was downgraded from Step 0's "required-in-spirit" |
| `wine_pairing_interest` | boolean, nullable | MVP_OPTIONAL |
| `status` | text + check | MVP_REQUIRED |
| `created_at` / `updated_at` | timestamptz | MVP_REQUIRED |

**Status values**: `submitted`, `contacted`, `in_discussion`,
`confirmed`, `closed`, `declined`. All six are cheap to include from day
one (a `check` constraint list costs nothing to define broadly even if
only `submitted`/`closed` see real usage at first) — including them now
avoids a schema migration purely to add a status value later, and costs
nothing today.

---

## 26A. Enquiry integrity — STEP 1A HARDENING

**Root cause**: the Step 1 INSERT policy on `private_chef_enquiries` only
verified `user_id = auth.uid()`. Ownership was correctly enforced, but
nothing stopped a client from also supplying arbitrary values for other
columns at creation time. Two concrete gaps followed directly from that:
a direct PostgREST client (any caller with a valid `authenticated` JWT,
not necessarily the Flutter app itself) could INSERT a row with `status =
'confirmed'` or `'closed'`, skipping the entire submitted → contacted →
... lifecycle at the moment of creation; and it could target a `draft`
(not yet public) or `archived` (no longer public) chef, since the FK to
`private_chefs(id)` only proves the row exists, not that it is currently
publicly selected.

**Hardened rule — a client-created enquiry must satisfy all three,
enforced entirely in the database, not by Flutter-side discipline**:

1. `user_id = auth.uid()` — unchanged from Step 1.
2. **`status = 'submitted'`** — the column's own `default 'submitted'` is
   necessary but not sufficient on its own, since a direct API client can
   supply any value it likes for a column that merely has a default; the
   initial state is additionally enforced as a hard `WITH CHECK`
   condition.
3. **The target chef is currently `published`** — `exists (select 1 from
   private_chefs pc where pc.id = private_chef_id and
   pc.publication_status = 'published')`.

**Exact final `WITH CHECK` predicate**:
```sql
with check (
  user_id = auth.uid()
  and status = 'submitted'
  and exists (
    select 1 from public.private_chefs pc
    where pc.id = private_chef_id
      and pc.publication_status = 'published'
  )
)
```

**RLS composition — no `SECURITY DEFINER` required.** The `exists(...)`
subquery runs under the same `authenticated` role executing the outer
INSERT, so Postgres applies `private_chefs`' own row security to it — and
`private_chefs_public_read` already restricts `authenticated` to
`publication_status = 'published'` rows only. A draft or archived chef is
therefore *invisible* to this subquery for a normal client regardless of
the explicit status filter also written into it — the two constraints
reinforce each other rather than either depending on the other alone, and
neither depends on bypassing RLS. The explicit `publication_status =
'published'` condition is deliberately kept even though it is presently
implied by `private_chefs`' own SELECT policy: if that policy's
definition ever changes, this `WITH CHECK` does not silently change
behavior with it. `SECURITY DEFINER` was considered and rejected — it
would bypass RLS rather than compose with it, which is unnecessary here
and would widen, not narrow, the trust boundary.

**No client UPDATE, no client DELETE — reconfirmed, unchanged.**
`private_chef_enquiries` has no UPDATE or DELETE policy *and* no
UPDATE/DELETE grant at all (verified directly against the local
database: both a client UPDATE and a client DELETE attempt fail with
Postgres' own `permission denied for table private_chef_enquiries`,
before RLS is even evaluated — blocked at the GRANT layer, the strictest
possible boundary). This means status, ownership, the chef relationship,
and every other field are already fully immutable after insert through
any direct table write — no redundant trigger was added to enforce
something the grant/RLS layer already prevents completely. If
editing or cancellation becomes a real product need later, it must go
through a dedicated, trusted RPC or admin workflow — not a client UPDATE
policy.

**Historical readability is independent of current chef publication
state.** An enquiry's SELECT policy (`user_id = auth.uid()`) does not
reference `private_chefs` at all — only the *INSERT* path checks current
publication status. If a chef is later archived, every enquiry a member
already submitted against them remains fully readable by its owner;
Step 1A's local test matrix confirmed this directly (§ below): a
submitted enquiry against a chef that was subsequently archived by an
admin/service-role update was still returned by the owner's own SELECT
query, unchanged.

---

## 27. Contact privacy

**Recommendation confirmed**: private chef phone numbers and email
addresses are never stored on the public `private_chefs` table and never
exposed by default. The only public "contact-adjacent" surface is the
optional `instagram_url`/`website_url` — genuinely public, professional
presence the chef already controls and has chosen to publish, not a
Chasing-Stars-collected private contact detail. The actual enquiry always
flows through `private_chef_enquiries`, preserving curation (no
direct-to-chef spam), member privacy (the chef doesn't receive a random
phone number), the members'-club positioning (Chasing Stars mediates, it
doesn't just link out), and Chasing Stars' own future ability to
understand aggregate demand.

---

## 28–29. Private Chefs landing & Chef Detail — future information
architecture

**Landing (concept, no UI built)**:
```
deepGreen masthead
  PRIVATE CHEFS
  "Exceptional private dining, personally selected."
↓
ivory editorial content
  Selected chefs — editorial rows/cards with photography
    portrait · chef name · optional business name · location ·
    short proposition · CHASING STARS SELECTED
```
No marketplace sidebar, no filter panel, no price sort, no rating sort,
no availability calendar, no "Top 10 cheapest chefs." Lightweight
discovery only: location and travel availability, if anything at all in
MVP.

**Chef Detail hierarchy — critiqued and revised**:

```
HERO (deepGreen, high-quality photography)
  Chef name
  Optional business identity (subordinate line)
  Location
  CHASING STARS SELECTED
↓
ABOUT
  Biography / cooking philosophy
↓
PROVENANCE
  Previously at
  Parkheuvel ★★  → RestaurantDetailScreen
↓
THE EXPERIENCE
  Personalization proposition
  Guest range · service area · travel · wine capability
↓
INSTAGRAM / WEBSITE
↓
REQUEST AN EXPERIENCE
```

**Provenance placed before "The Experience," reversing the task's own
draft order** — deliberately. Think through the premium decision journey:
a member has just read *who this person is* (ABOUT); the very next
question a skeptical, premium buyer asks is *why should I trust this
claim* — provenance is the credibility payoff that makes everything after
it (the experience proposition, the price context, the ask to enquire)
land with more weight. Putting "The Experience" first would ask the
member to take the personalization/wine/guest-range claims on faith
before they've seen any third-party-adjacent credibility signal at all.
Provenance is the hinge between "who are you" and "what will you do for
me" — it belongs right after the introduction, not after the pitch.

---

## 30. Chef vs. brand UI

Tested directly against Jagers Catering. The default template:

```
Lucas de Jager
Private Chef · Jagers Catering
```

— person-first, business as context, matching §4's schema decision
exactly (`display_name` primary, `business_name` subordinate). This
default must remain flexible enough to also render:
- Independent chef, no business: just `display_name`, no second line.
- A small team led by a named chef: same template — the person stays the
  headline; the team is still the subordinate line, since Chasing Stars
  curates a *chef relationship*, not a company account.

No decision is being locked in based on the one candidate alone — the
architecture (§4) supports all three shapes without a schema change; only
the *rendering template* is proposed here, and it's a straightforward
"primary name, optional secondary line" pattern already used elsewhere in
this app's own design language (e.g. `IdentityRow`'s name/@username
composition).

---

## 31. Photography — `private_chef_photos` BUILT IN STEP 2B

**Step 1 decision (superseded): `private_chef_photos` was not created.**
Before building it, Step 1's audit checked whether an existing, mature
media pattern in this codebase (the `photos`/`visit_photos` shape) made
the table necessary immediately for the schema to stay coherent — it
didn't: `profile_image_url` alone was a complete, valid MVP shape for a
chef with no gallery at all, and building a gallery table with no real
content or image-rights workflow to populate it would have been
speculative infrastructure.

**Step 2B: that content/image-rights need became concrete** (a 5-photo
hero gallery, product-approved) and `private_chef_photos` was built —
see the "STEP 2B" section above for the full design (schema, RLS,
max-5 trigger, ordering, and the `profile_image_url` vs.
`private_chef_photos` split). It uses a plain `image_url text` column
(matching `profile_image_url`'s own shape), **not** the `photos`/
`visit_photos` table's `storage_path` + Supabase-Storage pattern — that
pattern is for user-uploaded personal content in a Storage bucket, a
genuinely different system for a genuinely different (private,
user-owned) use case. Private Chef photography remains admin-curated,
supplied as already-hosted, rights-cleared URLs — exactly the model this
section originally anticipated.

---

## 32. Reviews

**No public reviews in MVP.** Confirmed, no changes to this stance.
Trust comes from curation + provenance + editorial profile + photography.
Future-only concepts, explicitly not designed now: verified post
-experience feedback (a member who actually enquired and dined could
leave a private, curated testimonial Chasing Stars chooses whether to
surface — closer to an editorial pull-quote than a review), purely
internal feedback (feeds `private_chef_internal_reviews`, never public),
or a curated testimonial system (hand-picked, attributed or anonymized
quotes, not an open review feed). None of these are built here.

---

## 33. Wishlist

**No change to Wishlist in this task.** Wishlist stays Restaurants/Hotels
only, per the already-finalized Wishlist UI Consistency work. Future
options, documented and deferred:

- **A. "Save Chef"**: the simplest extension — Wishlist's existing
  `entity_type`/`entity_id` polymorphic shape (`wishlist.entity_type
  check (entity_type in ('hotel','restaurant'))`) could in principle grow
  a third `'private_chef'` value.
- **B. Full polymorphic expansion**: same mechanism as A, just framed as
  "the general pattern," not a special case.
- **C. No chef Wishlist**: private chefs are a *relationship* (enquire,
  discuss, dine), arguably a poor fit for a "save for later" list
  semantics that Restaurants/Hotels use for genuinely deferred visits.

**Recommendation (for a future task, not decided here)**: A is
architecturally trivial (one new allowed `entity_type` value, one new
`PassportVenue`-style sealed-class case on the Flutter side) *if* product
direction wants it — but C deserves serious consideration first, since
"saving" a chef for later arguably undersells the curated, limited-supply
positioning this whole document argues for. Flagged as a genuine open
product question, not a default yes.

---

## 34. Passport

**Not added now.** Future concept, documented only: a completed private
dining experience could conceptually become a "Private Dining" stamp/
history entry in Passport, parallel to how a restaurant visit or hotel
stay is recorded today. This would require its own `entity_type` (or a
dedicated `private_chef_visits`-style table, since a private dining
experience isn't really "visiting a venue" the way a restaurant visit is)
and a real product decision about what "completing" an experience even
means without a booking system. Not designed further here.

---

## 35. Events

**Not built now.** The `events` migration (2026-08-10) already sketches
the exact future shape in its own comments: a `public.chefs` catalogue
table (this document's `private_chefs`) plus an `event_chefs` join table,
identical in structure to the already-existing `event_restaurants`/
`event_hotels`:
```sql
-- create table public.event_chefs (
--   id uuid primary key default gen_random_uuid(),
--   event_id uuid not null references public.events(id) on delete cascade,
--   chef_id uuid not null references public.private_chefs(id) on delete cascade,
--   unique (event_id, chef_id)
-- );
```
This document confirms that sketch remains architecturally correct and
requires zero changes to `events` itself when eventually built — noted
here for continuity, not created now.

---

## 36. Friends / Community

**Not built in MVP.** Explicitly excluded: "friends used this chef,"
"friends recommend this chef," any friend-based chef score, social
ranking, or a chef activity feed. Future context worth documenting only:
if `private_chef_enquiries` exists and a member's *own* enquiry history
were ever made friends-visible (mirroring the existing `visits`/
`wishlist` friends-visibility model), a "friends who've dined with this
chef" signal *could* one day exist using the exact same `is_friend()`
-based RLS pattern already established for visits/wishlist/event
attendance. Not designed further — flagged only because the *mechanism*
already exists in this codebase and wouldn't need to be invented from
scratch if this direction is ever pursued.

---

## 37. Explore placement

**Recommendation: a quiet, dedicated editorial entry point in Explore —
not a filter, not a new bottom-navigation tab (frozen at five, per this
task's own instruction).** Precedent already exists in this exact
codebase: Explore's own "Browse the Guides" row (`GuideDestinationRow`,
`_openGuides` → `Navigator.push` to `GuidesScreen`) is structurally
identical to what a "Private Chefs" entry would need — a single editorial
row/card in Explore that pushes to a dedicated, canonical Private Chefs
landing screen, exactly mirroring how Guides is discovered from Explore
today without adding a new tab or overcrowding Explore's existing
Restaurants/Hotels/Events/What's On content. Information architecture
only — no Flutter code proposed or written here.

---

## 38. World's 50 Best Bars — future context

Not built now. Noted only so this architecture doesn't accidentally
foreclose it: Private Chefs is being designed as its own clear domain
(`private_chefs`, not a row in some generic `venues` mega-table), which
is the same pattern a future Bars domain would need — a dedicated
`bars`-style catalogue table, its own join tables where relevant
(`event_bars`, potentially a bar's own provenance-adjacent concepts), and
no forced merger into Restaurants/Hotels. This document deliberately
avoids over-generalizing Private Chefs into a shape that would make a
*different* future domain (Bars) awkward — each new domain gets its own
clear table, following the restaurants/hotels/events precedent already
established three times over in this schema.

---

## 39. Global readiness

The architecture assumes none of: Netherlands-only, EUR-only, Dutch
-language-only, one-city-per-chef, no travel, a single restaurant
background, or a single business identity — every field above (
`home_country_code` as a real FK to the existing global `countries`
table, `service_area_text` as free text rather than a fixed region list,
`pricing_currency` as ISO 4217 rather than an implied EUR, `business_name`
as fully optional, `private_chef_restaurant_history` as one-to-many in
both directions) is already global-shaped. Explicitly **not** built in
MVP: a tax engine, payment-compliance handling, currency conversion, or
international booking infrastructure — none of which are needed until
payments/booking themselves are (deferred, §5).

---

## 40. Legal / content-quality flags (product/data requirements, not
legal conclusions)

Translated into concrete data/process requirements for the future
publication workflow (§41, §53), not legal advice:
- **Publish permission**: a chef (and, where relevant, the business they
  operate through) must have explicitly consented to being profiled
  before `publication_status` can move to `published` — a process
  requirement, not a database column, though a simple `permission
  _confirmed_at timestamptz` on the internal review record (§49) would be
  a reasonable place to track it if needed.
- **Photography rights**: portrait/gallery images must be rights-cleared
  for Chasing Stars' use (chef-supplied, commissioned, or licensed) —
  tracked as part of the curation checklist (§41), not a public column.
- **Instagram/website linking permission**: linking to a chef's public
  professional account doesn't need separate legal permission the way
  using their photography does, but confirming the account *is* the
  chef's own (not a fan account, not a former employer's account) is a
  verification step (§41).
- **Employment/provenance claims**: exactly why `verified_at` exists on
  `private_chef_restaurant_history` — an unverified provenance claim is a
  factual risk about a *third party* (the restaurant), not just the chef.
- **Michelin attribution**: covered exhaustively in §10 — the hard rule
  exists precisely because of this legal/reputational risk.
- **Business-name use**: using "Jagers Catering" publicly requires
  confirming that's the correct, current, permitted public name for the
  business — not assumed from a single web source.
- **Pricing accuracy**: if `pricing_from` is ever populated, it must be
  something the chef has actually confirmed, not inferred from market
  norms — `price_on_request` defaulting to `true` is partly a legal/
  accuracy safeguard, not just a product-tone choice.
- **Enquiry privacy**: `private_chef_enquiries.message` may contain
  sensitive personal context (an occasion, a location, guest details) —
  it must be treated with the same privacy posture as any other
  user-generated personal data in this schema (owner-only RLS, §50).
- **Personal contact details**: reconfirmed, §27 — never stored on the
  public catalogue table.

---

## 41. Publication standard

Refined from the task's own draft — grouped the same way, with hard
blockers explicitly marked:

**IDENTITY** *(hard blockers)*
- ✓ Chef identity confirmed directly with the chef (not inferred solely
  from a third-party website)
- ✓ Correct public `display_name` confirmed
- ✓ `business_name`, if used, confirmed as correct and permitted

**PROFILE** *(hard blockers)*
- ✓ Rights-cleared portrait image approved
- ✓ Biography approved (by Chasing Stars editorially, and confirmed
  accurate by the chef)

**PROVENANCE** *(hard blocker only if provenance is shown at all)*
- ✓ Every provenance row is independently verified **before** it is
  entered into `private_chef_restaurant_history` at all (§13 — there is
  no `verified_at` column to check after the fact; verification is a
  precondition of the row existing, not a gate on top of it)
- ✓ Every displayed row with a matching catalogue restaurant uses the
  canonical FK, never a duplicate text-only entry for a restaurant that
  *does* exist in the catalogue

**SOCIAL** *(soft — not a hard blocker on its own)*
- ✓ Instagram/website, if shown, confirmed as genuinely the chef's own
  professional presence

**EXPERIENCE** *(soft — improves the profile, doesn't block it alone)*
- Service area known; guest range known if relevant; personalization
  proposition understood; wine capability understood

**CURATION** *(hard blockers)*
- ✓ Chasing Stars internal review completed (§15/§49)
- ✓ Test dinner completed where required by that review
- ✓ Explicit human approval to publish

**CONTACT** *(hard blocker)*
- ✓ Enquiry path (`private_chef_enquiries`) functional for this chef
- ✓ No unintended personal contact data (phone/email) present anywhere
  on the public row

A chef can launch with a thinner EXPERIENCE/SOCIAL section (soft) but
never with unresolved IDENTITY, PROFILE, unverified-yet-displayed
PROVENANCE, incomplete CURATION, or a CONTACT gap — those five are the
non-negotiable minimum.

---

## 42. Product differentiation (summary)

| Chasing Stars Private Chefs | Generic chef marketplace |
|---|---|
| Curated, limited roster | Open, self-service listing |
| Editorial storytelling | Product-catalogue listings |
| Provenance tied to a real, canonical restaurant catalogue | Unverifiable resume claims |
| Qualitative trust ("Chasing Stars Selected") | Numeric star ratings, review counts |
| Personalized, conversational experience proposition | Configurable product options |
| Wine capability as a curated differentiator | Rarely modeled at all |
| Mediated, privacy-preserving enquiry | Direct contact / instant booking |
| Members'-club feeling | Gig-economy / price-comparison feeling |

This table is the north star for both this architecture and whatever UI
work follows it — any future proposal that pulls toward the right column
should be treated as a scope-creep warning sign, not a feature request.

---

## 43. Strict MVP (restated with challenges resolved)

Confirmed IN / LIKELY DEFER lists from §5, with the one challenge from
that section applied: "multiple bookable products per chef" is deferred
specifically because it would reopen per-product pricing, not merely
because it's "extra scope."

---

## 44. Current database architecture — audit summary

Conventions confirmed by reading the actual current schema/migrations
(not assumed):
- **PKs**: `uuid primary key default gen_random_uuid()` everywhere.
- **User FK**: `user_id uuid not null references public.profiles(id) on
  delete cascade` (visits, wishlist, planned_trips, event_attendance,
  friendships all match this exactly).
- **Countries**: `countries.country_code char(2) primary key`; every
  country-referencing column is `char(2) references public.countries
  (country_code)` (restaurants, hotels, events, profiles.home_country_code
  all match).
- **Cities**: `public.cities` is a *curated* Michelin-guide-edition-scoped
  table with a `(country_code, name, region)` uniqueness constraint —
  used by `restaurants`/`hotels` (catalogue entities that must resolve to
  a known, curated city). `events.city` is deliberately **plain text**,
  not a `cities` FK, with its own comment explicitly reasoning that an
  event's city "must not be restricted to the curated Michelin-guide city
  list." **This is the exact precedent `private_chefs.home_city` follows**
  — a chef's home city is no more restricted to the Michelin-guide city
  list than an event's is.
- **Timestamps**: `created_at timestamptz not null default now()`
  universally; `updated_at timestamptz not null default now()` plus a
  shared `set_updated_at()` trigger function wherever a row is expected
  to be edited after creation (restaurants, hotels; not on append-only/
  rarely-edited tables like `visits`).
- **Status/taxonomy fields**: this schema deliberately uses **`text` +
  `check (...)`** for taxonomies expected to grow or vary (`event_type`,
  event `status`, `wishlist`/`visits.entity_type`, `worlds_50_best
  .list_type`), reserving a real Postgres `enum` (`venue_status`) only for
  one older, materially fixed lifecycle. `private_chefs.publication
  _status` and `private_chef_enquiries.status` both follow the `text` +
  `check` convention, matching the newer, more-likely-to-grow precedent.
- **Join tables**: synthetic `id uuid primary key` + a `unique(...)`
  constraint on the pair of FKs — never a composite primary key
  (`hotel_restaurants`, `event_restaurants`, `event_hotels` all match).
  `private_chef_restaurant_history` follows the same shape.
- **Admin-managed catalogue tables**: RLS = public `select` only (`for
  select to anon, authenticated using (true)`, or — new for this domain —
  gated on `publication_status = 'published'`), with **no** insert/
  update/delete policy for any client role at all; writes happen only via
  the service role through import/admin scripts. `events`/`restaurants`/
  `hotels` all match this; `private_chefs` follows the same pattern with
  one deliberate addition (the publication-status gate) since, unlike
  events, not every row is meant to be publicly visible the moment it
  exists.
- **State-machine-shaped writes**: where a table's valid transitions are
  more subtle than plain row ownership, this project mediates through a
  `SECURITY DEFINER` RPC rather than direct client writes (`friendships`'
  `send_friend_request`/`accept_friend_request`/etc. have no direct
  insert/update policy at all). `private_chef_enquiries`' status
  transitions (submitted → contacted → ... ) are exactly this shape, and
  should follow the same RPC-mediated pattern once built — documented in
  §50, not implemented here.
- **Repository convention**: every existing repository selects an
  explicit, named column list (`restaurantFullColumns`, `hotelFullColumns`,
  `_attendanceColumns`), never `select *`. **Step 1 correction**: this
  convention is a client-side readability/discipline habit, not a
  security boundary — RLS in this project is row-level everywhere, so a
  column reachable by a table's SELECT policy is reachable by any client
  with a valid key regardless of what a specific repository queries. This
  is exactly why `source_url`/`verified_at` were removed from
  `private_chef_restaurant_history` entirely rather than merely omitted
  from a repository's select list (§13).
- **GRANT requirement**: this project's own migration history (Social
  Foundation Step 1) records, the hard way, that a table-level `grant
  select[, insert, ...] on public.<table> to authenticated` is required
  *in addition to* RLS policies for a brand-new table — RLS alone is a
  no-op without it. Noted here as a reminder for whenever this is
  actually built.

---

## 45–49. Database — AS BUILT in Step 1

The Step 0 concept-only tables below are superseded by the actual Step 1
migration (`supabase/migrations/20260817120000_create_private_chefs_foundation.sql`).
Differences from the Step 0 concept are called out inline.

### `private_chefs` (built)

| Field | Type | Null | Default | Constraint / FK | Index | Public/Private |
|---|---|---|---|---|---|---|
| `id` | uuid | not null | `gen_random_uuid()` | pk | pk | Public |
| `slug` | text | not null | — | unique + kebab-case format check | unique idx | Public |
| `display_name` | text | not null | — | — | — | Public |
| `business_name` | text | null | — | — | — | Public |
| `biography` | text | null | — | — | — | Public |
| `personalization_note` | text | null | — | — | — | Public |
| `home_city` | text | null | — | — | — | Public |
| `home_country_code` | char(2) | null | — | FK → `countries` | idx | Public |
| `service_area_text` | text | null | — | — | — | Public |
| `travel_available` | boolean | not null | `true` | — | — | Public |
| `minimum_guests` | smallint | null | — | check `> 0` when set | — | Public |
| `maximum_guests` | smallint | null | — | check `> 0` when set, `>= minimum_guests` when both set | — | Public |
| `wine_pairing_available` | boolean | not null | `false` | — | — | Public |
| `wine_note` | text | null | — | — | — | Public |
| `price_on_request` | boolean | not null | `true` | — | — | Public |
| `pricing_from` | numeric(10,2) | null | — | check `>= 0` | — | Public |
| `pricing_currency` | char(3) | null | — | check `^[A-Z]{3}$` | — | Public |
| `pricing_unit` | text | null | — | check in (`per_person`,`per_experience`) | — | Public |
| `instagram_url` | text | null | — | — | — | Public |
| `website_url` | text | null | — | — | — | Public |
| `profile_image_url` | text | null | — | — | — | Public |
| `languages` | text[] | null | — | — | — | Public |
| `publication_status` | text | not null | `'draft'` | check in (`draft`,`published`,`archived`) | idx | Public — **the sole selection signal, §14** |
| `selected_at` | timestamptz | null | — | — | — | Public (audit-only, never read for visibility, §14) |
| `created_at` | timestamptz | not null | `now()` | — | — | Internal |
| `updated_at` | timestamptz | not null | `now()` | trigger `set_updated_at()` | — | Internal |

**Not in the Step 1 migration** (see the field-classification table in
§6 for reasoning on each): `headline`, `cuisine_style`, `featured`,
`display_order`, `chasing_stars_selected` (never built — see §14, this
one is a deliberate permanent removal, not a deferral).

**Nullability note**: `home_city`/`home_country_code`/`service_area_text`
are schema-nullable (a draft profile mid-curation may not have every
field filled yet); the *publication* gate, not a NOT NULL constraint, is
what should enforce "a published chef has a known home city" as part of
the human publication standard (§41), matching `profile_image_url`'s own
established nullability reasoning from Step 0.

**Chef/business modeling decision**: confirmed — one table, `display_name`
+ optional `business_name`, no `private_chef_businesses` table (§4, §46).

### `private_chef_restaurant_history` (built)

| Field | Type | Null | Default | Constraint / FK | Index | Public/Private |
|---|---|---|---|---|---|---|
| `id` | uuid | not null | `gen_random_uuid()` | pk | pk | Public |
| `private_chef_id` | uuid | not null | — | FK → `private_chefs(id)` on delete cascade | idx | Public |
| `restaurant_id` | uuid | null | — | FK → `restaurants(id)` on delete set null | idx | Public |
| `restaurant_name_text` | text | null | — | XOR check with `restaurant_id` — exactly one populated, §11–12 | — | Public |
| `role` | text | null | — | — | — | Public |
| `period_text` | text | null | — | — | — | Public |
| `display_order` | smallint | not null | `0` | — | — | Public |
| `created_at` / `updated_at` | timestamptz | not null | `now()` | `updated_at` via `set_updated_at()` trigger | — | Internal |

**Removed from the Step 0 concept**: `is_current` (dropped, §11–12),
`source_url`/`verified_at` (removed entirely — evidence lives outside
this table, §13).

### `private_chef_photos` (built, Step 2B)

| Field | Type | Null | Default | Constraint / FK | Index | Public/Private |
|---|---|---|---|---|---|---|
| `id` | uuid | not null | `gen_random_uuid()` | pk | pk | Public |
| `private_chef_id` | uuid | not null | — | FK → `private_chefs(id)` on delete cascade | idx | Public |
| `image_url` | text | not null | — | — | — | Public |
| `alt_text` | text | null | — | — | — | Public |
| `display_order` | smallint | not null | `0` | unique with `private_chef_id` | — | Public |
| `created_at` / `updated_at` | timestamptz | not null | `now()` | `updated_at` via `set_updated_at()` trigger | — | Internal |

Max 5 rows per chef enforced by a `BEFORE INSERT` trigger
(`private_chef_photos_max_five`), not merely a curation convention — see
§31 for the full reasoning, including why `display_order` alone (no
`is_cover` boolean) is the single ordering source of truth.

### `private_chef_enquiries` (built)

| Field | Type | Null | Default | Constraint / FK | Public/Private |
|---|---|---|---|---|---|
| `id` | uuid | not null | `gen_random_uuid()` | pk | Owner-only |
| `user_id` | uuid | not null | — | FK → `profiles(id)` on delete cascade | Owner-only |
| `private_chef_id` | uuid | not null | — | FK → `private_chefs(id)` **on delete restrict** — see below | Owner-only |
| `preferred_date` | date | null | — | — | Owner-only |
| `location_text` | text | **not null** | — | — | Owner-only |
| `guest_count` | smallint | null | — | check `> 0` when set | Owner-only |
| `occasion` | text | null | — | — | Owner-only |
| `message` | text | null | — | — | Owner-only |
| `wine_pairing_interest` | boolean | null | — | — | Owner-only |
| `status` | text | not null | `'submitted'` | check in (`submitted`,`contacted`,`in_discussion`,`confirmed`,`closed`,`declined`) | Owner-only read; no client write of transitions at all |
| `created_at` / `updated_at` | timestamptz | not null | `now()` | `updated_at` via trigger | Owner-only |

**Judgment calls made explicit** (Step 1's own field list left these
ambiguous):
- **`location_text` is required, not optional.** A private-dining enquiry
  with no location context at all isn't actionable for a chef weighing
  travel/logistics — this is the one enquiry field kept mandatory beyond
  ownership itself.
- **`guest_count` is nullable**, despite Step 0's "required (product)"
  framing. Forcing an exact number at first-touch contradicts the
  "bespoke, not e-commerce" positioning this whole document argues for —
  a host may genuinely want to open a conversation before committing to a
  number.
- **`message` is nullable**, not required — same reasoning: a short,
  structured enquiry (date + location + guest count) is still a valid,
  actionable enquiry without free text.
- **`wine_pairing_interest`** (renamed from Step 0's
  `wine_pairing_requested`) is a nullable boolean with no default, so
  "never asked/answered" stays distinguishable from an explicit "no."

**`private_chef_id` uses `on delete restrict`, not cascade** — a
deliberate divergence from every other FK in this table/schema. A
member's own enquiry is their own activity history, not the chef's data;
losing it silently because a catalogue row was later removed would
contradict this project's own "History Is Permanent" principle
(`DATABASE_GUIDE.md`). Chefs are admin-managed and low-volume, expected to
be archived (`publication_status = 'archived'`), not hard-deleted, in the
ordinary course of business — `restrict` makes that expectation
structural: an attempt to delete a chef row with existing enquiries fails
loudly instead of silently erasing member history.

**Naming**: deliberately `_enquiries`, never `_bookings` — this is not a
booking, and calling it one would misrepresent the product to both
members and chefs (§48).

### `private_chef_internal_reviews` — DEFERRED, not built in Step 1
(future, admin-only — documented, not built)

| Field | Type | Notes |
|---|---|---|
| `id` | uuid pk | |
| `chef_id` | uuid, FK → `private_chefs(id)` on delete cascade | |
| `reviewer_user_id` | uuid, FK → `profiles(id)` | The internal team member conducting the review |
| `review_type` | text, check in (`portfolio_review`,`test_dinner`,`reference_check`,`follow_up`) | |
| `reviewed_at` | timestamptz | |
| `recommendation` | text, check in (`recommend`,`recommend_with_notes`,`not_yet`,`decline`) | The one structured judgment field — §15 |
| `notes` | text | Free-form qualitative notes against the named dimensions (§15) — not split into per-dimension columns; a low-volume, high-touch process doesn't need that structure |
| `created_at` | timestamptz, default `now()` | |

**No client role — anon or authenticated — ever gets a policy on this
table.** Not RLS'd open-then-restricted; simply never granted.

---

## 50. RLS design — AS BUILT in Step 1, hardened in Step 1A

```
private_chefs
  select: to anon, authenticated using (publication_status = 'published')
  insert/update/delete: none for any client role (service role only)
  grant: select to anon, authenticated

private_chef_restaurant_history
  select: to anon, authenticated using (
    exists (
      select 1 from private_chefs pc
      where pc.id = private_chef_id and pc.publication_status = 'published'
    )
  )
  -- no verified_at condition — §13's correction means there is no
  -- unverified state within this table left to additionally gate
  insert/update/delete: none for any client role
  grant: select to anon, authenticated

private_chef_enquiries
  select: to authenticated using (user_id = auth.uid())
  insert: to authenticated with check (
    user_id = auth.uid()
    and status = 'submitted'
    and exists (
      select 1 from private_chefs pc
      where pc.id = private_chef_id and pc.publication_status = 'published'
    )
  )
  -- Step 1A hardening — see §26A for the full root cause, the RLS
  -- composition reasoning (no SECURITY DEFINER needed), and the local
  -- test matrix that verified this predicate under real role/RLS
  -- simulation.
  update/delete: none directly — status transitions go through a future
    SECURITY DEFINER RPC (matching friendships' send/accept/decline
    pattern), never a raw client update, so a member can never edit their
    own enquiry into 'confirmed' or impersonate a status change
  grant: select, insert to authenticated (deliberately no update/delete
    grant in the migration's own text, matching the absence of any
    update/delete policy)

private_chef_photos
  select: to anon, authenticated using (
    exists (
      select 1 from private_chefs pc
      where pc.id = private_chef_id and pc.publication_status = 'published'
    )
  )
  insert/update/delete: none for any client role
  grant: select to anon, authenticated

private_chef_internal_reviews — DEFERRED, not built (§15, §49)
```

Every built table's explicit `grant select[, insert] on public.<table> to
<role>` statement is present in the migration, alongside RLS — this
project's own migration history (Social Foundation Step 1) already
learned the hard way that a *missing* grant makes RLS a no-op (no table
privilege at all means no access regardless of policy).

**Correction, post-deployment (project-wide privilege audit,
2026-08-17)**: this project's Supabase bootstrap grants `anon`/
`authenticated` broad table privileges by default on every table in
`public`, confirmed identical on all 25 other application tables. This
means the migration's own explicit `grant select[, insert]` statements
above do **not** themselves narrow production access the way this
section originally implied — live production inspection found `anon`/
`authenticated` hold full `SELECT`/`INSERT`/`UPDATE`/`DELETE`/etc. on all
three Private Chefs tables regardless of what the migration explicitly
grants. **RLS is the actual, sole, authoritative boundary**: a client
UPDATE/DELETE against `private_chef_enquiries` in production is blocked
by RLS (zero matching rows, since no UPDATE/DELETE policy exists), not
by a missing grant. This matches `friendships`' own long-established
pattern exactly (broad grant, zero write policy, RLS is what closes it)
— see `docs/Architecture/DATABASE_GUIDE.md`'s "Row Level Security"
section for the project-wide finding.

---

## 51. Admin / content management

MVP workflow (documented, not built): research/enrichment artifacts (the
same pattern already used for Michelin/W50B/Gault&Millau — see the Claude
Data Pipeline in `DATABASE_GUIDE.md`) → human approval → SQL/admin
ingestion → production → app. No chef self-registration, no chef-facing
admin portal, no in-app profile editing — all of that is explicitly later
-stage, once/if a real content-ops need justifies building it.

---

## 52. Evidence model — CORRECTED IN STEP 1

Resolved in §13, superseding the resolution originally recorded here:
**no evidence columns exist on `private_chef_restaurant_history` at
all.** Step 0 had resolved this by keeping `source_url`/`verified_at` as
production columns, relying on the repository's explicit-column-list
convention to keep them out of normal app reads — Step 1 identified that
convention as a client-side habit, not a server-side security boundary,
since RLS in this project is row-level, not column-level. The *research
process* that leads to a decided, verified source belongs in enrichment
artifacts, matching the existing Michelin/W50B/Gault&Millau pipeline —
but the resulting evidence stays there, outside any publicly-readable
table, rather than being promoted onto the row it supports. A future
service-role-only `private_chef_provenance_evidence` table remains a
plausible next step if this process ever needs structured storage — not
built now.

---

## 53. First test chef workflow — Lucas (documented, not executed)

Refined from the task's own draft:

1. Confirm Lucas's full identity directly with him (not solely from the
   business website) — including whether "Lucas de Jager" is the name he
   wants used publicly.
2. Obtain explicit permission to build and publish a Chasing Stars
   profile.
3. Confirm whether "Jagers Catering" is the correct public business
   identity he wants attached, or whether he'd prefer to lead purely
   under his own name.
4. Verify the Instagram account (@jagerscatering) is his own/his
   business's genuine professional account.
5. Verify jagers-catering.nl is his own/his business's genuine
   professional website.
6. Collect rights-cleared portrait and (optionally) gallery images.
7. Collect and approve biography text (informed by, but not copied
   verbatim from, the website's existing philosophy language, unless he
   explicitly grants permission to reuse it).
8. Document cooking philosophy/style in his own words where possible.
9. Determine service area precisely (confirm "Netherlands and Belgium"
   still holds, and whether it should be phrased differently).
10. Determine guest range (minimum/maximum), if he has one.
11. Determine pricing-disclosure preference (on-request vs. a public
    from-price).
12. Determine how to represent wine/pairing capability (confirm the
    sommelier-experience detail directly with him rather than relying on
    the ambiguous website phrasing).
13. **Independently verify** the Parkheuvel provenance claim — the
    website's own corroborating statement is a helpful signal, not
    sufficient verification on its own (§32/§41); seek a source
    independent of Jagers Catering's own marketing (e.g. direct
    confirmation from Lucas with enough detail to cross-check, or a
    source connected to Parkheuvel itself).
14. Resolve Parkheuvel against the canonical `restaurants` catalogue —
    confirm it exists there (it should, as a recognized Michelin
    establishment) and capture its `restaurant_id`.
15. Document the user's own private-dinner experience as internal input
    to the review (§15/§49) — valuable first-hand signal, but one input
    among several, not sufficient alone for approval.
16. Decide whether an additional, more formal test dinner is needed given
    the user already has firsthand experience, or whether that existing
    experience can partially substitute — a curation judgment call, not
    an automatic rule.
17. Complete the internal review record (`private_chef_internal_reviews`,
    once built) with an explicit `recommendation`.
18. Prepare the profile as a `draft` row.
19. Human review of the complete draft against the Publication Standard
    (§41).
20. Publish (`publication_status = 'published'` — alone, no separate flag
    to set, §14).
21. Physical-device review of the live profile (matching this project's
    own established review discipline for every UI change).
22. Test the enquiry flow end-to-end using a real (test) member account,
    confirming the enquiry reaches the intended internal recipient and
    that no personal contact detail leaks anywhere in the process.

---

## 54–58. UI direction (design proposal only — no Flutter code)

**Design system**: Private Chefs inherits the finalized system exactly —
`AppColors.deepGreen` (`#16302A`) as the primary dark surface, `ivory` as
the content canvas, `taupe`/`secondaryOnDark` for secondary text,
`forestGreen` where a secondary-elevated-panel role is genuinely needed
(matching its established role, not as a masthead color — see the Green
Token Consistency Migration). Gold remains reserved for Michelin/Keys
recognition beside the linked **Restaurant**, never beside a chef's name,
"Chasing Stars Selected," buttons, Instagram/website links, the enquiry
CTA, or any section heading.

**Landing**: deepGreen masthead ("PRIVATE CHEFS" + short curated-supporting
copy) over ivory editorial content — selected-chef rows/cards with real
photography, never generic marketplace card styling, no ratings, no
review counts, no price badges, no discount treatment.

**Chef Detail hierarchy** (final recommendation, per §29): Hero → About →
Provenance → The Experience → Instagram/Website → Request an Experience.

**Provenance row** (§57): a single editorial row — thumbnail, restaurant
name with `StarRow` beside the *restaurant* name only, city/country
context — matching the same restrained, non-marketplace row language
already established for `LinkedVenueRow`/`GuideVenueCard` elsewhere in
this app. The whole row is tappable, opening the canonical
`RestaurantDetailScreen`; no card-heavy marketplace styling, no chef-star
attribution anywhere near it.

**Enquiry** (§58): "Request an Experience" → a short in-app form
(preferred date, location, guests, occasion, wine-pairing interest, a
free-text message) → "Send Request." No checkout, no "Book now," no
payment step, no fabricated availability calendar.

---

## 59. Future testing strategy (not implemented)

For whenever this becomes real code: published-chef rendering vs.
unpublished-chef hidden from normal clients; optional `business_name`
present/absent; optional Instagram/website present/absent; a provenance
row linking to a canonical Restaurant vs. a text-only provenance row;
multiple provenance rows for one chef, correctly ordered; no fabricated
Michelin attribution ever rendered beside a chef; tapping a provenance
row opens the exact canonical `RestaurantDetailScreen`; an enquiry is
always created with the *authenticated caller's own* `user_id` (spoof
-prevention); a user can read their own enquiries and never another
user's; `private_chef_internal_reviews` is unreachable by a normal
authenticated client entirely; long chef names, long business names, and
globally varied locations (non-Latin scripts, long country names) don't
break layout; non-EUR pricing renders correctly; `travel_available`
renders sensibly when true/false; 320px/390px/1.6× text scale across
every section; and a full sweep confirming zero decorative gold anywhere
on a Chef Detail screen.

---

## 60. Summary of deferred features

Payments, instant booking, real-time availability, chef self-service,
in-app chat, a chef-matching engine, public reviews/ratings/rankings,
dynamic pricing, friend-based chef intelligence, Passport integration,
Wishlist integration, and Events relationships (`event_chefs`) are all
explicitly out of this MVP, with the architectural seams for each
documented above (§33–36, §38) so that building any of them later
requires an *extension*, never a redesign — matching this project's own
stated database philosophy.

---

## 61. Step 2C — Editorial discovery redesign + cover photo

The Private Chefs landing was rebuilt from a compact, directory-style
list (`PrivateChefRow` + circular `PrivateChefAvatar`, both deleted in
this step) into a curated editorial collection — the product framing is
"a members-club recommendation," not a marketplace/search-results list,
matching how ~5 chefs per country is expected at this scale, not
hundreds. The deepGreen masthead (title, subtitle, back button, safe
-area treatment) is unchanged from its original Step 2 approval; only the
body beneath it changed.

**Country grouping.** Chefs are grouped by `home_country_code` under a
quiet uppercase country heading (`CsTypography.eyebrow`, taupe) —
deliberately not "N results" search-result language. Grouping and
alphabetical-by-resolved-name sort order live in a pure function
(`groupChefsByCountry`, `lib/features/private_chefs/private_chef_grouping.dart`)
with no query and no hardcoded country — a second/third/fourth country
section appears automatically the moment a published chef with that code
exists. No editorial `display_order` field exists on `private_chefs` yet;
chefs within a country keep `getPublishedChefs`'s existing `display_name`
ascending order rather than inventing a ranking field for one chef. A
chef with no `home_country_code` at all falls into an unlabeled group
rendered last, so a data gap never crashes the grouping — not expected in
practice today (Lucas has `home_country_code = 'NL'`), but the function
handles it rather than assuming every row is complete.

**The discovery card** (`PrivateChefDiscoveryCard`,
`lib/features/private_chefs/widgets/private_chef_discovery_card.dart`)
replaces the old row entirely: a large portrait cover photo (4:5 aspect
ratio, `CsRadius.card` corners — the same "editorial, not bubbly" radius
token used elsewhere, not a new value), then `display_name` (primary),
then an optional `business_name · location` subordinate line (person
-first, matching §4/§30's identity hierarchy — a chef with no
`business_name` shows only the location, never a dangling separator),
then up to 3 quiet uppercase descriptors. The whole card is one tappable
region into the existing `PrivateChefDetailScreen` — no "View chef"
button, no score, no rating, no price badge, no decorative gold.

**Cover photo semantics.** The landing card and Chef Detail's hero now
both resolve their image from the *same* source: `private_chef_photos`'
lowest-`display_order` row is the cover, used for the landing card AND as
photo #1 of Chef Detail's hero gallery (`PrivateChefHero`, unchanged —
its existing photos/profileImageUrl/placeholder fallback order already
correctly renders a single photo with no misleading swipe affordance, so
Step 2C reused it rather than rebuilding it). Photos #2–5 remain
Detail-only story/gallery content, swipeable, cover first, `display_order`
sequenced — nothing about the 5-photo architecture or the max-5 DB
trigger changed. The landing card itself never falls back to
`profile_image_url` — only the cover photo or the large branded
placeholder (`CsImagePlaceholder`, sized to the full card, never the old
small circular avatar). `PrivateChefRepository.getCoverPhotos` resolves
covers for every chef on the landing in one batched query (never one
query per chef), mirroring `getRestaurantHistory`'s existing batched
-lookup shape.

**Location presentation.** `formatChefLocation`
(`lib/features/private_chefs/private_chef_location.dart`) prefers a full,
user-facing country name ("Breda, Netherlands") over the raw ISO code
("Breda, NL"), resolved via the same `resolveVenueCountries`/
`public.countries` helper Restaurant/Hotel already share
(`PrivateChefRepository.getCountryNames` — no new Private-Chefs-specific
country table or code→name map). Falls back to the raw code only when the
countries table has no match. This also changed Chef Detail's own hero
location line from the raw code to the resolved name, since showing
"Breda, Netherlands" on the landing card and "Breda, NL" on the very next
screen for the same chef would read as inconsistent — every other part of
Chef Detail (ABOUT/BACKGROUND/THE EXPERIENCE/CONNECT) is untouched, and
restaurant-provenance rows keep their existing raw-code format (`Rotterdam
NL`), which is a different, already-established convention for that
context.

**Descriptors.** Up to 3 quiet editorial micro-labels
(`chefDescriptors`, `lib/features/private_chefs/private_chef_descriptors.dart`),
deliberately not a marketplace filter/chip system: `PRIVATE DINING` always
shown (the one universal domain descriptor for this catalogue), `WINE
PAIRING` only when `wine_pairing_available` is true, `TRAVELS` only when
`travel_available` is true. Never invented per chef, never more than
these 3 — a larger taxonomy (tasting menus, seasonal, local produce, ...)
would need real supporting schema fields this table doesn't have and
isn't being added speculatively here.

**Media architecture — the `catalogue-media` Storage bucket.** Once the
user supplied Lucas's actual cover photograph, the pre-existing "no
Storage bucket needed" conclusion (image URLs were always a plain
`text` column, see §31) turned out to be half right: no bucket was
*structurally* required by the schema, but the project also had nowhere
of its own to host a rights-cleared image (the only existing bucket,
`visit-photos`, is private and user-scoped for personal visit
photography — architecturally wrong for public, admin-curated catalogue
content, and left untouched). `supabase/migrations/20260818150000_add_catalogue_media_storage.sql`
adds a small, deliberately reusable bucket for exactly this need:
`catalogue-media`, **public read, admin/service-role write only** —
public buckets serve objects directly over their public URL without
evaluating `storage.objects` RLS at all (so `Image.network(url)` needs
no auth), and a `select`-only policy exists for defence-in-depth on the
Storage API itself; no `insert`/`update`/`delete` policy exists for
`anon`/`authenticated` at all, so those roles are denied by default —
only the service role (used by admin import tooling, never the app)
bypasses RLS to write. Object paths follow `{entity_type}/{entity_id}/
{display_order}.{ext}` (e.g. `private-chefs/{chef_uuid}/0.jpg`) —
general enough for a future `restaurants/{id}/...` or `hotels/{id}/...`
prefix without a new bucket or migration, matching this section's own
"reusable catalogue-media concept, not a Private-Chef-only hack"
requirement. `private_chef_photos.image_url`/`private_chefs.profile_image_url`
keep their existing plain-`text` shape unchanged — they now typically
*contain* a `catalogue-media` public URL, but the column itself doesn't
know or care where the URL points.

**Lucas's cover photo — production state.** Lucas's supplied photograph
(chef whites, green apron, holding a plated dish) is uploaded to
`catalogue-media` at `private-chefs/2e2089b0-f94d-46f5-923b-4ebf9135a5a1/0.jpg`,
with exactly one `private_chef_photos` row for Lucas at `display_order =
0` (the cover). Provenance (user-supplied in-conversation, integration
date, approved use) is recorded in
`supabase/data/enrichment/private_chefs/lucas_de_jager/proposed_photos.json`
— no photographer/copyright owner/licence terms are recorded anywhere,
since none were ever stated. The original source file remains as an
internal enrichment artifact (`lucas_cover_source.jpg`, same directory)
— never bundled into Flutter assets; production runtime image loading
goes exclusively through `catalogue-media`/`private_chef_photos`. Lucas
is the first (and, as of this step, only) chef with a curated cover —
every other piece of this section (grouping, the discovery card,
descriptors, location, the large placeholder fallback) was built and
verified against the zero-photo state too, since that's what every
*future* chef starts in before their own cover is curated.

**Physical-device refinements (approved).** Three adjustments came out
of on-device review, all scoped narrowly:
- **Masthead height** — the deepGreen masthead's fixed spacing was
  trimmed (back-button top padding `xs`→`0`, the gap above the title
  `sm`→`xs`, the gap below the subtitle `xl`→`base`; 16px total) so the
  first chef photograph appears sooner, without touching typography,
  the back arrow, or SafeArea handling.
- **Chef Detail hero focal alignment** — `PrivateChefHero`'s photo now
  uses a top-biased `Alignment(0, -0.8)` (previously dead-center),
  independent of the discovery card's own separately-tuned `Alignment(0,
  -0.3)`: the hero's box is landscape-shaped while chef photography is
  typically portrait, so a naive center-crop pushed a subject's face up
  behind the iOS Dynamic Island/status-bar strip. Biasing toward the top
  of the source image keeps the natural headroom above a person's head
  in that strip instead of their face — a general fix for any hero
  photo, not tuned to Lucas's photo specifically, and the source image
  itself was never re-cropped or edited.
- **Chef Detail top navigation** — the SliverAppBar's top-center title
  (which duplicated the large `displayHero` name already shown lower in
  the same hero, and added visual competition in the same crowded top
  strip) was removed for this screen only; only the back arrow remains
  in the top strip. Restaurant/Hotel/Event Detail keep their own
  existing top-title convention — this change is scoped to Private
  Chefs' hero alone.

**Status: physical-device approved.** The editorial discovery landing,
masthead, Lucas's cover photo/crop/focal treatment, country presentation,
descriptors, and Chef Detail hero have all been reviewed on a physical
iPhone and accepted as-is. Nothing here introduces marketplace semantics
(no ratings, reviews, pricing filters, availability, booking, or search
-results framing) — the catalogue-media write model (admin/service-role
only) is also already shaped to support a future owner/admin-submitted
-then-approved content workflow (for chefs, and potentially Restaurants/
Hotels) without a schema change: it would add an approval step in front
of the same service-role write path, not a new one.
