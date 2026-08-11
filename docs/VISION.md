# Chasing Stars — Vision

**Status:** Living document
**Owner:** Product / Design
**Supersedes in spirit (not in force):** `docs/Vision/PRODUCT_VISION.md`, `docs/Vision/PRODUCT_RULES.md` — written under the product's former name, Michelin Passport. Their philosophy was sound and is carried forward here; this document restates and extends it under the Chasing Stars identity and adds what those documents didn't yet need to answer: design, editorial, community and monetisation principles for a product that is becoming a discovery platform, not only an archive.

> **We are not preserving restaurants. We are preserving moments — and helping people find the next one worth having.**

---

## Mission

Chasing Stars exists to help people live a more extraordinary relationship with exceptional hospitality — to discover the tables and rooms worth travelling for, and to preserve what happened when they got there.

Two verbs, in order: **discover**, then **remember**. Neither is allowed to crowd out the other. A product that only helps people find things is a listings app. A product that only helps people log things is a diary. Chasing Stars is the rare thing that does both, because for the kind of traveller we build for, discovery and memory are the same continuous story.

## Vision

Chasing Stars becomes the definitive personal companion for people who travel for food and exceptional hospitality — the one app a member opens before a trip to decide where to go, and the one they return to afterward to keep what happened. Not the biggest restaurant database in the world. The most trusted one to a small, discerning set of people who take this seriously.

In ten years, a long-time member should be able to open Chasing Stars and see a legible, beautiful record of a decade of remarkable meals and stays — and, in the same app, feel confidently pointed toward what's worth their time next. Both halves should feel like they were built by the same hand, for the same person, at the same standard.

---

## Design Principles

1. **Deep green is the home, not the accent.** The canvas is Chasing Stars, not a neutral backdrop with Chasing Stars moments scattered on top. Every screen should read as unmistakably ours within half a second, before a single word is read.
2. **Restraint is the luxury, not decoration.** Brass appears rarely and deliberately — a rating, a distinction, a single considered accent. The moment brass becomes a background, a button fill, or a default state color, it has stopped being special.
3. **Editorial typography, functional typography — never mixed up.** Cormorant Garamond speaks for the product: names, headlines, moments worth lingering on. Inter does the work: labels, metadata, controls. A screen that uses editorial type for functional text (or vice versa) reads as unconsidered, immediately.
4. **Whitespace is content.** Every screen should feel like it has room to breathe before it feels like it has enough information. When in doubt, remove a box, not add one.
5. **One screen, one canvas.** No screen should read as two products stitched together — a green header floating over an ivory page is the single most common way this app currently breaks its own rule, and it should never happen again once a screen is redesigned.
6. **Nothing should look like it shipped with the framework.** Default Material dialogs, snackbars, list tiles, and dividers are placeholders, not a finished interface. Every visible surface earns its place in the Chasing Stars visual language or it doesn't ship.
7. **Consistency compounds.** A button, a card, a filter chip, a bottom sheet should look and behave the same way everywhere they appear. Reuse the vocabulary before inventing a new word.
8. **Motion is a whisper.** Transitions exist to orient, not entertain. If an animation draws attention to itself, it's wrong for this product.

## Editorial Principles

1. **We curate, we don't crowdsource.** What Chasing Stars chooses to surface — a featured restaurant, a leading event, a discovery selection — should always be explainable by a clear, legitimate signal (a Michelin distinction, a World's 50 Best rank, a genuine editorial choice). Never a black box, never manufactured urgency.
2. **Say less, better.** One well-chosen sentence beats three generic ones. Section subtitles, empty states, and copy throughout should sound like they were written by someone who respects the reader's time and taste.
3. **Photography and typography carry the emotion; chrome should not have to.** Once real photography exists, it becomes the primary storyteller. Until then, the branded monogram and considered typography hold that role — never a stock icon standing in for craftsmanship.
4. **Content earns permanence before it earns prominence.** A Journal, guides, or editorial stories should never be shipped half-empty just to occupy a tab. An empty section is a worse first impression than no section at all.
5. **Never imply coverage we don't have.** Chasing Stars should never suggest — through empty-state copy, through absence of caveats, through confident-sounding defaults — that its catalogue is exhaustive. Confidence about what we do cover; honesty about what we don't.

## Community Principles

1. **Inspire, never compare.** This carries forward unchanged from the product's founding rules and remains the single most important constraint on every future social feature: leaderboards, streaks, and visible rankings-of-people are explicitly out of bounds unless they can be shown to inspire rather than induce anxiety or performance.
2. **Friendship is a lens on discovery, not a scoreboard.** "3 friends are going" or "someone you know loved this" should help a member decide where to go next — it should never become a metric to optimize or a status to chase.
3. **Sharing is a gift the member gives, not a growth mechanic we extract.** Every share action should exist because it makes the member's experience better (showing someone a memory, inviting someone to a table), never primarily because it acquires a new user.
4. **Privacy is the default, not a setting to find.** Nothing a member records — a visit, a note, a photo, a rating — is public unless they explicitly make it so. This is inherited directly from the founding product rules and does not change as community features grow.
5. **Community features are additive, never load-bearing.** A member with zero friends and zero social activity should still have a complete, satisfying experience. Community enriches Chasing Stars; it is never required to unlock its value.

