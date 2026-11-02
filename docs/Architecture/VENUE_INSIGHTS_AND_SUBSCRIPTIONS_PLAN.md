# Venue insights, dashboards and subscriptions — plan

**Status:** proposal, 2026-11-02. Decisions 1 and 2 were taken the same
day; 3 to 6 are open. Phase 1 (the admin dashboard) is in progress; nothing
else is built.

**The idea, in the product owner's words (2026-11-02):** a hidden page on
the website with dashboards on the app's data, first for the product owner
alone. Later, venues see data about their own venue and the market (what
people search for, which cuisines in which countries, where people travel,
followers, clicks) through a subscription — a Basic and a Pro tier — after
logging in on the website with the same account as the app. This is the
business model.

---

## 1. What already exists

The foundation is further along than it looks. Most of what a venue
dashboard needs is already recorded, and the privacy rules for sharing it
are already written down.

| Data | Where | Shareable shape today |
|---|---|---|
| Page opens per venue (never in "Preview my page") | `venue_page_opens` | `venue_page_open_stats_shareable`: per month, hidden below 5 distinct visitors |
| Website, booking, phone and directions taps | `venue_link_clicks` | `venue_link_click_stats`: hidden below 5 distinct users |
| Screens opened, that a search ran, that a filter changed | `app_usage_events` | internal only |
| Followers | `follows_restaurants` / `_hotels` / `_private_chefs` | counted from the table |
| Wishlist saves | `wishlist` | counted from the table |
| Visits and stays, ratings | `visits` and related | Rankings already shows averages from 3 raters |
| Event interest, attendance, ticket taps | `event_attendance`, `event_confirmed_attendance` | counted from the tables |
| Trips and destinations | `planned_trips`, `planned_trip_destinations`, `planned_venues` | not shared |
| Members by country and age group | `profiles`, `profile_private` | `admin_get_member_insights()`, admins only, hidden below 5 |

The privacy policy already says: *"We intend to share aggregated statistics
with venues and partners"*, with groups below five unique users suppressed
and no identifiers or precise timestamps. The venue dashboards must be
built inside that promise — or the promise is changed first, openly.

Every `*_shareable` view and the suppression function
(`venue_page_open_min_unique_users()`, `venue_link_click_min_unique_users()`)
was built for exactly this feature. Nothing grants them to a client role
yet, which is right: the dashboard will reach them through checked RPCs,
never directly.

## 2. Decisions needed first

These are the product owner's to take. Each one blocks only the parts
named next to it.