## Monetisation Principles

1. **The member's trust is the asset; never spend it for short-term revenue.** Anything that would make a member wonder "is this recommendation genuine, or is someone paying for it?" causes damage that outlasts whatever revenue it produced.
2. **Sponsored and editorial content are never visually ambiguous.** If a partnership, a sponsored placement, or a commercial listing ever exists, it is clearly and permanently labelled as such — in the same restrained visual language as everything else, never hidden, never disguised as organic curation.
3. **Monetisation augments discovery; it never replaces it.** A "Featured Partner" is additive alongside genuine editorial selection, never a substitute for it. Organic ranking logic is never quietly rewritten to favor a paying party.
4. **Premium tiers sell depth, not access to dignity.** If a subscription or premium tier ever exists, the free experience must remain genuinely excellent — premium should unlock more (richer archive tools, deeper discovery, concierge-level touches), not gate baseline quality behind a paywall.
5. **We build the separation before we build the revenue.** Selection logic (what gets shown) and rendering (how it looks) must stay architecturally separate from day one, specifically so that a future commercial layer can be introduced cleanly, later, without a rewrite and without compromising principle 1.

## Content Philosophy

- **Objective data belongs to the world; personal experience belongs to the member.** A restaurant's Michelin star is a fact anyone can see. A member's note about the night they got engaged there is theirs alone. The product must never blur this line — carried forward directly from the founding product rules.
- **History is never rewritten.** Awards, ranks, and stars change over time; Chasing Stars keeps the record exact for the year it happened, always. A member's memory of a two-star meal doesn't retroactively become a one-star memory because the restaurant lost a star since.
- **Closed doesn't mean deleted.** A restaurant that closes remains in a member's archive, clearly marked, permanently accessible. The archive is the point; it cannot have holes torn in it by the world moving on.
- **Discovery content is deterministic and explainable until it's genuinely editorial.** Until Chasing Stars has real editorial or community signal to work with, every "featured" or "worth the journey" selection must be traceable to a clear rule (distinction, rank, recency) — never a fabricated or arbitrary ordering presented as curation.
- **No content is manufactured to fill a gap.** No fake reviews, no invented articles, no placeholder editorial voice pretending to be a real one. An honest "coming soon" (or nothing at all) is always preferable to fabricated content.

## What Chasing Stars Should Never Become

- **A restaurant review platform.** We are not Yelp or TripAdvisor for fine dining. We do not host public star-ratings-of-venues-by-strangers as a core mechanic.
- **A booking or ticketing platform.** We may link out to official reservation/ticketing systems; we do not become the transaction layer ourselves.
- **A discount or deals platform.** Nothing about Chasing Stars should ever feel like a coupon app. Exclusivity is about craft and curation, never about price.
- **A generic social network.** Feeds, likes, follower counts, and public leaderboards-of-people are explicitly against the founding community principles above.
- **A database with a nice font.** Visual polish is not the finish line — if a screen is technically complete but feels like a spreadsheet wearing a nice typeface, it is not done.
- **Loud.** No gamified badge-explosions, no aggressive push-notification cadence, no urgency-manufacturing ("Only 2 spots left!"). Chasing Stars earns attention by being worth returning to, never by demanding it.
- **A platform where money quietly changes what's true.** See Monetisation Principle 1. This is the one principle that, if ever violated, would undo everything else this document asks for.

---

## Long-Term Roadmap

This is a direction, not a committed schedule — sequencing and scope are product decisions to be made deliberately, screen by screen, the same way Passport and Explore were.

**Horizon 1 — Finish the redesign.** Every screen speaks the same Chasing Stars visual language: deep green as home, Cormorant/Inter typography discipline, the shared `Cs*` component vocabulary, zero default-Material chrome left visible. This includes the entire authentication flow, every detail screen, Rankings, Wishlist, Trips, Profile, and every bottom sheet and dialog in the app. Nothing ships that still looks like it belongs to the old product.

**Horizon 2 — Make discovery whole.** Extend what Explore started: real photography once available, a genuine Journal (editorial stories, Road to Michelin, destination guides) built on real content rather than an empty tab, richer event social-readiness (interested/going, without becoming a scoreboard), and a first pass at true editorial/curated "featured" selection to replace the deterministic placeholder rules documented in `discovery_selectors.dart`.

**Horizon 3 — Deepen the archive.** Restaurant and hotel collections a member can curate themselves ("My Tokyo list"), richer photo storytelling per visit, a more complete Profile that feels like a personal culinary CV rather than a settings screen, and journey/trip planning promoted from a buried feature to a first-class, discoverable part of the product.

**Horizon 4 — Community, carefully.** Friend activity woven into discovery (never into competition), shared trips, the ability to see where people you trust have been — every one of these built against the Community Principles above, none of them shipped before the principles can actually be enforced in the design.

**Horizon 5 — Sustainable commercial layer.** Once the discovery and editorial foundation is genuinely strong, introduce monetisation exactly as described above: clearly labelled, additive, never corrosive to trust. Revenue is a consequence of having built something members truly value — never the thing shaping what gets shown to them.

Every horizon answers the same question the founding rules already asked: **does this help someone discover or preserve an extraordinary experience?** If a future feature can't answer yes, it doesn't belong here, however tempting it is to build.