1. **Search terms** (blocks "what people search for").
   `EVENTS_V2_ANALYTICS_CONTRACT.md` §8 settled that raw search text is
   never recorded, and the privacy policy says so ("never what you
   searched for"). Options:
   - **A — keep it.** Show only demand that comes from fixed choices:
     the filters people use (cuisine, country, stars, Keys), and which
     venues are opened from search. This needs `explore_filter_applied`
     to start carrying the chosen value. That is a controlled vocabulary,
     which §8 already allows for filters, but the Explore event today
     deliberately carries none.
   - **B — record matched entities only.** When a search matches a known
     cuisine, city, country or venue, record *that entity*, never the
     typed text. A search that matches nothing records nothing.
   - **C — record the text.** Not recommended: it reverses a settled
     decision and the policy, for little more than B gives.

   **Recommendation: B, then A.** It answers "what do people look for"
   in a form a venue can use, and it never stores what someone typed.
   Either way, the privacy policy's "How you use the app" paragraph
   changes before the first row is recorded.

   **Decided 2026-11-02 by the product owner: B, then A.** Raw search text
   stays unrecorded (§8 of the analytics contract stands). A search
   records the cuisine, city, country or venue it matched; filters
   record their chosen value. The privacy policy and the analytics
   contract are updated in the same change that ships the tracking, not
   before and not after.

2. **Trip destinations** (blocks "where people travel").
   Trips are personal plans, and the policy doesn't yet list them among
   what is shared in aggregate. Counting members planning a trip to a
   city or country, per month, with the usual rule (no number below 5),
   is defensible — but it is a new use and has to be named in the policy.

   **Decided 2026-11-02 by the product owner: yes, aggregated.** Members
   planning a trip to a city or country, per month, never a number below
   5, never who. The privacy policy names it before any venue sees it.

3. **What a free claimed venue sees.** Suggestion: a small free view (page
   opens and followers this month) as the shop window for Basic. Or
   nothing without a subscription.

4. **Prices, billing period, and who pays.** One subscription per venue,
   paid by the manager? A hotel with three restaurants: one subscription,
   or four? Monthly and yearly?

5. **The commercial terms for venues.** `site/terms.html` says *"Mantelier
   is free to use"*, which stays true for members. Venues need their own
   short terms of sale: subscription, cancellation, what the data is and
   isn't, and no guarantee of results.

6. **The trust line, stated once and kept** (VISION.md, Monetisation
   principles 1 and 3): *a subscription buys insight, never visibility.*
   No paid tier changes ranking, Explore, Guides, Rankings or what a
   member sees. Recommend writing it on the pricing page itself.

## 3. Architecture

```
mantelier.app (static, Cloudflare Pages)
  └─ studio.mantelier.app   ← one dashboard app, login required
        ├─ /admin           ← product owner only (is_admin)
        └─ /venue/...       ← venue managers (is_active_venue_manager + tier)
              │
              ▼  supabase-js, signed in with the app account
Supabase
  ├─ reporting RPCs (SECURITY DEFINER, aggregates only)
  ├─ rollup tables, refreshed nightly by pg_cron
  ├─ venue_subscriptions (written only by the Stripe webhook)
  └─ Edge Functions: stripe-checkout, stripe-webhook, stripe-portal
```

### 3.1 Where it lives

- **A subdomain, `studio.mantelier.app`,** rather than a hidden path on
  mantelier.app. "Hidden" is not protection — the data is protected by
  the checks in the RPCs, so a found URL shows a login and nothing else.
  A subdomain keeps the logged-in session and a stricter
  Content-Security-Policy away from the public site. Mark it `noindex`.
  It can be the same Cloudflare Pages project or a second one.
- **One dashboard app for admin and venues.** Same login, same charts and
  same code. The menu shows Admin only when `is_admin()` is true, and a
  venue picker for each venue the account manages.

### 3.2 Login

- **The same Supabase Auth accounts as the app.** Email and password,
  plus "forgot password" through the `/auth` pages the site already has.
  A venue manager signs in with the account that claimed the venue.
- **Admin requires two-factor.** Supabase Auth supports TOTP. Admin
  reports check `auth.jwt()->>'aal' = 'aal2'` in addition to `is_admin()`.
  The admin view sees unsuppressed numbers, so a stolen password alone
  should not be enough.
- **Permissions stay where they already are.** `is_admin()` for the
  admin view. `is_active_venue_manager()` plus an active subscription for
  a venue's view (CLAUDE.md: the single sources of each permission).
  Never the claims tables.

### 3.3 Data layer

- **Reports are RPCs, never table reads.** Each dashboard panel calls one
  `SECURITY DEFINER` function: `venue_report_overview(p_venue_type,
  p_venue_id, p_from, p_to)`, `admin_report_growth(...)` and so on. Each
  function:
  1. checks permission (admin, or manager of that venue);
  2. checks the tier (Basic or Pro) for that panel;
  3. returns aggregates only, with every group below 5 distinct people
     returned as null, the way `admin_get_member_insights()` does;
  4. has `revoke execute ... from public, anon` in the migration that
     creates it (CLAUDE.md).
- **Rollups, not live counts over raw events.** A nightly pg_cron job
  (the extension is now on) fills `venue_stats_daily` (opens, unique
  visitors, clicks by kind, new followers, wishlist saves, visits) and
  monthly market tables. Dashboards stay fast as the event tables grow,
  and the suppression rule lives in one place.
- **Months, not days, for venues.** The shareable views already work per
  month. Per-day numbers for a small venue can point at a single person
  ("the one visitor on Tuesday"), so venues get weekly at the finest,
  monthly by default. Admin may see daily.
- **Benchmarks only across at least 5 venues.** "Venues like yours"
  (same city, or same stars) is shown only as a median across five or
  more venues. Never another named venue's numbers.

### 3.4 Charts

No build step today: the site is plain HTML. For a first version, ES
modules plus `supabase-js` and one chart library from a CDN, pinned to an
exact version, is enough. Move to a small Vite build once there are more
than a handful of screens. Design follows the house style — ivory, deep
green, serif headings, calm charts, gold kept for stars and Keys only.

### 3.5 Payments

- **Stripe Billing** with two products (Basic, Pro). Stripe Checkout to
  start, and the Stripe customer portal to change plan, update the card,
  get invoices and cancel. Card details never touch Mantelier.
- **Tables:** `venue_subscriptions` (venue, tier, status,
  `current_period_end`, Stripe customer and subscription ids). Managers
  can read their own venue's row. Only the webhook writes, never a
  client.
- **Edge Functions:** `stripe-checkout` (checks the caller manages the
  venue, then creates the session), `stripe-webhook` (verifies Stripe's
  signature, then updates `venue_subscriptions`) and `stripe-portal`.
- **VAT:** Stripe Tax, with the venue's VAT number collected at checkout
  for EU reverse charge.
- **No in-app purchase.** Sales happen on the website only, and the
  subscription unlocks nothing inside the app — the dashboards live on
  the website. Keep it that way, and keep prices and "subscribe" links
  out of the app. Check Apple's current App Review Guidelines (3.1) again
  before launch, if a subscriber feature ever moves into the app.

## 4. What each tier sees

A starting point to react to, not settled.

### Free (claimed venue, optional — decision 3)
- Page opens this month
- Followers

### Basic
- Page opens and unique visitors per month, last 12 months
- Taps on website, booking, phone and directions
- Followers and wishlist saves: total and growth
- Visits recorded in Passports, and the Rankings average once it shows
- Your events: page opens, Interested, Going, attended, ticket taps
- Monthly email summary

### Pro — everything in Basic, plus:
- **Your audience:** members who opened or followed your page, by home
  country and age group (no number below 5)
- **Funnel:** page open → wishlist/follow → tap through → visit recorded
- **Where they found you:** search, map, Guides, Rankings, a friend's
  activity, an event (needs a `source` on `venue_detail_opened`)
- **Market demand:** cuisines and countries people filter and search for,
  per country of the member (decisions 1 and 2)
- **Travel:** members planning trips to your city or country, by month
  (decision 2)
- **Venues like yours:** your numbers next to the median of similar
  venues (5 or more)
- Longer history, CSV export, and data per event

## 5. New tracking needed

| Need | Change | Depends on |
|---|---|---|
| Where a visitor came from | a `source` on `venue_detail_opened` (search, map, guide, ranking, friend, event, notification) | — |
| What people filter on | `explore_filter_applied` carries the chosen value (controlled vocabulary) | decision 1 |
| What people search for | record the matched entity, never the text | decision 1 |
| Venue seen in results | optional, later: impressions in search and Explore | — |

Each one: a contract update in `EVENTS_V2_ANALYTICS_CONTRACT.md`, a privacy
policy update before it ships, and an app release. Old builds simply don't
send it, so every chart must handle "no data before date X".

## 6. Phases

1. **Admin dashboard (for the product owner).** `studio.mantelier.app`,
   login with 2FA, admin RPCs over what exists today: member growth,
   countries and ages, top venues by opens and taps, events funnel,
   search and filter usage counts, retention (members active again after
   30 days). No new tracking and no payments. **Ready to start.**
2. **Rollups and venue reports.** Nightly rollup tables and the
   `venue_report_*` RPCs with suppression. Tested against a local replay,
   the way every migration here is.
3. **Venue Basic, free during a pilot.** Managers of a few claimed venues
   log in and see Basic. Feedback before anyone pays.
4. **Payments and Pro.** Stripe, `venue_subscriptions`, tier checks, the
   pricing page, terms of sale. Pro panels use the new tracking from
   section 5, which ships in an app release ahead of this phase so there
   is history to show.
5. **Reports.** The monthly email to venues, through the Resend setup
   that already sends the claim notifications.

## 7. Risks

- **Small numbers.** Most venues will have few visitors at first, so
  many panels will say "fewer than 5". Pro needs volume to be worth
  paying for. The pilot (phase 3) shows when that is reached; price
  accordingly.
- **Trust.** If a member ever suspects that paying venues are shown
  more, the core of the product suffers (VISION.md). Decision 6 is the
  guard.
- **Policy drift.** Every new kind of data in a dashboard needs the
  privacy policy to say so first. One checklist item per panel.
- **An admin account with unsuppressed data.** 2FA, and nothing
  per-person on screen, even for admin — the same rule as Insights.
